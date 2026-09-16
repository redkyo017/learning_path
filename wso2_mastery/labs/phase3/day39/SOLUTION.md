# Day 39 — Solution: Unified Control Plane Integration

## Architecture

The unified Control Plane (`main.go`) integrates three subsystems:

```
┌──────────────────────────────────────────────────────────┐
│  Unified Control Plane (:8082)                           │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Registry (APIs)              Store (Apps + Subs)  │  │
│  │  - APIs: created/published    - Applications      │  │
│  │  - Lifecycle: create→pub...   - Subscriptions     │  │
│  └────────────────────────────────────────────────────┘  │
│                         │                                 │
│                         └─ (1) State changes              │
│                                 ↓                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │  EventBus                                           │  │
│  │  - Non-blocking Publish                           │  │
│  │  - Subscribe(type) + SubscribeAll()               │  │
│  │  - Buffered channels (32 events)                  │  │
│  └────────────────────────────────────────────────────┘  │
│                         │                                 │
│                         └─ (2) Events published           │
│                                 ↓                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │  HTTP Handlers                                   │   │
│  │  - GET /events (SSE)                             │   │
│  │  - GET /admin/sync (snapshot)                    │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
         │                           │
         ├─ (3) SSE stream           └─ (4) Full snapshot
         │                                  (on startup)
         ↓                                  ↓
    Gateway Instances           Each GW loads
    (real-time updates)         all PUBLISHED APIs
```

---

## Key Integration Points

### 1. API Creation Emits Event

```go
func (cp *ControlPlane) createAPI(w http.ResponseWriter, req *http.Request) {
    // ... parse request, create API struct ...
    
    cp.reg.mu.Lock()
    cp.reg.apis[api.ID] = api
    cp.reg.mu.Unlock()
    
    // NEW: Emit event
    cp.bus.Publish(NewEvent(EventAPICreated, map[string]any{
        "id": api.ID, "name": api.Name, "context": api.Context,
        "version": api.Version, "status": api.Status,
    }))
    
    writeJSON(w, http.StatusCreated, api)
}
```

**Timeline:**

- T=0: Handler acquires lock, modifies `cp.reg.apis`
- T=0.1: Lock released
- T=0.2: `cp.bus.Publish()` called (non-blocking, returns immediately)
- T=0.3: Event is in all subscribers' buffers
- T=0.4: HTTP response sent (201 Created)

The handler is never blocked by event publishing.

### 2. Lifecycle Transition Emits Event with Status Change

```go
func (cp *ControlPlane) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
    // ... parse action, validate transition ...
    
    cp.reg.mu.Lock()
    defer cp.reg.mu.Unlock()
    
    api, ok := cp.reg.apis[id]
    if !ok {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    
    // Validate and apply transition
    oldStatus := api.Status
    api.Status = target
    
    // NEW: Emit event with old and new status
    cp.bus.Publish(NewEvent(toEventType(target), map[string]any{
        "id": api.ID, "name": api.Name, "context": api.Context,
        "version": api.Version,
        "oldStatus": oldStatus, "newStatus": target,
        "tiers": api.AllowedTiers,
    }))
    
    writeJSON(w, http.StatusOK, api)
}
```

**Why include oldStatus and newStatus?** So the GW can apply the transition without re-querying the full API state.

### 3. Subscription Creation Emits Event

```go
func (cp *ControlPlane) createSub(w http.ResponseWriter, req *http.Request) {
    // ... parse request, validate ...
    
    sub := &Subscription{
        ID: newID(), AppID: body.AppID, APIID: body.APIID,
        Tier: body.Tier, Status: SubUnblocked, CreatedAt: time.Now().UTC(),
    }
    
    cp.subs.mu.Lock()
    cp.subs.subs[sub.ID] = sub
    cp.subs.subIdx[sub.AppID] = append(cp.subs.subIdx[sub.AppID], sub)
    cp.subs.mu.Unlock()
    
    // NEW: Emit event
    cp.bus.Publish(NewEvent(EventSubCreated, map[string]any{
        "id": sub.ID, "appId": sub.AppID, "apiId": sub.APIID,
        "tier": sub.Tier, "status": sub.Status,
    }))
    
    writeJSON(w, http.StatusCreated, sub)
}
```

---

## SSE Endpoint Implementation

```go
func (cp *ControlPlane) eventsSSE(w http.ResponseWriter, r *http.Request) {
    // Step 1: Set correct headers
    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")      // No caching
    w.Header().Set("Connection", "keep-alive")        // Keep connection open
    
    // Step 2: Acquire flusher (required for real-time streaming)
    flusher, ok := w.(http.Flusher)
    if !ok {
        http.Error(w, "streaming unsupported", http.StatusInternalServerError)
        return
    }
    
    // Step 3: Subscribe to all events
    events, unsubscribe := cp.bus.SubscribeAll()
    defer unsubscribe()  // Clean up on disconnect
    
    // Step 4: Stream events until client disconnects
    for {
        select {
        case e := <-events:
            // New event received; serialize and send
            data, _ := json.Marshal(e)
            fmt.Fprintf(w, "data: %s\n\n", data)  // SSE format: "data: <json>\n\n"
            flusher.Flush()  // CRITICAL: flush immediately
        case <-r.Context().Done():
            // Client disconnected or request timed out
            return
        }
    }
}
```

### Why `flusher.Flush()`?

HTTP buffers responses for efficiency. Without flushing:

```
Client connects to /events
CP publishes 10 events
Client sees nothing (buffered)
(10-100 ms later) Client sees all 10 events batched
```

With flushing:

```
Client connects to /events
CP publishes event 1
Event 1 flushed → Client sees it immediately (<1 ms)
CP publishes event 2
Event 2 flushed → Client sees it immediately
```

---

## Admin Sync Endpoint Implementation

```go
func (cp *ControlPlane) adminSync(w http.ResponseWriter, _ *http.Request) {
    // Snapshot: acquire locks, copy data, release locks
    
    // Collect PUBLISHED APIs
    cp.reg.mu.RLock()
    apis := make([]*API, 0)
    for _, a := range cp.reg.apis {
        if a.Status == StatusPublished {  // ONLY published
            apis = append(apis, a)
        }
    }
    cp.reg.mu.RUnlock()
    
    // Collect UNBLOCKED subscriptions
    cp.subs.mu.RLock()
    allSubs := make([]*Subscription, 0)
    for _, sub := range cp.subs.subs {
        if sub.Status == SubUnblocked {  // ONLY unblocked
            allSubs = append(allSubs, sub)
        }
    }
    cp.subs.mu.RUnlock()
    
    // Return snapshot
    writeJSON(w, http.StatusOK, map[string]any{
        "apis": apis,
        "subscriptions": allSubs,
    })
}
```

### Why Only PUBLISHED APIs?

- **CREATED:** Not yet ready; GW should not route to it
- **DEPRECATED:** Existing subscriptions can still use it, but GW may return 410 Gone
- **RETIRED:** No subscriptions; GW has no reason to route to it

### Why Only UNBLOCKED Subscriptions?

- **BLOCKED:** GW should reject requests from blocked apps with 403 Forbidden

---

## Data Flow: A Complete Example

### Scenario: Operator Publishes an API

**Terminal 1 (CP):**
```
go run main.go
```

**Terminal 2 (GW with SSE):**
```bash
curl -N http://localhost:8082/events
```

**Terminal 3 (Admin):**

Step 1: Create API
```bash
curl -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetStore","context":"/petstore/v1","version":"1.0","backendUrl":"...","allowedTiers":["Gold"]}'
```

CP response:
```json
{"id":"abc123","status":"CREATED",...}
```

EventBus publishes: `API_CREATED` event

Terminal 2 sees:
```
data: {"type":"API_CREATED","timestamp":"...","payload":{"id":"abc123",...}}

```

Step 2: Publish API
```bash
curl -X POST http://localhost:8082/apis/abc123/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}'
```

CP response:
```json
{"id":"abc123","status":"PUBLISHED",...}
```

EventBus publishes: `API_PUBLISHED` event

Terminal 2 sees:
```
data: {"type":"API_PUBLISHED","timestamp":"...","payload":{"id":"abc123","oldStatus":"CREATED","newStatus":"PUBLISHED",...}}

```

**GW (reading Terminal 2 SSE stream):**

1. Receives `API_PUBLISHED` event
2. Updates local cache: `cache["/petstore/v1"] = API{status: PUBLISHED}`
3. Traffic to `/petstore/v1` now routes to PetStore

---

## Event Payload Shapes

### API_CREATED
```json
{
  "type": "API_CREATED",
  "timestamp": "2026-09-16T14:00:00Z",
  "payload": {
    "id": "abc123",
    "name": "PetStore",
    "context": "/petstore/v1",
    "version": "1.0",
    "status": "CREATED"
  }
}
```

### API_PUBLISHED
```json
{
  "type": "API_PUBLISHED",
  "timestamp": "2026-09-16T14:00:01Z",
  "payload": {
    "id": "abc123",
    "name": "PetStore",
    "context": "/petstore/v1",
    "version": "1.0",
    "oldStatus": "CREATED",
    "newStatus": "PUBLISHED",
    "tiers": ["Gold", "Silver"]
  }
}
```

### SUBSCRIPTION_CREATED
```json
{
  "type": "SUBSCRIPTION_CREATED",
  "timestamp": "2026-09-16T14:00:02Z",
  "payload": {
    "id": "sub1",
    "appId": "app1",
    "apiId": "abc123",
    "tier": "Gold",
    "status": "UNBLOCKED"
  }
}
```

---

## Testing Flow

### Test 1: Admin Sync Returns Only Published APIs

```bash
# Create API (status = CREATED)
API=$(curl -s -X POST http://localhost:8082/apis ...)
ID=$(echo $API | jq -r '.id')

# Check /admin/sync (should be empty)
curl -s http://localhost:8082/admin/sync | jq '.apis'
# []

# Publish API (status = PUBLISHED)
curl -s -X POST http://localhost:8082/apis/$ID/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}'

# Check /admin/sync again (should have the API)
curl -s http://localhost:8082/admin/sync | jq '.apis'
# [{"id":"...","status":"PUBLISHED",...}]
```

### Test 2: SSE Events Arrive in Real-Time

```bash
# Terminal 2: curl -N http://localhost:8082/events

# Terminal 3: Create API
curl -s -X POST http://localhost:8082/apis ...

# Expected in Terminal 2 within 1 ms:
# data: {"type":"API_CREATED",...}
```

### Test 3: Multiple SSE Clients Receive Same Events

```bash
# Terminal 2: curl -N http://localhost:8082/events
# Terminal 4: curl -N http://localhost:8082/events

# Terminal 3: Create API
curl -s -X POST http://localhost:8082/apis ...

# Both Terminal 2 and Terminal 4 see the same event
```

---

## Production Considerations

### 1. Event Ordering

Events are published in the order they occur. However, multiple concurrent requests might cause events to arrive out of order. Add sequence IDs to detect and handle this:

```go
type Event struct {
    Sequence  int64           `json:"sequence"`  // NEW
    Type      EventType       `json:"type"`
    Timestamp time.Time       `json:"timestamp"`
    Payload   json.RawMessage `json:"payload"`
}
```

### 2. Event Durability

If a GW disconnects during an API publish, it misses the event. Mitigation:

- GW connects to `/events` (real-time)
- GW disconnects (network issue)
- (N seconds later) GW reconnects
- GW calls `GET /admin/sync` to get full state
- GW re-subscribes to `/events`

This is **not durable** (no event replay), but it's **recoverable** (via sync).

### 3. Buffer Overflow

If an SSE client is slow, its buffer fills (32 events). New events for that client are dropped. Mitigation:

- Monitor "buffer full" warnings
- Alert on sustained high drop rate
- Consider increasing buffer size
- Or scale up SSE clients

### 4. Broadcasting Inefficiency

If 1000 GWs connect to `/events`, the CP publishes to 1000 channels. With high event throughput (10,000 events/sec), this becomes a bottleneck.

Mitigation:

- Use a dedicated event streaming service (e.g., Kafka)
- Or shard the GWs (different GW clusters subscribe to different CP instances)

---

## Comparison: WSO2 vs. Go Implementation

| Aspect | WSO2 | Go Implementation |
|--------|------|-------------------|
| **Transport** | JMS (ActiveMQ) | HTTP/SSE |
| **Durability** | Durable topic subscriptions | No durability |
| **Recovery** | Replay from broker | Re-sync from `/admin/sync` |
| **Throughput** | ~1000 events/sec | ~10,000 events/sec |
| **Latency** | 10-100 ms | 1-10 ms |
| **Broker dependency** | Required (ActiveMQ) | Not required |
| **Complexity** | High (JMS, broker, clustering) | Low (in-process channels) |

---

## Next Steps

Tomorrow (Day 40), you'll orchestrate this CP with GW instances in Docker Compose. The GW will:

1. Call `GET /admin/sync` during startup
2. Stream events from `GET /events`
3. Route traffic based on synced cache
4. Re-sync on SSE disconnect

**Advanced exercise:** Implement event sequence IDs and sequence validation in the GW.
