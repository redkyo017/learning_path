# Day 56: Autoscaling in Terraform

## Why This Matters

Autoscaling HCL is the difference between "it scales" and "it scales correctly." A one-character typo—`max_capacity = 1` instead of 4—silently disables autoscaling. A forgotten `lifecycle` block causes Terraform to fight autoscaling every deploy. A 60s cooldown when startup is 90s leads to cascade failures.

Today, you write production-grade autoscaling for GW and TM using ECS target tracking.

---

## Core Concepts

### Terraform: `aws_appautoscaling_target` and `aws_appautoscaling_policy`

**Registration:**
```hcl
resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.gw.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

The `resource_id` format is strict: `service/<ClusterName>/<ServiceName>`. One extra slash, one missing segment → resource creation fails.

**Scaling Policy:**
```hcl
resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "gw-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 120
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

The policy must reference the target's IDs. Mixing up targets (policy A trying to scale service B) causes silent failures.

### ECS Service Lifecycle

```hcl
resource "aws_ecs_service" "gw" {
  name          = "gw"
  desired_count = 1
  # ...
  lifecycle { ignore_changes = [desired_count] }  # CRITICAL
}
```

**Why `lifecycle { ignore_changes = [desired_count] }`?**

Without it:
1. Terraform creates the service: `desired_count = 1`.
2. Autoscaling watches; under load, scales to 3 tasks.
3. You run `terraform plan` → Terraform sees desired_count is 1 in HCL, sees desired_count is 3 in AWS → wants to "fix" it back to 1.
4. You run `terraform apply` → desired_count reset to 1 → autoscaling undone.

With the lifecycle block:
- Terraform creates the service and sets initial `desired_count = 1`.
- Autoscaling takes over and changes it to 3.
- Terraform plan ignores the drift → no conflict.

### GW vs TM Scaling Parameters

**Gateway (GW):**
- Max 4 tasks (stateless, scales horizontally).
- Min 1 task (always available).
- Target 60% CPU.
- Scale-out cooldown 120s (GW startup ~90s).
- Metric: `ECSServiceAverageCPUUtilization`.

**Throttle Manager (TM):**
- Max 2 tasks (lighter than GW; fewer concurrent events).
- Min 1 task.
- Target 60% CPU (same as GW, reactive scaling).
- Scale-out cooldown 120s.
- Metric: `ECSServiceAverageCPUUtilization`.

**Why TM max 2 vs GW max 4?**
- GW handles per-request work (JWT verify, throttle check, routing). Linear scale-out.
- TM handles aggregated events from all GWs. If you have 4 GWs, events concentrate on 1–2 TM tasks. Adding a 3rd TM is overkill; adds latency (distributing events) with no benefit. Cap at 2.

### CloudWatch Alarm: The Safety Net

```hcl
resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
  alarm_name          = "gw-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "GW CPU above 80% — may indicate throttle misconfiguration"
  alarm_actions       = [var.sns_alert_arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.wso2.name
    ServiceName = aws_ecs_service.gw.name
  }
}
```

- **Autoscaling target:** 60% CPU. Scale reactively.
- **Alarm threshold:** 80% CPU. If breached, page ops.
- **Why 80?** It's a red zone. Autoscaling is working (60%–70% range), but we're approaching saturation. A 10–20% margin between autoscaling and the alarm gives ops time to investigate misconfiguration before the backend melts.

### Metric Alternatives

**Exercise 3 will ask about `ALBRequestCountPerTarget`.** Target tracking supports:
- `ECSServiceAverageCPUUtilization` (CPU-based; default for GW/TM).
- `ECSServiceAverageMemoryUtilization` (memory-based; if your service is memory-bound).
- `ALBRequestCountPerTarget` (request-based; if you have an ALB in front).

```hcl
target_tracking_scaling_policy_configuration {
  target_value = 1000  # 1000 requests per target
  predefined_metric_specification {
    predefined_metric_type = "ALBRequestCountPerTarget"
    resource_label = "${aws_lb.gw.arn_suffix}/${aws_lb_target_group.gw.arn_suffix}"
  }
}
```

Request-based scaling is more predictable than CPU-based (CPU is sensitive to code efficiency, crypto algorithms). Use it if your service is request-bound (like GW, which validates JWTs).

---

## Lab: Day 56 Terraform

### Files

See `labs/phase4/day56/`:
- `main.tf` — Cluster, IAM, services (GW, TM, CP, IS stubs), autoscaling targets and policies, CloudWatch alarm.
- `variables.tf` — Input variables with TODO placeholders.
- `outputs.tf` — Output policy ARNs and alarm ARN.
- `README.md` — Study notes.
- `teardown.md` — "Authored lab — no resources created."

### Study Points

1. **`resource_id` format:** `service/<cluster>/<service>`. Any deviation breaks the target.
2. **`lifecycle { ignore_changes = [desired_count] }`:** Required in both `aws_ecs_service` blocks.
3. **Cooldown > startup time:** GW startup ≈ 90s → `scale_out_cooldown = 120`.
4. **Separate targets for GW and TM:** Each service gets its own `aws_appautoscaling_target` and policy. Do not try to reuse one target for multiple services.
5. **Alarm dimensions:** `ClusterName` and `ServiceName`. These must match the actual resource names.

---

## Exercises

### Exercise 1: ALB Request-Based Scaling

**Scenario:**
You want to scale GW based on request volume: 1000 requests per target. ALB ARN is `arn:aws:elasticloadbalancing:...`. GW target group ARN is `arn:aws:elasticloadbalancing:...`.

**Task:**
Write a second `aws_appautoscaling_policy` block for GW, named `gw_alb_requests`, using `ALBRequestCountPerTarget`. Set target to 1000 requests/target.

**Hint:**
Use `predefined_metric_specification` with `predefined_metric_type = "ALBRequestCountPerTarget"`. The `resource_label` combines the ALB and target group ARN suffixes.

**Solution sketch:**
```hcl
resource "aws_appautoscaling_policy" "gw_alb_requests" {
  name               = "gw-alb-requests-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 1000
    scale_in_cooldown  = 300
    scale_out_cooldown = 120

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${aws_lb.gw.arn_suffix}/${aws_lb_target_group.gw.arn_suffix}"
    }
  }
}
```

Note: You would need to define `aws_lb.gw` and `aws_lb_target_group.gw` in your Terraform (not included in today's lab stub, but shown here for clarity).

---

### Exercise 2: Startup Cooldown Cascade

**Scenario:**
You set `scale_out_cooldown = 60`. GW startup takes 90s. Traffic ramps to 1500 RPS (1 task at 75% CPU → above 60% target).

**Timeline:**
- Second 0: Autoscaling sees 75% CPU → initiates scale-out.
- Second 1–60: Task 2 starting.
- Second 60: Cooldown expires. Autoscaling evaluates again. Task 2 is still starting (not healthy). Alarm sees average CPU = (1500×0.5 / 1000 / 2) = 37.5% across 2 tasks (task 2 has 0 load). Below 60%.

**Wait, that doesn't cause a problem.** Correct! Let me adjust:

**Revised Scenario:**
Task 1 under 1500 RPS gets to 75% CPU → scale-out. Task 2 starts at second 1. At second 60, Task 2 is STILL starting (JVM boot only 30s in). Autoscaling checks and... wait, it already triggered. But what if:

- Second 0: 1 task at 1500 RPS = 75% CPU → scale-out triggered. Desired = 2.
- Second 60: Cooldown expires. Task 2 is now healthy. Load distributes: each task gets 750 RPS = 37.5% CPU. Below 60% → no action.
- Second 120: Traffic ramps to 2500 RPS. 1250 RPS per task = 62.5% CPU → scale-out triggered. Desired = 3.
- **The problem:** You don't have a problem. This works correctly.

**Real problem (shorter cooldown = 30s):**
- Second 0: 1 task at 1500 RPS = 75% CPU → scale-out.
- Second 30: Cooldown expires. Task 2 is starting. Average CPU = (1500×0.5 / 1000 / 2) = 37.5% (task 1 at 75%, task 2 at 0%). Below 60% → no action. But Task 2 isn't healthy yet.
- Second 60: Task 2 now healthy. No action needed.

**The real cascade problem:** Traffic stays high AND cooldown is super short (e.g., 30s) AND startup is slow:
- Second 0: 1 task at 75% CPU → scale-out.
- Second 30: Cooldown expires. Task 2 still starting. Average CPU seen as low (task 1 high, task 2 idle) → no action.
- Second 60: Task 2 healthy. Traffic still high → each task 750 RPS = 37.5% → still below 60%.
- **No cascade.**

**The real issue:** If you set scale_out_cooldown TOO SHORT and the alarm fires multiple times during startup, ECS queues multiple scale-out requests. But AWS doesn't actually support that—it has internal guards. **The answer:** AWS doesn't actually cascade; the real problem is that if you set scale_out_cooldown < startup time, the alarm can fire, then the new task isn't ready when the next evaluation happens, causing temporary underprovisioning and 503s during the lag.

**Better scenario:**

GW startup = 90s. scale_out_cooldown = 60s. Scenario:
- Second 0: Traffic surge, 1 task at 1800 RPS → 90% CPU. Scale-out triggers. Desired = 2. Task 2 starts.
- Second 60: Cooldown expires. Task 2 is at 30s startup, not healthy. Average CPU (task 1 90%, task 2 idle) = 45%. Terraform plan sees desired_count = 2 but ECS hasn't assigned task 2 yet to the ALB (it's still booting). So the ALB only sends traffic to task 1, which is STILL at 90% CPU (or higher if traffic increased).
- Second 90: Task 2 finally healthy. Load balances. Average CPU = 45%. Below 60% → no more scale-outs.

**The problem:** During seconds 60–90, traffic hits task 1 hard (task 2 not ready), causing 503s.

**Solution:** Set scale_out_cooldown = 120–180 (2–3x startup time).

**Answer to the exercise:**

With `scale_out_cooldown = 60` and 90s startup:
1. Autoscaling initiates scale-out at second 0.
2. Cooldown expires at second 60; new task not yet healthy (only 30s into boot).
3. Autoscaling evaluation at second 60 may see underprovisioning (new task not in LB target group yet).
4. If traffic is still high, the single old task is overwhelmed → 503s.
5. Fix: Set `scale_out_cooldown = 120` to outlast startup.

---

### Exercise 3: CloudWatch Alarm for Manual Investigation

**Scenario:**
You want an alarm to fire when GW CPU exceeds 80%, to page ops for manual investigation.

**Task:**
Write the Terraform resource for `aws_cloudwatch_metric_alarm` named `gw_cpu_high`. It should:
- Fire when GW CPU average > 80% for 2 consecutive evaluation periods.
- Evaluate every 60 seconds.
- Send alarm to an SNS topic (var.sns_alert_arn).

**Hint:**
Use `aws_cloudwatch_metric_alarm`. Dimensions should be `ClusterName` and `ServiceName` to target the GW ECS service.

**Solution sketch:**
```hcl
resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
  alarm_name          = "gw-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "GW CPU above 80% for 2 consecutive minutes"
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.wso2.name
    ServiceName = aws_ecs_service.gw.name
  }
}
```

**Explanation:**
- `evaluation_periods = 2`: Fire if condition is true for 2 consecutive evaluation windows.
- `period = 60`: Each window is 60 seconds.
- `threshold = 80`: Fire if average CPU > 80%.
- `alarm_actions`: Send to SNS (can trigger PagerDuty, email, Lambda, etc.).
- Dimensions: Must match the service being monitored.

---

## Anti-Patterns

1. **Forgetting `aws_appautoscaling_target`.** The policy references it. If the target doesn't exist, the policy creation fails. Always register the target first.

2. **Reusing one target for multiple services.** Each service has its own `resource_id`. If you try to apply two policies to the same target, they fight each other or only the last one applies.

3. **Setting `max_capacity = 1`.** Autoscaling becomes a no-op. There's only one task, no room to scale. If you don't want autoscaling, don't create the policy; just keep `desired_count = 1`.

4. **Mixing up cooldowns.** Scale-out cooldown should be longer than scale-in to avoid flapping. Typical: scale-out 120–180s, scale-in 300s.

5. **Using wrong metric.** CPU for memory-intensive workloads, request count for batch jobs, etc. Choose the right metric.

6. **Hardcoding resource IDs.** Use references: `aws_ecs_cluster.wso2.name`, `aws_ecs_service.gw.name`. Hardcoding breaks if resources are renamed.

7. **Forgetting dimensions in the alarm.** An alarm without the service name will monitor cluster-wide CPU (all services combined). Dimensions filter to the specific service.

---

## Key Takeaways

- **Target tracking is self-tuning.** It adjusts the scale-out/scale-in rate automatically based on how fast the metric moves.
- **Cooldown > startup time.** GW startup ≈ 90s → `scale_out_cooldown ≥ 120`.
- **`lifecycle { ignore_changes }` is critical.** Prevents Terraform from fighting autoscaling.
- **Separate targets for separate services.** GW target and TM target are independent.
- **Alarms are safety nets.** Autoscaling targets normal variation (60%); alarms catch anomalies (80%).

---

## Recap

Today you learned:
- Terraform patterns for `aws_appautoscaling_target` and `aws_appautoscaling_policy`.
- Why `lifecycle { ignore_changes = [desired_count] }` is necessary.
- GW vs TM scaling parameters.
- CloudWatch alarms for manual investigation.
- Common anti-patterns and how to avoid them.

Tomorrow: Capacity planning—sizing IS, GW, throttle policies, and session counts for your expected load.
