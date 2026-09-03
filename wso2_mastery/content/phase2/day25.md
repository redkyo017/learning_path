# Day 25: Traffic Manager and the Throttle Architecture

## Why

Today you learn WSO2's throttle (rate-limiting) architecture, which is more sophisticated than a
simple per-gateway counter. Instead, it uses a centralized **Traffic Manager (TM)** that coordinates
throttle decisions across multiple gateway replicas.

This is critical for multi-region deployments: if your API gateway runs on three ECS Fargate replicas,
you can't have each one independently count requests — you'd allow 3x the limit. The TM solves this.

---

## WSO2 Throttle Architecture

### The Problem

Naive throttling (per-gateway counter):
```
Client
  ├─→ GW-1 (counter: 50/100) ✓
  ├─→ GW-2 (counter: 40/100) ✓
  └─→ GW-3 (counter: 60/100) ✓
     Total allowed: 150 (should be 100)  ❌ OVERAGE
```

Each gateway thinks it's within limit, but globally the app exceeded quota.

### The Solution: Traffic Manager

WSO2 architecture:
```
Client Requests (replica 1, 2, 3, ...)
  ↓
Gateway Replicas (local counters)
  ├─→ GW-1
  ├─→ GW-2
  └─→ GW-3
       ↓
Traffic Manager (Global Decision Point)
  |
  ├─ Tracks aggregate counts across all GW replicas
  ├─ Receives throttle events from GWs
  ├─ Makes global allow/deny decision
  └─ Returns decision to each GW
       ↓
GW Enforces: Allow or Deny (429)
```

### The Throttle Flow (Detailed)

1. **Client sends request to GW-1**
   ```
   GET /api/myapi?subscription_key=app1_PRODUCTION
   Authorization: Bearer <JWT>
   ```

2. **GW-1: JWT validation & subscription check (Day 24)** — Pass

3. **GW-1: Local throttle counter check**
   ```go
   // From JWT: claims.ApplicationName = "app1", claims.ApplicationTier = "gold"
   // Gold tier: 5000 requests / minute
   // GW-1's local bucket for "app1::gold": 4999/5000 remaining
   // → Counter not breached yet
   ```

4. **GW-1: Send throttle event to TM (if local counter breached or periodic sync)**
   ```json
   {
     "applicationId": "app1",
     "subscriptionId": "app1::myapi",
     "tier": "gold",
     "timestamp": "2026-09-03T10:30:00Z",
     "count": 1,
     "allowedCount": 5000
   }
   ```

5. **TM: Receive event, update global counter**
   ```
   TM's global counter for "app1::gold":
     Before: 4800/5000
     Incoming: +1 from GW-1, +2 from GW-2, +1 from GW-3
     After: 4804/5000
     Status: NOT_THROTTLED
   ```

6. **TM: Return decision to GW**
   ```json
   {
     "throttled": false,
     "globalCount": 4804,
     "allowedCount": 5000
   }
   ```

7. **GW-1: Enforce decision**
   - If `throttled=false` → Allow request → Forward to backend ✓
   - If `throttled=true` → Reject with 429 ✗

---

## Throttle Tiers

WSO2 API Manager defines throttle tiers (subscription-level throttling):

| Tier      | Rate              | Burst      | Use Case                           |
|-----------|-------------------|------------|-------------------------------------|
| Unlimited | No limit          | No burst   | Internal APIs, premium customers   |
| Gold      | 5000 req/min      | 60s burst  | Production, tier-1 partners        |
| Silver    | 2000 req/min      | 60s burst  | Standard tier, most customers      |
| Bronze    | 1000 req/min      | 60s burst  | Trial tier, low-volume partners    |

Each subscription record (created in Day 24) includes the tier:
```json
{
  "applicationname": "myapp",
  "apiname": "api1",
  "subscriptiontier": "gold",
  "keytype": "PRODUCTION"
}
```

---

## Token Bucket Algorithm

The TM (and individual GWs) implement the **token bucket** algorithm for rate limiting.

### Concept

Imagine a bucket with `capacity` tokens. Tokens refill at `rate` tokens/second.
Each request consumes 1 token.

```
Time 0:        bucket: [#####] (full, 100 tokens)
Time 0.01s:    request: bucket: [####_] (99 tokens)
Time 0.02s:    request: bucket: [####_] (98 tokens)
Time 0.1s:     refill: bucket: [#####] (100 tokens refilled during the 0.08s)
Time 0.11s:    request: bucket: [####_] (99 tokens)
Time 0.12s:    request DENIED: bucket: [     ] (no tokens left) → 429
```

### Parameters

For a tier like Gold (5000 req/min):
- **Rate (r)**: 5000 / 60 = ~83.33 tokens/second
- **Capacity (b)**: Usually 1-60 seconds worth of traffic
  - Common: `b = r * 60` (60 seconds of burst capacity)
  - For Gold: `b = 83.33 * 60 = 5000` tokens

### Allow Decision

```
On each request:
  1. Current time: t_now
  2. Last refill time: t_last
  3. Tokens to add: (t_now - t_last) * rate
  4. Current tokens: min(capacity, tokens_before + tokens_to_add)
  5. If current_tokens >= 1:
       tokens -= 1
       return ALLOW
     Else:
       return DENY (429)
```

---

## WSO2 Throttle Source Code References

### ThrottleHandler.java (in the GW)

Located in: `wso2am-universal-gw-4.7.0/components/throttle-handler/`

Key method: `handleThrottle()`
- Receives the request context (claims, tier)
- Checks local token bucket
- If breached: sends throttle event to TM
- Returns allow/deny

### GlobalThrottleEngineClient.java (in the GW)

Located in: `wso2am-universal-gw-4.7.0/components/traffic-manager-client/`

Key method: `publishNonThrottledEvent()` or `publishThrottledEvent()`
- Sends throttle events to TM via HTTP POST
- Endpoint: `http://tm-host:9611/throttle/data`
- Payload: JSON with appId, tier, count, timestamp

---

## Lab

See `labs/phase2/day25/` — source reading lab.

Your task: Find the `ThrottleHandler.java` file in the WSO2 GW source, and identify:
1. The method that invokes the TM client
2. The structure of the throttle event sent to TM
3. What data is logged when a throttle decision is made

---

## Exercises

**Exercise 1:** What is the difference between the TM throttle decision and local gateway throttle?

**Hint:** The local gateway can reject a request (429) before contacting TM. The TM makes the
global decision across all replicas. When does local rejection make sense? (Clue: network latency.)

**Solution sketch:**

```
Local Throttle (Gateway):
- Fast, no network round-trip
- Prevents DoS at the edge
- Can reject before TM is contacted
- Useful for circuit-breaking or bursty traffic

Global Throttle (TM):
- Accurate across replicas
- Eventual consistency (TM decision may arrive after local rejection)
- Resolves true app-level quota across the fleet
- Source of truth for subscription tier enforcement

In practice:
- GW has a local token bucket (fast path)
- GW also sends events to TM (slow path)
- If TM says "throttled", GW enforces immediately on next request
- If TM is unreachable, GW falls back to local bucket only
```

---

**Exercise 2:** For the Gold tier (5000 req/min), what should the token bucket capacity be?

**Hint:** Think about burst traffic. If all requests arrive in a 1-second spike, how many should
be allowed? The capacity should be at least 1 second worth.

**Solution sketch:**

```
Gold tier: 5000 req/min = 5000 / 60 ≈ 83.33 tokens/second

Reasonable capacity values:
- Conservative: b = r * 10  = 833 (10 seconds)
- Standard:    b = r * 60  = 5000 (60 seconds)
- Aggressive:  b = r * 120 = 10000 (120 seconds)

Standard choice (60s): Allows a spike of 60 seconds worth of traffic,
then enforces the rate limit. This absorbs normal client request bursts
while still protecting the API.
```

---

**Exercise 3:** The TM is a separate process. What happens if the TM is down or unreachable?

**Hint:** In production, WSO2 has a fail-over mode. What should the gateway do?

**Solution sketch:**

```
TM Down Scenarios:

1. TM Unreachable (network error):
   GW retries with backoff, then falls back to local bucket only.
   Risk: Distributed clients might exceed global quota.
   Mitigation: Reduce local bucket capacity or reduce rate to be conservative.

2. TM Recovers:
   GW re-syncs throttle events, TM rebuilds state from event log.
   Risk: Brief window where old state is used.
   Mitigation: Use time-windowed buckets that reset every minute.

3. Permanent TM Failure:
   Option A: GW continues with local bucket (best effort, non-strict).
   Option B: GW denies all requests to that app (strict, fail-closed).
   WSO2 default: Option A (best effort), logged with ERROR level.

Design lesson: Always have a fallback when depending on a centralized service.
```

---

## Anti-patterns

- **Ignoring the TM** — Some teams deploy only local throttle and skip TM. This works in
  single-replica setups but breaks under scale with distributed quota overages.

- **Blocking all requests if TM is slow** — If TM takes 500ms to respond, blocking all requests
  kills throughput. Instead, use the local bucket as the fast path and TM as async sync.

- **No monitoring on throttle events** — If 50% of requests are throttled (429), something is wrong
  (bad tier assignment or quota too low). Always alert on throttle rates.

- **Forgetting that tokens don't carry across buckets** — Gold tier and Silver tier have separate
  buckets. A request will check only its tier's bucket. Mixing them up causes unexpected rejections.

---

## Teardown

This is a reading lab only. No resources to clean up.

---

## Next Steps

- **Day 26:** Implement the token-bucket algorithm in Go and build a local throttle middleware.
- **Day 27:** Integrate a mock TM client to complete the gateway.
