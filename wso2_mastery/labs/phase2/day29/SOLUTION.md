# Solution: Day 29 — GW Log Analysis

## Analysis of gw_failure.log

This solution analyzes the synthetic gateway debug log file and answers each diagnostic question.

---

## Question 1: Which request succeeded and returned 200 OK to the client?

**Answer:** `req-001` succeeded and returned 200 OK.

**Evidence (Log Lines):**

```
[2026-09-03 10:30:00,107] DEBUG - JWT token validated successfully for application: app1
[2026-09-03 10:30:00,109] DEBUG - Subscription found: tier=gold, keytype=PRODUCTION
[2026-09-03 10:30:00,111] DEBUG - Bucket allows request, count=1
```

**Analysis:**
- JWT validation passed (line 107)
- Subscription check passed (line 109) — app1 is subscribed to hello API with gold tier
- Throttle check passed (line 111) — bucket had 4999 requests remaining, request allowed
- No WARN or ERROR logs for this request
- **Result: 200 OK**

---

## Question 2: What was the failure reason for req-002, and what HTTP status code would it return?

**Answer:** req-002 failed with **401 Unauthorized** due to **Token Expired**.

**Evidence (Log Lines):**

```
[2026-09-03 10:30:01,202] DEBUG - Extracting token from Authorization header
[2026-09-03 10:30:01,202] DEBUG - Token expiry: 2026-09-02T10:30:00Z
[2026-09-03 10:30:01,203] DEBUG - Current time: 2026-09-03T10:30:01Z
[2026-09-03 10:30:01,204] WARN - JWT token validation failed: Token expired
```

**Analysis:**
- Token extraction succeeded
- Token expiry time: 2026-09-02 10:30:00 (yesterday)
- Current time: 2026-09-03 10:30:01 (today)
- Token is **1 day old** and has expired
- Request rejected at JWT validation stage
- **HTTP Status: 401 Unauthorized**
- **Failure Reason: Token Expired**

**Recommendation:** Client must request a new token from the IS (Identity Server).

---

## Question 3: Which application hit the subscription wall (403 Forbidden), and what API was it trying to access?

**Answer:** `app2` hit the subscription wall when trying to access the `orders` API.

**Evidence (Log Lines):**

```
[2026-09-03 10:30:02,302] DEBUG - Claim applicationname: app2
[2026-09-03 10:30:02,307] DEBUG - JWT token validated successfully for application: app2
[2026-09-03 10:30:02,308] DEBUG - Checking subscription: app2::orders
[2026-09-03 10:30:02,309] WARN - API subscription not found for application: app2
```

**Analysis:**
- JWT token for app2 is valid (line 307)
- App2 is trying to access the `orders` API (line 308)
- Subscription check failed (line 309) — app2 has no subscription to the orders API
- Request rejected at subscription validation stage
- **HTTP Status: 403 Forbidden**
- **Failure Reason: API subscription not found**

**Recommendation:** Register a subscription for app2 to the orders API in the Control Plane admin UI.

---

## Question 4: Which tier was throttled (429 Too Many Requests), and what was the bucket state at failure?

**Answer:** The `gold` tier was throttled when processing req-005. The bucket was exhausted (0 requests remaining).

**Evidence (Log Lines):**

```
[2026-09-03 10:30:04,507] DEBUG - JWT token validated successfully for application: app1
[2026-09-03 10:30:04,509] DEBUG - Subscription found: tier=gold, keytype=PRODUCTION
[2026-09-03 10:30:04,510] DEBUG - Checking throttle: app=app1, tier=gold, bucket=0
[2026-09-03 10:30:04,511] DEBUG - Bucket exhausted
[2026-09-03 10:30:04,512] WARN - Request throttled for application: app1, tier: gold
```

**Analysis:**
- Application: app1
- Subscription tier: gold
- Bucket state before throttle check: 0 (exhausted)
- Throttle decision: DENIED (bucket exhausted)
- **HTTP Status: 429 Too Many Requests**
- **Throttled Tier: Gold**
- **Bucket State: 0/5000 (completely exhausted)**

**Explanation:** The gold tier has a quota of 5000 requests per minute. By the time req-005 arrived, all 5000 requests for this minute had already been used by app1 (previous 4 requests + other clients). The bucket will refill at the start of the next minute.

**Recommendation:** 
1. Wait ~60 seconds for the bucket to refill
2. If quota is consistently exceeded, upgrade app1 to a higher tier (platinum/unlimited)
3. Check if load is distributed evenly across GW replicas

---

## Summary: Request Outcomes

| Request | Application | API | Status | Reason |
|---|---|---|---|---|
| req-001 | app1 | hello | 200 OK | ✓ JWT valid, subscription found, quota ok |
| req-002 | (unknown) | (unknown) | 401 Unauthorized | ✗ Token expired |
| req-003 | app2 | orders | 403 Forbidden | ✗ Subscription not found |
| req-004 | app3 | hello | 200 OK | ✓ JWT valid, subscription found, quota ok |
| req-005 | app1 | hello | 429 Too Many Requests | ✗ Throttle quota exhausted |

---

## Log Pattern Recognition

This exercise demonstrates the 3 key failure patterns from Day 29:

1. **Pattern: JWT Validation Failure (401)**
   - Log: `WARN {JWTValidator} - JWT token validation failed: Token expired`
   - HTTP Status: 401 Unauthorized

2. **Pattern: Subscription Not Found (403)**
   - Log: `WARN {APIAuthenticationHandler} - API subscription not found for application: app2`
   - HTTP Status: 403 Forbidden

3. **Pattern: Throttle Limit Exceeded (429)**
   - Log: `WARN {ThrottleHandler} - Request throttled for application: app1, tier: gold`
   - HTTP Status: 429 Too Many Requests

---

## Key Takeaways

- **Successful requests** have only DEBUG lines, no WARN/ERROR
- **Failed requests** have a WARN log explaining the failure
- **Timestamps** help correlate requests across multiple log files (useful in multi-replica deployments)
- **Claim extraction** (applicationname, subscriber) appears in successful token parsing
- **Bucket state** is logged just before throttle decision
- **Subscription details** (tier, keytype) appear only after successful JWT validation

