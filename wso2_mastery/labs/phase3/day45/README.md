# Day 45 Lab: Phase 3 Review

## Objective

Review Day 43–44 artifacts, read the runbook, and reflect on the three key architectural design decisions behind WSO2's event-driven, cache-based approach to API management.

**This is a review day; no new code to write.**

## Files in This Lab

- `runbook.md` — Complete operational guide for Phase 3 system (topology, API reference, event types, failure checklist, production ECS notes, known limitations)
- `README.md` — This file; review steps
- `teardown.md` — Cleanup instructions

## Review Steps

### Step 1: Run the Smoke Test One Final Time

From `labs/phase3/day43/`:

```bash
docker compose up --build  # Or just skip if already running from day44
```

From `labs/phase3/day44/`:

```bash
bash smoke_test.sh
```

**Expected:** `=== ALL STEPS PASSED ===`

**What to observe:**
- All 7 steps complete successfully.
- No errors in step logs.
- GW returns 200 for the API request.

---

### Step 2: Read the Runbook Carefully

Open `runbook.md`. Focus on these sections:

1. **Topology Overview** — How do IS, CP, GW, and backend communicate?
2. **Sequence Diagram** — Trace a single API request from start to finish.
3. **Event Types Table** — What events does CP emit? When?
4. **Failure Checklist** — If something fails, which event should you look for?

---

### Step 3: Understand the Three Design Decisions

These three questions are the essence of WSO2's architecture. In your notes or a journal, answer all three:

#### Question 1: Why Does GW Cache Subscription Data Locally?

**Context:** Every API request requires the GW to check if the app (from the JWT) has an active subscription to the API being called.

**Options:**
- Option A: GW caches subscriptions locally (in-memory hashmap). Lookup time: ~1 microsecond.
- Option B: GW calls CP for every request. Lookup time: ~10-100ms (network round-trip).

**Your answer:**
- Why did WSO2 choose Option A?
- What is the trade-off?
- How does the system handle cache staleness?

**Example answer structure:**
```
Caching keeps validation latency under 1ms, vs. 10-100ms per CP call.
At 1000 req/sec, this saves 10-100 seconds of cumulative latency per second.

Trade-off: Cache can be stale. If a subscription is blocked in CP,
GW might not know for milliseconds (until the SSE event arrives).

Handle staleness:
  - Events propagate via SSE within milliseconds.
  - SSE stream ensures eventual consistency.
  - Fallback: GW can call CP on cache miss or validation failure.
```

---

#### Question 2: Why Does WSO2 Use Event Streaming (SSE/JMS) Instead of Polling?

**Context:** The CP publishes events (API published, subscription created). The GW needs to know when these happen.

**Options:**
- Option A: Event streaming (SSE, JMS). Publisher emits; subscribers receive in real-time.
- Option B: Polling. GW calls CP every N seconds for all current state.

**Your answer:**
- Why did WSO2 choose Option A?
- What is the trade-off?
- What would happen if you used Option B?

**Example answer structure:**
```
Event streaming is durable and immediate.
- Immediate: Events arrive within milliseconds (vs. poll intervals of 30s).
- Durable: Events can be replayed if GW restarts/reconnects.

Trade-off: Event streaming requires a persistent connection.
If the connection drops, GW misses events until it reconnects.

With polling every 30s:
- Rapid state changes between polls are lost.
- Example: Subscription blocked at T=0, next poll at T=30.
  For 30 seconds, GW allows traffic; subscription is actually blocked.
- With SSE: GW learns about the block within milliseconds.
```

---

#### Question 3: Why Does Each WSO2 Component Get Its Own Task Definition in ECS?

**Context:** The WSO2 platform has four services: IS, CP, GW, TM.

**Options:**
- Option A: Monolithic. All four run in a single container.
- Option B: Microservices. Each service in its own task definition.

**Your answer:**
- Why did WSO2 choose Option B?
- What are the benefits?
- What is the cost?

**Example answer structure:**
```
Microservices allow independent scaling and failure isolation.

Benefits:
- Scale what needs scaling: GW can scale 1-4 based on traffic,
  while CP stays fixed at 1 (stateful, no shared state layer).
- Failure isolation: A GW crash doesn't take down CP.
- Resource efficiency: Only pay for GW autoscaling.

Cost:
- Operational complexity: Manage four separate services.
- Network latency: Inter-service calls are now network hops (vs. in-process function calls).

For a monolith:
- High traffic → CPU maxed → hard to tell which component is slow.
- GW crash → entire platform down (IS, CP, TM too).
- Scaling: Add a container → 8GB RAM reserved (even if only GW needs it).
```

---

## Additional Reflection Questions (Optional)

If you want to go deeper, also consider:

- **What would break if GW and CP ran in the same container?** (Hint: Scaling, resilience, debugging.)
- **What would happen if the SSE connection dropped for 10 seconds?** (Hint: Cache staleness, race windows.)
- **How would you add distributed tracing (correlation IDs)?** (Hint: Inject ID in initial request; GW passes to CP, IS in headers.)

---

## Observing the System in Action (Optional Deep Dive)

If you want to experiment, try these scenarios:

### Scenario 1: Watch Events in Real-Time

Terminal 1:
```bash
curl -N http://localhost:8082/events | head -20
```

Terminal 2:
```bash
# Manually create an API
curl -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{"name":"ExpAPI","context":"/exp/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}'

# Extract API_ID from response and publish
API_ID="api-123"
curl -X POST "http://localhost:8082/apis/$API_ID/lifecycle" \
  -H 'Content-Type: application/json' -d '{"action":"Publish"}'
```

Terminal 1: You should see:
```
event: API_PUBLISHED
data: {...}
```

**Learning:** Events flow through SSE in real-time.

---

### Scenario 2: Check GW Cache After Restart

```bash
# Stop GW
docker compose stop gw

# Wait 5 seconds
sleep 5

# Check logs for "Loaded from CP"
docker compose logs gw | grep "Loaded from CP"

# Restart GW
docker compose start gw

# Wait 10 seconds for startup
sleep 10

# Check logs again
docker compose logs gw | grep "Loaded from CP"
```

**Learning:** On startup, GW calls `/admin/sync` to populate the cache.

---

### Scenario 3: Trace a Subscription Request

```bash
# Create app and subscription manually
curl -X POST http://localhost:8082/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"TraceApp","owner":"tester"}'

# Watch for SUBSCRIPTION_CREATED event
curl -N http://localhost:8082/events | grep "SUBSCRIPTION_CREATED"
```

**Learning:** Every state change in CP emits an event.

---

## Key Takeaways

1. **Local caching:** Drastically improves latency (microseconds vs. milliseconds).
2. **Event streaming:** Ensures consistency and immediate propagation.
3. **Microservices architecture:** Enables independent scaling and failure isolation.
4. **Health checks + startup ordering:** Prevents race conditions and ensures readiness.

---

## Reflection Log (Create This In Your Project)

Consider creating a file `REFLECTION.md` in your project to capture your own notes:

```markdown
# My Phase 3 Reflection

## Design Decision 1: Local Caching in GW
Q: Why cache subscriptions locally instead of calling CP per request?
A: [Your answer here]

## Design Decision 2: Event Streaming vs. Polling
Q: Why use SSE instead of polling?
A: [Your answer here]

## Design Decision 3: Microservices Architecture
Q: Why separate task definitions instead of monolithic?
A: [Your answer here]

## What Surprised Me
[Anything that caught you off guard?]

## What's Still Confusing
[Anything you want to revisit in Phase 4?]
```

---

## Next Phase Preview

Phase 4 (Optional; advanced production hardening):
- Distributed tracing with correlation IDs.
- Custom Go plugins for key managers and mediators.
- Failure mode analysis and recovery procedures.
- Terraform with RDS (CP persistence), ElastiCache (caching), X-Ray (tracing).

For now, you have a **fully functional, event-driven API management system** running locally and ready to scale to production.

---

## Files in This Phase

```
wso2_mastery/
├── content/phase3/
│   ├── day31.md through day42.md (previous days)
│   ├── day43.md (Docker Compose startup)
│   ├── day44.md (Smoke test guide)
│   └── day45.md (Design decisions + runbook)
├── labs/phase3/
│   ├── day31/ through day42/ (previous labs)
│   ├── day43/ (docker-compose.yml, README, teardown)
│   ├── day44/ (smoke_test.sh, README, SOLUTION, teardown)
│   └── day45/ (runbook, README, teardown)
```

---

## Congratulations!

You've completed Phase 3 of the WSO2 Mastery path. You understand:
- How to build an event-driven API platform from scratch.
- Why caching, event streaming, and microservices matter.
- How to test integration end-to-end.
- How to operate the system in production (via the runbook).

Next: Phase 4 (if interested) for production hardening, or return to other learning paths.

