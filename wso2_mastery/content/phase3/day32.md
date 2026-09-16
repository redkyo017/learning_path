# Day 32 — Building the Control Plane Registry: State Machine + CRUD

## Why This Matters

Building the Control Plane API registry forces you to encode every WSO2 design decision in Go — the state machine, the validation rules, the response shapes, the concurrency model. When you finish this lab, you will understand exactly why WSO2's code is structured the way it is, because you've had to make every design decision yourself. You'll also see how easy it is to introduce race conditions if you don't use proper synchronization primitives.

## Core Concepts

### Typed Lifecycle State Machine

Instead of using string literals everywhere, WSO2 wraps lifecycle statuses in a typed constant:

```go
type LifecycleStatus string

const (
    StatusCreated    LifecycleStatus = "CREATED"
    StatusPublished  LifecycleStatus = "PUBLISHED"
    StatusDeprecated LifecycleStatus = "DEPRECATED"
    StatusRetired    LifecycleStatus = "RETIRED"
)
```

This prevents typos and gives you type safety. The `validTransitions` map mirrors the `APILifeCycle.xml` configuration:

```go
var validTransitions = map[LifecycleStatus][]LifecycleStatus{
    StatusCreated:    {StatusPublished},           // CREATED can only go to PUBLISHED
    StatusPublished:  {StatusDeprecated},          // PUBLISHED can only go to DEPRECATED
    StatusDeprecated: {StatusRetired},             // DEPRECATED can only go to RETIRED
    // Note: StatusRetired has no outgoing transitions (end state)
}
```

### API Structure and Metadata

The `API` struct holds all the metadata the CP needs to track:

```go
type API struct {
    ID           string          // Unique identifier (e.g., "abc12345")
    Name         string          // Human-readable name
    Context      string          // URL path for routing (e.g., "/petstore/v1")
    Version      string          // API version (e.g., "1.0", "2.0")
    BackendURL   string          // Target backend URL
    Status       LifecycleStatus // Current state in the machine
    AllowedTiers []string        // Subscription tiers (Bronze, Silver, Gold, Unlimited)
    CreatedAt    time.Time       // Timestamp
}
```

**Key insight:** The `Context` is what the Gateway uses to route requests. Two APIs with the same context cannot both be PUBLISHED (enforced by the CP and/or CP-to-GW sync logic).

### Concurrency: `sync.RWMutex` over In-Memory Map

The CP registry stores APIs in memory (in this lab; production uses a database). To make it safe for concurrent HTTP handlers, we use a reader-writer mutex:

```go
type Registry struct {
    mu   sync.RWMutex
    apis map[string]*API
}
```

**Rules:**
- **For reads** (e.g., `GET /apis/{id}`): Use `mu.RLock()` and `defer mu.RUnlock()`. Multiple readers can hold the lock simultaneously.
- **For writes** (e.g., `POST /apis` to insert a new API): Use `mu.Lock()` and `defer mu.Unlock()`. Only one writer can hold the lock.

If you use `RLock()` for a write operation, you'll corrupt the map. If you forget the lock entirely, concurrent requests will cause data races.

### Lifecycle Endpoint Validation

When a client sends `POST /apis/{id}/lifecycle` with `{"action":"Publish"}`, the handler:

1. Looks up the API by ID.
2. Checks that the current status has a valid transition to the target status.
3. **For Publish only:** checks that `AllowedTiers` is non-empty (cannot publish without subscription options).
4. Updates the status.
5. Returns the updated API object.

If the transition is invalid, the handler returns `400 Bad Request` with an error message like `"invalid transition: CREATED → RETIRED"`.

### ID Generation

The lab uses `rand.Uint32()` to generate IDs:

```go
func newID() string { return fmt.Sprintf("%08x", rand.Uint32()) }
```

This generates an 8-character hex string (0x00000000 to 0xFFFFFFFF). **In production**, this is **not safe** because collisions are possible under high load. Production uses UUIDs or cryptographic randomness. But for this lab, it's sufficient and keeps the code simple.

## Exercises

### Exercise 1: Add a Partial Update Endpoint
**Q:** Add a `PUT /apis/{id}` endpoint that updates the Name and BackendURL fields, but not Status or Context.

**Hint:** Read the request body into a patch struct with only `Name` and `BackendURL` fields. Inside the locked section, only overwrite fields that are non-empty in the patch.

**Solution sketch:**
```go
// Handler for PUT /apis/{id}
func (r *Registry) updateAPI(w http.ResponseWriter, id string, req *http.Request) {
    var body struct {
        Name       string `json:"name"`
        BackendURL string `json:"backendUrl"`
    }
    if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
        http.Error(w, "bad request", http.StatusBadRequest)
        return
    }
    
    r.mu.Lock()
    defer r.mu.Unlock()
    api, ok := r.apis[id]
    if !ok {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    
    if body.Name != "" {
        api.Name = body.Name
    }
    if body.BackendURL != "" {
        api.BackendURL = body.BackendURL
    }
    
    writeJSON(w, http.StatusOK, api)
}
```

### Exercise 2: HTTP Status Code for Invalid Transition
**Q:** What HTTP status code should `POST /apis/{id}/lifecycle` return when the transition is invalid (e.g., trying to go from CREATED directly to RETIRED)?

**Hint:** Think about the difference between a client error and a server error. Is the request malformed, or is the client asking for something that violates business logic?

**Solution sketch:**
```
Return 400 Bad Request.

This is a client error because the client is asking for an invalid state transition.
It's not a 404 (resource not found), not a 409 (conflict), and not a 500 (server error).
400 says: "Your request is invalid according to our business rules."

The response body should include a message:
  {"error":"invalid transition: CREATED → RETIRED"}
```

### Exercise 3: Concurrency and Mutex Usage
**Q:** Two goroutines call `POST /apis` concurrently to create two different APIs. Why is `sync.RWMutex` not enough for the write path? What specifically could go wrong if you used `RLock()` instead of `Lock()`?

**Hint:** Think about what `RLock()` allows — multiple readers, or mutual exclusion? What does the Go spec say about concurrent map writes?

**Solution sketch:**
```
RLock() (reader lock) allows multiple concurrent readers, but does NOT prevent concurrent writers.

If two goroutines both called r.mu.RLock() and then tried to write to the map:
  - Goroutine 1: r.apis[newID()] = api1
  - Goroutine 2: r.apis[newID()] = api2

The Go runtime would panic: "fatal error: concurrent map write"

Maps in Go are not concurrency-safe for writes. You MUST use Lock() (exclusive writer lock)
for the write path. The code in the lab is correct because createAPI uses mu.Lock().

The difference:
  - RLock: Multiple readers, no writers. Good for GET endpoints.
  - Lock: One writer, no readers. Required for POST/PUT/DELETE endpoints.
```

## Anti-Patterns to Avoid

1. **Using a plain `map` without a mutex** — Concurrent HTTP handlers will cause data races and panic. Always use `sync.RWMutex` when sharing a map across goroutines.

2. **Returning the old status before updating** — If a handler updates an API and returns the old object (before the update), clients see stale data. Always read the updated object from the map and return it.

3. **Generating IDs with `time.Now().UnixNano()`** — Collisions are possible under load. Use `crypto/rand` for cryptographic randomness, or a UUID library.

4. **Forgetting to defer Unlock()** — If you lock the mutex but don't defer the unlock, and the handler panics or returns early, the lock stays held and all other requests block indefinitely. Always use `defer mu.Unlock()`.

5. **Holding the lock for too long** — If you're doing expensive I/O (e.g., calling an external service) while holding the lock, all other requests block. Lock only while accessing the shared map.

## What You'll Build

Your lab will create a running HTTP server that:

- Listens on `:8082`
- Accepts `POST /apis` to create an API in CREATED state
- Accepts `GET /apis` to list all APIs
- Accepts `GET /apis/{id}` to fetch one API
- Accepts `DELETE /apis/{id}` to remove an API
- Accepts `POST /apis/{id}/lifecycle` to transition the state
- Validates the state machine before any transition
- Rejects publishing without allowed tiers
- Returns `400 Bad Request` for invalid transitions
- Uses `sync.RWMutex` to safely handle concurrent requests

## Next Steps

Tomorrow (Day 33), you'll extend this registry with tier and policy management. You'll add `GET /apis/{id}/policies` to return subscription tier descriptions, and `PUT /apis/{id}/tiers` to update which tiers are allowed for an API. You'll also learn why you can't change tiers while an API is PUBLISHED (you have to deprecate it first).
