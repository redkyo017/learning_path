# Day 18: Complete Gateway Skeleton — Reverse Proxy + Middleware Chain + Graceful Shutdown

## Why

Days 16–17 gave you the theory (WSO2 handler chain) and the building blocks (reverse proxy +
middleware pattern). Today you assemble a production-shaped Go gateway skeleton: recovery
middleware, a health check, graceful shutdown, and a built-in mock backend so you can test
the whole flow without an external server.

This skeleton is the base that subsequent days extend with JWT validation, throttling, and
analytics — mirroring the WSO2 handler chain you read in Day 16.

---

## WSO2 Source Reading

WSO2 API Manager exposes a health check at:

```
GET /services/Version
```

This endpoint is used by load balancers and Kubernetes liveness probes to verify the GW
process is alive. It returns an XML body with the product version. Your Go gateway exposes
`GET /health` returning `{"status":"UP"}` — functionally equivalent, JSON-native.

---

## Core Concepts

### Request Flow

```
Client Request
      │
      ▼
mux.Handle("/", Chain(proxy, requestIDMiddleware, loggingMiddleware, recoveryMiddleware))
      │  (middleware chain runs first)
      ▼
requestIDMiddleware  ← assigns X-Request-ID if missing
      │
      ▼
loggingMiddleware    ← records start time; logs after response returns
      │
      ▼
recoveryMiddleware   ← wraps next in defer/recover; returns 500 JSON on panic
      │
      ▼
ReverseProxy (Director sets activityid)
      │
      ▼
Backend (or mock backend on :8080)
```

`/health` is registered directly on the mux, bypassing the middleware chain — healthchecks
should never fail due to backend connectivity issues.

### Recovery Middleware

Panics in HTTP handlers silently drop the connection unless you catch them. A recovery
middleware wraps the next handler in a `defer`:

```go
func recoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                slog.Error("panic recovered", "error", rec)
                w.Header().Set("Content-Type", "application/json")
                w.WriteHeader(http.StatusInternalServerError)
                fmt.Fprint(w, `{"error":"internal_server_error"}`)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

Key detail: `defer` runs even when `next.ServeHTTP` panics. The `recover()` call inside a
deferred function is the only mechanism that stops a goroutine panic from crashing the
process.

### Graceful Shutdown and ECS Fargate

`http.Server.Shutdown(ctx)` stops accepting new connections and waits for active requests to
finish before returning. Why this matters in **ECS Fargate**:

1. When ECS stops a task (deploy, scaling, health failure), it sends **SIGTERM** to the
   container's PID 1.
2. Fargate waits up to **30 seconds** (configurable `stopTimeout`) before sending **SIGKILL**
   which terminates the process unconditionally.
3. If your server just exits on SIGTERM, any in-flight requests are killed mid-response —
   clients see connection resets, broken downloads, or half-written database transactions.

Graceful shutdown drains those connections within the 30-second window:

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
defer stop()

go func() { srv.ListenAndServe() }()

<-ctx.Done()          // SIGTERM/Ctrl+C received
stop()                // allow signal to be received again if needed

shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
srv.Shutdown(shutCtx) // drain in-flight requests; 5s < 30s Fargate window
```

### Built-in Mock Backend

Instead of requiring an external server for testing, the skeleton starts a mock backend
on `:8080` in the same process. `BACKEND_URL` defaults to `http://localhost:8080`.
The mock handles any path under `/mock` and returns a JSON response. This lets you run
a full gateway → backend round-trip with zero external dependencies.

---

## Lab

See `labs/phase2/day18/` — complete gateway skeleton with mock backend.

```bash
go run main.go
# In another terminal:
curl http://localhost:9090/health
curl http://localhost:9090/mock/test
# Send Ctrl+C to the gateway — observe "shutdown complete" log
```

---

## Exercises

**Exercise 1:** Add a recovery middleware that catches panics and returns a 500 JSON response.

**Hint:** Use `defer func() { if r := recover(); r != nil { ... } }()` inside the returned
`http.HandlerFunc`. Set `Content-Type: application/json` before calling `WriteHeader`.

**Solution sketch:**

```go
func recoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                slog.Error("panic recovered", "error", rec)
                w.Header().Set("Content-Type", "application/json")
                w.WriteHeader(http.StatusInternalServerError)
                fmt.Fprint(w, `{"error":"internal_server_error"}`)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

---

**Exercise 2:** In the `ReverseProxy.Director`, add the `activityid` header to every
upstream request using the value from `X-Request-ID`.

**Hint:** `requestIDMiddleware` sets `X-Request-ID` before `Director` runs (the Director
runs inside the proxy, which is the innermost handler). The request object passed to
`Director` is the same one the middleware chain modified.

**Solution sketch:**

```go
proxy.Director = func(req *http.Request) {
    original(req)
    req.Host = u.Host
    req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
}
```

---

**Exercise 3:** Implement graceful shutdown so the server drains in-flight requests
within 5 seconds on SIGTERM (or Ctrl+C).

**Hint:** Use `signal.NotifyContext(context.Background(), os.Interrupt)` to get a context
that cancels on SIGTERM. Block on `<-ctx.Done()`, then call `srv.Shutdown` with a 5-second
timeout context.

**Solution sketch:**

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
defer stop()

go func() {
    if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        slog.Error("server error", "err", err)
    }
}()

<-ctx.Done()
slog.Info("shutdown signal received")
shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
if err := srv.Shutdown(shutCtx); err != nil {
    slog.Error("shutdown error", "err", err)
}
slog.Info("shutdown complete")
```

---

## Anti-patterns

- **Recovery middleware placed outermost** — If recovery is `m1` in `Chain(proxy, m1, m2,
  m3)` it never catches panics in m2 or m3. Place recovery **innermost** (last in the
  variadic list) so it wraps the proxy directly and catches panics anywhere inside the chain.
  Wait — actually the opposite: the innermost middleware (closest to the handler) sees panics
  that unwind through it. With `Chain(proxy, requestID, logging, recovery)`, execution is
  `requestID → logging → recovery → proxy`. A panic in the proxy unwinds through `recovery`
  first. So recovery should be **last** in the variadic list.

- **Not setting Content-Type before WriteHeader in recovery** — Once `WriteHeader` is called
  the headers are sent. Set `Content-Type: application/json` first, then `WriteHeader(500)`,
  then write the body.

- **Ignoring `srv.Shutdown` error** — `Shutdown` returns an error if the context deadline
  exceeds before all connections drain. Log it; do not silently discard it.

---

## Teardown

Stop the gateway with `Ctrl+C`. Both the gateway server and mock backend server stop
together (they share the same process). No containers to remove.
