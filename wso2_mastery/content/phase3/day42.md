# Day 42: Security Groups, IAM, and Autoscaling — Least Privilege and Scaling Patterns

## Why This Matters

You've built the cluster, the services, and the ALB. Now you need to **lock it down and automate growth**. Today covers the final layer: security group rules (who talks to whom), IAM roles (what each component is allowed to do on AWS), and autoscaling policies (scale GW and TM horizontally when traffic spikes).

---

## IAM Roles: Execution vs. Task

### Two Separate Roles, Two Separate Purposes

Principle of least privilege requires two distinct IAM roles:

| Role | Used By | Permissions | Examples |
|------|---------|-------------|----------|
| **Execution Role** | ECS agent (at container startup) | Pull ECR images; write CloudWatch logs; read secrets from Secrets Manager during bootstrap | `ecr:GetAuthorizationToken`, `logs:CreateLogStream`, `secretsmanager:GetSecretValue` (specific secrets) |
| **Task Role** | Container code (at runtime) | AWS API calls inside the container | Signatures for SigV4 auth; Secrets Manager access for keystores; X-Ray tracing |

### Example

**Execution Role (AmazonECSTaskExecutionRolePolicy):**
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ],
  "Resource": "*"
}
```

**Task Role (custom, for CP):**
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:dev/wso2/*"
}
```

### Why Not One Role?

- **Execution role** is short-lived: only during container startup.
- **Task role** is long-lived: entire container lifetime.
- If a container is compromised, the attacker gets task role permissions. You don't want them to have ECR write access or the ability to pull any image.

---

## Security Group Rules: Who Talks to Whom?

### Ingress Rules (Inbound)

Each component has a security group. Ingress rules define **who is allowed to send traffic to this component**.

```
ALB SG → GW SG: ports 8243, 8280
GW SG → CP SG: port 9443 (API calls + event hub subscription)
GW SG → IS SG: port 9443 (JWKS endpoint for JWT validation)
CP SG → IS SG: port 9443 (key manager config retrieval)
GW SG → TM SG: ports 9611, 9711 (throttle policy sync)
TM SG → CP SG: port 9443 (event hub subscription)
```

### Why Multiple Ingress Rules?

Different components need different ports. CP uses 9443; GW uses 8243. TM needs 9611/9711 for event sync.

**Example: CP Security Group**

```hcl
resource "aws_security_group" "cp" {
  name   = "dev-wso2-cp"
  vpc_id = var.vpc_id
  
  # Allow GW to call CP
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.gw.id]
  }
  
  # Allow TM to call CP (for event hub)
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.tm.id]
  }
  
  # Egress: allow CP to reach the internet (e.g., Secrets Manager)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### GW Security Group

```hcl
resource "aws_security_group" "gw" {
  name   = "dev-wso2-gw"
  vpc_id = var.vpc_id
  
  # Allow ALB to call GW
  ingress {
    from_port       = 8243
    to_port         = 8243
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  ingress {
    from_port       = 8280
    to_port         = 8280
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Egress: allow GW to reach CP, IS, TM, and the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### GW → IS Rule (for JWKS)

```hcl
# In IS security group
ingress {
  from_port       = 9443
  to_port         = 9443
  protocol        = "tcp"
  security_groups = [aws_security_group.gw.id]
}
```

### Anti-Pattern: Single Security Group

**Problem:** CP, GW, IS, and TM all use the same security group. Rules become a tangled mess.

```hcl
# BAD: No isolation
ingress {
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # Everything talks to everything
}
```

**Fix:** One security group per component. Explicit rules only.

---

## Autoscaling: When and How

### Stateless vs. Stateful Components

| Component | State | Scaling |
|-----------|-------|---------|
| **GW** | Stateless (validates and proxies only) | Yes, 1–4 replicas |
| **CP** | Stateful (API registry in-memory) | Fixed 1 replica |
| **IS** | Stateful (token store in-memory) | Fixed 1 replica |
| **TM** | Stateless (throttle policies synced from CP) | Yes, 1–4 replicas |

### Why CP and IS Can't Scale Horizontally (Without External State)

The CP holds the entire API registry in memory (uploaded by developers). Scaling to 2 replicas means each has a separate copy of the registry. If a developer uploads a new API to CP #1, CP #2 doesn't know about it unless they sync via a shared database or distributed cache (Redis, DynamoDB).

**Workaround (out of scope for this course):**
- Shared DynamoDB table for API registry.
- Redis for distributed cache.
- Deploy CP in active-passive mode with a shared datastore.

For now, **CP and IS stay at 1 replica**.

### GW Autoscaling

```hcl
resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4          # Never more than 4 GW tasks
  min_capacity       = 1          # Always at least 1 GW task
  resource_id        = "service/dev-wso2/dev-wso2-gw"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "dev-wso2-gw-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0          # Target 60% CPU utilization
    scale_out_cooldown = 60            # Wait 60s before scaling out again
    scale_in_cooldown  = 300           # Wait 5min before scaling in
  }
}
```

### Why Scale at 60% CPU?

- **Too high (e.g., 90%):** By the time you detect high CPU and spin up new tasks (60–90 seconds), response times are already degraded.
- **Too low (e.g., 30%):** You scale out too often, wasting resources.
- **60% is a sweet spot:** Leaves headroom for traffic spikes while avoiding wasteful over-provisioning.

### Scale-Out vs. Scale-In Cooldown

```
scale_out_cooldown = 60 seconds     # If CPU > 60%, add a task after 60s
scale_in_cooldown  = 300 seconds    # If CPU < 60%, remove a task after 5 min
```

**Why scale-in is slower:**
- **Scale-out:** Traffic spike → scale immediately to prevent degradation.
- **Scale-in:** Traffic dip → wait longer to avoid flapping (scaling in and out repeatedly).

If you set `scale_in_cooldown = 60` (same as scale-out), you risk oscillation:
```
CPU up → add task (60s)
CPU down → remove task (60s)
CPU up → add task (60s)
...
```

Tasks are being created and destroyed constantly, wasting resources.

---

## What Load Pattern Triggers Autoscaling?

### CPU Drivers in GW

1. **JWT Validation (RSA verification):** Computationally expensive. Days 20–21 showed that RSA signature verification dominates CPU under high API traffic.
2. **HTTPS/TLS handshake:** Establishes encrypted connection.
3. **Request routing:** Matching routes, checking policies.

### Sustained High API Traffic

```
Request rate: 1000 req/sec
JWT in each request: RSA verification
→ CPU load increases
→ Average GW CPU > 60%
→ Auto Scaling adds a new GW task after 60s
→ 2 GW tasks distribute load
→ CPU normalizes to 30–40%
```

---

## Anti-Patterns to Avoid

### 1. Same Security Group for CP and IS

**Problem:** CP allows port 9443 ingress from CP SG (for clustering). IS also uses 9443. If they share a SG, IS can receive traffic that's meant for CP (or vice versa).

**Fix:** Separate security groups per component. Only GW can reach CP; only GW and CP can reach IS.

### 2. Execution Role with SecretsManager Access

**Problem:** ECS agent has permanent access to Secrets Manager. If compromised, attacker can read all secrets.

```hcl
# BAD
resource "aws_iam_role" "ecs_execution" {
  # ...
  policy {
    Effect   = "Allow"
    Action   = ["secretsmanager:*"]
    Resource = "*"
  }
}
```

**Fix:** Only the task role gets Secrets Manager access. Execution role should not.

### 3. Autoscaling Min Capacity = 0

**Problem:** Under no load, GW scales to 0 tasks. Next request faces 60–90 second cold start.

```hcl
# BAD
min_capacity = 0  # Means GW can disappear entirely
```

**Fix:** `min_capacity = 1`. Always keep at least one task ready.

### 4. No Scale-In Cooldown

**Problem:** CPU dips momentarily → scale in. CPU spikes → scale out. Constant churn.

**Fix:** `scale_in_cooldown = 300` (5 minutes). Let things stabilize.

---

## Today's Lab: Security Groups + Autoscaling

Your Terraform code (`day42/main.tf`) adds:
- **GW security group:** Allow ALB on 8243, 8280. Egress to anywhere.
- **CP security group:** Allow GW and TM on 9443.
- **IS security group:** Allow GW and CP on 9443.
- **TM security group:** Allow GW on 9611–9711.
- **ECS autoscaling target and policy:** GW scales 1–4 based on 60% CPU; scale-in cooldown 300s.

**Key study points:**
- Why does CP security group allow both GW and TM on 9443? (Both subscribe to the event hub.)
- What would happen if you set `min_capacity = 0`? (Cold starts; avoid in production.)
- Why is scale-in cooldown 5x scale-out cooldown? (Avoid flapping under variable load.)

---

## Exercises

### Exercise 1: Fixed Replicas for CP and IS
**Question:** Why do CP and IS use fixed replicas (1) while GW scales horizontally (1–4)? What would break if you tried to scale CP to 3 replicas?

**Hint:** Think about in-memory state and what happens when you have two CP instances.

**Solution sketch:**
- **CP is stateful:** Holds the entire API registry in-memory. Each developer-uploaded API exists in this registry.
- **Two CP instances = two separate registries:** Developer uploads API #1 to CP instance A. CP instance B doesn't know about API #1 (unless they sync via a shared DB).
- **Result:** Requests get load-balanced: some hit CP A (sees API #1), some hit CP B (doesn't see API #1).
- **Same problem with IS:** Token store, OAuth state, etc. Multiple IS instances require a shared data layer (Redis, database).
- **GW is stateless:** Just validates and proxies. Three GW instances all do the same job; requests can route to any one.
- **Solution for scaling CP/IS:** Use a shared datastore (DynamoDB, PostgreSQL, Redis) or an active-passive setup with Raft consensus (complex, out of scope).

---

### Exercise 2: CPU Spikes and Autoscaling
**Question:** You see a sustained CPU spike that triggers autoscaling. GW scales from 1 to 2 tasks. What load pattern (i.e., what type of API traffic) most likely caused this spike?

**Hint:** Recall Days 20–21 and what's expensive in terms of CPU.

**Solution sketch:**
- **JWT validation is the CPU hog:** RSA signature verification (HMAC is cheaper).
- **High-volume API traffic with JWT-secured endpoints** → sustained CPU load.
- **Load pattern:** 500+ req/sec, each with a JWT. Every request requires RSA verification.
- **Why not network I/O?** Fargate network is usually not the bottleneck. CPU is, especially with cryptographic operations.
- **Why not memory?** GW doesn't accumulate memory over time (it's stateless). Memory usage plateaus quickly.
- **Confirmation:** Tail GW logs and look for times around JWT verification or policy enforcement.

---

### Exercise 3: Autoscaling Cooldown Ratios
**Question:** In the Terraform code, `scale_out_cooldown = 60` and `scale_in_cooldown = 300`. Explain why scale-in is 5x longer, and what would happen if you set them equal.

**Hint:** Think about load volatility and task startup time.

**Solution sketch:**
- **Scale-out (60s):** When traffic spikes (CPU > 60%), start a new task immediately (within 60s). New tasks take 60–90s to become healthy (Fargate boot + healthcheck). You want to start ASAP before requests degrade.
- **Scale-in (300s = 5min):** When traffic dips (CPU < 60%), wait 5 minutes before removing a task. Why?
  - **Oscillation prevention:** Traffic might spike again in the next minute. If you removed the task at 60s, you'd have to add it back at 120s. Wasteful.
  - **Graceful termination:** Existing requests on that task should complete. 5 minutes is generous for request drains.
  - **Variable load patterns:** Real traffic isn't smooth. It dips and recovers. Longer cooldown absorbs this variation.
- **If both were 60s:** CPU dips → remove task (60s) → CPU spikes → add task (60s) → CPU dips → remove task... Constant churn, task startups failing, degraded user experience.

---

## Key Takeaways

1. **Two IAM roles:** Execution (container startup), Task (runtime AWS calls). Separate for least privilege.
2. **Security groups enforce network policy:** One SG per component. No broadcast rules.
3. **Stateless = scalable:** GW and TM can scale. CP and IS can't (without shared state).
4. **Autoscaling target:** 60% CPU is a good balance. Min 1, max 4 for GW.
5. **Cooldown tuning:** Scale-out fast, scale-in slow. Avoid flapping.

---

## Next Steps

You've now completed the Day 40–42 trilogy: cluster setup, networking, and security. In Day 43, you'll integrate this Terraform with the WSO2 deployment runbook and run smoke tests against your Fargate cluster.

---

## Lab Breakdown

**Day 40:** ECS cluster + CP + IS task definitions (foundation).
**Day 41:** GW + TM task definitions + ALB (public entry point).
**Day 42:** Security groups + autoscaling (security and scalability).

Each day's Terraform lab is **cumulative**. Day 42's `main.tf` includes all resources from Days 40 and 41, plus the new security and scaling features. This allows you to understand the full topology and deploy all at once if needed.
