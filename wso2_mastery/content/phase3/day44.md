# Day 44: Smoke Test — End-to-End Validation and Failure Diagnostics

## Why This Matters

You have four services running. But do they **actually work together**? A health check on the GW endpoint might pass (GW is listening), but that doesn't prove the GW can validate JWTs from the IS or route requests correctly through the CP.

Today's **smoke test** is your first real end-to-end validation. It simulates what a real API consumer does and pinpoints which service breaks the chain.

---

## The End-to-End Flow: Seven Steps

Here's the complete journey of an API request from consumer to backend:

```
1. [CP] Create API
   ↓ (API state: CREATED)
2. [CP] Publish API
   ↓ (API state: PUBLISHED, SSE fires API_PUBLISHED event)
3. [CP] Create Application
   ↓ (Application created with consumer key)
4. [CP] Subscribe Application to API
   ↓ (Subscription created, SSE fires SUBSCRIPTION_CREATED event)
5. [IS] Request JWT Token
   ↓ (IS issues JWT with appname claim)
6. [GW] Validate JWT + Check Subscription Cache
   ↓ (GW checks: Is JWT valid? Does app have active subscription for this API?)
7. [GW] Route Request to Backend
   ↓ (Success: 200 OK with backend response)
```

Each step has a specific failure mode. Knowing which step failed tells you which service has the problem.

---

## Smoke Test as a Diagnostic Tool

Instead of logging into four different systems and checking logs manually, a smoke test **programmatically runs the happy path** and reports where it breaks.

```bash
bash smoke_test.sh
```

Output:
```
=== Phase 3 Smoke Test ===
[1] Create API...
  Created: api-001
[2] Publish API...
  Published.
[3] Create application...
  App: app-001  Key: smoke-consumer-key
[4] Subscribe app to API (Gold tier)...
  Subscribed.
[5] Register API context for validate endpoint...
  Done.
[6] Obtain JWT from IS...
  Token: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
[7] Call API through GW...
  PASS — GW returned 200

=== ALL STEPS PASSED ===
```

If step 7 fails with a 403, you know:
- Steps 1–4 worked (CP is healthy, can create APIs and apps).
- Step 6 worked (IS is healthy, can issue tokens).
- Step 7 failed (GW issue: likely subscription cache miss or JWT validation failure).

---

## Failure Diagnostic Mapping

### Step 1 Fails: "FAIL: could not create API"
**Root cause:** CP is down or `/apis` endpoint is broken.
**Diagnosis:** `curl http://localhost:8082/health` — if no 200, CP isn't running.

### Step 2 Fails: Publish returns non-200
**Root cause:** CP is up but lifecycle transition is broken.
**Diagnosis:** Check CP logs for state machine issues; may be a bug in the CP implementation.

### Step 3–4 Fail: Application or Subscription fails
**Root cause:** CP endpoints are broken.
**Diagnosis:** Same as Step 1.

### Step 6 Fails: "FAIL: IS did not return access_token"
**Root cause:** IS is down or `/oauth2/token` endpoint is broken.
**Diagnosis:** `curl http://localhost:8080/health` — if not 200, IS isn't running.

### Step 7 Fails: "FAIL — GW returned 403"
**Root causes (in order of likelihood):**
1. **GW hasn't received the `SUBSCRIPTION_CREATED` SSE event yet** (timing race).
2. **Subscription tier mismatch** (app subscribed at "Gold", API requires "Platinum").
3. **Subscription is BLOCKED** (CP marked it as inactive).
4. **JWT validation issue** (JWT malformed, signature invalid, or `iss` claim doesn't match GW's expected issuer).
5. **GW lost connection to CP** (no events received since startup).

---

## Wiring the IS, CP, GW Data Flow

### IS → GW (JWT Validation)
- GW fetches JWKS from IS at `http://is:8080/oauth2/jwks`.
- GW caches JWKS locally.
- GW validates incoming tokens by checking the signature against the cached JWKS.

### CP → GW (Event Sync)
- **On startup:** GW calls `http://cp:8082/admin/sync` to fetch all published APIs and subscriptions.
- **At runtime:** GW subscribes to SSE at `http://cp:8082/events`.
- **On event:** When an API is published or a subscription is created, CP emits an SSE event. GW receives it and updates its cache.

### CP → IS (Key Manager Config)
- CP calls IS to validate the key manager configuration and issue tokens on behalf of applications.

---

## Anti-Patterns in Smoke Test Design

### Anti-Pattern 1: Testing Only One API/App Pair
**Problem:** Your smoke test always uses the same API and app. You don't catch scenarios like:
- Creating a second API and failing to publish it.
- Subscribing the same app to multiple APIs.

**Fix:** Vary your test data. Create multiple APIs, apps, and subscriptions in the same run.

### Anti-Pattern 2: Not Checking Response Bodies
**Problem:** You check for HTTP 200 but don't verify the response is correct.

```bash
# BAD: Only checks HTTP code
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "$GW/smoke/v1/hello")
[ "$HTTP_CODE" = "200" ] || exit 1
```

**Fix:** Also verify the response body matches expectations.

```bash
# GOOD: Checks both HTTP code and body
BODY=$(curl -sf "$GW/smoke/v1/hello" \
  -H "Authorization: Bearer $TOKEN")
[ "$BODY" = "hello from backend" ] || { echo "FAIL: wrong body"; exit 1; }
```

### Anti-Pattern 3: Not Timing Out on Slow Services
**Problem:** If the GW is hung, your smoke test hangs too.

```bash
# BAD: No timeout
curl "$GW/smoke/v1/hello"
```

**Fix:** Set a timeout.

```bash
# GOOD: 5-second timeout
curl --max-time 5 "$GW/smoke/v1/hello"
```

---

## Real-World Scenarios: When Smoke Test Passes Locally But Fails in Production

### Scenario 1: TLS in Production, HTTP in Local
**Local test:**
```bash
GW="http://localhost:9090"  # HTTP
```

**Production:**
```bash
GW="https://api.example.com"  # TLS/HTTPS
```

The local smoke test passes because HTTP doesn't require certificates. But in production, the test fails if you don't handle TLS correctly (missing certs, expired certs, hostname mismatch).

**Fix:** Make the test aware of the environment. Use an environment variable or detect HTTPS automatically.

```bash
GW="${GW_URL:-http://localhost:9090}"
if [[ "$GW" == https* ]]; then
  CURL_OPTS="--insecure"  # For self-signed certs in staging
else
  CURL_OPTS=""
fi
curl $CURL_OPTS "$GW/..."
```

### Scenario 2: Different JWT Issuers
**Local:** IS issues JWTs with `iss: "http://localhost:8080"`.
**Production:** IS issues JWTs with `iss: "https://auth.example.com"`.

GW validates JWT against the `iss` claim. If the GW is hardcoded to expect `http://localhost:8080`, it rejects production JWTs even though they're valid.

**Fix:** The GW config should make `WSO2_IS_URL` variable and embed it in the JWT validation logic.

---

## Exercises

### Exercise 1: Root Causes of 403 Responses
**Question:** Your smoke test passes locally but returns 403 on step 7 in a staging environment. List the 3 most likely root causes in order of probability.

**Hint:** Think about the three main GW checks: JWT validation, subscription existence, subscription status.

**Solution sketch:**
1. **GW subscription cache miss (40% probability):** GW hasn't received the `SUBSCRIPTION_CREATED` SSE event yet (network delay, CP slow to emit event, GW lost connection). GW checks its cache, finds no subscription, returns 403. **Fix:** Add a short retry loop in the smoke test or a fallback to CP's validate endpoint.
2. **Subscription tier mismatch (30% probability):** App subscribed at "Gold" tier, but the API requires "Platinum". GW checks the subscription exists and is active, but the tier doesn't grant access. **Fix:** Ensure the smoke test subscribes at the correct tier (match what the API allows).
3. **Subscription BLOCKED (20% probability):** Subscription exists and tier is correct, but it's marked BLOCKED (e.g., app violated rate limits, admin disabled it). GW checks status and denies access. **Fix:** Check CP logs for why the subscription was blocked; may require manual admin intervention.
4. **JWT validation issue (10% probability):** JWT is malformed, signature invalid, or `iss` claim doesn't match GW's expected IS URL. **Fix:** Check the JWT token structure with `jq` or `jwt.io`; verify GW config has correct `WSO2_IS_URL`.

---

### Exercise 2: Extend the Smoke Test with Body Verification
**Question:** Modify the smoke test to verify not just that the GW returns 200, but that the response body is exactly `"hello from backend"`.

**Hint:** Use `curl -sf` to print the body; compare with `==`.

**Solution sketch:**
```bash
echo "[7] Call API through GW and verify response body..."
BODY=$(curl -sf \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$GW/smoke/v1/hello" || echo "")
if [ "$BODY" = "hello from backend" ]; then
  echo "  PASS — GW returned correct body: $BODY"
else
  echo "  FAIL — GW returned unexpected body: $BODY"
  exit 1
fi
```

---

### Exercise 3: Production Failure Scenarios
**Question:** The smoke test passes in staging but fails after you deploy to production with the exact same environment variables. Name 2 prod-specific causes and how you'd diagnose them.

**Hint:** Think about networking, DNS, TLS, and regional differences.

**Solution sketch:**
1. **TLS Certificate Issue (50% probability):** Production uses HTTPS; staging uses HTTP. The test connects to `https://api.prod.example.com` and gets a certificate validation error. **Diagnosis:** Add `curl --insecure` for self-signed certs or ensure the cert is valid for the hostname. Check: `curl -v https://api.prod.example.com` and look for certificate errors.
2. **DNS Resolution Failure (30% probability):** In staging, all services are on the same internal network. In production, CP and IS are on a different VPC or region. The GW can't resolve the CP or IS hostnames. **Diagnosis:** Check if the GW has the correct `WSO2_CP_URL` and `WSO2_IS_URL`. From inside the GW container (or a bastion), try: `nslookup cp.prod.internal` or `curl http://cp.prod.internal:9443/health`.
3. **Security Group or Network ACL Blocking:** Production has restrictive security groups. The GW container can reach the ALB (port 8243), but the test client (outside the VPC) can't reach the GW because ALB is in a private subnet. **Diagnosis:** Verify the ALB is in a public subnet and has a public IP or Elastic IP. Check ALB target group health: all targets should be healthy.
4. **JWT Issuer Mismatch (15% probability):** Production IS issues JWTs with a different `iss` claim (e.g., `https://auth.prod.example.com` vs. staging's `http://localhost:8080`). GW is configured with the staging issuer and rejects production tokens. **Diagnosis:** Decode the JWT: `echo $TOKEN | jq -R 'split(".")[1] | @base64d | fromjson'`. Check the `iss` claim. Ensure GW's config matches.

---

## Key Takeaways

1. **Smoke test = end-to-end validation:** Catches integration bugs that individual health checks miss.
2. **Step-by-step diagnostics:** Know which service fails by which step fails.
3. **Network reality:** Containers communicate via service names, not localhost. TLS, DNS, and SGs matter.
4. **Race conditions exist:** SSE events take time to propagate. Plan for eventual consistency.
5. **Test environments:** Smoking in staging doesn't guarantee production success. Variables like TLS, DNS, and SGs differ.

---

## Next Steps

Day 45 brings the full runbook: API quick reference, event types, failure checklist, and ECS production notes.

