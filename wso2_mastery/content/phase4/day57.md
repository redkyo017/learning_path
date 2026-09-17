# Day 57: Capacity Planning

## Why This Matters

Autoscaling is reactive. It responds to traffic after it arrives. Capacity planning is proactive: you predict peak load and size infrastructure to meet it without exhausting the scaling budget.

A classic scenario:
- You deploy GW with max 4 tasks. Load testing shows peak = 5400 RPS.
- At 1200 RPS per task, you need 5 tasks (5400 / 1200 = 4.5, round up).
- But your max is 4 → you hit the ceiling, autoscaling can't add more → traffic drops, you page.
- Capacity planning would have told you: "Set max 5, not 4."

Three capacity levers:
1. **IS session limit** — How many concurrent tokens can IS hold?
2. **Throttle policy** — What RPS cap prevents backend overload?
3. **Task sizing** — How many tasks for your peak load?

---

## Core Concepts

### IS Session Capacity

**Session = token.**
- User logs in → IS issues a JWT token → user keeps the token for `token_ttl` (default 3600s).
- IS holds the token in the revocation list (and session metadata) until TTL expires.
- Steady-state session count = `token_issue_rate × avg_token_ttl`.

**Example:**
- Token issue rate: 20 tokens/sec (measured from load tests or estimated from user count and login frequency).
- Token TTL: 3600s (1 hour).
- Steady-state sessions: 20 × 3600 = 72,000 active tokens in IS memory.

**Session size:** ~2 KB per token (JWT payload + metadata).
- RAM needed: 72,000 × 2 KB = 144 MB.
- IS task: 2048 MB Fargate.
- Headroom for JVM + WSO2 runtime (~1 GB) → 2048 - 144 - 1000 = 904 MB spare. OK.

**Per-user limit:**
- `identity.xml`: `<MaxSessionsPerUser>100</MaxSessionsPerUser>`.
- This is **per user**, not total.
- If you have 10,000 unique users and each user issues 2 tokens (e.g., browser session + mobile app), total = 20,000 tokens. Each user has 2 tokens, below the 100-per-user limit.
- **Anti-pattern:** Assuming `MaxSessionsPerUser` caps total sessions. A bot creating 1,000 users with 100 tokens each would bypass this and exhaust IS RAM.

### Throttle Policy Tuning

**Gold tier** (default): Unlimited RPS.
- In production, "Unlimited" means "limited by backend infrastructure."
- Set a practical cap to protect backends from overload.

**Formula:**
- Backend safe RPS (from backend load test): e.g., 500 RPS.
- Add 20% headroom (to absorb autoscaling lag): 500 × 0.8 = 400 RPS.
- WSO2 throttle limit unit: requests per minute → 400 × 60 = 24,000 req/min.

**Setting the limit in CP:**
```bash
curl -X PUT https://cp.wso2.internal:9443/api/am/admin/v4/throttling/policies/subscription/Gold \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"defaultLimit":{"requestCount":{"requestCount":24000,"timeUnit":"min"}}}'
```

**Why 20% headroom?** Autoscaling adds a new task, but there's a lag (cooldown + startup). During the lag, requests queue. A 20% cap gives the backend time to drain the queue before new traffic arrives.

### ECS Task Sizing for GW and IS

**GW: 1024 CPU / 2048 MB** (per Day 42).
- CPU-bound: JWT RSA-256 verify ≈ 0.5ms per core.
- 1 vCPU (1000 ms/s) at 1200 RPS → 1200 × 0.5 / 1000 = 60% CPU. At 60% autoscaling target, this task is fully utilized.
- **Capacity:** 1200 RPS per 1024 CPU/2048 MB task.
- **Peak RPS = 3000** → `ceil(3000 / 1200) = 3 tasks` at autoscaling target.

**IS: 1024 CPU / 2048 MB** (per Day 42).
- CPU-bound: Token issuance (HMAC, signature verification) ≈ 10ms per token at 1 vCPU.
- 1 vCPU at 100 tokens/sec → 100 × 10 / 1000 = 100% CPU (fully utilized).
- **Capacity:** 100 tokens/sec per task.
- But IS also has RAM constraints. At 72,000 steady-state sessions, 1 IS task at 2048 MB is fine. Two IS tasks would split the sessions (need shared state, e.g., Redis).

**CP: 1024 CPU / 2048 MB** (per Day 42).
- Memory-bound: API registry (~3 MB for 10,000 APIs).
- **Fixed at 1 replica** (no horizontal scaling without shared DB).

**TM: 1024 CPU / 2048 MB** (per Day 42).
- CPU-bound: Event processing from GW.
- **Max 2 replicas** (stateless, but event fanout efficiency caps scaling).

### Capacity Worksheet

The worksheet (day57/capacity_worksheet.md) has:
- Input variables (token_issue_rate, peak_rps, backend_safe_rps, etc.).
- Formulas (steady_state_sessions, gw_tasks_needed, throttle_limit).
- Sanity checks (IS RAM, GW max capacity, throttle limit set).

---

## Exercises

### Exercise 1: IS Session Capacity

**Scenario:**
- Token issue rate: 20 tokens/sec.
- Token TTL: 3600s.
- Each session takes 2 KB of memory.
- IS task: 2048 MB Fargate.

**Task:**
How many active IS sessions at steady state? Is the IS task sufficiently sized (accounting for JVM overhead of ~1 GB)?

**Hint:**
Use the formula: `steady_state_sessions = token_issue_rate × avg_token_ttl`.
Session RAM = `steady_state_sessions × 2KB`.
Total RAM needed = Session RAM + JVM overhead.

**Solution sketch:**
- Steady-state sessions: 20 tokens/sec × 3600s = 72,000 tokens.
- Session RAM: 72,000 × 2 KB = 144,000 KB = 141 MB.
- JVM overhead: ~1,000 MB (WSO2 Java runtime).
- Total: 141 + 1,000 = 1,141 MB.
- IS task: 2,048 MB.
- Headroom: 2,048 - 1,141 = 907 MB. OK.
- **Conclusion:** IS task is sufficiently sized. Token issuance is CPU-bound, not memory-bound, in this scenario.

---

### Exercise 2: GW Task Scaling at Peak

**Scenario:**
- Peak RPS: 3000.
- GW task capacity: 1200 RPS at 60% CPU target (from Day 55 Exercise 1).

**Task:**
How many GW tasks are needed to handle peak load without exceeding the autoscaling target?

**Hint:**
Use ceiling division: `ceil(peak_rps / rps_per_task)`.

**Solution sketch:**
- Peak RPS: 3000.
- RPS per task at 60% target: 1200.
- Tasks needed: ceil(3000 / 1200) = ceil(2.5) = 3 tasks.
- Verification: 3 tasks × 1200 RPS/task = 3600 RPS capacity. 3000 RPS peak leaves 600 RPS headroom.
- **Terraform config:** Set `max_capacity = 3` or higher (e.g., 4 for safety). At 60% target, autoscaling kicks in at 720 RPS per task (1200 × 0.6). The 3rd task comes online before you exceed it.

---

### Exercise 3: Throttle Policy Limit

**Scenario:**
- Backend safe RPS: 500 (from your backend load test).
- You want to add 20% headroom for autoscaling lag.
- WSO2 throttle policy is in requests per minute.

**Task:**
Calculate the throttle limit for the Gold tier and explain the unit conversion.

**Hint:**
Headroom formula: `safe_rps × 0.8`. Conversion: requests/sec → requests/min is × 60.

**Solution sketch:**
- Backend safe RPS: 500.
- With 20% headroom: 500 × 0.8 = 400 RPS.
- Requests per minute: 400 × 60 = 24,000 req/min.
- Set Gold tier throttle policy: `{"defaultLimit":{"requestCount":{"requestCount":24000,"timeUnit":"min"}}}`.
- **Why 20% headroom?** Autoscaling lag (startup + cooldown) can cause a 30–120s window where traffic spikes above your steady-state. The 20% buffer absorbs this spike without overwhelm.

---

## Sanity Checks from the Worksheet

1. **IS session RAM < task memory (with JVM headroom):**
   - `is_session_ram_mb` should be < 1500 MB (leaving 500 MB for JVM).
   - If > 1500 MB, scale IS to a larger task or add Redis for session offloading.

2. **GW peak tasks ≤ max_capacity:**
   - If peak RPS needs 5 tasks, set `max_capacity = 5` or adjust autoscaling target lower (e.g., 50% instead of 60%) to allow more tasks before hitting max.

3. **Throttle limit is set in CP:**
   - The formula calculates the limit, but you must actually apply it via CP admin UI or API.
   - Forgetting this step means throttle remains "Unlimited" → backend gets hammered.

4. **IS MaxSessionsPerUser > per-user session count:**
   - If you have 10,000 users and each issues 3 tokens, per-user count = 3. Set `MaxSessionsPerUser = 10` (at least).
   - If a bot creates 100 users with 100 tokens each → per-user is 100, set `MaxSessionsPerUser = 100` or higher.

---

## Common Miscalculations

1. **Confusing IS session count with transaction volume.**
   - Sessions = concurrent tokens in memory (long-lived).
   - Transactions = API calls per second (short-lived).
   - A login generates 1 session; 100 API calls generate 100 transactions but use the 1 session.

2. **Forgetting JVM overhead.**
   - A Java app doesn't start at 0 MB. WSO2 alone uses ~600–1200 MB for the JVM.
   - Don't allocate task memory purely to data. Reserve 1 GB for runtime.

3. **Setting throttle limit higher than backend capacity.**
   - Throttle protects backend, not frontend. If backend handles 500 RPS and you set throttle to 1000, requests overflow the backend.
   - Backend overload → slow requests → client timeouts → cascading failures.

4. **Assuming max_capacity = min tasks + 1.**
   - If min = 1 and peak needs 4 tasks, set max ≥ 4. Setting max = 2 caps you at 2 tasks → underprovisioned.

5. **Not accounting for startup lag.**
   - Scale-out cooldown should be > startup time. If you don't, there's a window where new tasks are starting but not ready, causing underprovisioning.

---

## Key Takeaways

- **Session capacity = token_issue_rate × token_ttl.** Plan IS sizing around this.
- **GW capacity = ceil(peak_rps / rps_per_task).** Determine max_capacity from this.
- **Throttle limit = backend_safe_rps × 0.8 × 60 req/min.** Protect the backend.
- **Always reserve JVM overhead.** Don't allocate 100% of task memory to data.
- **Worksheet is your checklist.** Fill it in before deploying; validate that all assumptions hold.

---

## Recap

Today you learned:
- How to calculate IS session capacity.
- How to size GW tasks for peak load.
- How to set throttle policies to protect backends.
- Common miscalculations and how to avoid them.
- How to use the capacity worksheet for validation.

---

## Phase 4 Summary: Days 55–57

**Day 55:** Autoscaling fundamentals. ECS target tracking, why CP and IS don't scale, ADR template.
**Day 56:** Terraform for autoscaling. Target, policy, lifecycle management, CloudWatch alarms.
**Day 57:** Capacity planning. Session sizing, task capacity, throttle limits.

You now understand the full picture: how to scale stateless services (GW, TM), why stateful services (CP, IS) need external infrastructure, and how to capacity-plan your deployment for predictable, efficient operations.

Next phase: Task 5 focuses on testing and validation in a multi-region setup.
