# Day 4 — Phase 1 Synthesis

Read this before starting the lab. Budget: 20 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Trace the full traffic path from an internet client to an EC2 instance, naming every hop and decision point
- Explain how an ALB health check failure and an ASG health check interact, and why the health check type setting is decisive
- Diagnose a 502 error using the correct tool at each step of the trace
- Describe what instance refresh does and how `min_healthy_percentage` controls rollout safety
- Explain what the Terraform outputs `alb_arn`, `alb_sg_id`, and `http_listener_arn` represent and why Phase 2 needs all three

---

## The end-to-end traffic path mental model

Before verifying any individual component, internalise the complete path you will trace every time something breaks:

> **Phase 1 builds one end-to-end traffic path: internet → ALB (routing decision at L7) →
> target group → EC2 fleet (ASG manages count and health). Understanding every hop in
> this path is what makes debugging fast.**

When a request fails, the failure is at a specific hop. Your job is to narrow down which
hop as fast as possible. Knowing the complete path cold is what allows you to start at the
right end rather than guessing.

---

## The end-to-end path

Walk every request through these six hops:

1. **Client DNS resolves the ALB name.** The ALB DNS name resolves to the ALB's public IP
   addresses in the Availability Zones it spans. If this step fails: check the ALB is in
   the Active state and that DNS propagation has completed.
2. **Request hits the ALB in the public subnet.** The ALB security group must allow inbound
   TCP 80 (and 443) from `0.0.0.0/0`. If blocked here: the client receives a connection
   timeout, not a 502.
3. **ALB evaluates listener rules.** The HTTP listener on port 80 evaluates rules in priority
   order. The default rule forwards to the target group. If no default rule is set or the
   listener is misconfigured: ALB returns 503.
4. **ALB selects a healthy target from the target group.** The target group must have at
   least one healthy target registered. If all targets are unhealthy or the target group is
   empty: ALB returns 503.
5. **ALB forwards the request to the EC2 instance in the private subnet on port 80.** The
   EC2 security group must allow inbound TCP 80 from the ALB security group ID. If the rule
   is missing or uses the wrong source: the request is dropped at the ENI and ALB returns
   502.
6. **Response returns via ALB to the client.** The connection is stateful at the ALB; the
   EC2 instance sends the response back through the same TCP connection. ALB streams the
   response to the client.

Knowing these six hops turns a 502 investigation into a checklist rather than a guessing game.

---

## How ALB and ASG health checks interact

The ALB target group and the ASG maintain independent health states for the same EC2
instance. How they interact is the most important operational concept in Phase 1.

**The ELB health check path:**
The ALB performs HTTP health checks against registered EC2 instances. When a check fails,
the ALB marks the target as unhealthy and stops routing requests to it. If the ASG is
configured with `health_check_type = "ELB"`, the ASG reads the ALB target health. When the
ALB marks an instance unhealthy, the ASG terminates the instance and launches a replacement.
The fleet self-heals without manual intervention.

**The trap — EC2 health check type:**
If the ASG is configured with `health_check_type = "EC2"` (the default), the ASG checks only
whether the instance is in RUNNING state — a hypervisor-level signal with no visibility into
your application. A crashed nginx or OOM-killed process is invisible: the instance is still
RUNNING, so the ASG retains it. The ALB marks the target unhealthy and stops routing to it,
but the ASG never terminates the instance. The broken instance sits idle consuming capacity
while the fleet operates short of its true desired count.

**The rule:** Always set `health_check_type = "ELB"` on any ASG that sits behind a load
balancer. This is the single most important health check configuration decision in Phase 1.
The EC2 health check is appropriate only when there is no load balancer at all.

**Grace period interaction:**
The `health_check_grace_period` delays health check evaluation for a defined window after
instance launch. Set it to at least the full bootstrap time (including application startup).
Too short: ASG terminates a still-booting instance; the replacement also fails; an endless
replace loop burns capacity indefinitely. Too long: a genuinely failed instance escapes
detection for extra minutes before replacement begins.

---

## The 502 root cause checklist

A 502 means the ALB received a valid request, forwarded it to a target, and either got no
response or got an invalid response. Work through these four causes in order.

**Cause 1: Target security group blocks port 80 from the ALB security group.**
The EC2 security group must have an inbound rule for TCP 80 whose source is the ALB security
group ID. If the rule is missing, uses `0.0.0.0/0`, or references the wrong SG, the ALB
connection attempt is dropped at the ENI and ALB reports 502.
Tool: Console → EC2 → Security Groups → select the EC2 SG → Inbound rules tab.

**Cause 2: The application is not listening on port 80.**
The instance may be healthy from the hypervisor perspective but nothing is bound to port 80.
This happens when nginx fails to start during user data execution, or when the application
configuration points to a different port.
Tool: Console → EC2 → select instance → Actions → Monitor and troubleshoot → Get system log.
Alternatively, from a bastion: `ss -tlnp | grep :80`.

**Cause 3: The health check path returns a non-200 response.**
The target group health check path (e.g. `/health`) returns 404, 500, or a redirect. The
ALB marks the target unhealthy. A target group with zero healthy targets returns 503;
a partially healthy target group can produce intermittent 502 when an unhealthy target is
selected just before deregistration completes.
Tool: Console → EC2 → Target Groups → select the target group → Targets tab → inspect
per-instance health status and the last health check response code.

**Cause 4: Instance still bootstrapping inside the grace period.**
The instance passed the lifecycle hook and entered InService, but the application has not
finished starting. Requests arrive before the app is ready and return connection refused,
which the ALB reports to the client as 502.
Tool: Target group Targets tab shows the instance as "Initial." Compare the health check
grace period setting on the ASG against the measured bootstrap time in the EC2 system log.

---

## Terraform outputs and why they matter

Phase 1 produces three Terraform outputs that Phase 2 consumes directly. Understanding what
each one represents makes the module composition clear before you write a single `.tf` file.

**`alb_arn`** — the ARN of the Application Load Balancer. Phase 2 uses this in CodeDeploy
deployment group configuration and in any CloudWatch Alarm that targets request metrics on
the ALB. Without this output, Phase 2 would need a data source lookup by name — fragile
and order-dependent.

**`alb_sg_id`** — the security group ID attached to the ALB. This is the most important
cross-phase dependency. Phase 2 creates a security group for ECS tasks and adds an inbound
rule with source `alb_sg_id`, ensuring only the ALB can reach the tasks. Any other source
exposes ECS tasks beyond the ALB, bypassing listener rules and WAF.

**`http_listener_arn`** — the ARN of the ALB's HTTP listener on port 80. Phase 2 creates an
`aws_lb_listener_rule` resource that adds the `/api/*` routing rule to this listener.
`aws_lb_listener_rule` requires the listener ARN as a mandatory argument — without this
output, Phase 2 cannot attach its rule to the correct listener.

**How module outputs wire phases together:**

```hcl
module "phase1" { ... }

module "phase2" {
  alb_sg_id         = module.phase1.alb_sg_id
  http_listener_arn = module.phase1.http_listener_arn
  alb_arn           = module.phase1.alb_arn
}
```

Terraform resolves these references at plan time. If Phase 1 has not been applied,
`alb_sg_id` is an unknown value and Phase 2 plan shows `(known after apply)` for all
dependent resources. Apply Phase 1 first, verify with `terraform output alb_dns_name`,
then apply Phase 2.

---

## Best practices

1. Always set `health_check_type = "ELB"` on ASGs behind a load balancer — EC2 health check
   is blind to application failures and silently retains broken instances.
2. Set `health_check_grace_period` to at least the full bootstrap time including application
   startup — too short causes an endless terminate/replace loop.
3. ALB security group: allow TCP 80 and 443 from `0.0.0.0/0`. EC2 security group: allow
   TCP 80 only from the ALB security group ID, never from `0.0.0.0/0` — any other source
   bypasses the ALB entirely.
4. Run `terraform output alb_dns_name` after applying Phase 1 and confirm the ALB returns
   a 200 before building Phase 2 on top of it.

---

## Common pitfalls

- **EC2 health check type masking a crashed application.** The ASG sees the instance as
  RUNNING; the ALB marks it unhealthy; requests to that target return 502 while the ASG
  never replaces it. The fleet console looks healthy. The target group console does not.
- **EC2 security group allows `0.0.0.0/0` on port 80.** Any client that discovers the
  instance's IP can bypass the ALB, circumventing listener rules, WAF, and SSL termination.
- **Health check grace period set to 0.** Instances are terminated before their applications
  start; every replacement also fails; the ASG spends capacity in an endless loop and the
  fleet never reaches a healthy state.
- **`target_group_arns` not set on the ASG.** Instances launch and report InService, but
  the target group stays empty — the ALB returns 503 for every request. The EC2 and ASG
  consoles show green; only the target group Targets tab reveals that no targets are
  registered.

---

## Exercises

Answer before starting the lab:

1. Your ALB shows 503. The target group shows 0 healthy targets. The EC2 instances show
   Running in the EC2 console. List your next 3 diagnostic steps in order, naming the
   exact tool or console page for each step.
2. You updated the launch template to use a new AMI. Name two ways to apply it to the
   running instances in the ASG without taking the service offline.
3. Phase 2 needs to add a `/api/*` routing rule to the ALB. Which two Phase 1 Terraform
   outputs does it need, and what is each one used for in Phase 2?

## Lab reference

Follow Day 4 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 4 — Phase 1 Synthesis
End-to-end path in my own words (6 hops): ...
What breaks when ASG health check type is EC2 instead of ELB: ...
Break-it exercise — 502 root cause I introduced and how I found it: ...
```
