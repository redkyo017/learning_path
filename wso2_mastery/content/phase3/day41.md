# Day 41: Public ALB for the Gateway — Networking and Health Checks

## Why This Matters

Users outside your VPC need to reach the API Gateway. The Application Load Balancer (ALB) is your entry point. But CP, IS, and TM are internal — they need no public exposure. Today you'll learn the two-tier networking model: public ALB in front of GW; internal services behind private IPs and Cloud Map DNS.

---

## Container Networking Architecture

### VPC Subnet Layout

```
AWS VPC (10.0.0.0/16)
├─ Public Subnet A (10.0.1.0/24)
│  └─ ALB (security group: allow 443 from 0.0.0.0/0)
├─ Public Subnet B (10.0.2.0/24)
│  └─ ALB
├─ Private Subnet A (10.0.11.0/24)
│  ├─ ECS task: GW (10.0.11.x)
│  ├─ ECS task: CP (10.0.11.y)
│  └─ Cloud Map endpoint
├─ Private Subnet B (10.0.12.0/24)
│  ├─ ECS task: IS (10.0.12.x)
│  ├─ ECS task: TM (10.0.12.y)
│  └─ NAT gateway for outbound (ECR, Secrets Manager)
```

### Why This Design?

| Layer | Purpose | Access | Components |
|-------|---------|--------|------------|
| **Public** | ALB only | Internet ↔ ALB | Application Load Balancer |
| **Private** | All ECS tasks | VPC only; outbound via NAT | GW, CP, IS, TM; Cloud Map |

---

## ALB Configuration for WSO2 GW

### Listener and Target Group

```hcl
# Listener on ALB
listener:
  Port: 443
  Protocol: HTTPS
  Certificate: ACM certificate ARN (TODO in variables.tf)
  
# Default action
Action: forward to target group

# Target group
Target group:
  Port: 8243 (GW HTTPS port)
  Protocol: HTTPS
  Target type: IP (for Fargate)
```

### Why HTTPS at the ALB AND at the Container?

1. **ALB → Internet:** TLS encryption (users' traffic).
2. **ALB → Container:** TLS encryption (internal traffic). WSO2 GW expects HTTPS on 8243.

The ALB does **not** terminate TLS inside the container. The container still listens on 8243 with its own certificate. The ALB connects to the container on 8243 as an HTTPS endpoint.

---

## Health Check Configuration

### ALB Health Check

```hcl
health_check:
  path: /services/Version
  protocol: HTTPS
  healthy_threshold: 2       # 2 successful checks = healthy
  unhealthy_threshold: 3     # 3 failed checks = unhealthy
  interval: 30 seconds       # check every 30s
  timeout: 5 seconds         # wait 5s for response
```

### WSO2 Health Check Paths

**These are the real, built-in WSO2 endpoints** — not custom `/health` paths:

| Component | Health Check Path | Method | Expected Response |
|-----------|-------------------|--------|-------------------|
| **GW** | `/services/Version` | GET | 200 OK, JSON with version |
| **CP** | `/services/Version` | GET | 200 OK, JSON with version |
| **IS** | `/oauth2/token` | HEAD | 400 (endpoint requires auth, but is alive) |
| **TM** | `/services/Version` | GET | 200 OK, JSON with version |

**Why `/oauth2/token` for IS?** IS doesn't have a `/services/Version` endpoint. The `/oauth2/token` endpoint is always present; a HEAD request (no auth) returns 400, confirming IS is alive and accepting requests.

---

## Container Port Mappings

### GW Ports

```hcl
portMappings:
  - containerPort: 8280   # HTTP (if you support unencrypted API traffic)
  - containerPort: 8243   # HTTPS (ALB targets this)
```

### Why Separate HTTP and HTTPS?

1. **8280 (HTTP):** Development or internal APIs. Production usually disables this.
2. **8243 (HTTPS):** Encrypted, production-grade. ALB targets this.

In Fargate, you expose both ports in the task definition, but the ALB target group specifies which port it connects to (8243 in your case).

---

## Why No ALB for CP, IS, TM?

### CP: Internal Only

Only the GW and TM call the CP. Neither needs to go through an ALB:
- **GW → CP:** Direct DNS lookup (`cp.wso2.internal:9443`), then HTTPS connection to container IP.
- **TM → CP:** Same; direct connection.

A public ALB would expose the CP to the internet, violating the principle of least privilege.

### IS: Internal Only

Only the GW and CP call the IS for JWKS and token issuer config. No public access needed.

### TM: Internal Only

Only the GW calls the TM for throttle policies. No external clients.

### When Would You Add an ALB for CP?

**Cross-VPC access:** If you have multiple VPCs and need a shared CP, you could add an NLB (Network Load Balancer) in front of the CP and peer the VPCs. But for a single VPC, Cloud Map DNS is sufficient.

---

## Container Networking: DNS Resolution

### Inside the Container (GW Task)

```bash
container-gw$ getent hosts cp.wso2.internal
10.0.11.50  cp.wso2.internal

container-gw$ curl https://cp.wso2.internal:9443/services/Version
# HTTPS connects directly to 10.0.11.50:9443 (CP container's ENI)
```

### How DNS Works in Fargate

1. **ECS task** starts with a task role ARN.
2. **Cloud Map** registers the task's private IP under `cp.wso2.internal` in the service discovery namespace.
3. **Route 53 private hosted zone** (`wso2.internal`) serves DNS queries from the VPC.
4. **VPC DNS resolver** (169.254.169.253) returns the IP for `cp.wso2.internal`.

---

## Health Check Failures: Common Causes

### Scenario: ALB health check fails for GW

```
Target status: Unhealthy
Reason: Health checks failed with these codes [502, 503]
```

**Possible causes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| **Container not started yet** | ECS task shows `PROVISIONING`; startup logs show WSO2 initializing | Increase `startPeriod` from 90 to 120 seconds |
| **Security group blocks ALB** | Tail CloudWatch logs: no incoming request logs | Add ingress rule: ALB SG → GW SG on port 8243 |
| **WSO2 startup takes >90s** | Tail CloudWatch logs: `/services/Version` returns 503 Service Unavailable | Increase `startPeriod` to 120–180 seconds |
| **GW not configured to reach CP** | CloudWatch logs show CP connection refused | Verify `WSO2_CP_URL=https://cp.wso2.internal:9443` in task definition |
| **Certificate validation fails** | Tail logs: `curl: (60) SSL certificate problem` | Ensure GW accepts the CP's self-signed cert (or use CA-signed certs) |

---

## Anti-Patterns to Avoid

### 1. Public Subnets for CP and IS

**Problem:** Unused public IPs; unnecessary exposure to the internet.

**Fix:** Private subnets only. ALB lives in public subnets; ECS tasks live in private subnets.

### 2. Using the ALB DNS Name for Internal Communication

**Problem:** GW needs to call CP. You configure `WSO2_CP_URL=https://alb-cp.internal:9443` (ALB in front of CP).

**Consequence:** Extra hop (ALB → CP), latency, unnecessary load on ALB, and if ALB fails, internal communication breaks.

**Fix:** Use Cloud Map DNS directly: `WSO2_CP_URL=https://cp.wso2.internal:9443`. ALB is only for external traffic.

### 3. Health Check Path is Not Idempotent

**Problem:** Health check endpoint changes app state (e.g., increments a counter, creates a session).

**Consequence:** ALB queries every 30 seconds; over time, side effects accumulate.

**Fix:** Use `/services/Version` (read-only) or similar stateless endpoints.

### 4. StartPeriod Too Short

**Problem:** Health check starts immediately; WSO2 is still initializing.

**Consequence:** Early health checks fail; task is marked unhealthy and replaced, restarting the boot cycle.

**Fix:** Set `startPeriod = 120` (2 minutes) for WSO2 components.

---

## Today's Lab: GW Task Definition + ALB

Your Terraform code (`day41/main.tf`) adds:
- **GW task definition** with environment variables pointing to CP and IS.
- **TM task definition** (simpler, no health checks yet).
- **ALB** in public subnets, listener on 443, target group on 8243.
- **ALB security group** allowing 443 from 0.0.0.0/0 (internet).

**Key study points:**
- Why does GW have `startPeriod = 90` (not 120)? (GW is stateless, boots faster than CP.)
- Why is the ALB target group protocol `HTTPS` (not `HTTP`)? (Container expects TLS.)
- What would happen if you set health check interval to 5 seconds instead of 30? (False positives during container startup.)

---

## Exercises

### Exercise 1: Why No ALB for CP?
**Question:** Why is there no ALB in front of the Control Plane? Who calls the CP, and how do they reach it?

**Hint:** Think about the consumers of the CP. Do they go through the internet or inside the VPC?

**Solution sketch:**
- Only **GW and TM** call the CP (both internal ECS services).
- Neither needs to go through an ALB; they resolve `cp.wso2.internal` and connect directly to the CP's private IP via Cloud Map DNS.
- A public ALB would expose the CP unnecessarily and add latency.
- **If you needed cross-VPC CP access:** You'd add an internal NLB (Network Load Balancer) and peer the VPCs, not a public ALB.
- **Principle:** Expose only what the outside world needs. GW is the API entry point; CP is not.

---

### Exercise 2: GW ALB Health Check Fails
**Question:** You deploy GW and the ALB health check keeps failing (502, 503). List 3 possible root causes and how you'd diagnose each.

**Hint:** Think about container startup, networking, and configuration.

**Solution sketch:**

1. **Container not ready (timing)**
   - Diagnosis: Check ECS task status. If task is `PROVISIONING` or `RUNNING` but recently started, GW is still initializing.
   - Tail CloudWatch logs `/ecs/dev/wso2-gw` and look for "Started successfully" or similar.
   - Fix: Increase `startPeriod` from 90 to 120 seconds.

2. **Security group blocks ALB → GW**
   - Diagnosis: Tail GW CloudWatch logs. If no health check requests appear (no GET `/services/Version`), traffic is blocked.
   - Check security group rules: ALB SG must have ingress rule allowing port 8243 from GW SG.
   - Fix: Add security group ingress rule.

3. **GW startup takes >90s**
   - Diagnosis: Tail CloudWatch logs. Look for when the first health check arrives (after 90s) vs when GW logs "ready".
   - If WSO2 startup takes 120+ seconds, early health checks fail.
   - Fix: Increase `startPeriod` to 120–180 seconds. You can also optimize WSO2 startup by removing unused transports/features.

---

### Exercise 3: Service Discovery vs ALB DNS
**Question:** ECS service discovery registers the GW at `gw.wso2.internal:8243`. The ALB DNS name is `alb-gw-12345.ap-southeast-1.elb.amazonaws.com`. When the GW needs to call itself (or when IS needs to call the GW), why would it use `gw.wso2.internal` instead of the ALB DNS?

**Hint:** Think about the ALB's purpose and latency.

**Solution sketch:**
- **ALB is for external clients:** Users on the internet; they need a single, stable entry point (ALB DNS).
- **Cloud Map is for internal services:** IS, CP, TM; they need direct IP routing for latency and reliability.
- **Why IS wouldn't use ALB DNS for GW:**
  - ALB adds a network hop (IS → ALB → GW), increasing latency.
  - ALB is load-balanced across availability zones; direct DNS is faster.
  - If ALB fails or is removed, internal communication breaks unnecessarily.
- **Cloud Map gives direct container IP routing:** IS → (DNS lookup) → 10.0.11.50 → (direct HTTPS) → GW.
- **Principle:** Different abstractions for different use cases. External clients (internet) use ALB; internal services (VPC) use Cloud Map DNS.

---

## Key Takeaways

1. **Public subnets:** ALB only. Private subnets: all ECS tasks.
2. **ALB target group:** Port 8243 (HTTPS), health check `/services/Version`.
3. **No ALB for internal services:** CP, IS, TM use Cloud Map DNS for direct IP routing.
4. **Health check paths are real WSO2 endpoints**, not custom `/health` paths.
5. **StartPeriod is critical:** Give WSO2 time to boot before health checks start.
6. **Security groups enforce network policy:** ALB SG must allow GW SG on port 8243.

---

## Next Steps

Tomorrow, you'll secure the deployment with security group rules, configure autoscaling policies for GW and TM, and ensure each component has the minimum IAM permissions it needs.
