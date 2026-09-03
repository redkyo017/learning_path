# Day 29: GW Log Line Patterns (The 6 to Memorize)

## Why

Yesterday you learned how to **enable** DEBUG logging. Today you learn to **read** it.

With debug enabled, your GW will log 10–50 lines per request. Most are noise. But **6 specific log line
patterns** tell you exactly what went wrong: token validation, subscription, throttle, or key mismatch.

By the end of today, you'll recognize these patterns instantly when debugging a 401, 403, or 429.

---

## The 6 Patterns (Memorize These)

### Pattern 1: JWT Validation Success

```
DEBUG {JWTValidator} - JWT token validated successfully for application: app1
```

**Meaning:** Token is valid, signature matches, not expired, key found.

**Action:** If you see this but still get 401, problem is downstream (subscription, throttle, or policy).

**Context:** Appears right before subscription check.

---

### Pattern 2: JWT Validation Failure — Token Expired

```
WARN {JWTValidator} - JWT token validation failed: Token expired
```

**Meaning:** Token's expiry timestamp (`exp` claim) is in the past.

**Action:** Client must request a new token from IS.

**Example fix:**
```bash
# Client-side
curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token > new_token.txt
curl -H "Authorization: Bearer $(cat new_token.txt)" http://localhost:9090/api/hello
```

**AWS prod context:** In ECS, tokens issued by IS have TTL (usually 1 hour). If client holds token > 1 hour, it expires.

---

### Pattern 3: JWT Validation Failure — Signature Mismatch

```
WARN {JWTValidator} - JWT token validation failed: Signature verification failed
```

**Meaning:** Token's signature doesn't match the public key. Causes:
- IS rotated signing keys, GW JWKS cache stale
- Token tampered with (malicious or corrupted)
- Client using wrong key to sign (rare, usually IS issue)

**Action:** Restart GW to refresh JWKS cache, or verify IS hasn't rotated keys.

**AWS prod fix:**
```bash
# In ECS Fargate, trigger GW task restart
aws ecs update-service --cluster my-cluster --service my-gw-service --force-new-deployment
# GW will fetch fresh JWKS from IS during startup
```

---

### Pattern 4: Subscription Not Found

```
WARN {APIAuthenticationHandler} - API subscription not found for application: app1
```

**Meaning:** Token is valid, but app (extracted from JWT claim `applicationname`) is not subscribed to this API.

**Action:** Register subscription in Control Plane admin UI, or verify app and API names match exactly.

**AWS prod context:** Check CP database for subscription record:
```sql
-- In CP database
SELECT * FROM IDN_APIM_SUBSCRIPTION WHERE APP_ID = (SELECT APP_ID FROM IDN_APIM_APPLICATION WHERE NAME = 'app1');
```

---

### Pattern 5: Throttle Limit Exceeded

```
WARN {ThrottleHandler} - Request throttled for application: app1, tier: gold
```

**Meaning:** App's tier quota has been exceeded (bucket exhausted).

**Action:** Wait for bucket to refill (usually 1 minute), or check if tier is misconfigured.

**Bucket refill logic:**
- Gold tier: 5000 req/min → refills at minute boundary
- Silver tier: 2000 req/min → refills at minute boundary
- Throttle duration: ~60 seconds

**AWS prod context:** If throttle is intermittent (only some replicas), likely load balancer issue:
```bash
# Check if GW replicas are healthy
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

---

### Pattern 6: JWKS Key Not Found

```
WARN {JWTValidator} - Public key not found for kid: e1a2b3c4
```

**Meaning:** Token's `kid` (Key ID in JWT header) doesn't exist in GW's JWKS cache.

**Causes:**
- IS generated new signing keys, GW cache stale
- IS JWKS endpoint is unreachable (network issue, wrong URL)
- Token was signed with a key IS has already revoked

**Action:** 
1. Restart GW to refresh cache
2. Verify deployment.toml `[apim.jwt]` section points to correct IS JWKS endpoint

**AWS prod fix:**
```bash
# Check GW config
cat deployment.toml | grep -A5 "\[apim.jwt\]"
# Example: jwks_url = "https://is:9443/oauth2/jwks"

# If URL is wrong, update ECS task definition, then redeploy
```

---

## How to Extract Info from Log Lines

### Full Debug Output Example

```
[2026-09-03 10:30:00,123] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - JWT token received: eyJhbGc...
[2026-09-03 10:30:00,124] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Extracting claims from token
[2026-09-03 10:30:00,125] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Claim subscriber: alice
[2026-09-03 10:30:00,126] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Claim applicationname: app1
[2026-09-03 10:30:00,127] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Token expiry: 2026-09-03T11:30:00Z
[2026-09-03 10:30:00,128] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Current time: 2026-09-03T10:30:00Z
[2026-09-03 10:30:00,129] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Signature valid for kid: e1a2b3c4
[2026-09-03 10:30:00,130] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - JWT token validated successfully for application: app1
[2026-09-03 10:30:00,131] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.authentication.APIAuthenticationHandler} - Checking subscription: app1::myapi
[2026-09-03 10:30:00,132] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.authentication.APIAuthenticationHandler} - Subscription found: tier=gold, keytype=PRODUCTION
[2026-09-03 10:30:00,133] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.throttling.ThrottleHandler} - Checking throttle: app=app1, tier=gold, bucket=4999
[2026-09-03 10:30:00,134] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.throttling.ThrottleHandler} - Bucket allows request, count=1
```

**What this tells you:**
1. ✓ Token extracted and parsed
2. ✓ Claims present: subscriber (alice), applicationname (app1)
3. ✓ Token not expired (current time < expiry)
4. ✓ Signature valid for key ID e1a2b3c4
5. ✓ JWT validation passed
6. ✓ Subscription found (app1 is subscribed to myapi)
7. ✓ Tier is gold (5000 req/min quota)
8. ✓ Throttle bucket has 4999 requests remaining
9. ✓ Request allowed
10. **Result:** 200 OK to client

---

## Common Failure Scenarios (Log Traces)

### Failure Case 1: Expired Token

```
[10:30:00,127] DEBUG {JWTValidator} - Token expiry: 2026-09-02T10:30:00Z
[10:30:00,128] DEBUG {JWTValidator} - Current time: 2026-09-03T10:30:00Z
[10:30:00,129] WARN {JWTValidator} - JWT token validation failed: Token expired
```

**Diagnosis:** Token is 1 day old, client held it too long.

**Fix:** Issue new token, client must refresh periodically.

---

### Failure Case 2: Signature Mismatch (Key Rotation at IS)

```
[10:30:00,125] DEBUG {JWTValidator} - Extracting claims from token
[10:30:00,126] DEBUG {JWTValidator} - Key ID in token: e1a2b3c4_old
[10:30:00,127] DEBUG {JWTValidator} - Fetching public key for kid: e1a2b3c4_old
[10:30:00,128] DEBUG {JWTValidator} - Public key found (cached)
[10:30:00,129] DEBUG {JWTValidator} - Verifying signature...
[10:30:00,130] WARN {JWTValidator} - JWT token validation failed: Signature verification failed
```

**Diagnosis:** GW has old key cached, IS rotated keys. Signatures don't match.

**Fix:** Restart GW to fetch new JWKS from IS.

---

### Failure Case 3: Subscription Missing

```
[10:30:00,130] DEBUG {JWTValidator} - JWT token validated successfully for application: app1
[10:30:00,131] DEBUG {APIAuthenticationHandler} - Checking subscription: app1::myapi
[10:30:00,132] DEBUG {APIAuthenticationHandler} - Subscription not found in database
[10:30:00,133] WARN {APIAuthenticationHandler} - API subscription not found for application: app1
```

**Diagnosis:** Token is valid, but app never subscribed to this API.

**Fix:** Register subscription in CP UI. Ensure app and API names match exactly (case-sensitive).

---

### Failure Case 4: Throttle Exceeded

```
[10:30:00,130] DEBUG {JWTValidator} - JWT token validated successfully
[10:30:00,131] DEBUG {APIAuthenticationHandler} - Subscription found: tier=gold
[10:30:00,132] DEBUG {ThrottleHandler} - Checking throttle: app=app1, tier=gold, bucket=0
[10:30:00,133] DEBUG {ThrottleHandler} - Bucket exhausted
[10:30:00,134] WARN {ThrottleHandler} - Request throttled for application: app1, tier: gold
```

**Diagnosis:** Quota (5000 for gold) was used up in this 1-minute window.

**Fix:** Wait for bucket to refill (60 sec), or upgrade tier if quota is consistently exceeded.

---

## Log Filtering in Production

### Using Correlation ID

Every request has a unique `activityid` (or `Correlation-ID` depending on config). Use it to trace
a single request across all logs:

```bash
# In ECS CloudWatch, search for specific correlation ID
aws logs filter-log-events --log-group-name /ecs/wso2-gw \
  --filter-pattern "activityid:correlationID-12345" \
  --query 'events[].message'

# Or tail local logs
grep "correlationID-12345" wso2carbon.log
```

### Grep for Specific Patterns

```bash
# Find all 401 decisions
grep "JWT token validation failed" wso2carbon.log

# Find all 429 decisions
grep "Request throttled" wso2carbon.log

# Find all 403 decisions
grep "API subscription not found" wso2carbon.log

# Find all successful validations
grep "JWT token validated successfully" wso2carbon.log
```

---

## Exercises

**Exercise 1:** You collect a GW log file and see this sequence:

```
[10:30:00] DEBUG {JWTValidator} - JWT token validated successfully for application: app2
[10:30:01] DEBUG {APIAuthenticationHandler} - Subscription found: tier=silver, keytype=PRODUCTION
[10:30:02] DEBUG {ThrottleHandler} - Bucket allows request, count=2048
[10:30:03] WARN {ThrottleHandler} - Request throttled for application: app2, tier: silver
```

Which request succeeded, and which failed? What was the throttle limit for silver tier?

**Hint:** Look for the "throttle allows" vs "throttle failed" decision and count the requests.

**Solution sketch:**

```
Successful request: count=2048 → allowed
Failed request: immediately after, throttled

Silver tier quota: Usually 2000 req/min (based on standard WSO2 tiers)
Pattern shows: request #2048 is rejected → tier limit is 2000 or slightly higher (say, 2000–2048)

Root cause: After 2000 requests, silver tier bucket is exhausted

Action: Wait ~60 seconds for bucket to refill, or upgrade app2 to gold tier (5000 req/min)
```

---

**Exercise 2:** In your CloudWatch logs, you find 100 occurrences of:

```
WARN {JWTValidator} - Public key not found for kid: abc123def456
```

All occurred in a 2-minute window, then stopped. What likely happened?

**Hint:** Think about what operation at IS would cause kid mismatches globally, and how the system recovered.

**Solution sketch:**

```
Timeline:
- 10:00 — IS rotates signing keys (new kid generated)
- 10:00–10:02 — Clients get tokens signed with new key, GW cache still has old keys
- 10:00–10:02 — 100 requests fail with "key not found" (GW doesn't have new kid yet)
- 10:02 — GW instance auto-restarts or someone manually restarts it
- 10:02+ — GW fetches fresh JWKS from IS at startup, now has new key
- 10:02+ — Requests succeed again

Diagnosis:
1. Check IS logs for key rotation event around 10:00
2. Check GW logs for restart event around 10:02
3. Verify JWKS refresh happened after restart

Prevention:
- Implement JWKS cache auto-refresh (every 15 min or on failed validation)
- Use correlation IDs to group failures and track recovery
- Alert when kid not found ratio > threshold (indicates key rotation without GW update)
```

---

**Exercise 3:** You run a canary deployment of a new GW binary. In the first minute, you see:

```
From GW-Old (legacy):
DEBUG {JWTValidator} - JWT token validated successfully for application: app1

From GW-New (canary):
WARN {JWTValidator} - JWT token validation failed: Signature verification failed
```

What's likely wrong with the new GW binary, and how do you fix it?

**Hint:** Think about configuration that might differ between old and new binaries (e.g., JWKS URL, key cache).

**Solution sketch:**

```
Likely issue: New GW binary has different deployment.toml configuration
- Old GW: correctly points to IS JWKS endpoint
- New GW: JWKS URL is wrong, stale, or endpoint unreachable
- Result: New GW can't fetch keys, validation fails

Debugging steps:
1. SSH into new GW container: docker exec -it <container> bash
2. Check config: cat deployment.toml | grep -A5 "\[apim.jwt\]"
3. Verify JWKS URL is reachable: curl -v https://is:9443/oauth2/jwks
4. Check GW logs for: "Failed to fetch JWKS" or "Connection refused"

Fix:
1. Correct deployment.toml with right JWKS URL
2. Restart new GW
3. Canary traffic should now succeed
```

---

## Anti-patterns

- **Ignoring WARN logs:** WARN = something failed, not just a warning. Always investigate.
- **Not correlating failures across replicas:** If only 1 GW has failures, it's a local config issue.
- **Mixing up kid (Key ID) with app name:** kid is in JWT header, app name is in claims. Different things.

---

## Next Steps

- **Lab:** Given a synthetic log file, answer questions about failures (Exercise 1–3 practice).
- **Day 30:** Capstone lab — run the gateway, generate real 401/403/429 errors, diagnose using logs.

