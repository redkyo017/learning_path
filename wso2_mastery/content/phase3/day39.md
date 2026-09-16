# Day 39 — Unified Control Plane: API Registry + Subscriptions + Event Bus + SSE

## Learning Objectives

After this day, you will:

1. Integrate the EventBus into the Control Plane
2. Emit events on every API lifecycle transition and subscription creation
3. Expose events via Server-Sent Events (SSE) for real-time GW sync
4. Implement the `/admin/sync` snapshot endpoint for initial GW bootstrap

## The Big Picture

Over the past 4 days, you've built:

- **Day 33:** API Registry (create, list, get, delete, lifecycle transitions)
- **Day 35:** Subscription Store (applications, subscriptions)
- **Day 36:** Validate Endpoint (GW checks subscription validity)
- **Day 38:** Event Bus (non-blocking publish, type-specific + all-events subscribe)

**Today:** Merge all three systems into **one unified Control Plane server** that:

1. Manages APIs and subscriptions (Days 33/35)
2. Publishes events to the EventBus on every state change (Day 38)
3. Streams events via SSE at `GET /events` (Day 39)
4. Exposes snapshots at `GET /admin/sync` (Day 39)

The server runs on `:8082` and is the single source of truth for the entire system.

---

## Part 1: Server-Sent Events (SSE) Protocol

### What Is SSE?

Server-Sent Events is a simple protocol for **push** data from server to client over HTTP. Simpler than WebSockets, perfect for one-way event streaming.

**HTTP Response Headers:**

```
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
```

**Response Body Format:**

```
data: <json>\n
\n
data: <json>\n
\n
```

Each event is a `data: ` line followed by a newline, then a blank line. Multiple events arrive as a continuous stream.

### The SSE Endpoint in Go

```go
func (cp *ControlPlane) eventsSSE(w http.ResponseWriter, r *http.Request) {
    // Set headers
    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    
    // Assert that the server supports flushing
    flusher, ok := w.(http.Flusher)
    if !ok {
        http.Error(w, "streaming unsupported", http.StatusInternalServerError)
        return
    }
    
    // Subscribe to all events
    events, unsubscribe := cp.bus.SubscribeAll()
    defer unsubscribe()
    
    // Stream events until the client disconnects
    for {
        select {
        case e := <-events:
            // Marshal and send
            data, _ := json.Marshal(e)
            fmt.Fprintf(w, "data: %s\n\n", data)
            flusher.Flush()  // CRITICAL: flush after each event
        case <-r.Context().Done():
            // Client disconnected or request timed out
            return
        }
    }
}
```

### Why `flusher.Flush()` Is Critical

Without flushing, HTTP buffers responses (for efficiency). The client might wait seconds before seeing events. Flush forces the data to the client immediately.

### GW Client-Side (Pseudocode)

```javascript
// Browser or GW written in Node.js
const eventStream = new EventSource("http://cp:8082/events");
eventStream.onmessage = (evt) => {
    const event = JSON.parse(evt.data);
    cache.apply(event);  // Update local cache
};
eventStream.onerror = () => {
    eventStream.close();
    // Re-sync from /admin/sync, then reconnect
    resync();
};
```

**Or in Go (GW side):**

```go
resp, _ := http.Get("http://cp:8082/events")
defer resp.Body.Close()
scanner := bufio.NewScanner(resp.Body)
for scanner.Scan() {
    line := scanner.Text()
    if strings.HasPrefix(line, "data: ") {
        data := strings.TrimPrefix(line, "data: ")
        var event Event
        json.Unmarshal([]byte(data), &event)
        cache.apply(event)
    }
}
```

---

## Part 2: The ControlPlane Struct

### Structure

```go
type ControlPlane struct {
    reg  *Registry    // From Day 33: API registry
    subs *Store       // From Day 35: Subscriptions
    bus  *EventBus    // From Day 38: Event bus
}

func NewControlPlane() *ControlPlane {
    return &ControlPlane{
        reg:  NewRegistry(),
        subs: NewStore(),
        bus:  NewEventBus(),
    }
}
```

### Event Type Mapping

Map lifecycle status changes to event types:

```go
func toEventType(s LifecycleStatus) EventType {
    switch s {
    case StatusPublished:  return EventAPIPublished
    case StatusDeprecated: return EventAPIDeprecated
    case StatusRetired:    return EventAPIRetired
    default:               return EventAPICreated
    }
}
```

---

## Part 3: Publishing Events on State Changes

### When Creating an API

```go
func (cp *ControlPlane) createAPI(w http.ResponseWriter, req *http.Request) {
    var body struct {
        Name       string   `json:"name"`
        Context    string   `json:"context"`
        Version    string   `json:"version"`
        BackendURL string   `json:"backendUrl"`
        Tiers      []string `json:"allowedTiers"`
    }
    if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
        http.Error(w, "bad request", http.StatusBadRequest)
        return
    }
    api := &API{
        ID: newID(), Name: body.Name, Context: body.Context,
        Version: body.Version, BackendURL: body.BackendURL,
        Status: StatusCreated, AllowedTiers: body.Tiers, CreatedAt: time.Now().UTC(),
    }
    cp.reg.mu.Lock()
    cp.reg.apis[api.ID] = api
    cp.reg.mu.Unlock()
    
    // Publish event
    cp.bus.Publish(NewEvent(EventAPICreated, map[string]any{
        "id": api.ID, "name": api.Name, "context": api.Context,
        "version": api.Version, "status": api.Status,
    }))
    
    writeJSON(w, http.StatusCreated, api)
}
```

### When Transitioning Lifecycle

```go
func (cp *ControlPlane) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
    var body struct {
        Action string `json:"action"` // Publish, Deprecate, Retire
    }
    if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
        http.Error(w, "bad request", http.StatusBadRequest)
        return
    }
    
    actionToStatus := map[string]LifecycleStatus{
        "Publish":   StatusPublished,
        "Deprecate": StatusDeprecated,
        "Retire":    StatusRetired,
    }
    target, ok := actionToStatus[body.Action]
    if !ok {
        http.Error(w, fmt.Sprintf(`{"error":"unknown action %q"}`, body.Action), http.StatusBadRequest)
        return
    }
    
    cp.reg.mu.Lock()
    defer cp.reg.mu.Unlock()
    api, ok := cp.reg.apis[id]
    if !ok {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    if body.Action == "Publish" && len(api.AllowedTiers) == 0 {
        http.Error(w, `{"error":"cannot publish API with no allowed tiers"}`, http.StatusBadRequest)
        return
    }
    
    allowed := validTransitions[api.Status]
    valid := false
    for _, s := range allowed {
        if s == target {
            valid = true
            break
        }
    }
    if !valid {
        http.Error(w, fmt.Sprintf(`{"error":"invalid transition: %s → %s"}`, api.Status, target), http.StatusBadRequest)
        return
    }
    
    oldStatus := api.Status
    api.Status = target
    
    // Publish event
    cp.bus.Publish(NewEvent(toEventType(target), map[string]any{
        "id": api.ID, "name": api.Name, "context": api.Context,
        "version": api.Version,
        "oldStatus": oldStatus, "newStatus": target,
        "tiers": api.AllowedTiers,
    }))
    
    writeJSON(w, http.StatusOK, api)
}
```

### When Creating a Subscription

```go
func (cp *ControlPlane) createSub(w http.ResponseWriter, req *http.Request) {
    var body struct {
        AppID string `json:"appId"`
        APIID string `json:"apiId"`
        Tier  string `json:"tier"`
    }
    if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
        http.Error(w, "bad request", http.StatusBadRequest)
        return
    }
    
    sub := &Subscription{
        ID: newID(), AppID: body.AppID, APIID: body.APIID,
        Tier: body.Tier, Status: SubUnblocked, CreatedAt: time.Now().UTC(),
    }
    cp.subs.mu.Lock()
    cp.subs.subs[sub.ID] = sub
    cp.subs.subIdx[sub.AppID] = append(cp.subs.subIdx[sub.AppID], sub)
    cp.subs.mu.Unlock()
    
    // Publish event
    cp.bus.Publish(NewEvent(EventSubCreated, map[string]any{
        "id": sub.ID, "appId": sub.AppID, "apiId": sub.APIID,
        "tier": sub.Tier, "status": sub.Status,
    }))
    
    writeJSON(w, http.StatusCreated, sub)
}
```

---

## Part 4: The Admin Sync Endpoint

### Purpose

The GW calls `/admin/sync` during startup to bootstrap its cache with **all current state**. It returns:

- All PUBLISHED APIs (deprecated/retired are not served)
- All UNBLOCKED subscriptions (blocked subscriptions don't route traffic)

### Implementation

```go
func (cp *ControlPlane) adminSync(w http.ResponseWriter, _ *http.Request) {
    // Snapshot all published APIs
    cp.reg.mu.RLock()
    apis := make([]*API, 0)
    for _, a := range cp.reg.apis {
        if a.Status == StatusPublished {
            apis = append(apis, a)
        }
    }
    cp.reg.mu.RUnlock()
    
    // Snapshot all unblocked subscriptions
    cp.subs.mu.RLock()
    allSubs := make([]*Subscription, 0)
    for _, sub := range cp.subs.subs {
        if sub.Status == SubUnblocked {
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

### Response Example

```json
{
  "apis": [
    {
      "id": "abc123",
      "name": "PetStore",
      "context": "/petstore/v1",
      "version": "1.0",
      "backendUrl": "http://backend:3000",
      "status": "PUBLISHED",
      "allowedTiers": ["Gold", "Silver"],
      "createdAt": "2026-09-16T10:00:00Z"
    }
  ],
  "subscriptions": [
    {
      "id": "sub1",
      "appId": "app1",
      "apiId": "abc123",
      "tier": "Gold",
      "status": "UNBLOCKED",
      "createdAt": "2026-09-16T10:05:00Z"
    }
  ]
}
```

### Why Only PUBLISHED APIs?

- **CREATED:** Not yet published; GW should not route to it
- **DEPRECATED:** Existing subscriptions can still access, but new subscriptions cannot be created
- **RETIRED:** No subscriptions; GW should return 404

Same logic for subscriptions: only UNBLOCKED subscriptions are served.

---

## Part 5: GW Sync + Stream Pattern

### Sequence Diagram

```
┌─────────────────────────────┐
│  Gateway Startup            │
└─────────────────────────────┘
            │
            ├─ (1) GET /admin/sync
            │       ↓
            │   Load APIs + subscriptions into cache
            │
            ├─ (2) GET /events (SSE)
            │       ↓
            │   Subscribe to event stream
            │
            │   (3) CP publishes API_PUBLISHED
            │       ↓
            │   Event arrives in stream
            │   Cache.apply(event)
            │
            │   (4) If SSE connection drops:
            │       ↓
            │   Sleep 1 second
            │   Go to (1) — re-sync + reconnect
            │
            └─ Accept traffic on `:8081`
              Route using cache (synced + updated)
```

### Timeline Example

```
T=0:    GW starts, calls GET /admin/sync → cache = {PetStore@v1}
T=1:    GW connects to GET /events (SSE)
T=5:    Operator publishes a new API "UserStore"
T=5.1:  API_PUBLISHED event published on bus
T=5.2:  Event streamed via SSE to GW
T=5.3:  GW cache.apply(event) → cache = {PetStore@v1, UserStore@v1}
T=100:  User requests GW → routes to UserStore (works immediately)
```

---

## Part 6: Integration Checklist

When building the unified CP, ensure:

- [ ] All Day 33 endpoints present: POST /apis, GET /apis, GET /apis/{id}, DELETE /apis/{id}, POST /apis/{id}/lifecycle, GET /apis/{id}/policies, PUT /apis/{id}/tiers
- [ ] All Day 35/36 endpoints present: POST /applications, GET /applications/{id}, POST /subscriptions, GET /subscriptions?appId=..., POST /subscriptions/validate, POST /admin/apis (API registration)
- [ ] New EventBus endpoints: GET /events (SSE), GET /admin/sync
- [ ] Every API lifecycle transition publishes an event
- [ ] Every subscription creation publishes an event
- [ ] Every API creation publishes an event
- [ ] SSE response has correct headers (Content-Type, Cache-Control, Connection)
- [ ] flusher.Flush() called after each event in SSE handler
- [ ] /admin/sync returns only PUBLISHED APIs and UNBLOCKED subscriptions
- [ ] All endpoints return correct HTTP status codes
- [ ] All response bodies are JSON

---

## Exercises

### Exercise 1: Context Cancellation in SSE

**Question:** The GW connects to `/events` and immediately disconnects. What Go mechanism closes the SSE goroutine?

**Hint:** What signal does the request context provide when the client disconnects?

**Solution sketch:**

The `http.Request` carries a `context.Context` that is cancelled when:

1. The client disconnects
2. The server shuts down
3. A timeout is reached

In the SSE handler:

```go
select {
case e := <-events:
    // Send event
    fmt.Fprintf(w, "data: %s\n\n", data)
    flusher.Flush()
case <-r.Context().Done():
    // Client disconnected; exit handler
    return
}
```

The `<-r.Context().Done()` case unblocks when the connection is closed. The handler returns, the `defer unsubscribe()` runs, and the goroutine exits cleanly.

---

### Exercise 2: Multiple Concurrent SSE Clients

**Question:** Two GW replicas connect to `/events`. Does each get all events?

**Hint:** Each client calls `SubscribeAll()` independently.

**Solution sketch:**

**Yes, each GW gets all events.**

**Why:** Each call to `SubscribeAll()` creates a new buffered channel. When an event is published, it's sent to **all** active channels:

```go
func (b *EventBus) Publish(e Event) {
    b.mu.RLock()
    all := make([]chan Event, len(b.allSub))  // Copy all channels
    copy(all, b.allSub)
    b.mu.RUnlock()
    
    for _, ch := range all {  // Send to EACH channel
        select {
        case ch <- e:
        default:
            // Dropped for this subscriber; others still get it
        }
    }
}
```

**Timeline:**

```
T=0: GW1 connects → SubscribeAll() → gets ch1
T=1: GW2 connects → SubscribeAll() → gets ch2
T=2: CP publishes API_PUBLISHED
T=2.1: Sends to ch1 (GW1 receives)
T=2.2: Sends to ch2 (GW2 receives)
T=2.3: Publish returns
```

Both GWs see the same event.

---

### Exercise 3: SSE Line Parsing in GW Code

**Question:** The GW parses SSE lines with `bufio.Scanner`. Write the parsing loop.

**Hint:** SSE lines start with `data: `. The value after `data: ` is the JSON payload.

**Solution sketch:**

```go
resp, _ := http.Get("http://localhost:8082/events")
defer resp.Body.Close()

scanner := bufio.NewScanner(resp.Body)
for scanner.Scan() {
    line := scanner.Text()
    
    // SSE format: "data: <json>"
    if strings.HasPrefix(line, "data: ") {
        // Extract JSON
        data := strings.TrimPrefix(line, "data: ")
        
        // Unmarshal
        var event Event
        if err := json.Unmarshal([]byte(data), &event); err != nil {
            log.Printf("parse error: %v", err)
            continue
        }
        
        // Apply to cache
        cache.apply(event)
        log.Printf("applied %s event", event.Type)
    }
    // Blank lines are SSE delimiters; ignore
}

if err := scanner.Err(); err != nil {
    log.Printf("stream error: %v", err)
}
```

---

## Key Takeaways

1. **SSE is a push protocol:** Server sends events; client receives. Ideal for real-time cache sync.

2. **Flusher is critical:** Without flush, events batch up and clients see stale data.

3. **Sync + stream pattern:** Initial full snapshot from `/admin/sync`, then stream incremental updates via `/events`.

4. **Non-blocking events:** The EventBus never blocks the CP. Slow subscribers see dropped events and re-sync.

5. **Context cancellation:** Use `<-r.Context().Done()` to detect disconnections and clean up.

---

## Next Steps

Tomorrow (Day 40), you'll test this unified CP with real GW clients and Docker Compose orchestration. The system will be production-ready: resilient to network failures, handling concurrent events, and keeping multiple GWs perfectly synchronized.

**Code exercise:** Add event sequence IDs and implement sequence validation in the GW parser. If sequences are out of order, trigger a re-sync from `/admin/sync`.
