# Day 35 — Lab: Building the Subscription Store

## Goal

Implement a standalone Go server that manages applications and their subscriptions. This is the foundation for the validation endpoint you'll build on Day 36.

## Prerequisites

- Go 1.18+ installed
- `curl` for testing HTTP endpoints
- Text editor or IDE

## Running the Server

Start the server:

```bash
go run main.go
```

**Expected output:**
```
WSO2 CP — Subscription Manager listening on :8083
```

The server listens on `http://localhost:8083` and serves the following endpoints.

## Testing the Server

### Test 1: Create an Application

Create a new application:

```bash
curl -s -X POST http://localhost:8083/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetApp","owner":"alice","callbackUrl":"https://petapp.example.com/callback"}'
```

**Expected response (201 Created):**
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

**Important:** Save the `id` and `consumerKey` values; you'll use them in subsequent tests.

**Exercise:** Run this command and paste the response. Note the `consumerSecret` is exposed here (and only here).

### Test 2: Retrieve the Application

Retrieve the application by ID:

```bash
curl -s http://localhost:8083/applications/{appId}
```

Replace `{appId}` with the ID from Test 1.

**Expected response (200 OK):**
```json
{
  "id": "abc123de",
  "name": "PetApp",
  "consumerKey": "abcd1234ef567890...",
  "consumerSecret": "***",
  "owner": "alice",
  "callbackUrl": "https://petapp.example.com/callback",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

**Key observation:** The `consumerSecret` is now `"***"`. It's never exposed again after creation.

**Exercise:** Run this command and verify the secret is masked.

### Test 3: Create a Subscription

Create a subscription (subscribe the app to an API):

```bash
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"{appId}","apiId":"petstore-v1","tier":"Gold"}'
```

Replace `{appId}` with the app ID from Test 1.

**Expected response (201 Created):**
```json
{
  "id": "sub12345",
  "appId": "abc123de",
  "apiId": "petstore-v1",
  "tier": "Gold",
  "status": "UNBLOCKED",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

**Exercise:** Run this command and save the subscription ID for later tests.

### Test 4: List Subscriptions for an App

List all subscriptions for the app:

```bash
curl -s "http://localhost:8083/subscriptions?appId={appId}"
```

Replace `{appId}` with the app ID from Test 1.

**Expected response (200 OK):**
```json
[
  {
    "id": "sub12345",
    "appId": "abc123de",
    "apiId": "petstore-v1",
    "tier": "Gold",
    "status": "UNBLOCKED",
    "createdAt": "2026-09-16T12:00:00Z"
  }
]
```

**Exercise:** Run this command. Try listing subscriptions for a non-existent app (`?appId=missing`). You should get `[]` (empty array), not an error.

### Test 5: Create a Second Subscription (Same App)

Subscribe the same app to a different API:

```bash
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"{appId}","apiId":"users-v2","tier":"Bronze"}'
```

**Expected response (201 Created):**
```json
{
  "id": "sub67890",
  "appId": "abc123de",
  "apiId": "users-v2",
  "tier": "Bronze",
  "status": "UNBLOCKED",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

Now list subscriptions again:

```bash
curl -s "http://localhost:8083/subscriptions?appId={appId}"
```

**Expected response (200 OK):**
```json
[
  {
    "id": "sub12345",
    "appId": "abc123de",
    "apiId": "petstore-v1",
    "tier": "Gold",
    "status": "UNBLOCKED",
    "createdAt": "2026-09-16T12:00:00Z"
  },
  {
    "id": "sub67890",
    "appId": "abc123de",
    "apiId": "users-v2",
    "tier": "Bronze",
    "status": "UNBLOCKED",
    "createdAt": "2026-09-16T12:00:00Z"
  }
]
```

**Exercise:** Run these commands and verify both subscriptions appear in the list.

### Test 6: Health Check

Verify the server is running:

```bash
curl -s http://localhost:8083/health
```

**Expected response (200 OK):**
```json
{
  "status": "UP"
}
```

## Verification Checklist

- [ ] Server starts and listens on `:8083`
- [ ] `POST /applications` creates app with generated ConsumerKey/ConsumerSecret
- [ ] `GET /applications/{id}` returns app with ConsumerSecret masked
- [ ] `POST /subscriptions` creates subscription
- [ ] `GET /subscriptions?appId={id}` lists subscriptions for app
- [ ] Empty subscription list returns `[]`, not an error
- [ ] `/health` endpoint returns `{"status":"UP"}`

## Key Design Patterns Observed

1. **Two-map indexing:** The store uses `apps` (by ID) and `byKey` (by ConsumerKey) for O(1) lookups.
2. **Cryptographic key generation:** Uses `crypto/rand`, not `math/rand`.
3. **Secret masking:** ConsumerSecret is exposed only at creation; masked on retrieval.
4. **Soft deletion readiness:** The Subscription model has a Status field (for blocking, not hard deletion).
5. **Empty array semantics:** Listing with no results returns `[]`, not `null`.

## Next Steps

Stop the server (Ctrl+C) and move to Day 36, where you'll add the validate endpoint that the Gateway calls.
