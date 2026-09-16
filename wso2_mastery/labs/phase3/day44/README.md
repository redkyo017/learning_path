# Day 44 Lab: Smoke Test

## Objective

Run an automated end-to-end smoke test that validates the complete flow: API creation, publishing, application subscription, JWT issuance, and API invocation through the GW.

## Prerequisites

- All four services running: `docker compose up` from `labs/phase3/day43/`
- `bash`, `curl`, and `grep` available in your shell.
- Network connectivity: localhost:8080 (IS), localhost:8082 (CP), localhost:9090 (GW).

## Files in This Lab

- `smoke_test.sh` — Main test script (executable).
- `README.md` — This file; usage and interpretation.
- `SOLUTION.md` — Detailed failure diagnostics and debugging techniques.
- `teardown.md` — Cleanup instructions.

## How to Run

```bash
chmod +x smoke_test.sh  # Make executable (if not already)
bash smoke_test.sh
```

**Expected output:**
```
=== Phase 3 Smoke Test ===
[1] Create API...
  Created: <API_ID>
[2] Publish API...
  Published.
[3] Create application...
  App: <APP_ID>  Key: <CONSUMER_KEY>
[4] Subscribe app to API (Gold tier)...
  Subscribed.
[5] Register API context for validate endpoint...
  Done.
[6] Obtain JWT from IS...
  Token: eyJhbGciOiJSUzI1...
[7] Call API through GW...
  PASS — GW returned 200

=== ALL STEPS PASSED ===
```

Exit code: `0` (success)

## What Each Step Tests

| Step | Service | Tests | Failure Means |
|------|---------|-------|---------------|
| 1 | CP | Can create an API | CP is down or `/apis` endpoint broken |
| 2 | CP | Can publish an API | CP lifecycle transitions broken; SSE event emitted |
| 3 | CP | Can create an app | CP `/applications` endpoint broken |
| 4 | CP | Can subscribe app to API | CP `/subscriptions` endpoint broken; SSE event emitted |
| 5 | CP | Can register API context | CP `/admin/apis` endpoint (optional for GW fallback) |
| 6 | IS | Can issue JWT | IS down or `/oauth2/token` endpoint broken |
| 7 | GW + IS + CP | Can validate and route request | GW subscription cache miss, JWT validation failure, or subscription blocked |

## Interpreting Failures

### Failure at Step 1: "FAIL: could not create API"
```
[1] Create API...
FAIL: could not create API
```

**Diagnosis:**
1. Is the CP running? `curl http://localhost:8082/health`
2. Is the CP on the correct port? Check `docker compose ps`.
3. Are there any errors in the CP logs? `docker compose logs cp | tail -50`

### Failure at Step 6: "FAIL: IS did not return access_token"
```
[6] Obtain JWT from IS...
FAIL: IS did not return access_token
```

**Diagnosis:**
1. Is the IS running? `curl http://localhost:8080/health`
2. Is the IS on the correct port? Check `docker compose ps`.
3. Did the CP create the app correctly? Check that step 3 completed.
4. Are there any errors in the IS logs? `docker compose logs is | tail -50`

### Failure at Step 7: "FAIL — GW returned 403"
```
[7] Call API through GW...
FAIL — GW returned 403
```

**Diagnosis (in order of likelihood):**
1. **Subscription cache miss:** GW hasn't received the `SUBSCRIPTION_CREATED` SSE event yet.
   - **Fix:** Wait a few seconds and re-run the test.
   - **Check:** `curl -N http://localhost:8082/events | grep SUBSCRIPTION_CREATED`
2. **Subscription tier mismatch:** App subscribed at a different tier than expected.
   - **Fix:** Check the test script; ensure tier is "Gold" in both places.
3. **JWT validation failure:** Token is malformed or signature doesn't match.
   - **Check:** Decode the token: `echo $TOKEN | jq -R 'split(".")[1] | @base64d | fromjson'`
4. **GW lost connection to CP:** No events received since startup.
   - **Check:** `docker compose logs gw | grep -i "error\|events\|subscribe"`

See `SOLUTION.md` for detailed debugging techniques.

### Failure at Step 7: "FAIL — GW returned 404"
```
[7] Call API through GW...
FAIL — GW returned 404
```

**Diagnosis:**
1. Did the API publish successfully? (Step 2 should have succeeded.)
2. Did the GW receive the `API_PUBLISHED` event?
   - **Check:** Watch the SSE stream: `curl -N http://localhost:8082/events | grep API_PUBLISHED`
   - **Check:** GW logs: `docker compose logs gw | grep -i "api\|route"`
3. Is the GW routing table empty?
   - **Fix:** Restart GW to force a fresh `/admin/sync`: `docker compose restart gw`

## Debugging Techniques

### Watch Events in Real-Time

In one terminal, watch the CP's event stream:

```bash
curl -N http://localhost:8082/events
```

In another terminal, run the smoke test. You should see:
```
:
event: API_PUBLISHED
data: {"id":"api-001","context":"/smoke/v1","version":"1.0",...}

event: SUBSCRIPTION_CREATED
data: {"appId":"app-001","apiId":"api-001","tier":"Gold",...}
```

If you **don't** see these events, the CP's EventBus isn't connected to the lifecycle handlers (check CP code).

If you see events but the smoke test still fails, the GW isn't subscribed to `/events` (check GW logs).

### Check Service Health

```bash
curl http://localhost:8080/health  # IS
curl http://localhost:8082/health  # CP
curl http://localhost:9090/health  # GW
curl http://localhost:8000/        # Backend
```

All should return 200 and "OK" or similar.

### Inspect Logs

```bash
docker compose logs is   # Identity Server
docker compose logs cp   # Control Plane
docker compose logs gw   # Gateway
docker compose logs backend
```

Add `--tail 100` to see the last 100 lines. Add `-f` to follow in real-time.

### Manual API Creation

```bash
# Create an API
curl -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "TestAPI",
    "context": "/test/v1",
    "version": "1.0",
    "backendUrl": "http://backend:8000",
    "allowedTiers": ["Gold"]
  }'
# Expected: { "id": "api-001", "name": "TestAPI", ... }

# Get the API ID from the response and save it
API_ID="api-001"

# Publish it
curl -X POST http://localhost:8082/apis/$API_ID/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action": "Publish"}'
# Expected: 200 OK
```

## When to Use This Smoke Test

- **After deployment:** Run smoke test to verify all services are integrated.
- **After config changes:** Ensure a change to GW config (e.g., new IS URL) doesn't break integration.
- **After restarts:** Verify services still work after restarting Docker containers.
- **In CI/CD:** Include smoke test as a post-deployment check before marking deployment as success.

## Next Steps

- Review `SOLUTION.md` for deeper debugging techniques.
- Day 45: Read the runbook and understand the production checklist.

