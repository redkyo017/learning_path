# Day 3 — Auto Scaling Groups

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what a lifecycle hook does and identify the two transitions where hooks can be inserted
- Choose the correct scaling policy type (target tracking, step, scheduled) for a given load pattern
- Describe instance refresh and the role of `min_healthy_percentage` in a zero-downtime rollout
- Explain why ELB health check type is almost always preferable to EC2 health check for web workloads
- Identify when a warm pool reduces scale-out latency and when it adds unnecessary cost
- Trace the sequence of ASG events when a lifecycle hook abandons (times out without CONTINUE)

---

## The fleet manager mental model

Before memorising any scaling policy, internalise one idea you will return to
throughout this day:

> **An ASG is a fleet manager, not just an autoscaler. It owns the entire
> instance lifecycle from launch to termination. Lifecycle hooks are the
> mechanism by which YOUR code participates in that lifecycle — without hooks,
> ASG makes all lifecycle decisions unilaterally.**

Every ASG capability — scaling policies, health checks, instance refresh, warm
pools — is an extension of this fleet management role. Lifecycle hooks give
you a voice at the two moments that matter most: just before an instance joins
the fleet, and just before one is removed.

When something breaks, ask: which fleet management decision was made, and was
it the correct one given the configuration in place?

---

## The instance lifecycle

An EC2 instance in an ASG passes through a defined sequence of states. Without
lifecycle hooks the path is direct: `Pending → InService` on launch, and
`Terminating → Terminated` on removal. With hooks, two wait states are
inserted:

```
Pending → Pending:Wait (launch hook) → Pending:Proceed → InService
InService → Terminating → Terminating:Wait (termination hook) → Terminating:Proceed → Terminated
```

**The critical insight:** ASG does not wait for your application to be ready
unless you have a lifecycle hook or an ELB health check. An instance moves to
InService as soon as the launch hook completes — or immediately if there is no
hook. Without a hook, an instance that takes 90 seconds to bootstrap will
receive traffic after roughly 60 seconds and return 502 errors for the
remaining 30 seconds.

This is the most common ASG misconfiguration in production. The fix is a
launch lifecycle hook that blocks InService until your application signals
it is ready.

---

## Lifecycle hooks in depth

A lifecycle hook pauses the instance at a wait state and gives your code a
window to act. There are two hook types:

**`autoscaling:EC2_INSTANCE_LAUNCHING`** fires after the instance launches but
before it enters InService. Use this hook to pull configuration from SSM or S3,
join a service mesh, register with an external service registry, or run
application-level health checks before the instance receives traffic.

**`autoscaling:EC2_INSTANCE_TERMINATING`** fires after the instance is
deregistered from the load balancer but before it is terminated. Use this hook
to flush in-memory queues, deregister from a service registry, drain
connections, or ship final logs to an aggregation service.

Key parameters for both hook types:

| Parameter | Purpose | Default | Range |
|---|---|---|---|
| Heartbeat timeout | Window to call complete-lifecycle-action | 3600 s | 30–7200 s |
| Default result | What happens if the heartbeat times out | ABANDON | CONTINUE or ABANDON |

**Default result matters more than most engineers realise.** On a launch hook,
ABANDON terminates an instance that never signalled — safe, because a bad
instance never reaches the fleet. CONTINUE proceeds to InService on timeout —
the unsafe option. Always set ABANDON on launch hooks.

Your code signals completion with:

```bash
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name <hook-name> \
  --auto-scaling-group-name <asg-name> \
  --instance-id <id> \
  --lifecycle-action-result CONTINUE
```

Hooks can publish to an SNS topic or SQS queue; a Lambda or ECS consumer
reacts, runs its logic, and calls `complete-lifecycle-action`. Call
`record-lifecycle-action-heartbeat` to reset the timer if more time is needed
without yet signalling a final result.

---

## Scaling policies

ASG supports three policy types. Each solves a different problem.

**Target tracking** is the recommended default. You declare a target value for
a metric; ASG continuously adjusts instance count to maintain it. Predefined
metrics include `ASGAverageCPUUtilization`, `ASGAverageNetworkIn`,
`ASGAverageNetworkOut`, and `ALBRequestCountPerTarget`. Scale-out is triggered
immediately when the metric exceeds the target. Scale-in is conservative: ASG
waits 15 minutes below the target before removing instances, which prevents
flapping on transient metric dips. Use target tracking for steady-state
workloads where you can express the desired operating point as a single value.

**Step scaling** gives you control over the magnitude of the response. You
define CloudWatch alarms at multiple thresholds and specify the instance count
adjustment for each band. A typical configuration:

| CPU threshold | Scaling action |
|---|---|
| 70–90% | Add 2 instances |
| > 90% | Add 4 instances |

This allows an asymmetric response: modest overload gets a small adjustment;
severe overload gets an aggressive one. Use step scaling when you know the
load-to-instance relationship for your workload and the single target value of
tracking policy does not capture the response shape you need.

**Scheduled scaling** sets a specific desired capacity at a specific time via
cron or one-time event. Use it for predictable periodic load — business hours,
nightly batch jobs, a product launch. Combine with target tracking: the
scheduled action sets the floor before a known peak, and target tracking handles
variable load within that window.

**Cooldown** prevents ASG from launching or terminating additional instances
before the previous change has had time to affect metrics. The default is
300 seconds. Cooldown applies to simple scaling and step scaling; target
tracking has its own stabilisation logic and ignores the cooldown setting.

---

## Health check types

ASG uses health checks to decide when to replace an instance. The check type
you configure determines how much ASG actually knows about your application.

**EC2 health check** reports healthy if the instance is in RUNNING state — a
hypervisor-level signal with no visibility into your application. An instance
with a crashed nginx or OOM-killed process is still "healthy" by this
definition. ASG retains it and continues routing traffic to it.

**ELB health check** reports health based on the ALB or NLB target health check
— typically an HTTP path your application responds to. If the application
returns an unexpected status code, the target is marked unhealthy, and ASG
terminates and replaces it.

**Always configure ELB health check for web workloads** — EC2 health check is only appropriate when there is no load balancer.

**Health check grace period** is how long ASG ignores health check failures
after launch. Set it to at least the full bootstrap time. A period that is too
short causes ASG to terminate a still-booting instance, whose replacement also
fails — producing an endless replace loop.

---

## Instance refresh

Instance refresh gradually replaces old instances with new ones running an
updated launch template, without taking the ASG offline.

`min_healthy_percentage` controls batch size: at least this percentage of
desired capacity must be healthy throughout the refresh. 90% on a 10-instance
ASG means at most one instance terminates at a time before its replacement is
healthy. 50% allows larger batches and finishes faster but leaves less headroom
if the new version is defective.

`instance_warmup` excludes a newly launched replacement from health checks for
a defined window, preventing the refresh from advancing before the instance is
actually ready. Optional checkpoints pause the refresh at defined completion
percentages so you can inspect new instances before ASG continues. A refresh
can be cancelled at any point; already-replaced instances remain on the new
template.

---

## Warm pools

A warm pool holds stopped (or running) instances outside the ASG. When ASG
needs to scale out, it pulls from the pool instead of launching from scratch —
scale-out latency drops from minutes to seconds because the AMI boot phase is
already complete.

Stopped instances incur EBS and Elastic IP charges; running instances incur
full compute cost. Both accrue continuously even when the pool is idle.

When to use a warm pool:
- Application bootstrap takes more than 3 minutes AND fast scale-out is a
  hard business requirement

When not to use a warm pool:
- Bootstrap is under 60 seconds — the ongoing holding cost is not justified
- Instances are stateless and startup cost is dominated by AMI hydration rather
  than application initialisation (a custom AMI or ECS is a better fit)

---

## Best practices

1. Always configure ELB health check type, not EC2 — EC2 health check misses
   every app-level failure and silently retains broken instances.
2. Set health check grace period to at least the full instance bootstrap time —
   too short triggers an endless replace loop.
3. Set default result to ABANDON on launch hooks — instances that fail bootstrap
   must never reach the fleet.
4. Use target tracking as the default scaling policy — simpler to maintain and
   avoids manual threshold tuning.
5. Set instance refresh `min_healthy_percentage` to 90% for production — slower
   rollout but significantly safer.
6. Never use launch configurations — deprecated; always use launch templates.

---

## Common pitfalls

- **No lifecycle hook with a slow bootstrap.** The instance enters InService
  before the application is ready. ALB health checks fail for 60–90 seconds and
  every request routed to the new instance returns 502.
- **EC2 health check masking a crashed application.** The ASG retains the
  instance; the load balancer keeps routing to it; requests fail silently.
- **Health check grace period too short.** ASG terminates instances during
  bootstrap; replacements also fail the grace-period check — endless loop.
- **Cooldown misconfigured on step scaling.** ASG launches a second wave before
  the first wave's CPU contribution appears in CloudWatch, causing large
  over-provisioning spikes.
- **Desired capacity frozen after a scheduled action expires.** Desired stays at
  the scheduled value until a second action or a scaling policy corrects it.
- **Default result CONTINUE on a launch hook.** An instance whose bootstrap
  hangs stays in Pending:Wait until timeout, then enters InService — the exact
  failure the hook was meant to prevent.

---

## Worked example — tracing a lifecycle hook

An ASG scales from `desired = 3` to `desired = 4`. A
`autoscaling:EC2_INSTANCE_LAUNCHING` hook (300 s heartbeat, `ABANDON` default)
publishes to SNS; a Lambda consumer runs bootstrap validation.

1. ASG launches a new EC2 instance → enters `Pending`.
2. Launch hook fires → instance transitions to `Pending:Wait`.
3. ASG publishes the lifecycle event to SNS.
4. Lambda is invoked and waits for SSM Run Command to finish bootstrap (90 s).
5. Bootstrap succeeds. Lambda calls `complete-lifecycle-action CONTINUE`.
6. Instance transitions: `Pending:Wait → Pending:Proceed → InService`.
7. ALB registers the instance; ELB health check begins.
8. Instance passes the health check and starts receiving traffic.

If Lambda is not invoked and the 300-second heartbeat expires, ABANDON fires:
the instance moves to `Terminating`. ASG detects it is one short of desired
and launches a replacement, repeating the cycle from step 1.

---

## Exercises

Answer before starting the lab:

1. A new instance needs 3 minutes to pull configuration and start the
   application before it can serve traffic. What lifecycle hook event name and
   heartbeat timeout do you configure? What is the correct default result?
2. Your ASG has EC2 health check enabled. An instance's application crashes but
   the EC2 OS is still running. What does the ASG do? What should you have
   configured instead?
3. You want instances to scale out aggressively (4 instances) when CPU exceeds
   90% but conservatively (1 instance) when CPU is between 70% and 90%. Which
   policy type do you use, and why can't target tracking satisfy this
   requirement on its own?
4. During an instance refresh with `min_healthy_percentage = 50` on a
   10-instance ASG, how many instances can ASG terminate simultaneously?

## Lab reference

Follow Day 3 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 3 — Auto Scaling Groups
Key concept — lifecycle hooks: ...
When would I NOT use target tracking (use step scaling instead): ...
Break-it — how a hung bootstrap script manifests in the ASG: ...
```
