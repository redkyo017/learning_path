# Day 45: Phase 3 Completion — Design Decisions and the Path Forward

## Why This Matters

Phase 3 is complete. You've built a **fully distributed API management system** from scratch in Go. Before moving to Phase 4 (production hardening), it's time to pause and understand the **why** behind the big architectural choices.

Today is a reflection day. You'll run the smoke test one more time, review the runbook, and answer three design questions that reveal how real-world API platforms think about scale, reliability, and cost.

---

## Phase 3 at a Glance: All 15 Days

| Day | Block | Title | Deliverable |
|-----|-------|-------|-------------|
| **31** | Architecture | API Model Evolution | Source reading |
| **32** | Architecture | API Lifecycle State Machine | Go: state transitions |
| **33** | Architecture | Subscription Model | Go: tier system |
| **34** | Architecture | Event-Driven Sync | Source reading |
| **35** | CP | Control Plane Core | Go: `/apis`, `/subscriptions` |
| **36** | CP | API Lifecycle Transitions | Go: lifecycle HTTP handlers |
| **37** | CP | Event Hub and SSE | Source reading |
| **38** | CP | Event Emission | Go: EventBus (JMS simulation) |
| **39** | CP | Unified CP Integration | Go: `/admin/sync` + `/events` |
| **40** | Infra | ECS Cluster + Task Defs | Terraform: foundational resources |
| **41** | Infra | ALB + GW + TM Task Defs | Terraform: networking and routing |
| **42** | Infra | Security Groups + Autoscaling | Terraform: SGs, IAM, autoscaling policies |
| **43** | Integration | Docker Compose Startup | Docker Compose: local integration |
| **44** | Integration | Smoke Test | Bash: end-to-end validation |
| **45** | Review | Design Decisions + Runbook | Reflection + operational guide |

---

## Three Key Design Decisions and Why WSO2 Made Them

### Design Decision 1: Why Does GW Cache Subscription Data Locally Instead of Calling CP Per Request?

**The Question:** Every time a request arrives, the GW needs to check if the app (identified by the JWT) has an active subscription to the requested API. Why not call the CP every time instead of caching?

**Answer: Latency.**

```
Option A: Local Cache
  1. Request arrives at GW
  2. GW checks local cache (in-memory hashmap): ~1 microsecond
  3. Cache hit: subscription exists, tier is Gold, not blocked
  4. Validation passes; request forwarded to backend
  Total: ~1ms (mostly backend processing)

Option B: Call CP Per Request
  1. Request arrives at GW
  2. GW makes HTTP call to CP: /subscriptions/validate?...
  3. Network round trip: 5–50ms (depending on region)
  4. CP queries its state: ~1ms
  5. CP responds to GW: +5–50ms
  Total: ~10–100ms per request
```

**Scale impact:** At 1000 requests/second, Option B adds 10–100ms overhead per request. Users complain about latency. Option A keeps it to 1ms.

**Reliability tradeoff:** Local cache can become stale. If a subscription is blocked in the CP, the GW might not know for seconds (until the next event arrives). But SSE events propagate quickly (< 100ms typically). In practice, this stale window is acceptable because:
- Subscriptions don't change often.
- When they do, SSE events update the cache within milliseconds.
- The fallback (step 7 of the smoke test) calls `/subscriptions/validate` on a cache miss or error.

**ECS implication:** GW instances can be in different AZs. Each GW has its own local cache. If a subscription is blocked on GW #1 but GW #2 hasn't received the event yet, requests to GW #2 might still pass. This is **eventual consistency**. It's acceptable because API subscriptions change rarely, and the window is tiny.

---

### Design Decision 2: Why Does WSO2 Use JMS (Event Streaming) for Sync Instead of HTTP Polling?

**The Question:** The CP publishes events (API published, subscription created). The GW consumes them. Why not have the GW poll the CP every few seconds instead of using SSE/JMS?

**Answer: Reliability and durability.**

```
Option A: SSE (JMS simulation in our Go labs)
  1. GW subscribes to /events endpoint
  2. CP publishes events to SSE stream
  3. All connected GW instances receive events in real-time
  4. Guarantees: events are durable (JMS broker holds them)
  5. If a GW reconnects, it can replay missed events

Option B: Polling
  1. GW calls /admin/sync every 30 seconds
  2. CP returns all current state (all APIs, subscriptions, policies)
  3. GW updates its cache
  4. Problem: Rapid events can be missed
     - Subscription created at T=0
     - GW polls at T=25 (sees subscription)
     - Subscription blocked at T=26
     - GW polls at T=55 (sees blocked subscription)
     - For 29 seconds, GW allowed traffic; subscription was blocked
```

**Durability:** In a broker-based event system (JMS, Kafka), events are persisted to disk. If the GW crashes and restarts, it can reconnect and replay events it missed. With polling, if the GW misses a window, those events are lost.

**Real-world scenario:** A developer accidentally publishes a malicious API. The admin should be able to immediately block it. With polling every 30s, there's a 30-second window where requests get through. With SSE, the GW learns about the block in milliseconds.

**Trade-off:** SSE requires a persistent connection. If the network hiccups, the GW might disconnect and miss events. **Fix:** Implement automatic reconnection with re-sync (Phase 4).

---

### Design Decision 3: Why Does ECS Give Each WSO2 Component a Separate Task Definition?

**The Question:** Why not run IS, CP, GW, and TM in a single Docker container?

**Answer: Independent scaling and failure isolation.**

```
Single Container (monolithic):
  - 1 container = 1 CPU, 1 GB RAM
  - Running all four services
  - High traffic → CPU at 80% → can't distinguish which component is slow
  - GW issue with JWT validation → restart container → all services down (IS, CP, TM too)
  - Scaling: autoscale to 2 containers → 8 GB RAM reserved (even if only GW needs it)

Separate Task Definitions (microservices):
  - IS: 1 task × 256 MB RAM × fixed
  - CP: 1 task × 512 MB RAM × fixed
  - GW: 1–4 tasks × 256 MB RAM × autoscaled
  - TM: 1–4 tasks × 256 MB RAM × autoscaled
  - High traffic → GW CPU at 80% → autoscale GW only → add 1 GW task
  - GW crash → GW task restarts; IS, CP, TM unaffected
  - Resource efficiency: scale only what needs scaling
```

**Failure isolation:** A buggy GW (memory leak, infinite loop) takes down only GW, not the entire platform. Requests briefly fail, but IS and CP stay up and accept requests from other GW instances.

**Independent tuning:**
- GW is stateless: can be bursty (scale 1–4 on demand).
- IS and CP are stateful: fixed 1 replica each (no shared state layer).
- TM is stateless: can scale 1–2 for load distribution.

**Cost:** Running four separate tasks (even if some are size 1) costs more than a single monolith. But operationally, it's cleaner: failures don't cascade, you can deploy just the GW without restarting CP, and metrics are clearer.

---

## Phase 3 Anti-Patterns to Carry Forward and Flag

### Anti-Pattern 1: In-Memory State in the CP
**Current:** CP stores APIs and subscriptions in RAM. On restart, all data is lost.
**Fix (Phase 4):** Add a persistent store (DynamoDB, PostgreSQL). Rebuild state on startup.
**Lesson:** Stateful components need durability. Never run a registry or store in-memory in production.

### Anti-Pattern 2: No Authentication on CP Endpoints
**Current:** Anyone can call `POST /apis` to create an API.
**Fix (Phase 4):** Add authentication middleware. Only authenticated admin roles can create APIs.
**Lesson:** Internal services still need auth. Just because they're behind an ALB doesn't mean they're secure.

### Anti-Pattern 3: SSE Without Reconnection Logic
**Current:** GW subscribes to `/events`. If the connection drops, GW loses the event stream.
**Fix (Phase 4):** Implement automatic reconnection. On reconnect, call `/admin/sync` to catch up.
**Lesson:** Network connections are unreliable. Always plan for disconnection and recovery.

### Anti-Pattern 4: No Rate Limiting on Internal APIs
**Current:** CP accepts unlimited requests.
**Fix (Phase 4):** Add rate limiting to CP endpoints (e.g., 1000 req/sec max). Gracefully degrade under load.
**Lesson:** Just because a service is internal doesn't mean it won't face DOS conditions (a buggy GW polling CP in a tight loop, for example).

---

## Phase 4 Preview: What's Next

Phase 4 (Production Hardening) will cover:

1. **Distributed Tracing:** Correlation IDs across all four services. Every request gets a unique ID; follow it through IS, CP, GW logs.
2. **Custom Extension Points:** How to write a custom Go Key Manager adapter (plug into IS). Custom mediator in GW (inspect/modify requests before backend).
3. **Failure Mode Catalog:** Common failure scenarios (CP restarts during active requests, network partition between GW and CP, IS key rotation) and recovery procedures.
4. **Production Runbook:** How to debug real incidents. Checklist for common issues.
5. **Terraform Improvements:** Add RDS (for CP state), ElastiCache (for distributed caching), X-Ray (for tracing), CloudWatch Logs Insights (for debugging).

---

## Today's Lab: Reflection Review

### Step 1: Run the Smoke Test One More Time

```bash
cd labs/phase3/day43
docker compose up --build

# In another terminal
cd labs/phase3/day44
bash smoke_test.sh
```

Expected output:
```
=== ALL STEPS PASSED ===
```

Observe how all four services communicate. Think about which service handles which step.

### Step 2: Read the Runbook

Open `labs/phase3/day45/runbook.md`. Review:
- **Event types table:** Which events does CP emit? When?
- **Failure checklist:** If a request fails, which SSE event should you look for?
- **ECS Fargate checklist:** How do you translate Docker Compose setup to production?

### Step 3: Answer the Three "Why" Reflection Questions

In your notes (or a comment in the code), answer:

1. **Why does GW cache subscriptions instead of calling CP per request?**
   - Answer: ___

2. **Why does WSO2 use event streaming (SSE/JMS) instead of polling?**
   - Answer: ___

3. **Why separate task definitions for each component?**
   - Answer: ___

These answers are the foundation for Phase 4.

---

## Exercises

### Exercise 1: Tracing a Missing API
**Question:** You added an API to the CP but the GW still returns 404 when you call `/newapi/v1/hello`. Using only the `/events` SSE endpoint, how would you diagnose whether the problem is in the CP or the GW?

**Hint:** Watch the SSE stream in real-time. Trigger the lifecycle change and look for the event.

**Solution sketch:**
```bash
# Terminal 1: Watch events
curl -N http://localhost:8082/events

# Terminal 2: Create and publish API
curl -X POST "http://localhost:8082/apis" \
  -H 'Content-Type: application/json' \
  -d '{"name":"NewAPI","context":"/newapi/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}'
# Extract API_ID from response

curl -X POST "http://localhost:8082/apis/$API_ID/lifecycle" \
  -H 'Content-Type: application/json' -d '{"action":"Publish"}'

# Back to Terminal 1: Check if API_PUBLISHED event appears in the SSE stream
# If YES → CP is working; GW might not be subscribed or not applying events
# If NO → CP's EventBus isn't connected to the lifecycle handler
```

If the event appears but GW still 404s, the issue is in the GW's event handling (not applying the event to its route cache).

---

### Exercise 2: Stale Data After CP Restart
**Question:** In production, the event sync works fine. But after you restart the CP, the GW has stale data: it still routes to APIs that were deleted before the restart. Why does this happen, and how do you fix it?

**Hint:** Think about the CP's state persistence.

**Solution sketch:**
- **Why:** The CP's in-memory registry is wiped on restart. It starts fresh with no APIs or subscriptions. But the GW's local cache still has the old state (from before the restart). The GW doesn't know the CP lost data.
- **Fix:** On the CP restart, emit a full `STATE_RESET` event. GW receives it, clears its cache, and calls `/admin/sync` to reload. Or, implement CP persistence: CP stores APIs/subscriptions in a database; on restart, it rebuilds state from the DB and emits events to replay the state to connected GWs.
- **Phase 3 limitation:** The Go CP has no persistence. This is flagged as a Phase 4 task.

---

### Exercise 3: Cross-Cluster CP and IS
**Question:** Your company runs CP and IS on separate ECS clusters in different VPCs. The GW cluster is in a third VPC. How do you configure the GW task definition to find the CP and IS?

**Hint:** Service discovery and security group rules.

**Solution sketch:**
- **DNS:** Both CP and IS are registered in AWS Cloud Map in their respective clusters. E.g., `cp.wso2-internal` and `is.auth-internal`.
- **GW environment variables:**
  ```hcl
  WSO2_CP_URL = "https://cp.wso2-internal:9443"
  WSO2_IS_URL = "https://is.auth-internal:9443"
  ```
- **Network:** GW VPC has VPC peering or Transit Gateway to CP VPC and IS VPC.
- **Security groups:**
  - GW SG must have outbound rule to CP SG on port 9443.
  - GW SG must have outbound rule to IS SG on port 9443.
  - CP SG must have inbound rule from GW SG on port 9443.
  - IS SG must have inbound rule from GW SG on port 9443.
- **TLS certificates:** Ensure TLS certs in CP and IS are valid for `cp.wso2-internal` and `is.auth-internal`. Otherwise, TLS handshake fails.

---

## Key Takeaways

1. **Caching vs. synchronous calls:** Choose based on latency and consistency tolerance.
2. **Event streaming vs. polling:** Event streaming is more reliable for state sync.
3. **Microservices design:** Independent scaling and failure isolation justify the operational complexity.
4. **In-memory is not production-ready:** Stateful components need persistent stores.
5. **Run smoke tests post-deployment:** They catch integration bugs that metrics miss.

---

## Next Phase Preview

Phase 4 (Optional; not part of the core 60-day path):
- Distributed tracing with correlation IDs.
- Custom Go plugins for key managers and mediators.
- Failure mode analysis and recovery procedures.
- Production runbook with real incident scenarios.
- Terraform with RDS, ElastiCache, CloudWatch.

For now, **you have a fully functional API management system.** Congratulations!

