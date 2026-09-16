# Day 40: The 4-Service Fargate Topology — ECS Cluster Setup

## Why This Matters

Your company runs all four WSO2 components on AWS ECS Fargate. Knowing the deployment topology tells you:
- **Which task to restart** when event sync breaks (is it the CP? The TM?).
- **Which CloudWatch log group** to tail for each failure mode.
- **Why hardcoding `localhost`** breaks your config immediately — there is no localhost in Fargate.

Today you'll learn the architecture behind the most common WSO2 deployment pattern in the cloud, and understand how service discovery works without traditional DNS.

---

## The 4-Service Fargate Topology

WSO2's four core components run as **separate ECS services**, each with its own task definition, private IP, and Elastic Network Interface (ENI).

### Component Overview

| Component | Port(s) | Role | Replicas | Scaling |
|-----------|---------|------|----------|---------|
| **Control Plane (CP)** | 9443, 9611, 9711 | API registry + event hub | Fixed 1 | No (stateful) |
| **Universal Gateway (GW)** | 8280, 8243 | Proxy + JWT validation | 1–4 | Yes (stateless) |
| **Identity Server (IS)** | 9443, 9763 | OAuth/token issuer + JWKS | Fixed 1 | No (stateful) |
| **Traffic Manager (TM)** | 9611, 9711, 9443 | Throttling + quota policy | 1–4 | Yes (stateless) |

### Why Separate Services?

1. **Independent scaling profiles** — GW and TM handle request volume; CP and IS hold in-memory state.
2. **Separate IAM roles** — each component gets only the AWS permissions it needs.
3. **Granular monitoring** — CloudWatch logs per service; easier to correlate failures.
4. **Fault isolation** — CP crash doesn't bring down GW.

---

## ECS Fargate vs Docker Compose

### Key Differences

| Aspect | Docker Compose | ECS Fargate |
|--------|---|---|
| **Network** | `localhost` works; all containers share an IP | Each task gets its own ENI + private IP |
| **Service Discovery** | `/etc/hosts` hardcoding or internal DNS | AWS Cloud Map (Route 53 private namespace) |
| **Configuration** | Environment files, mounted volumes | Task definition, secrets in Secrets Manager |
| **Restart** | In-place, reuse IP | New task, new ENI (old IP invalidated) |

### The "No Localhost" Problem

In Docker Compose, if GW needs to call CP, you write:
```yaml
WSO2_CP_URL=http://cp:8080
```

In ECS Fargate, **there is no `cp` service running on the same machine**. CP runs in a different task, likely a different availability zone. You must use Cloud Map DNS:
```
WSO2_CP_URL=https://cp.wso2.internal:9443
```

**Hardcoding `localhost` or private IP addresses breaks immediately.**

---

## CloudWatch Log Groups

Each component writes to its own log group for operational clarity:

```
/ecs/dev/wso2-cp        ← Control Plane logs
/ecs/dev/wso2-gw        ← Gateway logs
/ecs/dev/wso2-is        ← Identity Server logs
/ecs/dev/wso2-tm        ← Traffic Manager logs
```

### Debugging a Single Request

When debugging a request failure, **filter by `activityid` (correlation ID) across all four log groups**:

1. Start with GW logs: `{ $.activityid = "abc123" }`
2. Tail CP logs: `{ $.activityid = "abc123" }`
3. Cross-check IS logs: `{ $.activityid = "abc123" }`
4. Look for policy violations in TM logs: `{ $.activityid = "abc123" }`

This correlation ID flows through all components in a single request.

---

## AWS Cloud Map Service Discovery

### How It Works

1. **ECS service** registers its task with Cloud Map under a private namespace (`wso2.internal`).
2. **Route 53** (private hosted zone) maintains the DNS records.
3. **VPC DNS resolver** (169.254.169.253) returns the private IP of the task.
4. **Each container task** can reach other services via DNS name: `cp.wso2.internal`, `gw.wso2.internal`, etc.

### DNS Resolution Inside the VPC

```
container-gw$ curl https://cp.wso2.internal:9443/services/Version
  → 169.254.169.253 (VPC resolver)
  → Route 53 private zone
  → returns 10.0.1.42 (CP task's ENI IP)
  → HTTPS connection established
```

**No ALB needed for internal communication.** Direct IP routing via DNS.

---

## Startup Order and Dependencies

### Dependency Chain

```
IS starts first (no dependencies)
    ↓
CP starts (needs IS for key manager config)
    ↓
GW starts (needs CP for API registry; calls IS for JWKS)
    ↓
TM starts (needs CP for event hub; calls GW for throttle sync)
```

### Why This Order Matters

- **IS first:** No upstream dependencies; issues can be debugged in isolation.
- **CP second:** Needs IS to be healthy for keystore initialization.
- **GW third:** Needs both CP and IS; will fail health checks if either is unreachable.
- **TM last:** Needs both CP and GW for event sync.

### ECS Task Startup Control

ECS has **no native ordering** — all tasks start in parallel. You enforce order via:
1. **Health checks:** GW won't pass health until CP is reachable.
2. **Readiness probes in config:** WSO2 doesn't mark itself "ready" until dependencies are up.
3. **Load balancer target registration:** ALB won't route until health checks pass.

---

## Anti-Patterns to Avoid

### 1. Running CP and IS as the Same ECS Service

**Problem:** Different scaling profiles. If you need 3 CP replicas for registry caching, you've also scaled IS to 3, wasting memory for token storage.

**Fix:** Separate services with independent replica counts.

### 2. Running CP/IS in Public Subnets

**Problem:** Unnecessary exposure. CP should never accept traffic from the internet.

**Fix:** Private subnets only. ALB (for GW) and NAT gateway (for outbound) in public subnets.

### 3. Hardcoding Private IP Addresses

**Problem:** When a task restarts, it gets a new ENI and new private IP. Hardcoded IPs become stale.

**Fix:** Always use Cloud Map DNS names (`cp.wso2.internal`) or Route 53 alias records.

### 4. Missing Correlation IDs in Logs

**Problem:** When debugging multi-service requests, you tail each log group separately and can't correlate events.

**Fix:** Ensure every WSO2 request includes an `activityid` header; filter all logs by this ID.

---

## Today's Lab: ECS Cluster + CP + IS Task Definitions

Your Terraform code (`day40/main.tf`) creates:
- An ECS cluster with Container Insights enabled.
- IAM roles (execution role for container startup, task role for runtime permissions).
- Task definition for Control Plane (3 ports: 9443, 9611, 9711).
- Task definition for Identity Server (2 ports: 9443, 9763).

**Key study points:**
- Why is `startPeriod = 120` seconds? (WSO2 takes time to boot.)
- What's the difference between `execution_role_arn` and `task_role_arn`?
- Why is the health check different for IS (HEAD to `/oauth2/token`) vs CP?

---

## Exercises

### Exercise 1: Service Discovery
**Question:** The GW needs to call `https://cp.wso2.internal:9443/api/am/admin/v1/...`. What AWS service resolves this DNS name? What happens when a CP task restarts?

**Hint:** Think about Route 53 and how it handles task replacement in ECS.

**Solution sketch:**
- AWS Cloud Map registers the CP service under the `wso2.internal` private namespace.
- Route 53 maintains the DNS record pointing to the current task's private IP.
- When the CP task restarts, ECS creates a new task with a new ENI and private IP.
- Cloud Map automatically updates the DNS record.
- Existing connections to the old IP will fail (connection refused); new requests resolve to the new IP.
- **Conclusion:** Cloud Map abstracts the IP change; DNS names are the right level of indirection.

---

### Exercise 2: Startup Order and Health Checks
**Question:** What startup order must ECS enforce: IS → CP → GW → TM, or can some start in parallel? Justify your answer.

**Hint:** Think about what happens if CP starts before IS is fully initialized. What about GW before CP?

**Solution sketch:**
- **IS must start first:** No upstream dependencies. If IS fails, it's not GW's problem yet.
- **CP can start after IS is healthy:** Needs IS for key manager config; will fail initialization if IS is not reachable.
- **GW can start after CP is healthy:** Needs CP for API registry sync. Will fail health check (curl to `/services/Version`) if CP is unreachable.
- **TM can start after CP is healthy:** Needs CP for event hub. Can run in parallel with GW or after.
- **Parallel startup:** You can start IS and do other work; only GW must wait for CP to be healthy. TM doesn't block GW.
- **In practice:** ECS starts all tasks; health checks and readiness gates enforce the order implicitly.

---

### Exercise 3: Task Restart and ENI Reuse
**Question:** When an ECS Fargate task restarts (due to OOMKill or manual update), does it reuse the same ENI and IP address?

**Hint:** Compare ECS Fargate behavior to EC2 instances.

**Solution sketch:**
- **No.** ECS Fargate creates a **new task** with a **new ENI**.
- On EC2, you might have an AMI or a single instance that you restart in-place; the instance ID and primary ENI remain the same.
- In Fargate, a task is ephemeral. Restart = new task, new network interface, new private IP.
- **Implication:** Any process that cached the old IP (e.g., a hardcoded IP in another config) is now broken.
- **Why Cloud Map exists:** DNS abstracts this. When you restart, Cloud Map updates the DNS record, and all clients automatically use the new IP on the next DNS query.
- **Startup time:** A new Fargate task typically takes 60–90 seconds to become healthy (container pull + WSO2 initialization).

---

## Key Takeaways

1. **No localhost in Fargate** — each task is isolated. Use Cloud Map DNS.
2. **Separate services** for independent scaling profiles and cleaner fault isolation.
3. **CloudWatch correlation by activityid** for multi-service debugging.
4. **Health checks enforce startup order** implicitly; no need for explicit orchestration.
5. **Task restart = new ENI** — why DNS is essential, not optional.

## Next Steps

Tomorrow, you'll add the Universal Gateway and Traffic Manager task definitions, configure the Application Load Balancer, and explore how traffic flows from external clients to your internal services.
