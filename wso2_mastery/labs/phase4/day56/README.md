# Day 56 Lab: ECS Fargate Autoscaling

**Authored lab — syntax validation only. Do NOT run `terraform apply`.**

This lab demonstrates ECS Fargate autoscaling configuration for the WSO2 API Manager deployment. It includes:
- 4 ECS task definitions (GW, TM, CP, IS)
- 4 ECS services (GW and TM with autoscaling; CP and IS with fixed replicas)
- Autoscaling targets and policies for GW and TM
- CloudWatch alarm for GW CPU > 80%

---

## Files

- **main.tf** — ECS cluster, IAM roles, task definitions, services, autoscaling targets/policies, CloudWatch alarm.
- **variables.tf** — Input variables with TODO placeholders (replace with actual AWS resource IDs).
- **outputs.tf** — Output autoscaling policy ARNs, alarm ARN, service names, cluster name.
- **README.md** — This file.
- **teardown.md** — Cleanup instructions (none—authored lab).

---

## Key Study Points

### 1. Lifecycle Management: `lifecycle { ignore_changes = [desired_count] }`

```hcl
resource "aws_ecs_service" "gw" {
  desired_count = 1
  lifecycle {
    ignore_changes = [desired_count]  # CRITICAL
  }
}
```

**Why?**
- Terraform defines the initial `desired_count = 1`.
- Autoscaling dynamically adjusts `desired_count` based on load (e.g., 1 → 3 → 2).
- Without the lifecycle block, Terraform treats the 3-task state as "drift" and tries to reset it to 1 on the next `terraform apply`.
- With the lifecycle block, Terraform ignores the `desired_count` field and lets autoscaling manage it.

**Important:** CP and IS do NOT have this lifecycle block because they are NOT autoscaling-managed. Their `desired_count = 1` is permanent.

### 2. Cooldown Timing: `scale_out_cooldown = 120`

```hcl
target_tracking_scaling_policy_configuration {
  target_value       = 60
  scale_in_cooldown  = 300  # 5 minutes
  scale_out_cooldown = 120  # 2 minutes
}
```

**Why `scale_out_cooldown = 120` (not 60)?**
- GW startup takes ~90 seconds (JVM boot, Spring context initialization, DNS resolution).
- If `scale_out_cooldown = 60s`, autoscaling can trigger scale-out at second 0, but at second 60 the new task isn't healthy yet.
- If traffic is still high, the alarm evaluates at second 60 and sees underprovisioning (new task not ready) → initiates another scale-out → cascading failures.
- Setting `scale_out_cooldown = 120s` ensures the new task is healthy before the next evaluation.

**Rule of thumb:** `scale_out_cooldown ≥ 2 × startup_time`.

### 3. Separate Targets for GW and TM

```hcl
resource "aws_appautoscaling_target" "gw" {
  resource_id = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.gw.name}"
  ...
}

resource "aws_appautoscaling_target" "tm" {
  resource_id = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.tm.name}"
  ...
}
```

**Why separate?**
- Each service scales independently based on its own load and metric.
- GW scales up to 4 tasks (high request volume).
- TM scales up to 2 tasks (event volume from GW; stateless event fanout).
- Mixing targets causes conflicts or silent failures.

### 4. Autoscaling Parameters: GW vs TM

| Parameter | GW | TM | Rationale |
|---|---|---|---|
| max_capacity | 4 | 2 | GW handles per-request work (linear scale). TM handles aggregated events (sublinear scale). |
| min_capacity | 1 | 1 | Always available; WSO2 cold start is slow. |
| target_value | 60% CPU | 60% CPU | Same target for reactive scaling. |
| scale_out_cooldown | 120s | 120s | Both need time for task startup and stabilization. |
| scale_in_cooldown | 300s | 300s | Avoid rapid scale-in/out cycles (flapping). |

### 5. CloudWatch Alarm: Safety Net

```hcl
resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
  alarm_name          = "${var.environment}-gw-cpu-high"
  threshold           = 80
  alarm_actions       = [var.sns_alert_arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.wso2.name
    ServiceName = aws_ecs_service.gw.name
  }
}
```

**Autoscaling vs Alarms:**
- **Autoscaling (60% CPU target):** Responds automatically. Scale-out happens within seconds. Good for expected load variation.
- **Alarm (80% CPU threshold):** Signals anomaly. Pages on-call. Autoscaling is working (60–70% range), but something is wrong (throttle misconfiguration, backend slowness, attack).
- **Why 80%, not 60%?** Buffer between autoscaling and alarm. If alarm fires at 60%, it's redundant. At 80%, it signals a red zone → human investigation needed.

---

## Validation

Run `terraform validate` to check syntax:
```bash
cd labs/phase4/day56/
terraform validate
# Expected output: Success! Configuration is valid.
```

This checks:
- HCL syntax correctness
- Resource and variable reference validity
- No real AWS API calls (no authentication needed)

---

## Resources Created (if you ran `terraform apply` — DO NOT)

| Resource | GW | TM | CP | IS |
|---|---|---|---|---|
| ECS Task Definition | ✓ | ✓ | ✓ | ✓ |
| ECS Service | ✓ | ✓ | ✓ | ✓ |
| Autoscaling Target | ✓ | ✓ | — | — |
| Autoscaling Policy | ✓ | ✓ | — | — |
| CloudWatch Alarm | ✓ (GW CPU high) | — | — | — |

---

## Exercises

See `content/phase4/day56.md` for exercises:
1. Write a second autoscaling policy for GW using `ALBRequestCountPerTarget`.
2. Explain why `scale_out_cooldown = 60` causes cascading failures with 90s startup.
3. Write a CloudWatch alarm for custom metric or resource.

---

## Next Steps

- **Day 57:** Capacity planning worksheet. Use it to calculate task counts, session limits, throttle policies for your expected load.
- **Testing:** Once deployed (in another lab), monitor ECS service metrics and validate autoscaling behavior.
- **Real deployment:** Replace TODO placeholders with actual AWS resource IDs and ECR image URIs.

---

## Common Pitfalls

1. **Forgetting `lifecycle { ignore_changes = [desired_count] }`** → Terraform resets `desired_count = 1` every apply, undoing autoscaling.
2. **Hardcoding resource IDs** (e.g., `resource_id = "service/wso2-cluster/wso2-gw"`) → Breaks if names change. Use references instead.
3. **Setting `max_capacity = 1`** → Autoscaling is a no-op. At least `max > min`.
4. **Using step scaling instead of target tracking** → Manual tuning needed for each workload. Target tracking self-tunes.
5. **Mixing metrics (CPU, memory, request count)** without validation → Could choose the wrong metric for your workload.

---

## References

- Day 55: ECS Fargate autoscaling fundamentals.
- Day 56 exercises: Scaling policy variations, cooldown timing, CloudWatch alarms.
- AWS documentation: [ECS Autoscaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)
