# Day 30: GW Capstone — Debug Any Error in 3 Minutes

## Why

You've spent 4 weeks learning the gateway internals: token validation, subscriptions, throttling, and debug logging.
Now you put it all together in a capstone: **given a real error from the gateway (401/403/429), diagnose and fix it in 3 minutes.**

This is the skill that defines a GW engineer. In production, when a client reports "My API is broken,"
you need to:
1. Identify whether it's a GW problem or client problem
2. Pull the right logs
3. Read the log patterns (Day 29)
4. Root cause the issue
5. Recommend a fix

Today's lab simulates a production incident.

---

## Phase 2 Recap: What You've Built

### Days 16–20: Foundation
- HTTPS certificates, TLS handshakes, certificate chains
- JWT structure, claims, signature, expiry

### Days 21–23: Integration Patterns
- IS (Identity Server) as token issuer
- GW (Gateway) as token validator
- Key sharing: JWKS endpoint

### Days 24–26: Security & Throttling
- JWT validation in GW (signature, expiry, key lookup)
- Subscription checks (app must be bound to API)
- Per-tier throttle limits (Gold 5000, Silver 2000, etc.)

### Days 27: Distributed Throttling
- Traffic Manager for multi-replica deployments
- TM aggregates quota across GW replicas
- GW sends throttle events to TM

### Day 28–29: Debugging
- 5 GW-specific log4j2 loggers to enable
- 6 log line patterns to memorize
- How to correlate failures across logs

---

## The 3-Minute Diagnostic Framework

### Step 1: Identify the Error (15 seconds)

When a client reports a problem, ask:

```
Q: What HTTP status code?
A: 401 Unauthorized
   → JWT validation failed

A: 403 Forbidden
   → Subscription check failed, or keytype mismatch

A: 429 Too Many Requests
   → Throttle limit exceeded

A: 502 Bad Gateway
   → GW can't reach backend (not a GW security issue)

A: 5xx Internal Server Error
   → GW crashed (check GW logs for exceptions)
```

### Step 2: Collect Logs (30 seconds)

For ECS Fargate deployments:

```bash
# Get correlation ID from error response header
correlation_id=$(curl -i https://gw:8243/api/myapi | grep -i activityid | cut -d: -f2)

# Pull GW logs from CloudWatch (last 5 min)
aws logs filter-log-events \
  --log-group-name /ecs/wso2-gw \
  --start-time $(($(date +%s)*1000 - 300000)) \
  --filter-pattern "$correlation_id" \
  --query 'events[].message' > /tmp/gw.log

# Pull IS logs (if 401 — might be token issuance problem)
aws logs filter-log-events \
  --log-group-name /ecs/wso2-is \
  --start-time $(($(date +%s)*1000 - 300000)) \
  --filter-pattern "OAuthClientAuthn" \
  --query 'events[].message' > /tmp/is.log
```

For Docker dev:

```bash
docker logs gateway 2>&1 | tail -100 > /tmp/gw.log
docker logs is 2>&1 | tail -100 > /tmp/is.log
```

### Step 3: Match Log Patterns (1 minute)

Use Day 29 patterns:

```bash
# 401? Look for:
grep "JWT token validation failed" /tmp/gw.log
  → Token expired? Signature failed? Key not found?

# 403? Look for:
grep "API subscription not found" /tmp/gw.log
  → App not subscribed to this API?

# 429? Look for:
grep "Request throttled" /tmp/gw.log
  → Which tier? How many requests in window?
```

### Step 4: Root Cause (1 minute)

Based on patterns, narrow down:

```
401 + "Token expired"
  → Client is using old token. Recommend: issue new token

401 + "Signature verification failed"
  → IS rotated keys, GW cache stale. Recommend: restart GW

401 + "Public key not found for kid"
  → kid mismatch. Recommend: restart GW, verify JWKS URL in deployment.toml

403 + "API subscription not found"
  → App never subscribed. Recommend: register subscription in CP UI

429 + "Request throttled"
  → Quota hit. Recommend: wait 60 sec or upgrade tier
```

### Step 5: Verify Fix (15 seconds)

Re-test:

```bash
# Get new token (if 401)
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# Retry request
curl -H "Authorization: Bearer $TOKEN" https://gw:8243/api/hello
  → Should get 200 OK or 502 (backend problem, not GW)
```

---

## IS vs GW Split

In production, IS logs and GW logs are separate. Know which to check:

| Symptom | Check | Root Cause |
|---|---|---|
| No token issued (401) | IS logs (OAuthClientAuthn) | IS down, credentials wrong, or client app not registered |
| Token issued but 401 at GW | GW logs (JWTValidator) | Key rotated, token expired, or key fetch failed |
| 401 inconsistently (some requests ok) | GW logs (JWTValidator) + TM logs | Load balancer sending to replica with stale cache |
| Token valid but 403 | GW logs (APIAuthenticationHandler) | Subscription missing, or keytype mismatch |
| Throttle 429 (all users affected) | TM logs + GW logs | Global quota misconfigured or TM unreachable |
| Throttle 429 (only some users) | GW logs (ThrottleHandler) | Per-replica bucket exhaustion, or load balancer imbalance |

---

## ECS Fargate Specific: CloudWatch Log Filtering

In a production ECS deployment, logs go to CloudWatch. Useful queries:

```bash
# All errors in last hour
aws logs filter-log-events \
  --log-group-name /ecs/wso2-gw \
  --start-time $(($(date +%s)*1000 - 3600000)) \
  --filter-pattern "ERROR" \
  --query 'events[].[timestamp, message]' \
  --output text

# All 401 related to specific app
aws logs filter-log-events \
  --log-group-name /ecs/wso2-gw \
  --filter-pattern "[..., app=\"app1\", ...]" \
  --query 'events[].message'

# Count occurrences of each error type
aws logs filter-log-events \
  --log-group-name /ecs/wso2-gw \
  --start-time $(($(date +%s)*1000 - 600000)) \
  --filter-pattern "WARN" \
  --query 'events[].message' | jq -s 'group_by(.) | map({pattern: .[0], count: length})'
```

---

## Phase 2 Completion Checklist

By the end of Day 30, you should be able to:

| Skill | Evidence |
|---|---|
| Understand HTTPS handshake | Explain certificate chain, TLS versions, self-signed certs |
| Parse JWT structure | Extract header, payload, signature from a token |
| Validate JWT in GW | Trace through signature verification, expiry check, key lookup |
| Handle subscriptions | Register app, bind API, check subscription state |
| Throttle per-tier | Understand bucket refill, quota per tier, TM coordination |
| Enable debug logging | Edit log4j2.properties, add 5 GW loggers, restart container |
| Recognize 6 log patterns | Read logs and identify token expiry, signature mismatch, subscription missing, throttle, key not found, validation success |
| Diagnose 401/403/429 | Pull logs, correlate failures, root cause in < 3 min |
| Deploy to ECS | Use CloudWatch Logs, correlation IDs, task restarts |

---

## Exercises

**Exercise 1:** You get an alert: "50% of requests to API 'payments' are returning 401 Unauthorized."
Walk through the 3-minute diagnostic framework. What would you check first, and why?

**Hint:** Think about what could cause a **sudden** 50% failure rate (not 0% or 100%).

**Solution sketch:**

```
Sudden 50% failure suggests:
- Load balancer directing traffic to 2 healthy GW replicas (ok) + 1 with stale cache (fails)
- Or: IS just rotated keys, and only half of GW replicas restarted
- Or: IS JWKS endpoint became unreachable 5 min ago, TM cache degradation

Diagnostic steps:
1. Check if exactly 2 out of 3 GW replicas are failing → cache/config issue
2. Check GW logs for "Public key not found for kid" or "Signature verification failed"
3. Check IS logs for key rotation event
4. Check if IS JWKS endpoint is reachable:
   curl -v https://is:9443/oauth2/jwks
5. If IS is healthy, restart the 1 failing GW replica:
   docker-compose restart gateway
   (or aws ecs update-service --force-new-deployment)

Expected recovery time: < 1 min
```

---

**Exercise 2:** A client reports: "I can call the 'hello' API, but 'orders' API gives 403. Both are from my app."
What's the most likely root cause, and how do you fix it?

**Hint:** Both APIs use the same token (JWT), and both are called from the same app. Why would one work and one fail?

**Solution sketch:**

```
Root cause: App is subscribed to 'hello' API, but NOT subscribed to 'orders' API.

Evidence:
- Same app, same token → JWT validation succeeds for both
- 'hello' returns 200 → JWT is valid, app can call hello
- 'orders' returns 403 → subscription check fails for 'orders'

GW logs will show:
- hello: "DEBUG {APIAuthenticationHandler} - Subscription found: hello"
- orders: "DEBUG {APIAuthenticationHandler} - Subscription not found: orders"

Fix:
1. In CP (Control Plane) admin UI, navigate to: Subscriptions → Add New Subscription
2. Create subscription: app=app1, api=orders, tier=gold, keytype=PRODUCTION
3. Test: curl -H "Authorization: Bearer $TOKEN" https://gw:8243/api/orders
   → Should return 200 (or 502 if backend down, but not 403)
```

---

**Exercise 3:** You run 3 GW replicas. Traffic is ~100 req/s, all to one app with gold tier (5000 req/min).
Suddenly, some requests get 429, but average load is only 75 req/min. Why?

**Hint:** Think about per-replica vs global quota, and what the load balancer might be doing.

**Solution sketch:**

```
Problem: Per-replica bucket exhaustion even though global quota isn't hit.

Math:
- Global quota: 5000 req/min for this app
- 3 replicas: ideally each handles ~1667 req/min
- But traffic is only 100 req/s = 6000 req/min (oops, that exceeds quota!)
- Actually 100 req/s = 6000 req/min if sustained over 1 minute

Wait, let me recalculate:
- 100 req/s × 60 sec = 6000 requests/min
- Global quota is 5000 req/min
- So quota IS being exceeded

But the problem says "load is only 75 req/min" which doesn't match 100 req/s...

Assuming problem meant 75 req/s = 4500 req/min:
- Global quota: 5000 req/min (not hit yet)
- But some replicas are getting 429

Causes:
1. Load balancer is NOT evenly distributing (sticky sessions, or misconfiguration)
   - GW-1 gets 3000 req/min → 429 (exceeds 5000 local quota? No, per-replica is 5000)
   - Actually, per-replica quota should also be 5000 (copied from global)

2. More likely: TM is unreachable, all GWs use local buckets
   - GW-1: local bucket, 4500 requests fit → no 429
   - GW-2: local bucket, 4500 requests fit → no 429
   - But some are hitting 429...

3. Most likely: Load balancer weighted wrong
   - GW-1 gets 3000 req/min (ok)
   - GW-2 gets 1500 req/min (ok)
   - GW-3 gets 1000 req/min (ok)
   - Total 5500 req/min → slightly over quota
   - But if TM is coordinating globally, only 5000 should be allowed

Root cause: TM is returning throttled=true after 5000 requests, but load balancer is still sending requests.
Requests hitting the 5001-6000 mark get throttled.

Fix:
1. Check TM logs for throttling decisions
2. Verify TM is reachable from all GW replicas
3. Increase per-tier quota in TM config if this tier needs more
```

---

## Next Steps

- **Milestone:** You've completed Phase 2! (Days 16–30)
- **Phase 3:** Production deployment patterns, multi-region, disaster recovery, monitoring.

---

## Summary: What You Know Now

You can:
- ✓ Explain TLS handshakes and certificate validation
- ✓ Parse and validate JWTs
- ✓ Implement token validation in a gateway
- ✓ Handle subscription checks and throttling
- ✓ Enable debug logging and read log patterns
- ✓ Diagnose 401/403/429 errors in < 3 minutes
- ✓ Deploy to ECS Fargate with CloudWatch Logs
- ✓ Coordinate throttling across multiple replicas using TM

**This is production-grade gateway engineering.**

