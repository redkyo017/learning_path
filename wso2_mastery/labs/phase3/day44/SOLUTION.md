# Day 44 Lab: Smoke Test Solution and Diagnostics

## Complete Failure Diagnostic Map

Use this section to systematically narrow down where an integration failure occurs.

### Failure Step Flow Chart

```
Run smoke_test.sh
│
├─ Step 1-2 FAIL (CP issue)
│  └─ Check: curl http://localhost:8082/health
│     └─ Not 200 → CP not running (docker compose ps)
│     └─ 200 → CP is running but endpoint broken (check CP logs)
│
├─ Step 3-5 FAIL (CP issue)
│  └─ Same as above; likely /applications or /subscriptions endpoint
│
├─ Step 6 FAIL (IS issue)
│  └─ Check: curl http://localhost:8080/health
│     └─ Not 200 → IS not running
│     └─ 200 → IS running but /oauth2/token endpoint broken
│
└─ Step 7 FAIL (GW + subscription issue)
   ├─ GW returned 403
   │  └─ GW is running but subscription validation failed
   │     ├─ Cache miss (SSE event not received)
   │     ├─ Tier mismatch
   │     ├─ Subscription blocked
   │     └─ JWT validation failed
   │
   ├─ GW returned 404
   │  └─ API not in GW routing cache
   │     ├─ API_PUBLISHED event not received
   │     └─ GW lost connection to CP
   │
   └─ GW timeout / connection refused
      └─ GW not running or not responding
         └─ Check: curl http://localhost:9090/health
```

---

## Diagnostic Techniques with Examples

### Technique 1: Real-Time Event Monitoring (SSE Stream)

**What it shows:** Are CP lifecycle transitions firing events?

**How to do it:**

Terminal 1: Start watching CP events
```bash
curl -N http://localhost:8082/events
```

Terminal 2: Create an API and publish it
```bash
API=$(curl -sf -X POST "http://localhost:8082/apis" \
  -H 'Content-Type: application/json' \
  -d '{"name":"DiagAPI","context":"/diag/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}')
API_ID=$(echo "$API" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# Publish
curl -sf -X POST "http://localhost:8082/apis/$API_ID/lifecycle" \
  -H 'Content-Type: application/json' -d '{"action":"Publish"}'
```

Terminal 1: Expected output
```
:
event: API_PUBLISHED
data: {"id":"<API_ID>","context":"/diag/v1","version":"1.0",...,"tiers":["Gold"]}
```

**Diagnostics:**
- **No event appears:** CP EventBus not wired. Check CP main.go: is the lifecycle handler connected to EventBus.Emit()?
- **Event appears with wrong data:** EventBus.Emit() is called but with incorrect payload. Check the JSON structure.
- **Event appears but GW still 404s:** GW isn't subscribed to `/events` or isn't processing the event. Check GW logs.

---

### Technique 2: JWT Token Inspection

**What it shows:** What claims does the JWT contain? Is it valid?

**How to do it:**

After the smoke test runs (or you issue a token manually):

```bash
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."  # Paste your token here

# Decode header
echo $TOKEN | cut -d'.' -f1 | base64 -d | jq .

# Decode payload (claims)
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq .

# Or use a one-liner to extract applicationname
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq .applicationname
```

**Expected payload:**
```json
{
  "iss": "http://localhost:8080",
  "sub": "user",
  "aud": "default",
  "exp": 1234567890,
  "iat": 1234567000,
  "applicationname": "SmokeApp",
  "scope": "default"
}
```

**Diagnostics:**
- **Missing `applicationname` claim:** GW won't find the app. Check IS token-generation code.
- **Wrong `iss` claim:** GW expects `http://localhost:8080`; token says something else. Check IS config and GW `WSO2_IS_URL`.
- **`exp` in the past:** Token is expired. Check server clocks are synchronized.

---

### Technique 3: GW Routing Cache State

**What it shows:** Does the GW have the API in its routing table?

**How to do it:**

After running smoke test (or creating an API manually):

```bash
# Check GW logs for cache state
docker compose logs gw | grep -i "loaded\|cache\|api"
```

**Expected output:**
```
gw_1 | [INFO] Loaded from CP: 1 APIs, 1 subscriptions
gw_1 | [INFO] Cache: /smoke/v1 → SmokeAPI (v1.0)
```

**Diagnostics:**
- **"Loaded from CP: 0 APIs":** GW's `/admin/sync` call returned empty. Either CP has no APIs, or GW's HTTP call failed. Check GW logs for errors.
- **API doesn't appear after publishing:** GW hasn't received the `API_PUBLISHED` SSE event. Monitor SSE stream (Technique 1) and check GW SSE subscription code.

---

### Technique 4: Subscription Cache Validation

**What it shows:** Is the subscription in CP's store? Is it active?

**How to do it:**

Manually check subscriptions in the CP:

```bash
# This endpoint may not be public in the Go labs, but if available:
curl http://localhost:8082/subscriptions

# Or create a fresh subscription and check its state:
APP=$(curl -sf -X POST "http://localhost:8082/applications" \
  -H 'Content-Type: application/json' \
  -d '{"name":"DiagApp","owner":"tester"}')
APP_ID=$(echo "$APP" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# Create subscription
curl -sf -X POST "http://localhost:8082/subscriptions" \
  -H 'Content-Type: application/json' \
  -d "{\"appId\":\"$APP_ID\",\"apiId\":\"$API_ID\",\"tier\":\"Gold\"}"
```

**Diagnostics:**
- **Subscription not created:** CP `/subscriptions` endpoint broken. Check CP logs.
- **Subscription created but tier is different:** Check the request body matches what GW expects.

---

### Technique 5: GW Subscription Cache Validation Check (CP Endpoint)

**What it shows:** Does the CP agree the subscription is valid?

**How to do it:**

```bash
# GW calls this endpoint on cache miss or to validate
curl http://localhost:8082/subscriptions/validate?consumerKey=<KEY>&apiContext=/smoke/v1&method=GET&path=/hello
```

**Expected response:**
```json
{
  "valid": true,
  "tier": "Gold",
  "status": "ACTIVE",
  "applicationname": "SmokeApp"
}
```

**Diagnostics:**
- **`"valid": false`:** CP doesn't know about this subscription. GW cache got out of sync (missed the SSE event).
- **`"status": "BLOCKED"`:** Subscription exists but is blocked. Check CP logs for why it was blocked.
- **Endpoint returns 404:** CP doesn't have a `/subscriptions/validate` endpoint. Check if it's implemented.

---

### Technique 6: GW Logs for JWT Validation

**What it shows:** Why does GW reject a JWT?

**How to do it:**

```bash
docker compose logs gw | grep -i "jwt\|validation\|token\|failed" | tail -20
```

**Expected when token is valid:**
```
gw_1 | [DEBUG] JWT validation passed for app: SmokeApp
gw_1 | [DEBUG] Checking subscription: SmokeApp -> /smoke/v1
gw_1 | [DEBUG] Cache hit: subscription valid, tier Gold
```

**Expected when token is invalid:**
```
gw_1 | [ERROR] JWT signature verification failed
gw_1 | [ERROR] Token issuer mismatch: expected http://localhost:8080, got http://localhost:9999
gw_1 | [ERROR] Token expired
```

**Diagnostics:**
- **Signature verification failed:** JWKS cache is stale or token wasn't signed by IS. Check GW's JWKS_URL points to correct IS.
- **Issuer mismatch:** GW expects one IS URL; token was issued by a different IS. Check GW `WSO2_IS_URL`.

---

### Technique 7: Container Network Isolation Test

**What it shows:** Can one container reach another by service name?

**How to do it:**

```bash
# From inside GW container, can it reach CP?
docker compose exec gw curl http://cp:8082/health

# From inside GW container, can it reach IS?
docker compose exec gw curl http://is:8080/health

# From outside (your terminal), can you reach services?
curl http://localhost:8082/health
```

**Diagnostics:**
- **`docker compose exec gw curl http://cp:8082/health` returns 200 but smoke test returns 403:** Network is fine; issue is with data/configuration.
- **`docker compose exec gw curl http://cp:8082/health` times out:** Network problem. Check Docker network, firewall, or service is not listening.

---

## Full Example Debugging Session

### Scenario: Smoke Test Fails at Step 7 with 403

```bash
bash smoke_test.sh
# ... steps 1-6 pass ...
# [7] Call API through GW...
# FAIL — GW returned 403
```

**Step 1: Check GW is running**
```bash
docker compose ps gw
# NAME       STATUS
# day44-gw-1 Up 30s
curl http://localhost:9090/health
# 200 OK
```

**Step 2: Check if subscription cache is populated**
```bash
docker compose logs gw | grep "Loaded from CP"
# [INFO] Loaded from CP: 1 APIs, 1 subscriptions
```

**Step 3: Verify subscription is in CP**
```bash
curl http://localhost:8082/subscriptions/validate?consumerKey=smoke-key&apiContext=/smoke/v1&method=GET
# {"valid": true, "tier": "Gold", "status": "ACTIVE"}
```

**Step 4: Check if SUBSCRIPTION_CREATED event was emitted**
```bash
# Terminal 1
curl -N http://localhost:8082/events

# Terminal 2
bash smoke_test.sh  # Just re-run the smoke test
# or manually create the subscription again

# Terminal 1 output should show:
# event: SUBSCRIPTION_CREATED
# data: {...}
```

**Step 5: Decode the JWT to check claims**
```bash
# Extract token from a manual run
TOKEN_RESP=$(curl -sf -X POST "http://localhost:8080/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=smoke-key&client_secret=unused&scope=default")
TOKEN=$(echo "$TOKEN_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Decode
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq .

# Expected:
# {
#   "applicationname": "SmokeApp",
#   "iss": "http://localhost:8080",
#   ...
# }
```

**Step 6: If all looks fine, check GW logs for JWT validation errors**
```bash
docker compose logs gw | grep -i "jwt\|error" | tail -20
```

**Conclusion:** If GW claims subscription is valid (Step 3) but still returns 403, issue is likely JWT validation. Check GW config and JWT claims against GW expectations.

---

## Common Fixes

| Issue | Fix |
|-------|-----|
| "Step 1 fails: FAIL: could not create API" | `docker compose restart cp` or check CP logs for startup errors |
| "Step 6 fails: IS did not return access_token" | `docker compose restart is` or check IS has the app credentials |
| "Step 7 fails: 403 but sub cache looks OK" | Restart GW and re-run: `docker compose restart gw` |
| "Step 7 fails: 404 for published API" | Wait 2 seconds and re-run (SSE event propagation delay) |
| "Services restart in a loop" | Check logs: `docker compose logs` — likely a startup error in one service |

