# Day 6 — ECS, ALB, and Service Discovery

Read this before starting the lab. Budget: 25 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain how ECS registers and deregisters task IP addresses with ALB target groups
- Explain what deregistration delay does and describe the 502 it prevents when set correctly
- Describe how AWS Cloud Map provides service discovery for container-to-container traffic
- Distinguish a blue/green CodeDeploy deployment from a rolling update and name the
  situation where each is the right choice
- Configure ECS task auto-scaling using target tracking on the correct metric for web workloads

---

## The ephemeral IP mental model

Before working through any ECS + ALB concept, fix this model in place:

> **Containers are ephemeral — their IP addresses change on every deploy. The ALB target
> group is the mechanism that tracks which task IPs are currently healthy. Deregistration
> delay is the mechanism that ensures in-flight requests complete before a task disappears.**

Without this model, the sequence of events during a deploy looks like chaos — tasks
launching and stopping, IPs appearing and disappearing. With the model, every event has a
clear purpose: new IPs are registered and health-checked before old IPs are drained and
released.

---

## ALB and ECS integration

ECS and ALB integrate natively through the ECS service configuration. You do not manually
register targets — ECS handles registration and deregistration as part of the task lifecycle.

**On task launch:**
1. ECS starts the new Fargate task and assigns it a private IP (the task's ENI IP).
2. ECS registers this IP as a target in the target group (`target_type = "ip"`).
3. The ALB target group begins its health check sequence against the registered IP.
4. After the task passes the configured `healthy_threshold` (default: 3 consecutive
   successes), ALB marks it healthy and starts sending requests to it.

**On task stop (during deploy or scale-in):**
1. ECS marks the task as draining in the target group.
2. ALB immediately stops routing **new** requests to the draining target.
3. ALB waits for `deregistration_delay` seconds to allow in-flight requests to complete.
4. After the delay, ALB removes the target from the group.
5. ECS stops the task.

`health_check_grace_period_seconds` on the ECS service and ALB `deregistration_delay` on
the target group are two separate timers that operate at opposite ends of the task
lifecycle. Grace period protects task startup; deregistration delay protects task shutdown.
Both must be calibrated to your application's behaviour.

---

## Deregistration delay

Deregistration delay is the most important Day 6 concept. Getting it wrong causes 502
errors during every deploy.

**The full timeline during a rolling deploy:**

1. Deploy is triggered — ECS service begins replacing old tasks with new ones.
2. Old task is marked "draining" in the target group.
3. ALB stops sending new requests to the draining task.
4. ALB waits `deregistration_delay` seconds (default: 300 seconds on ALB, but ECS service
   configuration often overrides this lower).
5. After the delay, ALB removes the target from the target group.
6. ECS stops the task.

**Why 502s happen when the delay is too short:**
Steps 3 and 5 are not instantaneous. A request that arrived at the ALB 1 second before
the task was marked draining is already in flight to that task. If the task is stopped
before the response returns (because `deregistration_delay` is smaller than the request
duration), the ALB receives a connection reset and returns 502 to the client.

**Setting the value:**
- REST API requests (sub-second): 15–30 seconds is sufficient.
- File uploads or downloads: set to the maximum expected transfer duration.
- WebSocket connections or streaming responses: set to at least the maximum connection
  lifetime, or implement graceful shutdown in the application to close connections before
  the task exits.
- Production default for most web services: 30–60 seconds.

**Configuring it in Terraform:**
The `deregistration_delay` attribute is on the `aws_lb_target_group` resource, not on
the ECS service. It is easy to miss because the ECS service configuration does not
surface it. Always verify the target group's deregistration delay when debugging 502s
during deploys.

---

## AWS Cloud Map service discovery

Cloud Map provides DNS-based service discovery for container-to-container traffic inside
a VPC. It is ECS's native answer to "how does service A find service B's current IPs
without an ALB?"

**How it works:**
When a Fargate task starts, ECS registers an A record (or SRV record) in a Cloud Map
private namespace. Other services in the same VPC resolve the namespace hostname
to get the current task IPs. When a task stops, ECS deregisters the record. The DNS
TTL on Cloud Map records is 0 by default — resolvers always get a fresh answer.

**Example:** Service B is registered in namespace `internal.myapp.local`. Service A
calls `http://api.internal.myapp.local/users` — the DNS resolver returns the IPs of
all currently healthy `api` tasks. No sidecar, no service mesh, no extra infrastructure.

**When to use Cloud Map instead of ALB:**
- Service-to-service HTTP calls within the VPC where path-based routing is not needed
- Microservices that should not be externally reachable
- When ALB overhead (cost, latency, TLS termination) is not justified for internal traffic
- High-frequency inter-service calls where every millisecond matters

**When to keep ALB:**
- External-facing traffic (internet clients)
- Services that need path-based routing, WAF, or SSL termination
- Services that need ALB access logs for billing or compliance

ECS integrates Cloud Map natively — add `service_registries` to the ECS service
resource in Terraform and ECS handles registration/deregistration automatically.

---

## Blue/green deployment with CodeDeploy

A rolling update deploys new tasks gradually, but for a window of time both old and new
task versions are receiving traffic simultaneously and old tasks are being replaced while
in service. Blue/green eliminates that window.

**How blue/green works:**
- **Blue target group:** currently serving production traffic.
- **Green target group:** new version deployed here, not yet receiving traffic.
- The ALB listener has two rules pointing to each target group.
- CodeDeploy controls the traffic shift between them.

**Traffic shift strategies:**
- `LINEAR_10PERCENT_EVERY_1MINUTE` — shifts 10% of traffic per minute; fully shifted in
  10 minutes. Use for gradual validation of a new version under real load.
- `CANARY_10PERCENT_5MINUTES` — shifts 10% immediately, waits 5 minutes for error metrics
  to stabilise, then shifts the remaining 90%. Use when you want early signals quickly.
- `ALL_AT_ONCE` — shifts 100% immediately. Same risk profile as a rolling deploy but
  with instant rollback available.

**Why rollback is fast:**
The blue target group keeps running throughout the entire deployment. If the green version
fails (CloudWatch alarms trigger, or you manually stop the deployment), CodeDeploy shifts
traffic back to blue in seconds — the old version was never stopped. Compare this to a
rolling deploy, where rolled-back instances must be re-launched.

**When to use blue/green:**
- Production services where zero 502s during deploy is a hard requirement
- Services with low tolerance for error rate spikes during updates
- When instant rollback (not gradual rollback) is required

**When rolling update is sufficient:**
- Internal services or staging environments
- Services with short deregistration delays where the 502 window during rolling updates
  is acceptable
- When the added operational complexity of CodeDeploy is not justified

---

## Task auto-scaling

ECS services support Application Auto Scaling, which adjusts `desired_count` automatically
based on metrics.

**Target tracking policies (recommended):**
- `ALBRequestCountPerTarget` — tracks requests per task. The most accurate metric for
  web workloads because it reflects actual traffic load, not a proxy like CPU. If requests
  per task exceed the target, ECS adds tasks; if below, ECS removes tasks (after a
  15-minute stabilisation window).
- `ECSServiceAverageCPUUtilization` — useful for CPU-bound services. Set the target to
  60–70% to leave headroom before a spike exhausts capacity.
- `ECSServiceAverageMemoryUtilization` — use for services with predictable memory growth
  patterns (e.g. caches). Less reactive than CPU or request count because memory grows
  gradually.

**Scale-in protection:**
Individual tasks can be marked as protected from scale-in (`aws ecs update-container-instances-state`
or via the ECS API). Useful for tasks running long jobs that should not be interrupted
mid-execution. The task continues to run until you remove the protection flag.

**Minimum and maximum capacity:**
Always set a minimum (typically 2 for production — one task is not HA) and a maximum that
reflects both your cost ceiling and downstream capacity (RDS connection limits, SQS
throughput, etc.).

---

## Best practices

1. Set `deregistration_delay` to a minimum of 30–60 seconds for any service handling
   synchronous HTTP requests — this is the primary defence against 502s during rolling
   deploys.
2. Use rolling update as the default deployment strategy; use blue/green only when the
   service requires zero 502s during deploy and you need instant, full-fleet rollback.
3. Use Cloud Map for internal microservice-to-microservice traffic; use ALB for
   external-facing services, services that need WAF, or services where access logs are
   required.
4. Scale on `ALBRequestCountPerTarget` for web workloads — it reflects actual traffic
   load more directly than CPU utilisation.

---

## Common pitfalls

- **`deregistration_delay` shorter than request duration.** In-flight requests are reset
  when the task stops; clients receive 502 for the exact window between deregistration and
  task stop. Always set it longer than your P99 request latency.
- **`health_check_grace_period_seconds = 0` on the ECS service.** ECS receives unhealthy
  status from the ALB target group immediately after task start and stops the task before
  the application is ready. The service never stabilises — it keeps launching and stopping
  tasks.
- **Blue/green rollback not configured before a deployment starts.** If a deployment fails
  mid-shift and CodeDeploy has no rollback alarm or manual intervention plan, the
  deployment stalls at partial traffic shift. Define CloudWatch alarms that trigger
  automatic rollback before the first production blue/green deployment.
- **Forgetting to grant ECS service permissions to the CodeDeploy IAM role.** CodeDeploy
  must be able to describe and update ECS services and target groups. If the role is
  missing `ecs:DescribeServices`, `ecs:UpdateService`, or `elasticloadbalancing:*`
  permissions, the deployment fails immediately with AccessDenied.

---

## Exercises

Answer before starting the lab:

1. Your ECS rolling deploy causes 502 errors for about 10 seconds. The new tasks are
   healthy and the old tasks are running. What is the most likely cause? What is the fix?
2. You have 20 microservices that communicate over HTTP. You do not want to create 20
   internal ALBs. What service discovery mechanism would you use, and what ECS feature
   handles registration and deregistration automatically?
3. Your CodeDeploy blue/green deployment is stuck at 10% traffic shifted to the green
   target group. The deploy is not progressing. How do you roll back, and why is rollback
   fast compared to a rolling update?

## Lab reference

Follow Day 6 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 6 — ECS, ALB, and Service Discovery
Deregistration delay in my own words — what it prevents: ...
When I would use Cloud Map instead of ALB for service-to-service traffic: ...
Break-it exercise — short deregistration delay 502 and how I observed it: ...
```
