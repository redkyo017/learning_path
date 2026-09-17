# Day 50 — Solutions

## Exercise 1: RateLimitHandler (5 requests/minute per API key)

**Concept:** Track request timestamps per key in a sliding window. Discard entries older than 1 minute, then count. If count >= 5, reject with 429; otherwise add current timestamp and continue.

**Solution:**

Add this to `main.go` (before or after LatencyTrackerHandler):

```go
import "sync"

type RateLimitHandler struct {
	mu   sync.RWMutex
	hits map[string][]time.Time // key → timestamps
}

func NewRateLimitHandler() *RateLimitHandler {
	return &RateLimitHandler{hits: make(map[string][]time.Time)}
}

func (h *RateLimitHandler) Name() string { return "RateLimit" }
func (h *RateLimitHandler) HandleRequest(ctx *MessageContext) bool {
	key := ctx.Request.Header.Get("X-API-Key")
	if key == "" {
		return true // no key, skip ratelimit
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	now := time.Now()
	window := []time.Time{}
	
	// Slide the window: discard entries older than 1 minute
	for _, t := range h.hits[key] {
		if now.Sub(t) < time.Minute {
			window = append(window, t)
		}
	}
	
	// Check limit
	if len(window) >= 5 {
		ctx.Writer.Header().Set("Content-Type", "application/json")
		ctx.Writer.WriteHeader(http.StatusTooManyRequests) // 429
		json.NewEncoder(ctx.Writer).Encode(map[string]string{
			"error": "rate_limit_exceeded",
			"limit": "5 requests per minute",
		})
		return false
	}
	
	// Add current request
	window = append(window, now)
	h.hits[key] = window
	ctx.Properties["rateLimitWindow"] = len(window)
	return true
}
func (h *RateLimitHandler) HandleResponse(ctx *MessageContext) bool { return true }
```

**How to use:**

```go
func main() {
	chain := NewHandlerChain("http://httpbin.org")
	chain.Add(&RequestLogHandler{})
	chain.Add(NewAPIKeyCheckHandler())
	chain.Add(NewRateLimitHandler())  // Add after API key check
	chain.Add(&LatencyTrackerHandler{})
	
	fmt.Println("Go APIHandler extension blueprint on :8090")
	http.ListenAndServe(":8090", chain)
}
```

**Test:**

```bash
# First 5 requests succeed (200)
for i in {1..5}; do curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get; done

# 6th request fails (429)
curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get
# Returns: {"error":"rate_limit_exceeded","limit":"5 requests per minute"}

# After 1 minute, the window slides and requests are allowed again
```

**Key points:**
- Use `sync.RWMutex` to protect concurrent map access
- Slide the window by filtering timestamps older than 1 minute
- 429 (Too Many Requests) is the HTTP status for rate limit exceeded
- Store the window size in properties if other handlers need it

---

## Exercise 2: Why LatencyTrackerHandler is placed last in request chain but first in response?

**Explanation:**

Timing needs to capture backend latency only, not the entire pipeline:

1. **Request flow (forward):** RequestLogHandler → APIKeyCheckHandler → LatencyTrackerHandler → backend
   - LatencyTrackerHandler is LAST because it starts timing immediately before the backend call
   - This excludes time spent in validation handlers

2. **Response flow (reverse):** LatencyTrackerHandler → APIKeyCheckHandler → RequestLogHandler → client
   - LatencyTrackerHandler is FIRST (when iterating backward) because it stops timing as soon as backend responds
   - This ensures we measure only backend latency, not response serialization time

**Code reference:**

```go
func (h *LatencyTrackerHandler) HandleRequest(ctx *MessageContext) bool {
	ctx.Properties["reqStart"] = time.Now()  // Start timing
	return true
}

func (h *LatencyTrackerHandler) HandleResponse(ctx *MessageContext) bool {
	if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
		elapsed := time.Since(start)  // Stop timing
		slog.Info("latency", "ms", elapsed.Milliseconds())
	}
	return true
}
```

In `ServeHTTP`:

```go
// Request loop (forward order)
for _, h := range c.handlers {
	if !h.HandleRequest(ctx) { return }
}
c.backend.ServeHTTP(w, r)  // Time between last handler's HandleRequest and here

// Response loop (reverse order) — LatencyTrackerHandler runs first here
for i := len(c.handlers) - 1; i >= 0; i-- {
	c.handlers[i].HandleResponse(ctx)
}
```

Result: The clock starts right before `backend.ServeHTTP()` and stops right after, giving pure backend latency.

---

## Exercise 3: Is validKeys map safe under concurrent requests?

**Answer:** Yes, it is safe.

**Why:**

- `validKeys` is populated once in `NewAPIKeyCheckHandler()` during initialization
- `validKeys` is never written to after that — only read during `HandleRequest()`
- Go's concurrency guarantee: concurrent reads of a map with no concurrent writes are safe
- WSO2's `APIHandler` instances are shared across all requests in a GW instance, so multiple goroutines call the same handler's `HandleRequest()` method concurrently

**Code:**

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
// WRONG — modifying validKeys during HandleRequest
func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
	key := ctx.Request.Header.Get("X-API-Key")
	tier, ok := h.validKeys[key]
	if ok {
		h.validKeys[key] = "used"  // CONCURRENT WRITE — race condition!
	}
	return true
}
```

**Takeaway:** For stateless handler instances (read-only config), no synchronization needed. For mutable state (like RateLimitHandler's `hits` map), use `sync.RWMutex` or `sync.Mutex`.
