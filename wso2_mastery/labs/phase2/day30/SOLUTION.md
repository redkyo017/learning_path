# Solution: Day 30 — GW Capstone

## Overview

This solution documents the expected outcomes when running the Day 30 capstone lab with the Day 27 gateway.

---

## Scenario A: 401 Unauthorized (Expired Token)

### Test Case

```bash
# Get a token (valid for 30 seconds in dev)
TOKEN=$(curl -s "http://localhost:8888/token?username=alice&appname=app1" | jq -r .token)

# Verify it works first
curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN" -k
# Expected: 200 OK

# Wait 31 seconds for token to expire
sleep 31

# Try again with expired token
curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN" -k
# Expected: 401 Unauthorized
```

### Expected Outcome

**HTTP Status:** 401 Unauthorized

**Log Pattern Found:**

```
WARN {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - JWT token validation failed: Token expired
```

**Full Log Trace:**

```
DEBUG {JWTValidator} - JWT token received
DEBUG {JWTValidator} - Extracting token from Authorization header
DEBUG {JWTValidator} - Token expiry: 2026-09-03T10:30:30Z
DEBUG {JWTValidator} - Current time: 2026-09-03T10:31:02Z
DEBUG {JWTValidator} - Token is expired (31 seconds old)
WARN {JWTValidator} - JWT token validation failed: Token expired
```

**Root Cause:**

Token's expiry timestamp (`exp` claim) is in the past. The token was issued 31 seconds ago with a 30-second TTL.
When the request arrived at 31 seconds after issuance, the gateway rejected it as expired.

**Remediation:**

1. **Client-side fix:** Request a new token from the Identity Server before making the API call
   ```bash
   TOKEN=$(curl -s "http://localhost:8888/token?username=alice&appname=app1" | jq -r .token)
   curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN" -k
   ```

2. **Production context:** 
   - Tokens in production are usually valid for 1 hour, not 30 seconds
   - Implement token refresh logic on the client to refresh before expiry
   - Tokens expire to reduce impact of token theft (limited use window)

---

## Scenario B: 403 Forbidden (Subscription Not Found)

### Test Case

```bash
# Get a token for app3 (which has NO subscription to any API)
TOKEN3=$(curl -s "http://localhost:8888/token?username=charlie&appname=app3" | jq -r .token)

# Try to call hello API (app3 is not subscribed)
curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN3" -k
# Expected: 403 Forbidden
```

### Expected Outcome

**HTTP Status:** 403 Forbidden

**Log Pattern Found:**

```
WARN {org.wso2.carbon.apimgt.gateway.handlers.authentication.APIAuthenticationHandler} - API subscription not found for application: app3
```

**Full Log Trace:**

```
DEBUG {JWTValidator} - JWT token received
DEBUG {JWTValidator} - Extracting token from Authorization header
DEBUG {JWTValidator} - Claim applicationname: app3
DEBUG {JWTValidator} - Token expiry: 2026-09-03T10:31:32Z
DEBUG {JWTValidator} - Current time: 2026-09-03T10:31:02Z (valid)
DEBUG {JWTValidator} - Signature valid for kid: key-uuid-1234
DEBUG {JWTValidator} - JWT token validated successfully for application: app3
DEBUG {APIAuthenticationHandler} - Checking subscription: app3::hello
DEBUG {APIAuthenticationHandler} - Subscription not found in database
WARN {APIAuthenticationHandler} - API subscription not found for application: app3
```

**Root Cause:**

The gateway validated the JWT token successfully. However, app3 is not subscribed to the `hello` API in the Control Plane.
The gateway checks:
1. Is the app bound to this API? **NO**
2. If yes, what tier? (skipped)
3. Result: 403 Forbidden

This is a **subscription mismatch**, not a token problem.

**Remediation:**

1. **Admin-side fix:** Register app3 to the hello API in the Control Plane:
   ```bash
   curl -s -X POST http://localhost:9090/admin/subscriptions -k \
     -H "Content-Type: application/json" \
     -d '{
       "applicationname": "app3",
       "apiname": "hello",
       "subscriptiontier": "gold",
       "keytype": "PRODUCTION"
     }' | jq .
   ```

2. **Then retry:**
   ```bash
   curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN3" -k
   # Expected: 200 OK (or 502 if backend is down, but not 403)
   ```

3. **Production context:**
   - Subscriptions are managed by app developers in the self-service portal
   - If a new API is released, existing apps must manually subscribe to it
   - Some deployments use auto-subscribe for trusted apps (not recommended for security)

---

## Scenario C: 429 Too Many Requests (Throttle Exceeded)

### Test Case

```bash
# Get a fresh token for app2 (silver tier, 2000 req/min quota)
TOKEN2=$(curl -s "http://localhost:8888/token?username=bob&appname=app2" | jq -r .token)

# Send 2001 requests in rapid succession
for i in {1..2001}; do
  curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN2" -k > /dev/null
done

# Last request should get 429
curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN2" -k
# Expected: 429 Too Many Requests
```

### Expected Outcome

**HTTP Status:** 429 Too Many Requests

**Log Pattern Found:**

```
WARN {org.wso2.carbon.apimgt.gateway.handlers.throttling.ThrottleHandler} - Request throttled for application: app2, tier: silver
```

**Full Log Trace (Request #2001):**

```
DEBUG {JWTValidator} - JWT token validated successfully for application: app2
DEBUG {APIAuthenticationHandler} - Subscription found: tier=silver, keytype=PRODUCTION
DEBUG {ThrottleHandler} - Checking throttle: app=app2, tier=silver, bucket=0
DEBUG {ThrottleHandler} - Bucket exhausted, count=2000
WARN {ThrottleHandler} - Request throttled for application: app2, tier: silver
```

**Root Cause:**

Silver tier has a quota of 2000 requests per minute. The application has consumed 2000 requests in the current window.
When the 2001st request arrived, the token bucket was empty, so the gateway rejected it.

**Why This Matters:**

- **Tier:** silver = 2000 req/min
- **Quota consumed:** 2000
- **Quota remaining:** 0
- **Request #2001:** Rejected (would exceed quota)

**Remediation:**

1. **Immediate fix:** Wait for the bucket to refill (~60 seconds at minute boundary):
   ```bash
   sleep 60
   curl -s https://localhost:8243/api/hello -H "Authorization: Bearer $TOKEN2" -k
   # Expected: 200 OK (new minute window, bucket refilled)
   ```

2. **Long-term fix:** Upgrade app2 to a higher tier:
   ```bash
   # Modify subscription in CP: app2 silver → gold (5000 req/min)
   curl -s -X PUT http://localhost:9090/admin/subscriptions/app2 -k \
     -H "Content-Type: application/json" \
     -d '{"subscriptiontier": "gold"}'
   ```

3. **Multi-replica scenario:** If you have 3 GW replicas and only **some** get 429:
   - Problem: Load balancer is not distributing traffic evenly
   - Check: GW replica health and target group distribution (AWS ELB)
   - Solution: Enable even distribution or use sticky sessions less

4. **Production context:**
   - Throttle helps prevent abuse and protects backend services
   - Quotas should match SLA agreements with clients
   - Implement client-side rate limiting to respect quotas proactively

---

## Questions Answered

### Q1: For each error scenario (401/403/429), what log pattern confirmed the diagnosis?

**A1:**

- **401:** `WARN {JWTValidator} - JWT token validation failed: Token expired`
- **403:** `WARN {APIAuthenticationHandler} - API subscription not found for application: app3`
- **429:** `WARN {ThrottleHandler} - Request throttled for application: app2, tier: silver`

---

### Q2: If you had 3 GW replicas and got intermittent 429 errors with low global traffic, what would you check first?

**A2:**

Check the **load distribution** across replicas:

```bash
# Check if load balancer (ALB) is evenly distributing traffic
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Look for:
# - All replicas healthy? If 1 is unhealthy, traffic goes to 2 replicas
# - All replicas receiving traffic? If one replica gets 80% of traffic, its bucket fills faster

# Enable DEBUG logging on ThrottleHandler to see bucket state per replica
# Example:
# GW-1 bucket=0 (exhausted) → sends 429
# GW-2 bucket=1500 (ok) → sends 200
# GW-3 bucket=2000 (ok) → sends 200
# Result: ~33% of requests get 429 (intermittent)
```

If traffic is not evenly distributed:
1. Check ALB target group deregistration delay
2. Verify no sticky sessions enabled
3. Check if one replica is responding slower (high latency)

---

### Q3: How would you use correlation IDs (activityid) to trace a single request across multiple replicas?

**A3:**

**Multi-replica tracing:**

```bash
# Step 1: Make a request and capture the correlation ID
curl -s -v https://localhost:8243/api/hello \
  -H "Authorization: Bearer $TOKEN" -k \
  2>&1 | grep -i "activityid\|x-correlation"
# Output: x-correlation-id: req-12345-abcdef

# Step 2: Collect logs from all replicas
for i in 1 2 3; do
  docker logs gw-replica-$i 2>&1 | grep "req-12345-abcdef" > /tmp/gw-$i.log
done

# Step 3: Compare timing and decisions across replicas
cat /tmp/gw-1.log /tmp/gw-2.log /tmp/gw-3.log | sort -t: -k2

# Example output:
# GW-1: [10:30:00] DEBUG - JWT validation started
# GW-2: [10:30:00] DEBUG - JWT validation started
# GW-1: [10:30:00] WARN - JWT validation failed: Token expired
# GW-2: [10:30:00] DEBUG - JWT validation successful

# This reveals: GW-1 had stale JWKS keys (validation failed)
#              GW-2 had fresh keys (validation passed)
```

**In production with CloudWatch:**

```bash
# Search CloudWatch Logs with correlation ID
aws logs filter-log-events \
  --log-group-name /ecs/wso2-gw \
  --filter-pattern "req-12345-abcdef" \
  --query 'events[].{timestamp:timestamp, message:message}' \
  --output text | sort
```

---

### Q4: What's the difference between "subscription not found" vs "key type mismatch"?

**A4:**

| Scenario | Log Message | Root Cause | Fix |
|---|---|---|---|
| **Subscription not found** | `API subscription not found for application: app3` | App never subscribed to this API | Register subscription in CP |
| **Keytype mismatch** | `API subscription found but keytype mismatch: SANDBOX vs PRODUCTION` | App is subscribed, but using wrong key type | Client must use PRODUCTION key, not SANDBOX |

**Example:**

```
Subscription registered:
  app3 → hello API (PRODUCTION key type)

Client sends with SANDBOX key:
  token.keytype = "SANDBOX"
  → 403 Forbidden (keytype mismatch)
  Log: WARN - keytype mismatch: SANDBOX not allowed for hello API

Remediation:
  - Use PRODUCTION key instead of SANDBOX key
  - Or register separate subscription for SANDBOX if testing
```

---

### Q5: If DEBUG logs are disabled, how would you diagnose a 401 error?

**A5:**

**With DEBUG disabled (INFO level), you'd see:**

```
INFO {APIGateway} - Request rejected with 401
```

That's all. Very limited information.

**Diagnosis steps without DEBUG:**

1. **Check IS logs** — maybe token was never issued:
   ```bash
   docker logs is 2>&1 | grep "OAuthClientAuthn\|OAuth2"
   ```

2. **Check request headers** — is Authorization header present?
   ```bash
   curl -v https://localhost:8243/api/hello
   # Look for "Authorization: Bearer" in request headers
   ```

3. **Check if token format is valid** — base64 decode the token:
   ```bash
   TOKEN="eyJhbGc..."
   echo $TOKEN | cut -d'.' -f1 | base64 -d
   # Should show JSON header with {"alg":"RS256",...}
   ```

4. **Check GW deployment config** — is JWKS URL correct?
   ```bash
   cat deployment.toml | grep -A5 "\[apim.jwt\]"
   # Should show: jwks_url = "https://is:9443/oauth2/jwks"
   ```

5. **Enable DEBUG** and retry — this is the best approach:
   ```bash
   # Edit log4j2.properties to enable JWTValidator DEBUG
   # Restart gateway
   # Retry request
   # Now you see exactly where it failed
   ```

**Key takeaway:** Always enable DEBUG when debugging 401 errors. Without DEBUG, you're flying blind.

---

## Summary: Phase 2 Capstone Completion

By completing this lab, you've demonstrated:

| Skill | Evidence |
|---|---|
| Understand error flows | Generated 3 real errors (401/403/429) |
| Read debug logs | Interpreted WARN messages to identify root cause |
| Use the playbook | Applied decision tree to each scenario |
| Diagnose in < 3 min | Traced from error to root cause quickly |
| Know remediation | Identified fix for each scenario |
| Multi-tenant awareness | Understood app subscriptions and tiers |
| ECS readiness | Know how to apply this in CloudWatch Logs |

**You're now a production-ready GW engineer for Phase 2.**

