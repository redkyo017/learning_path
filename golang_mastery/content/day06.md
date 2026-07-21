# Day 6 — net/http Deep Dive

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Articulate the `http.Handler` interface and why a single method is enough to build the entire Go HTTP ecosystem
- Explain what `http.HandlerFunc` does and when to use it over implementing a struct
- Describe the five phases of a Go HTTP request lifecycle
- Build a middleware wrapper by hand without reaching for a framework
- Configure `http.Server` with timeouts and understand why the zero value is production-dangerous

---

## Core mental model: One interface, infinite composition

`http.Handler` is an interface with exactly one method:

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}
```

That's the entire contract. Every router, every framework, every middleware library in the Go ecosystem satisfies this one interface. The Go HTTP server calls `ServeHTTP` and does nothing else. Once you internalize this, you can read any Go HTTP code — whether it's stdlib, Gin, Chi, or Echo — and immediately locate where the request goes.

The analogy: think of `http.Handler` as a Unix pipe stage. Each stage receives bytes (a request) and emits bytes (a response). You can chain stages by wrapping one handler inside another. The outermost wrapper is what the server calls; it decides whether to call the inner handler or not. This is how middleware works — it is not magic, it is not a framework concept, it is just function composition over a single-method interface.

The second key piece is `http.HandlerFunc`, a named function type that implements `Handler` automatically:

```go
type HandlerFunc func(ResponseWriter, *Request)

func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) { f(w, r) }
```

This is the adapter pattern. Any function with the right signature becomes a `Handler` with a single cast. You will see this constantly in idiomatic Go HTTP code — it lets you avoid defining a struct just to satisfy an interface.

---

## The http.Handler interface in detail

Every `http.Handler` receives two arguments:

| Argument | Type | What it is |
|---|---|---|
| `w` | `http.ResponseWriter` | The outbound channel — write headers and body here |
| `r` | `*http.Request` | The inbound channel — URL, headers, body, context |

`ResponseWriter` is itself an interface:

```go
type ResponseWriter interface {
    Header() http.Header       // set response headers BEFORE WriteHeader
    WriteHeader(statusCode int) // send status line — only once, first write wins
    Write([]byte) (int, error) // write body bytes
}
```

Critical rule: once you call `Write`, the status code is committed. If you haven't called `WriteHeader` yet, Go implicitly sends `200 OK`. This is a common source of bugs when handlers try to set headers after writing the body.

---

## http.HandlerFunc: the adapter in practice

```go
// A plain function — not yet a Handler
func greet(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintln(w, "hello")
}

// Adapt it with a cast — now it satisfies http.Handler
http.Handle("/greet", http.HandlerFunc(greet))

// http.HandleFunc is syntactic sugar that does the cast for you
http.HandleFunc("/greet", greet)
```

When you write middleware, you return an `http.Handler` that wraps another `http.Handler`. `HandlerFunc` makes the closure easy to return:

```go
func logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}
```

---

## ServeMux and its limitations

`http.DefaultServeMux` (and `http.NewServeMux()`) is Go's built-in router. It matches by longest path prefix. It works for simple APIs but has real limitations you need to know before reaching for a third-party router:

| Feature | stdlib ServeMux | Third-party (Chi, Gin) |
|---|---|---|
| Path parameters (`/users/:id`) | Not supported | Supported |
| Method-based routing (`GET` vs `POST`) | Not supported | Supported |
| Regex routes | Not supported | Supported |
| Trailing-slash redirect | Automatic | Configurable |
| Performance (trie vs map) | O(n) scan | O(log n) trie |

Go 1.22 (released February 2024) significantly upgraded `http.ServeMux` — this is your biggest gap.

---

## Middleware as handler wrappers

The pattern is: a function that takes a `Handler` and returns a `Handler`. You wrap behavior around the inner handler:

```
Request → [middleware A] → [middleware B] → [handler] → [middleware B] → [middleware A] → Response
```

Middleware runs before and after the inner call. Code before `next.ServeHTTP(w, r)` is pre-processing; code after is post-processing. This is how you build auth, logging, metrics, compression, and CORS — all as independent, composable wrappers.

To compose a chain manually:

```go
// innermost handler first, outermost last
handler := logging(auth(compress(myHandler)))
```

---

## Request lifecycle: five phases

1. **Accept** — `net.Listener` accepts a TCP connection; the server spawns a goroutine per connection
2. **Parse** — HTTP/1.1 or HTTP/2 framing is decoded; `http.Request` is populated
3. **Route** — `ServeMux.ServeHTTP` matches the path and delegates to the registered handler
4. **Handle** — Your handler (and its middleware chain) runs in the goroutine
5. **Flush** — The response writer buffers bytes and flushes to the TCP connection; the goroutine exits

Each connection gets its own goroutine. This is Go's concurrency model applied directly to HTTP: cheap goroutines absorb concurrency without a thread pool. The implication: shared state in handlers must be goroutine-safe (use `sync.Mutex`, channels, or atomic ops).

---

## http.Server configuration

The zero value `http.Server{}` is production-dangerous. Without timeouts, a slow or malicious client can hold a goroutine forever:

```go
srv := &http.Server{
    Addr:         ":8080",
    Handler:      myRouter,
    ReadTimeout:  5 * time.Second,   // time to read entire request including body
    WriteTimeout: 10 * time.Second,  // time to write the response
    IdleTimeout:  120 * time.Second, // keep-alive connection idle limit
    ReadHeaderTimeout: 2 * time.Second, // just the header (Go 1.8+)
}
```

| Timeout | What it guards against |
|---|---|
| `ReadTimeout` | Slow-body upload attacks (Slowloris body variant) |
| `ReadHeaderTimeout` | Slowloris header attacks |
| `WriteTimeout` | Handler running too long; slow downstream client |
| `IdleTimeout` | Keep-alive connections consuming goroutines |

Always set `ReadHeaderTimeout` explicitly — `ReadTimeout` alone does not protect against header attacks in all configurations.

---

## Returning engineer: what changed since 1.16–1.18

**Go 1.22 (February 2024)** is the biggest change to `net/http` in years:

- `http.ServeMux` now supports **method routing** and **path wildcards**: `GET /users/{id}` is valid stdlib routing syntax
- Path parameters are extracted via `r.PathValue("id")` — no third-party router needed for simple APIs
- Trailing slash matching semantics changed — existing code that relied on redirect behavior may need review

**Go 1.20**: `http.ResponseController` was added — a concrete type wrapping `ResponseWriter` that provides `Flush()`, `Hijack()`, and deadline control, replacing the ugly type-assertion pattern:

```go
// Old (pre-1.20)
if flusher, ok := w.(http.Flusher); ok { flusher.Flush() }

// New (1.20+)
rc := http.NewResponseController(w)
rc.Flush()
```

**Go 1.21**: `log/slog` became the standard structured logger — you will see `slog` in production middleware now instead of `logrus` or `zap` in newer codebases.

---

## Key concepts to memorize
- `http.Handler` has one method: `ServeHTTP(ResponseWriter, *Request)`
- `http.HandlerFunc` is a function type that implements `http.Handler` via an adapter method
- `http.HandleFunc` is a convenience wrapper that casts for you — it is not the same as `http.HandlerFunc`
- Calling `Write` before `WriteHeader` implicitly sends `200 OK` — the status is then committed
- Middleware wraps handlers: code before `next.ServeHTTP` is pre-processing, code after is post-processing
- Never use `http.ListenAndServe` in production — it creates a zero-value `http.Server` with no timeouts
- Go 1.22 added method routing and `{wildcard}` params to stdlib `ServeMux`

---

## Common mistakes

**1. Writing headers after the body**
Calling `w.Header().Set(...)` after `w.Write(...)` is a no-op and Go logs a warning. Always set headers first, then write the body. Set `Content-Type` explicitly — Go sniffs it from the first 512 bytes only if you don't.

**2. Calling `http.ListenAndServe` directly**
`http.ListenAndServe(":8080", nil)` uses `DefaultServeMux` and a zero-timeout server. In production, construct `http.Server` explicitly with all four timeouts set.

**3. Forgetting that ServeMux is global**
`http.HandleFunc` registers on `DefaultServeMux`, which is a package-level global. Tests that call `http.HandleFunc` pollute the global state across test cases. Always use `http.NewServeMux()` in production code and pass it to your server.

**4. Not reading the request body**
If a handler does not read `r.Body` fully and close it, the underlying TCP connection may not be reused. Always `defer r.Body.Close()` and either read it or discard with `io.Discard` if unused:
```go
defer io.Copy(io.Discard, r.Body)
defer r.Body.Close()
```

**5. Ignoring `r.Context()` cancellation**
Long-running handlers should check `r.Context().Done()`. If the client disconnects, Go cancels the request context — handlers that ignore this waste goroutines doing work nobody will read.

---

## Check your understanding

1. What is the minimum interface a type must satisfy to act as an HTTP handler in Go? Write the method signature from memory.
2. `http.HandleFunc("/path", myFunc)` and `http.Handle("/path", http.HandlerFunc(myFunc))` — are these equivalent? What does each do under the hood?
3. You add a `w.Header().Set("X-Request-ID", id)` call in your handler, but the header never appears in the response. What is the most likely cause, and how do you fix it?
