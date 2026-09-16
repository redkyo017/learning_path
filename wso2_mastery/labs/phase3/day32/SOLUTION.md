# Day 32 — Solution Guide

## Exercise 1 Solution: Partial Update Endpoint

Add the following method to the `Registry` type:

```go
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

Then add to the mux handler (inside the `/apis/` catch-all, after extracting `id`):

```go
if len(parts) == 2 && req.Method == http.MethodPut {
	reg.updateAPI(w, id, req)
	return
}
```

Test it:

```bash
# First, create an API
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{"name":"OldName","context":"/test/v1","version":"1.0","backendUrl":"http://old:9000","allowedTiers":["Gold"]}' | jq .

# Copy the ID, then update it
curl -s -X PUT http://localhost:8082/apis/{id} \
  -H 'Content-Type: application/json' \
  -d '{"name":"NewName","backendUrl":"http://new:9000"}' | jq .
```

**Expected output:**
```json
{
  "id":"...",
  "name":"NewName",
  "context":"/test/v1",  // unchanged
  "version":"1.0",
  "backendUrl":"http://new:9000",
  "status":"CREATED",    // unchanged
  "allowedTiers":["Gold"],
  "createdAt":"..."
}
```

**Key points:**
- Only the provided fields are updated
- Fields that are empty strings are skipped (not cleared)
- Status and Context are immutable (not overwritten even if provided)
- The updated API is returned to the client

## Exercise 2 Solution: HTTP Status Code

The registry returns **`400 Bad Request`** for invalid transitions.

**Why 400?**

The HTTP status code `400 Bad Request` is used when the request violates the server's business rules or constraints. In this case:

- The API exists (not a 404)
- The request is well-formed (not a 400 for syntax reasons)
- But the requested state transition is invalid according to the state machine

Other possible codes:
- `409 Conflict` — also valid; means "the current state of the resource conflicts with your requested change"
- `422 Unprocessable Entity` — also valid; means "the request is well-formed but semantically invalid"

But `400` is the most common and most direct: "Your request violates our business rules."

**Evidence from the code:**

```go
if !valid {
    http.Error(w, fmt.Sprintf(`{"error":"invalid transition: %s → %s"}`, api.Status, target), http.StatusBadRequest)
    return
}
```

## Exercise 3 Solution: Concurrency and Defer

### Why `defer r.mu.Unlock()`?

The `defer` statement ensures that `Unlock()` is called when the function exits, **no matter what**:
- If the function returns normally
- If the function panics
- If an early return is executed

### What Happens Without Defer?

Consider this (buggy) code:

```go
func (r *Registry) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
    // ... decode and validate ...
    r.mu.Lock()
    api, ok := r.apis[id]
    if !ok {
        r.mu.Unlock()  // Have to manually unlock
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    // ... more logic ...
    panic("oops!")  // Forgot to unlock before panicking!
    r.mu.Unlock()    // Never reached
}
```

If a panic occurs, the lock is never released. All other goroutines (HTTP handlers) block indefinitely trying to acquire the same lock. The server becomes unresponsive.

### With Defer (Correct)

```go
func (r *Registry) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
    // ... decode and validate ...
    r.mu.Lock()
    defer r.mu.Unlock()  // Guaranteed to unlock
    api, ok := r.apis[id]
    if !ok {
        http.Error(w, "not found", http.StatusNotFound)
        return  // Unlock is still called
    }
    // ... more logic ...
    panic("oops!")  // Unlock is still called
}
```

The `defer` ensures the lock is released in all cases.

### Test It

Try modifying `transitionLifecycle` to panic:

```go
if body.Action == "Publish" && len(api.AllowedTiers) == 0 {
    panic("TESTING DEFER")  // Add this
    // ... rest of code ...
}
```

Without defer:
- The panic propagates
- The lock stays held
- The next request blocks forever
- You have to kill the server

With defer:
- The panic propagates
- The lock is released
- The next request proceeds normally
- (Though the panic is still logged)

## Key Design Patterns Demonstrated

### 1. State Machine with `validTransitions`

```go
var validTransitions = map[LifecycleStatus][]LifecycleStatus{
    StatusCreated:    {StatusPublished},
    StatusPublished:  {StatusDeprecated},
    StatusDeprecated: {StatusRetired},
}
```

This is the clearest way to express valid state transitions in code. It mirrors the `APILifeCycle.xml` configuration exactly.

### 2. RWMutex for Concurrent Access

```go
r.mu.RLock()    // Multiple readers allowed
list := make([]*API, 0, len(r.apis))
for _, a := range r.apis {
    list = append(list, a)
}
r.mu.RUnlock()
```

For reads, use `RLock()` to allow concurrency. For writes, use `Lock()` to ensure mutual exclusion.

### 3. Validation Before State Transitions

```go
if body.Action == "Publish" && len(api.AllowedTiers) == 0 {
    http.Error(w, `{"error":"cannot publish API with no allowed tiers"}`, http.StatusBadRequest)
    return
}
```

Always validate business rules before making changes. Return clear error messages with appropriate HTTP status codes.

### 4. Type-Safe Status Constants

Using `type LifecycleStatus string` and constants prevents typos and enables the compiler to catch mistakes.

## Common Mistakes and How to Avoid Them

1. **Forgetting to lock before accessing the map** → Use `r.mu.Lock()` or `r.mu.RLock()` for every map access
2. **Using `RLock()` for writes** → Use `Lock()` for any operation that modifies the map
3. **Not deferring unlock** → Always use `defer r.mu.Unlock()` immediately after locking
4. **Holding the lock during I/O** → Do JSON encoding/decoding outside the lock when possible
5. **Returning data without deep copy** → Returning pointers to locked data can lead to race conditions; consider when this is safe

## Production Considerations

- **Persistence:** This lab stores APIs in memory. Production uses a database.
- **Distributed systems:** WSO2 runs multiple CP instances. They need distributed coordination (e.g., Zookeeper, etcd).
- **Event publishing:** This lab only updates local state. Production publishes events to notify the Gateway.
- **Audit logging:** Production logs all state transitions for compliance.
- **Metrics:** Production tracks transition failures, API creation rates, etc.

## What's Next

Tomorrow you'll extend this registry with subscription tier management. You'll learn why you can't change tiers while an API is PUBLISHED, and how the CP and Gateway coordinate tier information.
