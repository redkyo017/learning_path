# Day 50 — Go APIHandler Chain Extension Blueprint

## Why This Matters

Day 49 introduced the WSO2 APIHandler interface: a chain of request/response interceptors. Building that chain from scratch in Go lets you:

1. **Understand the pattern without Java/OSGi/Axis2 complexity:** The handler chain is a universal pattern used in HTTP middleware everywhere (Express, Django, Rack, etc.). Implementing it in Go shows the core mechanics.

2. **Prototype extensions before integrating with WSO2:** Design a custom validation handler in Go, test it locally, then translate to Java for production deployment. Lower risk, faster iteration.

3. **Build the mental model for Day 51's token endpoint:** Both use the same dispatch pattern (iterate handlers, first match wins). You'll see the same concepts applied to OAuth2.

4. **Extend your platform's edge layer:** If you're not ready to customize WSO2 itself, you can run Go handlers in front of WSO2 (as a reverse proxy chain). This Go blueprint is production-ready for that use case.

---

## Core Concept: The Handler Chain

### APIHandler Interface

```go
type APIHandler interface {
    HandleRequest(ctx *MessageContext) bool
    HandleResponse(ctx *MessageContext) bool
    Name() string
}
```

**Semantics (same as WSO2):**

- **`HandleRequest(ctx) bool`**
  - Called for each request, in chain order
  - Returns `true` → continue to next handler and backend
  - Returns `false` → stop chain, response already written by this handler
  - Use for: validation, authentication, logging, request modification

- **`HandleResponse(ctx) bool`**
  - Called after backend responds, in **reverse chain order**
  - Always called (even if `HandleRequest` returned `false` on another handler, that handler's response doesn't run)
  - Access same `MessageContext` as `HandleRequest`
  - Use for: latency tracking, response logging, cache population

- **`Name() string`**
  - Returns unique handler identifier (e.g., "RequestLogger", "APIKeyCheck")
  - Used for logging and debugging

### MessageContext

```go
type MessageContext struct {
    Request    *http.Request
    Writer     http.ResponseWriter
    Properties map[string]any
}
```

The context carries:
- **Request:** The incoming HTTP request (headers, body, URL)
- **Writer:** The response writer (set headers, write body, set status)
- **Properties:** Key-value map for inter-handler communication

Each handler can read/write properties:

```go
// RequestLogHandler writes to Properties
ctx.Properties["reqStart"] = time.Now()

// LatencyTrackerHandler reads from Properties
if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
    elapsed := time.Since(start)
    // log elapsed
}
```

This allows handlers to coordinate without tight coupling.

### HandlerChain and ServeHTTP

```go
type HandlerChain struct {
    handlers []APIHandler
    backend  *httputil.ReverseProxy
}

func (c *HandlerChain) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    ctx := &MessageContext{Request: r, Writer: w, Properties: make(map[string]any)}
    
    // Request phase (forward order)
    for _, h := range c.handlers {
        if !h.HandleRequest(ctx) {
            return  // Chain short-circuited; response already sent
        }
    }
    
    // Backend call
    c.backend.ServeHTTP(w, r)
    
    // Response phase (reverse order)
    for i := len(c.handlers) - 1; i >= 0; i-- {
        c.handlers[i].HandleResponse(ctx)
    }
}
```

**Flow example with 3 handlers:**

```
Request:  H1.HandleRequest() → H2.HandleRequest() → H3.HandleRequest() → backend.call()
Response: H3.HandleResponse() → H2.HandleResponse() → H1.HandleResponse() → client
```

---

## Example Handlers

### 1. RequestLogHandler

Simple logging of every request:

```go
type RequestLogHandler struct{}

func (h *RequestLogHandler) Name() string { return "RequestLogger" }
func (h *RequestLogHandler) HandleRequest(ctx *MessageContext) bool {
    slog.Info("request", "method", ctx.Request.Method, "path", ctx.Request.URL.Path)
    return true  // Always continue
}
func (h *RequestLogHandler) HandleResponse(ctx *MessageContext) bool { return true }
```

Used for: audit trails, debugging, request counting.

### 2. APIKeyCheckHandler

Validate API key and set tier in context:

```go
type APIKeyCheckHandler struct {
    validKeys map[string]string // key → tier
}

func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
    key := ctx.Request.Header.Get("X-API-Key")
    tier, ok := h.validKeys[key]
    if !ok {
        ctx.Writer.Header().Set("Content-Type", "application/json")
        ctx.Writer.WriteHeader(http.StatusUnauthorized)
        json.NewEncoder(ctx.Writer).Encode(map[string]string{
            "code": "900901", "message": "Invalid Credentials",
        })
        return false  // Stop chain
    }
    ctx.Properties["tier"] = tier  // Share with downstream handlers
    return true  // Continue
}
func (h *APIKeyCheckHandler) HandleResponse(ctx *MessageContext) bool { return true }
```

Used for: API key validation, access control.

**Key points:**
- Read header
- Check against valid keys map
- On failure: set status (401), write error JSON, return `false`
- On success: set property, return `true`

### 3. LatencyTrackerHandler

Measure backend latency:

```go
type LatencyTrackerHandler struct{}

func (h *LatencyTrackerHandler) HandleRequest(ctx *MessageContext) bool {
    ctx.Properties["reqStart"] = time.Now()
    return true
}
func (h *LatencyTrackerHandler) HandleResponse(ctx *MessageContext) bool {
    if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
        elapsed := time.Since(start)
        slog.Info("latency", "ms", elapsed.Milliseconds(),
            "path", ctx.Request.URL.Path, "tier", ctx.Properties["tier"])
    }
    return true
}
```

Used for: observability, SLO tracking, performance monitoring.

**Key points:**
- Record start time in `HandleRequest`
- Calculate elapsed in `HandleResponse` (after backend call)
- Read properties from prior handlers (e.g., `tier`)

---

## Running the Lab

```bash
cd labs/phase4/day50
go run main.go
```

Output:
```
Go APIHandler extension blueprint on :8090
Test: curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get
Test 401: curl http://localhost:8090/get
```

**Test 1: Valid key (200)**
```bash
curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get
```

Expected: HTTP 200, response from httpbin.org's `/get` endpoint, logs show:
```
request method=GET path=/get
latency ms=<X> path=/get tier=Gold
```

**Test 2: Missing key (401)**
```bash
curl http://localhost:8090/get
```

Expected: HTTP 401, error JSON:
```json
{"code":"900901","message":"Invalid Credentials"}
```

Logs show request but NO latency (chain short-circuited).

---

## Design Patterns in This Blueprint

### 1. Fluent Builder Pattern

```go
chain := NewHandlerChain("http://httpbin.org")
chain.Add(&RequestLogHandler{}).
      Add(NewAPIKeyCheckHandler()).
      Add(&LatencyTrackerHandler{})
```

`Add()` returns `*HandlerChain`, allowing method chaining. Makes the setup readable and extensible.

### 2. Stateless vs. Stateful Handlers

**Stateless (RequestLogHandler):**
- No fields, just methods
- Safe for concurrent requests (no shared state to corrupt)
- Simplest pattern

**Stateful read-only (APIKeyCheckHandler):**
- `validKeys` map is populated once in constructor
- Never modified after that
- Safe for concurrent requests (concurrent reads of map with no writes are safe in Go)

**Stateful mutable (would be RateLimitHandler):**
- Maintains a map of request counts per key
- Requires synchronization (`sync.Mutex`) to protect concurrent writes

### 3. Context Properties for Loose Coupling

Handlers communicate via `ctx.Properties` instead of direct method calls:

```go
// RequestLogHandler could set
ctx.Properties["clientIP"] = r.RemoteAddr

// APIKeyCheckHandler sets
ctx.Properties["tier"] = tier

// LatencyTrackerHandler reads both
tier := ctx.Properties["tier"]
ip := ctx.Properties["clientIP"]
```

This allows you to add a new handler without modifying existing ones. If LatencyTrackerHandler didn't know about "tier", it would just not find the property (no error).

---

## Comparison to WSO2 APIHandler

| Aspect | WSO2 (Java) | Go Blueprint |
|--------|-------------|-------------|
| **Chain order** | Sorted by priority (ascending) | Order of `.Add()` calls |
| **Shared state** | Handler instance shared → must synchronize | HTTP request goroutines → can use sync.Mutex |
| **Short-circuiting** | `return false` | `return false` |
| **Response handling** | `handleResponse()` always called | `HandleResponse()` always called |
| **Context** | `MessageContext` with Axis2 internals | Simple struct with Properties map |
| **Configuration** | XML `api-handlers.xml` | Go code |
| **Loading** | OSGi bundles on classpath | Imported packages, instantiated in code |

---

## Exercises

### Exercise 1: Implement RateLimitHandler

**Question:**
Add a `RateLimitHandler` that allows 5 requests per minute per API key. Track request times in a sliding window. If the limit is exceeded, return 429 (Too Many Requests).

**Hint:**
- Maintain a map `map[string][]time.Time` keyed by API key
- In `HandleRequest`, get the key from header (same as APIKeyCheckHandler)
- Discard timestamps older than 1 minute
- If remaining timestamps count >= 5, return 429; otherwise append current time and return `true`
- Use `sync.RWMutex` to protect concurrent map access

**Solution sketch:**

```go
type RateLimitHandler struct {
    mu   sync.RWMutex
    hits map[string][]time.Time
}

func NewRateLimitHandler() *RateLimitHandler {
    return &RateLimitHandler{hits: make(map[string][]time.Time)}
}

func (h *RateLimitHandler) Name() string { return "RateLimit" }

func (h *RateLimitHandler) HandleRequest(ctx *MessageContext) bool {
    key := ctx.Request.Header.Get("X-API-Key")
    if key == "" {
        return true  // No key, skip rate limit
    }

    h.mu.Lock()
    defer h.mu.Unlock()

    now := time.Now()
    window := []time.Time{}
    
    // Slide window: keep only recent timestamps
    for _, t := range h.hits[key] {
        if now.Sub(t) < time.Minute {
            window = append(window, t)
        }
    }
    
    // Check limit
    if len(window) >= 5 {
        ctx.Writer.Header().Set("Content-Type", "application/json")
        ctx.Writer.WriteHeader(http.StatusTooManyRequests)
        json.NewEncoder(ctx.Writer).Encode(map[string]string{
            "error": "rate_limit_exceeded",
            "limit": "5 requests per minute",
        })
        return false
    }
    
    // Add current request
    window = append(window, now)
    h.hits[key] = window
    return true
}

func (h *RateLimitHandler) HandleResponse(ctx *MessageContext) bool { return true }
```

**Usage:**

```go
chain := NewHandlerChain("http://httpbin.org")
chain.Add(&RequestLogHandler{})
chain.Add(NewAPIKeyCheckHandler())
chain.Add(NewRateLimitHandler())     // Add rate limiter
chain.Add(&LatencyTrackerHandler{})
```

---

### Exercise 2: Why is LatencyTrackerHandler Placed Last?

**Question:**
In the lab, `LatencyTrackerHandler` is added last (so it's placed last in the request chain but runs first in the response chain). Why this position?

**Hint:**
Think about what it measures: backend latency vs. pipeline latency.

**Solution sketch:**

LatencyTrackerHandler placed last ensures accurate **backend latency**:

1. **Request flow (forward):** RequestLogHandler → APIKeyCheckHandler → LatencyTrackerHandler → backend
   - LatencyTrackerHandler's `HandleRequest()` starts timing immediately before the backend call
   - This excludes time spent in logging, validation, etc.

2. **Response flow (reverse):** LatencyTrackerHandler → APIKeyCheckHandler → RequestLogHandler → client
   - LatencyTrackerHandler's `HandleResponse()` stops timing immediately after backend returns
   - This measures only the backend call, not serialization or prior handlers

**Code:**
```go
func (h *LatencyTrackerHandler) HandleRequest(ctx *MessageContext) bool {
    ctx.Properties["reqStart"] = time.Now()  // Start just before backend
    return true
}

func (h *LatencyTrackerHandler) HandleResponse(ctx *MessageContext) bool {
    if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
        elapsed := time.Since(start)  // Stop just after backend
        slog.Info("latency", "ms", elapsed.Milliseconds())
    }
    return true
}
```

**Comparison:**
- If LatencyTrackerHandler was **first** (priority 0), it would measure the entire pipeline (including logging, key validation) → not pure backend latency
- Placed **last**, it measures only backend latency → useful for SLOs

---

### Exercise 3: Is validKeys Map Safe Under Concurrent Requests?

**Question:**
Two concurrent HTTP requests call `APIKeyCheckHandler.HandleRequest()` at the same time. Is the `validKeys` map safe from race conditions?

**Hint:**
Think about Go's concurrency guarantees:
- Concurrent reads of a map are safe
- Concurrent reads AND writes are NOT safe
- `validKeys` is never modified after handler construction

**Solution sketch:**

**Yes, it is safe.**

Reason: `validKeys` is populated once in `NewAPIKeyCheckHandler()` and never written after that. Go's concurrency guarantee is:

> Concurrent reads of a map (with no concurrent writes) are safe.

Code:
```go
func NewAPIKeyCheckHandler() *APIKeyCheckHandler {
    return &APIKeyCheckHandler{validKeys: map[string]string{
        "test-key-gold":   "Gold",
        "test-key-silver": "Silver",
    }}
}
// validKeys is never modified after this

func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
    key := ctx.Request.Header.Get("X-API-Key")
    tier, ok := h.validKeys[key]  // READ-ONLY, concurrent safe
    // ...
}
```

**Anti-pattern (unsafe):**
```go
// WRONG
func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
    key := ctx.Request.Header.Get("X-API-Key")
    tier, ok := h.validKeys[key]
    if ok {
        h.validKeys[key] = "used-once"  // WRITE during HandleRequest
        // This races with other goroutines reading the map!
    }
    return true
}
```

**Takeaway:** For read-only handler configuration (like API keys, tiers, permissions), no synchronization needed. For mutable state (like RateLimitHandler's hit counts), use `sync.Mutex`.

---

## Next Steps

1. **Complete the lab:** `go run main.go`, test both endpoints
2. **Implement Exercise 1:** Add RateLimitHandler
3. **Compare to Day 49:** How does this Go chain relate to WSO2's `APIHandler` interface?
4. **Preview Day 51:** The same dispatch pattern (check, validate, execute) applies to OAuth2 grant handlers
