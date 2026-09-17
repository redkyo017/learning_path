# Day 52: Failure Mode Catalog — Reading Error Codes

## Why This Matters

Every WSO2 production incident reduces to one of **7 failure classes**. Knowing the class immediately tells you:
- Which log group to check
- Which component to restart
- Which engineer to page

Rather than panicking and restarting all four services (GW, IS, CP, TM), you read the error code from the HTTP response body, find it in the catalog below, and run the one action that fixes it.

**Time value:** A 2-minute incident becomes a 30-second incident when you can name the failure class and the first action before you've even opened a ticket.

---

## The 7 Failure Classes

### 1. AUTH_FAILED (900901)

**Log Signature:** `"Invalid Credentials"` or `"900901"` in the GW log (typically in a warning or error handler).

**Root Cause:** One of:
- Wrong API key (caller sent the wrong subscription key)
- Expired token (OAuth token past its TTL)
- Missing subscription (caller never provisioned one)

**Immediate Action:**
1. Check the subscription in the CP dashboard — does it exist? Is it active?
2. Verify the IS token endpoint (`/oauth2/token`) is healthy — can the GW reach it?
3. If the GW can't reach IS, restart the IS and check the CP→IS network SG.

---

### 2. SUBSCRIPTION_NOT_FOUND (900908)

**Log Signature:** `"no valid subscription"` or `"subscription not found"` or `"900908"` in the GW log.

**Root Cause:**
- The GW's event cache is stale — the CP issued a subscription update but the GW never received the event.
- The subscription was deleted in the CP, but the GW's cached subscription list still has the old entry and is now out of sync.

**Immediate Action:**
1. Restart the GW to force a full `/admin/sync` re-fetch from the CP.
2. While it's restarting, check the CP logs to confirm the subscription exists (or that it was deliberately deleted).
3. If the GW continues to report 900908 after restart, check the GW→CP SSE/JMS connection.

---

### 3. THROTTLE_EXCEEDED (900800)

**Log Signature:** `"Throttle limit exceeded"` or `"900800"` in the GW or TM log.

**Root Cause:** One of:
- The rate limit for the subscription tier has been hit (e.g., Gold tier = 30 RPS, and the caller is at 31 RPS).
- The TM is unreachable, and the GW fell back to its local throttle cache (which may have stale limits).

**Immediate Action:**
1. Check the TM health (AWS health checks, CloudWatch metrics).
2. Check the security group — can the GW reach TM on ports 9611 (TM stream port) and 9711 (TM event port)?
3. If TM is healthy, verify the throttle policy in the CP matches the tier definition and what the GW is enforcing.

---

### 4. BACKEND_TIMEOUT

**Log Signature:** `"connection timed out"` or `"read timeout"` in the GW log (usually when forwarding to the backend).

**Root Cause:**
- The backend API is unreachable (crashed, scaled down, or never registered).
- The backend is overloaded and not responding within the timeout window (default 30 seconds).
- Network path is broken: GW SG does not allow outbound to backend SG, or backend SG blocks inbound from GW SG.

**Immediate Action:**
1. Check the backend ECS task — is it running? Is the health check passing?
2. Check the security group rules: does the GW SG have an outbound rule to the backend SG on the right port (usually 8080 or 443)?
3. If backend is running and SGs are correct, check GW logs for the actual backend URL — is it correct?

---

### 5. JWT_EXPIRED

**Log Signature:** `"JWT expired"` or `"token expired"` or `"exp claim"` in the GW log.

**Root Cause:**
- The client's OAuth token's `exp` claim has passed the current time (token TTL was too short or client didn't refresh).
- Clock skew: the GW and IS clocks are out of sync, so the GW thinks the token is expired when it's not (or vice versa).

**Immediate Action:**
1. Tell the client to re-authenticate and get a fresh token.
2. Check the IS container's NTP sync: `ntpstat` or `timedatectl status`.
3. Check the GW container's NTP sync as well — if the GW's clock is ahead of IS, it will reject tokens prematurely.

---

### 6. JWT_INVALID_SIGNATURE

**Log Signature:** `"Signature verification failed"` or `"invalid JWT"` or `"JwtClaimValidator"` in the GW log.

**Root Cause:**
- The IS JWKS endpoint is unreachable from the GW, so the GW cannot fetch the IS's public key to verify the JWT signature.
- The IS rotated its keystore but the GW wasn't restarted, so it's still using the old public key.

**Immediate Action:**
1. Check IS health from the GW container: `curl -k https://is.wso2.internal:9443/oauth2/jwks` (should return a JSON array of keys).
2. If that fails, check the GW→IS network SG and the IS service health.
3. If it succeeds but JWT verification still fails, restart the GW to reload the JWKS cache.

---

### 7. EVENT_SYNC_LAG

**Log Signature:** `"eventHub.*error"` or `"sync lag"` or `"event sync.*fail"` in the GW log (often an ERROR or WARN level).

**Root Cause:**
- The CP→GW SSE or JMS connection is broken. The GW is no longer receiving subscription/throttle updates from the CP.
- The GW has fallen back to serving stale data (old subscriptions, old throttle limits).

**Immediate Action:**
1. Restart the GW to re-establish the connection to the CP.
2. While it's restarting, check the CP `/admin/sync` endpoint: `curl http://cp.wso2.internal:9763/admin/sync/status`.
3. Check the CP CloudWatch logs for any errors related to the GW connection.

---

## Anti-Patterns to Avoid

1. **Restarting all four services on every incident.** The error code tells you exactly which component broke. Restart only that one (or the minimum needed to reconnect).

2. **Assuming 401 = JWT_EXPIRED.** A 401 response can mean:
   - `AUTH_FAILED` (900901) — wrong API key
   - `JWT_EXPIRED` — token past its TTL
   - `JWT_INVALID_SIGNATURE` — public key fetch failed or keystore rotated
   
   Read the response body error code, not the HTTP status.

3. **Ignoring error codes in WSO2 responses.** The error codes (900901, 900908, 900800, etc.) are the Rosetta Stone of WSO2 errors. Grep for them first.

---

## Exercises

### Exercise 1: Missing Subscription (Hint: 403 = Subscription or JWT Issue)

**Scenario:** A user reports getting 403 on an API they were using successfully yesterday. The GW logs show their request, but no 200 response. Which failure class should you suspect first, and what is your first action?

**Hint:** 403 errors in WSO2 come from either a missing subscription or an invalid JWT. Check the error code in the response body.

**Solution Sketch:**
- First suspect: `SUBSCRIPTION_NOT_FOUND` (900908). The subscription may have been deleted, or the GW's cache is stale.
- First action: Check the subscription in the CP dashboard — does it still exist? If yes, restart the GW to re-fetch `/admin/sync`. If it doesn't exist, confirm with the user that it's intentional.
- Second suspect: If the subscription exists and the GW restart doesn't fix it, check the GW→CP event sync logs for `EVENT_SYNC_LAG`.

---

### Exercise 2: 200 for Invalid Requests (Hint: Unexpected Success = Sync Issue)

**Scenario:** You notice the GW is now returning 200 to requests with completely invalid API keys. Normally those should get 403. No one redeployed, but this started happening 2 hours ago. Which failure class is this?

**Hint:** When a system starts accepting invalid requests, it's usually because it lost the list of valid credentials. Think about what event or connection breaking would cause that.

**Solution Sketch:**
- Class: `EVENT_SYNC_LAG`. The GW lost its connection to the CP and is no longer receiving subscription updates. It's fallen back to permissive mode.
- Root cause: Check the GW's event sync logs for errors. Check the CP's `/admin/sync` endpoint.
- Action: Restart the GW to re-establish the connection, then check CP and IS health.

---

### Exercise 3: Load Test Throttle Cliff (Hint: 429 = Rate Limit)

**Scenario:** During a load test, you drive traffic to 50 RPS. Everything works fine up to 30 RPS, but at exactly 30 RPS all responses suddenly become 429. Which failure class?

**Hint:** 429 means throttle limit exceeded. Look at the tier definition and the throttle policy in the TM.

**Solution Sketch:**
- Class: `THROTTLE_EXCEEDED` (900800). The Gold tier limit is likely set to 30 RPS in the throttle policy.
- Root cause: The tier was configured with a 30 RPS limit, and the load test reached it.
- Action: Check the throttle policy in the TM; check the subscription tier config in the CP. Either raise the limit or reduce the load to the tier limit. (This is expected behavior, not an incident!)

---

## Key Takeaway

Before you restart anything, read the error code. The 7 failure classes cover 90% of production incidents. Once you know the class, the action is almost always the same:
- AUTH_FAILED → check CP subscription
- SUBSCRIPTION_NOT_FOUND → restart GW
- THROTTLE_EXCEEDED → check TM health
- BACKEND_TIMEOUT → check backend ECS
- JWT_EXPIRED → client re-auth
- JWT_INVALID_SIGNATURE → restart GW
- EVENT_SYNC_LAG → restart GW and check CP

This is why the catalog (day52/failure_catalog.md) is taped to every WSO2 SRE's monitor.
