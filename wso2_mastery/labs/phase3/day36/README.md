# Day 36 — Lab: The Validate Endpoint and Gateway Integration

## Goal

Extend the Day 35 subscription store with the validate endpoint that the Gateway calls for subscription verification at request time. This is a critical path: every request that requires authorization flows through this endpoint.

## Prerequisites

- Go 1.18+ installed
- `curl` for testing HTTP endpoints
- Day 35 understanding of the application/subscription store

## Running the Server

Start the server:

```bash
go run main.go
```

**Expected output:**
```
WSO2 CP — Subscription Manager listening on :8083
```

## Testing the Server

### Setup: Create Test Data

First, create an application, register an API, and create a subscription.

**Test 1: Create an Application**

```bash
APP_RESPONSE=$(curl -s -X POST http://localhost:8083/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetApp","owner":"alice","callbackUrl":"https://petapp.example.com/callback"}')

echo "$APP_RESPONSE"
```

**Expected response:**
```json
{
  "id": "abc123de",
  "name": "PetApp",
  "consumerKey": "abcd1234ef567890...",
  "consumerSecret": "secret1234567890...",
  "owner": "alice",
  "callbackUrl": "https://petapp.example.com/callback",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

Save the `id` and `consumerKey` from the response.

**Test 2: Register an API**

```bash
curl -s -X POST http://localhost:8083/admin/apis \
  -H 'Content-Type: application/json' \
  -d '{"apiId":"petstore-abc","apiContext":"/petstore/v1"}'
```

**Expected response (201 Created):**
```json
{
  "apiId": "petstore-abc",
  "apiContext": "/petstore/v1"
}
```

**Test 3: Create a Subscription**

```bash
SUB_RESPONSE=$(curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"abc123de","apiId":"petstore-abc","tier":"Gold"}')

echo "$SUB_RESPONSE"
```

**Expected response:**
```json
{
  "id": "sub12345",
  "appId": "abc123de",
  "apiId": "petstore-abc",
  "tier": "Gold",
  "status": "UNBLOCKED",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

### Validation Scenarios

#### Test 4: Valid Subscription

The GW calls validate with a valid ConsumerKey and API context:

```bash
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1&tier=Gold"
```

**Expected response (200 OK):**
```json
{
  "valid": true,
  "tier": "Gold",
  "appName": "PetApp",
  "appId": "abc123de"
}
```

**Key observation:** Response is 200 OK, not 404. The endpoint answered the question: "Is this valid?" Yes, it is.

#### Test 5: Application Not Found

Query with a ConsumerKey that doesn't exist:

```bash
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=missing&apiContext=/petstore/v1&tier=Gold"
```

**Expected response (200 OK):**
```json
{
  "valid": false,
  "reason": "application_not_found"
}
```

**Key observation:** Still 200 OK (not 404). The endpoint answered the question: "Is this valid?" No, the app doesn't exist.

#### Test 6: API Not Found

Query with an apiContext that hasn't been registered:

```bash
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/unknown&tier=Gold"
```

**Expected response (200 OK):**
```json
{
  "valid": false,
  "reason": "api_not_found"
}
```

#### Test 7: Subscription Not Found (App Exists, but No Subscription to This API)

Create a second app and try to validate without subscribing:

```bash
# Create app 2
APP2=$(curl -s -X POST http://localhost:8083/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"UserApp","owner":"bob"}' | jq -r '.consumerKey')

# Try to validate (no subscription)
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=$APP2&apiContext=/petstore/v1&tier=Gold"
```

**Expected response (200 OK):**
```json
{
  "valid": false,
  "reason": "subscription_not_found"
}
```

#### Test 8: Tier Mismatch

The GW requests tier=Silver, but the subscription is tier=Gold:

```bash
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1&tier=Silver"
```

**Expected response (200 OK):**
```json
{
  "valid": false,
  "reason": "tier_mismatch"
}
```

#### Test 9: Blocked Subscription

Block a subscription and try to validate:

```bash
# First, find the subscription ID from Test 3 (save it as SUB_ID)
# Then delete (soft-delete) it
# Note: The current code doesn't have DELETE, but you can manually set status to BLOCKED

# For now, create a second subscription and manually block it
# (This requires code changes; see SOLUTION.md)

# Query with the blocked subscription
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1&tier=Gold"
```

**Expected response (once implemented):**
```json
{
  "valid": false,
  "reason": "subscription_blocked"
}
```

#### Test 10: No Tier Specified (Optional Parameter)

The GW can query without specifying a tier. In this case, any UNBLOCKED subscription to the API is valid:

```bash
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1"
```

**Expected response (200 OK):**
```json
{
  "valid": true,
  "tier": "Gold",
  "appName": "PetApp",
  "appId": "abc123de"
}
```

**Key observation:** `tier` parameter is optional. If provided, it must match exactly. If omitted, any tier is accepted.

## Performance Characteristics

### Time Complexity

- **`GET /subscriptions/validate`:** O(1) + O(n_small)
  - O(1) lookup by ConsumerKey (hash map)
  - O(1) lookup by API context (hash map)
  - O(n_small) scan through subscriptions for the app (typically 5-10 subscriptions)
  - Total: ≈ O(1) in practice

Under high load (1000s of requests/sec), this endpoint should have sub-millisecond latency.

### Memory Characteristics

Three maps, all using pointers to shared Application and Subscription objects:
- `apps` and `byKey` both point to the same Application instances (no duplication)
- `apiContextMap` stores strings (minimal memory)
- `subIdx` stores pointers to Subscription instances (no duplication)

Memory overhead is negligible.

## Verification Checklist

- [ ] Server starts and listens on `:8083`
- [ ] `/admin/apis` registers API contexts
- [ ] `GET /subscriptions/validate` returns 200 in all cases (never 404)
- [ ] Valid subscription returns `{"valid":true,...}`
- [ ] Invalid subscription returns `{"valid":false,"reason":"..."}`
- [ ] `tier` parameter is optional
- [ ] ConsumerKey lookup is O(1)
- [ ] Missing ConsumerKey returns 200 `{"valid":false,"reason":"application_not_found"}`
- [ ] Missing API context returns 200 `{"valid":false,"reason":"api_not_found"}`
- [ ] Tier mismatch returns 200 `{"valid":false,"reason":"tier_mismatch"}`

## Key Design Insights

1. **Always 200:** The endpoint answers a question ("Is this valid?"), not retrieves a resource. Always return 200, even for "no."

2. **Three-map pattern:** `byKey` for ConsumerKey lookup, `apiContextMap` for context resolution, both O(1).

3. **Tier parameter is optional:** If the GW doesn't care about tier, it omits the parameter. The endpoint accepts any UNBLOCKED subscription to the API.

4. **Soft deletion ready:** The `SubBlocked` status is checked before returning valid=true.

## Next Steps

Move to the SOLUTION.md to see implementation details and test result examples.
