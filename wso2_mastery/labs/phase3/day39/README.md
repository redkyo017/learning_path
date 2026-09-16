# Day 39 — Lab: Unified Control Plane with SSE and Event Streaming

## Goal

Test the unified Control Plane server that integrates:

- API Registry (Day 33)
- Subscription Store (Day 35/36)
- Event Bus (Day 38)
- Server-Sent Events (SSE) for real-time streaming
- Admin sync snapshot endpoint

The server runs on `:8082` and is the single source of truth for the system.

## Prerequisites

- Go 1.18+ installed
- `curl` with the `-N` flag (for unbuffered streaming)
- `jq` (optional, for JSON pretty-printing)
- Three terminal windows

## Running the Server

Start the unified CP:

```bash
go run main.go
```

**Expected output:**

```
WSO2 CP — Unified Control Plane listening on :8082
```

---

## Testing Sequence

### Terminal 1: Start Server

```bash
go run main.go
```

(Keep this running for all tests.)

### Terminal 2: Stream Events via SSE

Start the SSE event stream:

```bash
curl -N http://localhost:8082/events
```

**Expected behavior:** curl connects and waits for events. It will print events as they arrive, in real-time.

**What you'll see initially:**
```
(nothing; waiting for events)
```

### Terminal 3: Create and Publish API

Create an API:

```bash
API=$(curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetStore","context":"/petstore/v1","version":"1.0","backendUrl":"http://backend:3000","allowedTiers":["Gold","Silver"]}')

echo "$API"
```

**Expected response:**
```json
{
  "id": "a1b2c3d4",
  "name": "PetStore",
  "context": "/petstore/v1",
  "version": "1.0",
  "backendUrl": "http://backend:3000",
  "status": "CREATED",
  "allowedTiers": ["Gold", "Silver"],
  "createdAt": "2026-09-16T14:00:00Z"
}
```

**Check Terminal 2:** You should see an API_CREATED event:

```
data: {"type":"API_CREATED","timestamp":"2026-09-16T14:00:00Z","payload":{"id":"a1b2c3d4","name":"PetStore","context":"/petstore/v1","version":"1.0","status":"CREATED"}}

```

Extract the API ID:

```bash
ID=$(echo "$API" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "API ID: $ID"
```

### Publish the API

Transition the API to PUBLISHED:

```bash
curl -s -X POST http://localhost:8082/apis/$ID/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}'
```

**Expected response:**
```json
{
  "id": "a1b2c3d4",
  "name": "PetStore",
  ...
  "status": "PUBLISHED",
  ...
}
```

**Check Terminal 2:** You should see an API_PUBLISHED event:

```
data: {"type":"API_PUBLISHED","timestamp":"2026-09-16T14:00:01Z","payload":{"id":"a1b2c3d4","name":"PetStore","context":"/petstore/v1","version":"1.0","oldStatus":"CREATED","newStatus":"PUBLISHED","tiers":["Gold","Silver"]}}

```

### Create an Application

In Terminal 3:

```bash
APP=$(curl -s -X POST http://localhost:8082/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetApp","owner":"alice","callbackUrl":"https://petapp.example.com"}')

echo "$APP"
```

Extract the app ID:

```bash
APP_ID=$(echo "$APP" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "App ID: $APP_ID"
```

### Register the API with the Store

```bash
curl -s -X POST http://localhost:8082/admin/apis \
  -H 'Content-Type: application/json' \
  -d "{\"apiId\":\"$ID\",\"apiContext\":\"/petstore/v1\"}"
```

**Expected response:**
```json
{
  "apiId": "a1b2c3d4",
  "apiContext": "/petstore/v1"
}
```

### Create a Subscription

```bash
SUB=$(curl -s -X POST http://localhost:8082/subscriptions \
  -H 'Content-Type: application/json' \
  -d "{\"appId\":\"$APP_ID\",\"apiId\":\"$ID\",\"tier\":\"Gold\"}")

echo "$SUB"
```

**Expected response:**
```json
{
  "id": "sub12345",
  "appId": "<APP_ID>",
  "apiId": "<API_ID>",
  "tier": "Gold",
  "status": "UNBLOCKED",
  "createdAt": "2026-09-16T14:00:02Z"
}
```

**Check Terminal 2:** You should see a SUBSCRIPTION_CREATED event:

```
data: {"type":"SUBSCRIPTION_CREATED","timestamp":"2026-09-16T14:00:02Z","payload":{"id":"sub12345","appId":"<APP_ID>","apiId":"<API_ID>","tier":"Gold","status":"UNBLOCKED"}}

```

---

## Testing the Admin Sync Endpoint

The GW uses `/admin/sync` during startup to bootstrap its cache with all PUBLISHED APIs and UNBLOCKED subscriptions.

```bash
curl -s http://localhost:8082/admin/sync | jq .
```

**Expected response:**
```json
{
  "apis": [
    {
      "id": "a1b2c3d4",
      "name": "PetStore",
      "context": "/petstore/v1",
      "version": "1.0",
      "backendUrl": "http://backend:3000",
      "status": "PUBLISHED",
      "allowedTiers": ["Gold", "Silver"],
      "createdAt": "2026-09-16T14:00:00Z"
    }
  ],
  "subscriptions": [
    {
      "id": "sub12345",
      "appId": "<APP_ID>",
      "apiId": "<API_ID>",
      "tier": "Gold",
      "status": "UNBLOCKED",
      "createdAt": "2026-09-16T14:00:02Z"
    }
  ]
}
```

**Key observations:**

1. Only PUBLISHED APIs are in the response (not CREATED, DEPRECATED, or RETIRED)
2. Only UNBLOCKED subscriptions are in the response (not BLOCKED)
3. The snapshot is consistent at a point in time

---

## Testing Event Filtering

### Type-Specific Subscriber (Not Implemented in HTTP)

The EventBus supports type-specific subscribers. If you were to add an endpoint like:

```go
// GET /events/API_PUBLISHED — only API_PUBLISHED events
mux.HandleFunc("/events/API_PUBLISHED", func(w http.ResponseWriter, r *http.Request) {
    // Similar to eventsSSE, but uses bus.Subscribe(EventAPIPublished)
})
```

This would stream only API_PUBLISHED events, not subscription events.

---

## Performance Observations

### Event Latency

From publishing to appearing in the SSE stream: typically **<10 ms** (sub-buffer, non-blocking send).

### Throughput

The CP can publish hundreds of events per second without blocking HTTP handlers.

### Memory Usage

- Empty EventBus: ~1 KB
- Per subscriber (32-event buffer): ~6.5 KB
- With 10 SSE clients: ~70 KB overhead

---

## Verification Checklist

- [ ] Server starts and listens on `:8082`
- [ ] `/health` returns `{"status":"UP"}`
- [ ] POST `/apis` creates an API with status=CREATED
- [ ] POST `/apis/{id}/lifecycle` with action=Publish transitions to PUBLISHED
- [ ] GET `/events` (SSE) streams events in real-time
- [ ] API_CREATED event appears when an API is created
- [ ] API_PUBLISHED event appears when lifecycle transitions
- [ ] SUBSCRIPTION_CREATED event appears when a subscription is created
- [ ] SSE response has `Content-Type: text/event-stream`
- [ ] SSE response has `Cache-Control: no-cache`
- [ ] GET `/admin/sync` returns only PUBLISHED APIs
- [ ] GET `/admin/sync` returns only UNBLOCKED subscriptions
- [ ] Event payloads are valid JSON
- [ ] All Day 33 endpoints work (create, list, get, delete, policies, tiers, lifecycle)
- [ ] All Day 35/36 endpoints work (applications, subscriptions, validate)

---

## Key Insights

### 1. Real-Time Sync Pattern

The unified CP enables the GW to stay synchronized without polling:

```
GW startup:
  1. GET /admin/sync → load current APIs + subscriptions
  2. GET /events (SSE) → stream subsequent changes
  
CP updates:
  1. Modify API registry or subscription store
  2. Publish event via EventBus
  3. Event streamed to all connected GWs via SSE
```

### 2. Non-Blocking Publish

All HTTP handlers are responsive because `Publish()` never blocks. If an SSE client is slow, its buffer fills, and new events for that client are dropped (with a warning).

### 3. Consistency

`/admin/sync` is always consistent at a point in time. It doesn't race with event publishing because it takes a snapshot under locks.

---

## Next Steps

Move to the SOLUTION.md for implementation details and advanced scenarios.

Then (Day 40), you'll orchestrate this CP with GW instances in Docker Compose for end-to-end testing.

**Advanced exercise:** Add sequence IDs to events and implement sequence validation in a custom GW client.
