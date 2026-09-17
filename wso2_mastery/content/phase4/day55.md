# Day 55: ECS Fargate Autoscaling Fundamentals

## Why This Matters

WSO2 is not monolithic. The Gateway (GW) is stateless—it validates JWTs, proxies requests, enforces throttles, then forgets about the connection. The Carbon Publisher (CP) holds the API registry in memory (Day 32). The Identity Server (IS) holds active tokens and session state in memory. Throttle Manager (TM) listens for throttle events from GW.

**The scaling puzzle:**
- GW can scale horizontally—throw more stateless proxies at traffic surges, drain gracefully when traffic falls.
- CP and IS cannot scale horizontally without shared external state—two CP replicas with stale API caches cause 5xx errors.
- TM is lighter and can scale, but state-aware.

**What happens if you get this wrong:**
- Scale CP horizontally without a shared database → API updates on CP-1 don't reach CP-2 → one replica serves stale metadata.
- Set GW min tasks to 0 → cold start in production takes 60–120s; concurrent traffic bursts hit the scaling lag and cascade to 503s.
- Use the wrong cooldown → tasks flap (scale in, scale out, scale in…) wasting money and causing connection resets.

This day teaches the concepts; Day 56 writes the Terraform; Day 57 sizes the deployment for your load.

---

## Core Concepts

### ECS Fargate Autoscaling Components

**Three pieces:**

1. **`aws_appautoscaling_target`** — registers an ECS service as a scalable resource:
   ```hcl
   resource "aws_appautoscaling_target" "gw" {
     max_capacity       = 4
     min_capacity       = 1
     resource_id        = "service/<cluster>/<service>"
     scalable_dimension = "ecs:service:DesiredCount"  # the thing we scale
     service_namespace  = "ecs"
   }
   ```
   This tells AWS: "This service can have 1–4 tasks."

2. **`aws_appautoscaling_policy`** — defines the scaling rule. Target-tracking autoscaling is the modern way:
   ```hcl
   resource "aws_appautoscaling_policy" "gw_cpu" {
     policy_type = "TargetTrackingScaling"
     target_tracking_scaling_policy_configuration {
       target_value       = 60  # keep avg CPU at 60%
       scale_in_cooldown  = 300 # wait 5 min before removing a task
       scale_out_cooldown = 120 # wait 2 min before adding a task
       predefined_metric_specification {
         predefined_metric_type = "ECSServiceAverageCPUUtilization"
       }
     }
   }
   ```
   AWS computes the average CPU across all GW tasks. If it drifts above 60%, it adds a task. If it falls below 60%, it removes a task (after the cooldown).

3. **`aws_cloudwatch_metric_alarm`** — a safety net for manual intervention:
   ```hcl
   resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
     alarm_name          = "gw-cpu-high"
     metric_name         = "CPUUtilization"
     threshold           = 80  # alert at 80% CPU
     comparison_operator = "GreaterThanThreshold"
     alarm_actions       = [var.pagerduty_sns_arn]  # page on-call
   }
   ```
   Autoscaling targets 60%—fine for normal traffic. But if CPU hits 80%, something is wrong (throttle misconfigured, backend is slow, attack). Alert ops.

### Cooldown Timing

- **scale_out_cooldown = 120** — why 120 instead of 60? A GW task takes ~90s to start (JVM boot, Spring context, DNS resolution). If you add a task at 60s and autoscaling checks again at 120s, the new task isn't healthy yet. AWS launches another task. You end up with double desired capacity. Instead, set cooldown to 120–180s—let the task stabilize.
- **scale_in_cooldown = 300** — avoid rapid remove-add cycles (flapping). 5 minutes is conservative; traffic rarely stays stable.

### Why CP and IS Stay at 1 Replica

**CP (Carbon Publisher):**
- Holds API metadata (name, version, throttle tier, auth scheme) in a HashMap.
- Day 32 showed: 10,000 APIs = ~3 MB of memory (API struct ≈ 300 bytes).
- If you scale CP to 2 tasks: CP-1 has the latest API list; CP-2 served the last sync (5 minutes old). A dev deploys a new API version; CP-1 knows about it; CP-2 returns 404 for that API to half the traffic. Result: 50% of requests fail.
- **Fix (out of scope now):** Move API metadata to a shared database (RDS PostgreSQL). Then you can scale CP horizontally.
- **For now:** Keep CP at 1. Make it highly available (multi-AZ ISS with cross-AZ failover) but not horizontal.

**IS (Identity Server):**
- Holds active tokens and session state in memory (token revocation list, user sessions).
- Default behavior: 1 session per token. If IS-1 issued the token, only IS-1 knows it's valid. If the token lands on IS-2 after a deploy, IS-2 doesn't recognize it → 401 Unauthorized.
- **Fix (out of scope):** Add Redis for shared session store. Then scale IS.
- **For now:** Keep IS at 1. Use RDS or Elasticache to add resilience.

**TM (Throttle Manager):**
- Receives binary events from GW on ports 9611 (plain) and 9711 (SSL).
- Event volume = function of GW traffic. Scales at same 60% CPU target as GW.
- Can scale to 2–3 replicas safely—TM event flow is stateless (events are ephemeral).

---

## ADR: Architectural Decision Records

An **ADR** is a document that records a significant decision, the context that led to it, the alternatives considered, and the consequences (positive and negative).

### ADR Structure

```
# ADR-NNN: <Decision Title>

**Status:** Proposed | Accepted | Superseded by ADR-NNN
**Date:** YYYY-MM-DD

## Context
Problem statement, constraints, forces.

## Decision
What we decided. Be specific.

## Consequences
**Positive:**
- ...
**Negative / Trade-offs:**
- ...
**Risks Mitigated:**
- ...

## Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|---|---|---|---|
| ... | | | |

## Review Trigger
When should we revisit this?
```

**Why ADRs matter for scaling:**
- In 2 years, someone asks: "Why don't we scale IS horizontally?" The ADR says: "Because IS holds session state in memory. See ADR-001. When we add Redis, we can scale."
- Decisions made in isolation (no ADR) get rediscovered, challenged, and re-fought.

### Example ADR: "Keep CP and IS at Fixed Replica Count"

See `day55/adr_template.md` for the filled template.

---

## Exercises

### Exercise 1: RPS to CPU Scaling

**Scenario:**
The GW scales out at 60% CPU. JWT RSA-256 verification consumes ~0.5 ms of CPU per core at 1 vCPU.
- How many RPS triggers a scale-out event? (Assume each request needs one JWT verify.)

**Hint:**
1 vCPU = 1000 ms/s of CPU work. At 60% target, that's 600 ms/s available for real work.
Each verify takes 0.5 ms.

**Solution sketch:**
- 1 vCPU = 1000 ms/s of CPU capacity.
- 60% target = 600 ms/s of work.
- 0.5 ms/verify → 600 / 0.5 = 1200 RPS per task.
- Two GW tasks = 2400 RPS. If traffic hits 1300 RPS, scale-out triggers (avg CPU = 1300 × 0.5 / 1000 / 2 = 32.5% → below 60%). If traffic hits 1500 RPS, scale-out triggers. At 1500 RPS on 1 task: 1500 × 0.5 / 1000 = 75% CPU → above 60%. AWS scales to 2 tasks.

---

### Exercise 2: Cooldown Flapping

**Scenario:**
You set `scale_in_cooldown = 30` (30 seconds). Traffic arrives in bursts: 500 RPS for 2 minutes, then 0 RPS for 30 seconds, repeating.
- What happens? Why is this a problem?

**Hint:**
GW task startup time is 30–60s. What does the autoscaler see every 30s?

**Solution sketch:**
- Minute 1: traffic is 500 RPS, GW CPU = 500 × 0.5ms / 1000ms / 1 task = 25%. Below 60% → no scale-out.
- Minute 2: still 500 RPS. No change.
- Minute 2:30 – traffic drops to 0. CPU falls to 0%. Below 60% → AWS initiates scale-in.
- Minute 3:00 – cooldown expires (30s). AWS removes a task. DesiredCount = 0. (If min_capacity = 1, it stays at 1.)
- Minute 3:30 – traffic resumes at 500 RPS. But the single task is under-provisioned momentarily. No big deal.

**The real problem:** Replace 30s burst with longer bursts, or GW startup takes 60s. Scenario:
- Minute 0: Traffic burst, 1 task at 75% CPU → scale out (add task 2).
- Minute 1: New task not healthy yet; scale-out cooldown hasn't expired.
- Minute 1:30 – AWS checks again (cooldown now expired), sees CPU still high → adds task 3.
- Minute 2: Two new tasks starting, traffic eases, CPU drops → scale-in triggered.
- Minute 2:30 – cooldown expires, tasks removed.
- This flapping wastes money (extra task hours), causes connection resets (draining tasks), and adds latency (cold starts).

**Lesson:** Set cooldown to at least 2x the startup time. GW startup ≈ 60–90s → `scale_out_cooldown = 120–180`.

---

### Exercise 3: CP Memory Estimation

**Scenario:**
The CP holds 10,000 APIs. The API struct (from Day 32 Go lab) contains:
- Name (50 bytes avg)
- Version (20 bytes avg)
- Throttle tier (10 bytes avg)
- Auth scheme (30 bytes avg)
- Backend URL (80 bytes avg)
- Security config (40 bytes avg)
- Total: ~230 bytes per API struct + ~70 bytes Go struct overhead = ~300 bytes per API.

The ECS CP task is Fargate 1024 CPU / 2048 MB.
- Estimate CP memory usage for 10,000 APIs.
- Is this a problem?

**Hint:**
Use the per-API struct size. Add overhead for the JVM (WSO2 Java binary uses ~800 MB–1.2 GB for the JVM alone).

**Solution sketch:**
- 10,000 APIs × 300 bytes = 3,000,000 bytes = ~3 MB of API data.
- CP is Java/Spring Boot. JVM + WSO2 runtime ≈ 800–1,200 MB at startup.
- Total: 1,200 MB (JVM) + 3 MB (data) = ~1,203 MB. Well within 2,048 MB.
- **Is this a problem?** No. CP has headroom. The real bottleneck is API update latency (recompiling policy chains) and horizontal scaling (two CPs with stale data). Memory is not the constraint.

---

## Anti-Patterns

1. **min_capacity = 0.** WSO2 startup is 60–120s. A traffic burst hits an empty cluster; ECS launches task 1; 60s later task 1 is healthy. Requests queued during the gap time out or get 503 errors from load balancer. Always use min 1 (or more for HA).

2. **Horizontal scaling of IS without session replication.** Two IS tasks = two independent session stores. Token issued on IS-1 → request lands on IS-2 → 401. Fix: use Redis or RDS for session state first.

3. **Step scaling instead of target tracking.** Old pattern: "if CPU > 70%, add 2 tasks; if CPU < 50%, remove 1 task." Requires manual tuning for each service. Target tracking autoscales the multiplier—simpler, self-tuning.

4. **Forgetting `lifecycle { ignore_changes = [desired_count] }` in Terraform.** Autoscaling changes `desired_count`; Terraform wants to enforce your `desired_count = 1`. Conflict → every Terraform apply resets `desired_count = 1` → autoscaling undone. Always add the lifecycle block.

---

## Key Takeaways

- **Stateless services scale horizontally.** GW, TM: yes. CP, IS: not yet.
- **Autoscaling is reactive.** It responds to load, not predicts it. Pair with load testing and capacity planning (Day 57).
- **Cooldowns prevent flapping.** 2–3x startup time is a rule of thumb.
- **ADRs document why.** Future engineers understand the constraints and know when to revisit the decision.
- **Always set min ≥ 1.** Cold starts in production are expensive.

---

## Recap

Today you learned:
- ECS autoscaling components: target, policy, metric.
- Why CP and IS don't scale, and what would be needed.
- Cooldown timing and flapping.
- ADR structure and why it matters.
- Three exercises to practice scaling calculations.

Tomorrow: Write the Terraform. Day 57: Plan your capacity.
