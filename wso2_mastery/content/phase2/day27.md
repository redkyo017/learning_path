# Day 27: Traffic Manager Client and Global Throttling

## Why

Today you integrate a **mock Traffic Manager (TM)** into the gateway. The TM is the source of truth
for global throttle decisions across multiple gateway replicas. In production, each gateway sends
throttle events to the TM, and the TM coordinates the rate limiting across the fleet.

For a single-replica dev setup (your company's common case), the local token bucket (Day 26) is
sufficient. But as you scale to multi-replica deployments (ECS Fargate, Kubernetes), the TM becomes
essential to avoid quota overages.

---

## Throttle Events and the TM API

### What is a Throttle Event?

When a gateway's local bucket is breached (or periodically), it sends a throttle event to the TM:

```json
{
  "applicationId": "app1",
  "subscriptionId": "app1::myapi",
  "tier": "gold",
  "userId": "alice",
  "timestamp": "2026-09-03T10:30:00Z",
  "count": 1,
  "allowedCount": 5000
}
```

**Fields:**
- `applicationId`: The app's name (from JWT claim `applicationname`)
- `subscriptionId`: Unique subscription ID (usually `appName::apiName`)
- `tier`: Subscription tier (gold, silver, bronze, unlimited)
- `userId`: User who made the request (from JWT claim `subscriber`)
- `timestamp`: When the request occurred (ISO 8601)
- `count`: Number of requests in this batch
- `allowedCount`: Quota for this tier (5000 for gold, etc.)

### The TM HTTP API

The mock TM listens at `http://tm:9611` (default port).

**Endpoint:** `POST /throttle/data`

**Request body:** JSON throttle event (above)

**Response:**
```json
{
  "throttled": false,
  "globalCount": 4804,
  "allowedCount": 5000
}
```

**Fields:**
- `throttled`: Boolean — true if the app exceeded global quota
- `globalCount`: Current global count for this app::tier
- `allowedCount`: Quota for this tier
- (Optional) `nextResetTime`: When the quota resets (for sliding windows)

---

## Single-Replica vs. Multi-Replica

### Single-Replica Deployments (Your Company's Dev)

```
Client → GW (single replica) → Backend
          ↓
        Local Bucket
        (sufficient for accuracy)
        ↓
       (Optional) TM
```

Local token bucket is accurate because there's only one gateway.
No need to contact TM for correctness; local bucket is the source of truth.

### Multi-Replica Deployments (Production)

```
Client
  ├─→ GW-1 → Local Bucket A
  ├─→ GW-2 → Local Bucket B
  └─→ GW-3 → Local Bucket C
       ↓
   Traffic Manager (Global Truth)
   ├─ Aggregate from A, B, C
   ├─ Track global quota
   └─ Return: Allow or Deny
       ↓
   Each GW Enforces
```

Local buckets are fast but inaccurate across replicas.
TM maintains global accuracy by aggregating all events.

**Problem without TM:**
```
Request 5001-5003 arrive simultaneously at three GWs
- GW-1: local bucket allows → 429 from TM global check
- GW-2: local bucket allows → 429 from TM global check
- GW-3: local bucket allows → 429 from TM global check
Total: allowed 3 but should have denied 2 (quota is 5000)
```

**Solution with TM:**
```
GW-1 sends: count=5001, TM says throttled=true
GW-2 sends: count=5002, TM says throttled=true
GW-3 sends: count=5003, TM says throttled=true
All three GWs enforce the TM decision → correct behavior
```

---

## Mock TM Implementation

For your dev environment, you don't need a full TM. A mock TM that:
1. Accepts POST requests at `/throttle/data`
2. Logs the throttle events
3. Always returns `throttled=false` (permissive, for testing)

This is enough to:
- Verify the GW is sending events correctly
- Practice the GW→TM integration
- Test end-to-end flow

In production, replace the mock with the real WSO2 TM.

### Mock TM Handler

```go
func mockTMHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
        return
    }
    var event struct {
        ApplicationID  string `json:"applicationId"`
        SubscriptionID string `json:"subscriptionId"`
        Tier           string `json:"tier"`
        UserID         string `json:"userId"`
        Timestamp      string `json:"timestamp"`
        Count          int    `json:"count"`
        AllowedCount   int    `json:"allowedCount"`
    }
    if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
        http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
        return
    }
    slog.Info("throttle event received",
        "app", event.ApplicationID,
        "tier", event.Tier,
        "count", event.Count,
    )
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"throttled":false,"globalCount":1000,"allowedCount":5000}`)
}
```

---

## Sending Throttle Events from the GW

The gateway sends throttle events when:
1. Local bucket is breached (optional, depends on implementation)
2. Periodically (e.g., every 60 seconds) to keep TM in sync
3. When an app's quota resets (start of new window)

For simplicity in the lab, the GW sends events **on every request** (not scalable in production,
but works for dev):

```go
func sendThrottleEvent(applicationName, tier string) error {
    tmURL := os.Getenv("TM_URL")
    if tmURL == "" {
        tmURL = "http://localhost:9611"
    }
    event := map[string]interface{}{
        "applicationId":  applicationName,
        "subscriptionId": applicationName + "::" + tier,
        "tier":           tier,
        "userId":         "unknown",
        "timestamp":      time.Now().UTC().Format(time.RFC3339),
        "count":          1,
        "allowedCount":   5000, // Hardcoded for mock
    }
    body, _ := json.Marshal(event)
    resp, err := http.Post(tmURL+"/throttle/data", "application/json", 
        bytes.NewReader(body))
    if err != nil {
        slog.Error("failed to send throttle event", "err", err)
        return err
    }
    defer resp.Body.Close()
    return nil
}
```

---

## Lab

See `labs/phase2/day27/` — full gateway with throttle middleware + mock TM.

### Features

- JWT validation + subscription check + throttle middleware (from Days 24–26)
- **NEW:** Mock TM server listening at `/throttle/data`
- **NEW:** GW sends throttle events to TM
- **NEW:** In docker-compose, TM runs on separate container

### Running the Lab

```bash
cd labs/phase2/day27
docker-compose up --build

# In another terminal:

# 1. Add a subscription
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'

# 2. Get a token
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# 3. Make a request
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello

# 4. Check TM logs (should see throttle event logged)
docker-compose logs tm
# Expected: "throttle event received app=app1 tier=gold count=1"

# 5. Try with an app that has a different tier
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app2",
    "apiname":"hello",
    "subscriptiontier":"silver",
    "keytype":"PRODUCTION"
  }'

TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

curl -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello

# 6. Check TM logs again
docker-compose logs tm
# Expected: "throttle event received app=app2 tier=silver count=1"
```

---

## Exercises

**Exercise 1:** In production with 3 GW replicas, if the TM is unreachable for 5 seconds, what
should happen to requests?

**Hint:** Should the gateway:
- A) Block all requests until TM recovers
- B) Allow requests using local bucket only
- C) Return 503 Service Unavailable
- D) Retry with exponential backoff then fall back to local bucket

**Solution sketch:**

~~~
Best practice: D (retry with exponential backoff, then fall back)

Rationale:
- Option A (block all): Kills availability, not acceptable for prod
- Option C (503): Same as A, unnecessary failure
- Option B (silent fallback): No visibility into TM health, might miss issues
- Option D (retry + fallback): Resilient, observable

Implementation sketch:
```go
err := sendThrottleEventWithRetry(event, maxRetries=3, backoff=100ms)
if err != nil {
    slog.Warn("TM unreachable, using local bucket only", "app", app)
    // Continue with local bucket
} else {
    // TM returned decision, enforce it
}
```

This is called the "circuit breaker" or "bulkhead" pattern in resilience engineering.
~~~

---

**Exercise 2:** The mock TM always returns `throttled=false`. In production, when would the TM
return `throttled=true`?

**Hint:** Think about the scenario from Exercise 1 of Day 25: three replicas each allowing
1667 requests out of 5000, exceeding the quota.

**Solution sketch:**

```
TM tracks global state:

globalCount = 0
allowedCount = 5000

Request arrives at GW-1:
- GW-1 sends: count=1
- TM updates: globalCount = 1
- TM checks: 1 <= 5000, returns throttled=false

Requests arrive at GW-2 and GW-3 simultaneously:
- GW-2 sends: count=1
- GW-3 sends: count=1
- TM updates: globalCount = 3
- TM checks: 3 <= 5000, returns throttled=false

... many requests later ...

globalCount = 4999

Request arrives at GW-1:
- GW-1 sends: count=1
- TM updates: globalCount = 5000
- TM checks: 5000 <= 5000, returns throttled=false

Next request:
- GW-2 sends: count=1
- TM updates: globalCount = 5001
- TM checks: 5001 > 5000, returns throttled=true
- GW-2 enforces: 429 returned to client

Once throttled=true is returned, GW stops sending events (or reduces rate)
until the quota resets (usually at the start of next minute/hour/day).
```

---

**Exercise 3:** Design a scenario where you have 3 GW replicas, each with local buckets
(Gold: 5000/min), handling 4000 requests/min from clients, and explain why only the TM
can enforce the true quota.

**Hint:** Assume requests are load-balanced evenly across the three replicas (no sticky sessions).

**Solution sketch:**

```
Setup:
- 3 GW replicas, each has local bucket for Gold tier: 5000/min
- Total global quota: 5000/min (NOT 15000/min)
- Load balancer distributes requests: ~1333 req/min per GW
- Clients send: 4000 req/min total

Without TM (local buckets only):
- GW-1: 1333 requests, bucket has 5000 capacity, allows all ✓
- GW-2: 1333 requests, bucket has 5000 capacity, allows all ✓
- GW-3: 1333 requests, bucket has 5000 capacity, allows all ✓
- Total allowed: 4000 (all requests pass)
- Global quota: 5000 (exceeded? No, but close)
- Problem: If traffic spikes to 5001 req/min:
  - Each GW sees ~1667 req/min
  - Each GW's bucket allows it (has capacity for 5000)
  - Total allowed: 5001 (OVER quota, WRONG)

With TM (global decision):
- GW-1: sends 1333 events to TM
- GW-2: sends 1333 events to TM
- GW-3: sends 1333 events to TM
- TM aggregates: 4000 total, quota is 5000, throttled=false
- If spike to 5001:
  - GW-1: 1667, TM says globalCount would be 5001, throttled=true
  - GW-2: 1667, TM queues (or buffers), doesn't send more until window resets
  - GW-3: 1667, TM queues
  - Total allowed: ~5000 (CORRECT)

Conclusion: TM makes throttling accurate across replicas by maintaining global state.
Local buckets alone cannot coordinate across distributed GWs.
```

---

## Anti-patterns

- **Sending throttle events too frequently** — If you send an event per request and have 10k req/s,
  you're hammering the TM. Batch events or send periodically instead.

- **Blocking requests while waiting for TM response** — TM communication should be async/non-blocking.
  If TM is slow, the request should proceed using local bucket and TM answer is cached/deferred.

- **Hardcoding the TM URL** — Use an environment variable (`TM_URL`) so the mock TM can be
  replaced with the real TM in production.

- **Not logging throttle decisions** — Always log when TM returns throttled=true. This is a signal
  that quotas are wrong, apps need upgrades, or there's unusual traffic.

---

## Teardown

Stop docker-compose with `Ctrl+C`.

```bash
docker-compose down -v
```

---

## Next Steps

- **Task 5:** Add gateway debug patterns (request logging, metrics, tracing).
- **Production integration:** Replace mock TM with real WSO2 TM; add retry logic, circuit breaker,
  and event batching.
