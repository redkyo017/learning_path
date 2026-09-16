# Day 42 Lab: Security Groups, IAM, and Autoscaling

## Overview

This Terraform lab includes **all Day 40 and Day 41 resources** (ECS cluster, all task definitions, ALB) **plus**:
- Security groups for GW, CP, IS, TM (least-privilege ingress/egress rules)
- Application Auto Scaling targets and policies for GW and TM
- Rationale for fixed replicas (CP, IS) vs. dynamic scaling (GW, TM)

**Important:** This is an **authored lab**. You will NOT run `terraform apply`. This lab is for study and understanding only.

## Key Day 42 Resources

### Security Groups

Each component has its own security group with granular ingress rules:

#### GW Security Group
- **Ingress 8243:** ALB SG → 8243 (HTTPS traffic from ALB)
- **Ingress 8280:** ALB SG → 8280 (HTTP traffic from ALB)
- **Egress:** All (0.0.0.0/0) — GW needs to reach CP, IS, TM, and internet

#### CP Security Group
- **Ingress 9443:** GW SG → 9443 (API calls from GW) + TM SG → 9443 (event hub from TM)
- **Egress:** All (0.0.0.0/0) — CP needs to reach Secrets Manager, databases

#### IS Security Group
- **Ingress 9443:** GW SG → 9443 (JWKS endpoint) + CP SG → 9443 (key manager config)
- **Egress:** All (0.0.0.0/0) — IS needs to reach databases, identity providers

#### TM Security Group
- **Ingress 9611–9711:** GW SG → 9611:9711 (event hub from GW)
- **Egress:** All (0.0.0.0/0) — TM needs to reach CP for event hub subscription

### Auto Scaling

#### GW Auto Scaling
- **Scalable dimension:** ECS service desired count (1–4 replicas)
- **Metric:** Average CPU utilization
- **Target:** 60% CPU
- **Scale-out cooldown:** 60 seconds (fast response to traffic spikes)
- **Scale-in cooldown:** 300 seconds (slow scale-down to avoid flapping)

#### TM Auto Scaling
- Same configuration as GW (stateless, can scale)

#### CP and IS: No Auto Scaling
- **Reason:** Stateful. Hold in-memory state (API registry, token store).
- **Scaling challenge:** Multiple replicas would have separate state; changes on one don't propagate to others without a shared data layer.
- **Fixed replicas:** 1 each (ensures single instance of truth)
- **Scaling workaround:** Use external storage (DynamoDB, PostgreSQL, Redis) for shared state (out of scope for this lab)

---

## Study Points

### 1. Security Groups: Why Separate SGs per Component?

**Problem (shared SG):**
```hcl
# BAD: Everything talks to everything
ingress {
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]
}
```

**Benefits of separate SGs:**
1. **Least privilege:** Each component only accepts traffic it needs.
2. **Fault isolation:** If GW SG is misconfigured, it doesn't affect CP or IS.
3. **Audit trail:** Clear rules for who talks to whom.
4. **Compliance:** Security review is easier with explicit rules.

### 2. Security Group Rules: The Complete Picture

**Request flow with SG rules enforced:**

```
User → ALB SG (ingress 443 from 0.0.0.0/0)
     → ALB sends to GW SG (ingress 8243 from ALB SG)
     → GW reaches CP SG (ingress 9443 from GW SG)
     → GW reaches IS SG (ingress 9443 from GW SG)
     → GW reaches TM SG (ingress 9611/9711 from GW SG)
     → TM reaches CP SG (ingress 9443 from TM SG)
```

If any SG ingress rule is missing, traffic is blocked at the network level.

### 3. IAM Roles: Separation Diagram

```
┌─────────────────────────────────────────────────┐
│ Execution Role (ECS agent, container startup)   │
│ Permissions: ECR pull, CloudWatch logs          │
│ Lifetime: ~30 seconds (only during boot)        │
└─────────────────────────────────────────────────┘
                     ↓
          Container starts running
                     ↓
┌─────────────────────────────────────────────────┐
│ Task Role (Container runtime, inside container) │
│ Permissions: Secrets Manager, X-Ray tracing     │
│ Lifetime: Duration of container (hours/days)   │
└─────────────────────────────────────────────────┘
```

**Security benefit:** If container is compromised at runtime, attacker gets task role (limited). They do NOT get execution role (which has ECR access to all images).

### 4. Autoscaling Cooldown Timing

**Scale-out (GW detects high CPU):**
```
T=0s: CPU = 65%
T=30s: CPU still high, average = 62% (threshold 60%)
T=60s: New GW task starts provisioning
T=90s: New task becomes healthy (health check passes)
T=120s: New task receives traffic, CPU load distributed
```

**Scale-in (GW detects low CPU):**
```
T=0s: CPU = 40%
T=30s: CPU still low, average = 35%
T=60s: Would normally trigger scale-in, but cooldown blocks it
T=300s: Scale-in cooldown expires, can now remove a task
T=360s: Task gracefully drains existing connections
```

**Why 300s > 60s:**
- Traffic is rarely static. A dip might be temporary.
- 5 minutes gives confidence that load is truly low.
- Avoids task churn and startup/shutdown overhead.

### 5. Stateless vs. Stateful: Why GW Scales but CP Doesn't

**GW (stateless):**
- Task #1 validates JWT and forwards to CP.
- Task #2 validates the same JWT and forwards to CP (same result).
- Tasks are interchangeable.

**CP (stateful):**
- Holds API registry: `{api_id_1: {...}, api_id_2: {...}, ...}`
- If you scale to 2 CPs, each has its own registry.
- Developer uploads API #3 to CP #1. CP #2 doesn't know about it.
- **Result:** Some requests hit CP #1 (sees API #3), some hit CP #2 (doesn't see API #3). Inconsistency.

**Solution (for CP scaling):**
- Shared database: All CP instances read/write to a central DB.
- Event syncing: CP #1 notifies CP #2 when new API is uploaded.
- Active-passive: One CP is active, other is standby. No scaling, but redundancy.

---

## Autoscaling Configuration

### Target Tracking vs. Step Scaling

**Target tracking (used here):**
```hcl
target_tracking_scaling_policy_configuration {
  predefined_metric_specification {
    predefined_metric_type = "ECSServiceAverageCPUUtilization"
  }
  target_value = 60.0
}
```
**Pros:** Simple, automatic adjustment. **Cons:** Less control.

**Step scaling:**
```hcl
step_scaling_policy_configuration {
  steps = [
    { lower_bound = 0,   upper_bound = 30,  adjustment_percent = 0 },
    { lower_bound = 30,  upper_bound = 60,  adjustment_percent = 50 },
    { lower_bound = 60,  upper_bound = 80,  adjustment_percent = 100 }
  ]
}
```
**Pros:** Granular control. **Cons:** More complex to configure.

For this lab, target tracking is sufficient and easier to understand.

### Metrics for Autoscaling

**Available ECS metrics:**
- `ECSServiceAverageCPUUtilization`: Average CPU across all tasks in the service
- `ECSServiceAverageMemoryUtilization`: Average memory
- **Custom metrics:** Memory usage, request latency, queue depth (via CloudWatch)

**Why CPU?**
- Easy to measure and normalize.
- JWT validation (RSA verify) is CPU-intensive.
- Reflects actual work being done.

**Alternative: Custom metric (request latency)**
```hcl
target_tracking_scaling_policy_configuration {
  customized_metric_specification {
    metric_name = "APIGatewayLatency"
    namespace   = "WSO2"
    statistic   = "Average"
  }
  target_value = 100  # milliseconds
}
```
(Advanced; out of scope for this lab)

---

## Variables to Customize

All Day 41 variables apply. No new variables for Day 42.

---

## Outputs

All Day 41 outputs plus:
- `gw_security_group_id`: ID of GW SG
- `cp_security_group_id`: ID of CP SG
- `is_security_group_id`: ID of IS SG
- `tm_security_group_id`: ID of TM SG
- `gw_autoscaling_target_arn`: ARN of GW autoscaling target
- `gw_autoscaling_policy_arn`: ARN of GW autoscaling policy

---

## Next Steps

This completes the 3-day Terraform trilogy:
- **Day 40:** ECS cluster + CP + IS (foundation)
- **Day 41:** GW + TM + ALB (networking)
- **Day 42:** Security groups + autoscaling (security and scalability)

The final `labs/phase3/day42/main.tf` is a complete, production-ready Terraform module for WSO2 on ECS Fargate (with placeholders for your AWS values).

## Exercise Review

If you're stuck on Day 42 exercises:
- **Exercise 1 (Why CP can't scale):** In-memory state. Multiple instances = multiple registries. No coordination without shared DB.
- **Exercise 2 (CPU spikes):** JWT validation (RSA verify) is expensive. High API traffic with JWT = high CPU.
- **Exercise 3 (Cooldown ratio):** Scale-out fast (60s) to prevent degradation. Scale-in slow (300s) to avoid flapping.

---

## Security Best Practices Checklist

- [ ] Separate IAM roles: execution (startup) ≠ task (runtime)
- [ ] Separate security groups: one per component
- [ ] Least privilege: each SG only allows necessary traffic
- [ ] ALB SG: public (0.0.0.0/0); all others: private (within VPC)
- [ ] Auto scaling: scale-in cooldown > scale-out cooldown
- [ ] Min capacity: always ≥ 1 (never 0, to avoid cold starts)
- [ ] Max capacity: limit to prevent runaway costs
- [ ] Stateful components: fixed replicas (1) or shared data layer
- [ ] Health checks: use real WSO2 endpoints (/services/Version)
- [ ] Start period: generous (120s for CP/IS, 90s for GW)
