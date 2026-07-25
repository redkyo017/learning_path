# Day 7 — Phase 2 Synthesis

Read this before starting the lab. Budget: 20 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain how one ALB serves two distinct backends using listener rule priorities
- Explain why `target_type` must be `"ip"` for Fargate targets and what silently breaks
  when it is set to `"instance"`
- Describe the interaction between `health_check_grace_period_seconds` on the ECS service
  and ALB target group health checks, and what happens when the grace period is too short
- Trace a complete request through the combined Phase 1 and Phase 2 stack, branching on
  path to the correct backend

---

## The dual-backend mental model

Before tracing a single request, fix this model in place:

> **One ALB, two target groups, two backends. The routing rule determines which backend
> receives each request. This is the production pattern for running both legacy (EC2) and
> modern (container) workloads behind the same load balancer during a migration.**

The ALB is completely stateless with respect to which backend it uses. It evaluates rules
on every request independently, routes to the appropriate target group, and never "knows"
whether the response came from EC2 or Fargate. This makes gradual migration safe: you
control the traffic split entirely through listener rules, without changing clients or
DNS.

---

## One ALB, two target groups

A single ALB listener can have multiple rules, each routing to a different target group.
The Phase 1 + Phase 2 combined stack uses two rules on the same HTTP listener (port 80):

| Rule priority | Condition | Target group | `target_type` |
|---|---|---|---|
| 10 | Path `/api/*` | ECS Fargate target group | `ip` |
| Default | All other requests | EC2 ASG target group | `instance` |

**How rule evaluation works:**
ALB evaluates rules from lowest priority number to highest. Priority 10 is evaluated
first. If the request path matches `/api/*`, ALB routes to the ECS target group and stops
evaluating further rules. If the path does not match, ALB falls through to the default
rule and routes to the EC2 ASG target group.

Both target groups share the same ALB, the same listener port, and the same ALB
security group. They are logically separate — each has its own health check configuration,
deregistration delay, and registered targets. A health check failure in one target group
has no effect on the other.

The ALB itself is not aware of any application logic. It reads the request path and
forwards. The routing decision is entirely determined by the listener rule configuration.

---

## target_type = "ip" vs "instance"

This is the most common Terraform mistake in Phase 2.

**Why Fargate requires `target_type = "ip"`:**
Fargate tasks have no EC2 instance ID. They have a private ENI with a private IP address,
and nothing else. When ECS registers a Fargate task as a target, it registers the IP
address of the task's ENI. The ALB routes directly to that IP. There is no EC2 instance
involved at any point in the request path.

**What happens when you set `target_type = "instance"` for Fargate:**
ECS attempts to register the task but cannot produce an EC2 instance ID. The registration
call is silently dropped. The target group remains empty. The ALB has no targets for
`/api/*` and returns 503 for every matching request. No error appears in the ECS console
or CloudWatch Events. The only visible symptom is the target group Targets tab showing
zero registered targets.

This failure mode is especially insidious because the ECS service reports as ACTIVE with
the correct desired count. The tasks are running. Everything looks healthy in ECS. The
failure is only visible in the target group.

**For EC2 ASG targets (`target_type = "instance"`):**
EC2 instances have instance IDs. The ASG registers instances by ID when they enter
InService. This is the correct and only valid option when your targets are EC2 instances.

**Rule:** `target_type = "ip"` for Fargate. `target_type = "instance"` for EC2. Never mix them.

---

## health_check_grace_period interaction

The grace period and the target group health check operate against each other. Calibrating
them correctly is what separates a stable deployment from an endless restart loop.

**The sequence when a new ECS task starts:**

1. ECS launches the task and the container starts.
2. ECS registers the task's IP in the ALB target group.
3. The ALB target group begins health checks immediately.
4. If the app needs 30 seconds to start but `health_check_grace_period_seconds = 0`:
   the first health check hits the task before the app is listening. The check fails.
   ECS receives unhealthy status from the target group. ECS stops the task and launches
   a replacement. The replacement also fails the grace period check. The service never
   stabilises.
5. If `health_check_grace_period_seconds = 60` (or ≥ app startup time): ECS ignores
   unhealthy status from the target group for 60 seconds after task start. The app has
   time to start and begin responding to health checks. After the grace period, health
   checks are evaluated normally.

**Setting the correct value:**
Measure the actual time from container start to first successful health check response
under normal conditions. Set `health_check_grace_period_seconds` to at least 2× that
value. The cost of a value that is too large is only a slightly longer detection window
for genuinely failed tasks. The cost of a value that is too small is an unresolvable
restart loop.

**The relationship to ALB health check settings:**
The target group health check `healthy_threshold` (default: 3 consecutive checks) and
`interval` (default: 30 seconds) mean that a task takes at least 90 seconds to be marked
healthy under default settings. The grace period must cover the app startup time plus
enough time for the first successful health check to register. For most applications,
120 seconds is a safe starting value.

---

## Tracing a request through Phase 1 and Phase 2

Walk every request through this combined path:

1. **Client request arrives at the ALB DNS name.** The ALB resolves to public IPs across
   multiple AZs. The client connects to the nearest AZ endpoint.
2. **ALB evaluates listener rules.** The HTTP listener checks rules in priority order.
   Does the request path match `/api/*`?
3a. **YES — path matches `/api/*`:** ALB selects a healthy task IP from the ECS target
   group. It forwards the request to the Fargate task's ENI on the container port.
   The task processes the request and returns the response via the same ALB connection.
3b. **NO — path does not match `/api/*`:** The default rule applies. ALB selects a
   healthy EC2 instance from the ASG target group. It forwards the request to the EC2
   instance in the private subnet on port 80. The instance processes the request and
   returns the response via the ALB.
4. **Response returns to the client via ALB.** The client is unaware of which backend
   served the request.

**Debug routing for the combined stack:**

| Symptom | Where to look |
|---|---|
| `/api/` returns 502 | ECS target group health status; task's CloudWatch Logs |
| `/api/` returns 503 | ECS target group Targets tab — zero healthy targets (check `target_type`) |
| `/` returns 502 | EC2 ASG target group health status; EC2 system log |
| `/` returns 503 | EC2 ASG target group Targets tab — check `target_group_arns` on the ASG |
| Both paths return 503 | ALB security group inbound rules; listener configuration |

---

## Terraform module composition

Phase 2 depends on three outputs from Phase 1. If Phase 1 has not been applied, Phase 2
will fail with "Error: Reference to undeclared resource" or produce a plan where all
dependent resource IDs show `(known after apply)`.

**How the modules reference each other:**

```hcl
module "phase1" {
  source = "./terraform/phase1_compute"
  # ... variables
}

module "phase2" {
  source            = "./terraform/phase2_containers"
  alb_sg_id         = module.phase1.alb_sg_id
  http_listener_arn = module.phase1.http_listener_arn
  alb_arn           = module.phase1.alb_arn
}
```

**What each output enables in Phase 2:**

- `alb_sg_id` — used as the ingress source in the ECS task security group. The inbound
  rule reads: allow TCP `containerPort` from `alb_sg_id`. Without this, the ALB cannot
  reach the task.
- `http_listener_arn` — the `aws_lb_listener_rule` resource for `/api/*` requires the
  ARN of the listener it attaches to. This is the only way to add a rule to an existing
  listener without recreating it.
- `alb_arn` — used in the ECS CodeDeploy deployment group and in CloudWatch Alarms scoped
  to this specific ALB.

**Apply order:**
Always apply Phase 1 first and verify with `terraform output`. Apply Phase 2 only after
Phase 1 outputs contain real resource IDs. In a root module that wires both, Terraform
resolves the dependency graph automatically and applies Phase 1 before Phase 2.

---

## Best practices

1. Use different path prefixes for each backend (`/api/*`, `/app/*`, `/health`) and never
   configure two rules that match the same path — the rule with the lower priority number
   always wins and the higher priority rule is silently ignored.
2. Keep target groups separate even when they serve similar traffic — sharing a target group
   between EC2 and Fargate backends creates invisible coupling and makes `target_type`
   changes impossible without recreation.
3. Always verify both routing paths work end-to-end (`curl /api/health` and `curl /health`)
   before declaring a Phase 2 deployment complete.

---

## Common pitfalls

- **`target_type = "instance"` for Fargate targets.** ECS silently fails to register tasks;
  the target group stays empty; all `/api/*` requests return 503 with no obvious error in
  ECS console or CloudWatch Events. The only visible symptom is the target group Targets
  tab showing zero registered targets.
- **Listener rule priority collision.** If two listener rules share the same priority
  number, the ALB API returns a `DuplicatePriority` error and the conflicting rule is
  rejected. Phase 1 may already use certain priorities — check existing rule priorities
  before adding Phase 2 rules.
- **Applying Phase 2 before Phase 1 outputs exist.** The `http_listener_arn` and
  `alb_sg_id` references resolve to unknown values; Terraform produces a plan it cannot
  apply or creates resources with missing security group rules.

---

## Exercises

Answer before starting the lab:

1. Your ALB returns 502 for `/api/users` but returns 200 for `/`. List your diagnostic
   steps in order, naming the exact console page or tool at each step.
2. Why can't you use `target_type = "instance"` for Fargate tasks? What is the only
   resource identifier a Fargate task exposes to the ALB registration mechanism?
3. `module.phase2` has `depends_on = [module.phase1]` in the root module. Is this
   necessary given that `module.phase2` already references `module.phase1` outputs?
   Explain why Terraform's dependency resolution handles this without the explicit
   `depends_on`.

## Lab reference

Follow Day 7 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 7 — Phase 2 Synthesis
How the ALB routes to two different backends in my own words: ...
What silently breaks when target_type is wrong for Fargate: ...
Break-it exercise — which route I broke and what the target group showed: ...
```
