# Solution — Lab Day 18

## Recovery Middleware Implementation

```go
func recoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                slog.Error("panic recovered", "error", rec, "path", r.URL.Path)
                w.Header().Set("Content-Type", "application/json")
                w.WriteHeader(http.StatusInternalServerError)
                fmt.Fprint(w, `{"error":"internal_server_error"}`)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

Key points:

1. **`defer` is required.** A panic unwinds the call stack, skipping any non-deferred code.
   Only `defer`red functions run during the unwind. Without `defer`, `recover()` is never
   called and the goroutine crashes.

2. **`recover()` must be called directly inside a deferred function**, not in a helper
   called from a defer. The Go spec states that `recover()` returns the panic value only
   when called directly by a deferred function; otherwise it returns nil.

3. **Set `Content-Type` before `WriteHeader`.** Once `WriteHeader` is called, the response
   headers are sent to the client. Calling `w.Header().Set(...)` after `WriteHeader` is
   silently ignored.

4. **Position in Chain matters.** `recoveryMiddleware` should be the *last* argument to
   `Chain` so it wraps the proxy directly:

   ```go
   Chain(proxy, requestIDMiddleware, loggingMiddleware, recoveryMiddleware)
   // Execution: requestID → logging → recovery → proxy
   // A panic in proxy unwinds through recovery first ✓
   ```

   If recovery were first, panics in inner middlewares would bypass it:

   ```go
   // BAD: Chain(proxy, recoveryMiddleware, loggingMiddleware, requestIDMiddleware)
   // Execution: recovery → logging → requestID → proxy
   // A panic in requestID skips recovery because recovery is outermost ✗
   ```

---

## Exercise 1: Why recovery must be last in Chain

`Chain(h, m1, m2, m3)` produces `m1(m2(m3(h)))`. Execution on a request:

```
m1.before → m2.before → m3.before → h → m3.after → m2.after → m1.after
```

A panic in `h` or `m3` unwinds the call stack. The first `defer` it encounters during
unwinding is inside `m3`'s handler function, then `m2`'s, then `m1`'s.

For recovery to catch panics from the proxy and from any middleware running after it,
recovery must be the wrapper *closest* to the proxy — i.e., the last argument to `Chain`.

---

## Exercise 2: Adding `X-Gateway-Version` via ModifyResponse

```go
proxy.ModifyResponse = func(resp *http.Response) error {
    resp.Header.Set("X-Gateway-Version", "1.0")
    return nil
}
```

`ModifyResponse` runs after the backend returns a response and before it is forwarded to
the client. This is the correct place for response-level headers — unlike middleware, you
cannot reliably set response headers after `next.ServeHTTP` returns when the inner handler
is a reverse proxy (it flushes headers immediately).

---

## Exercise 3: Graceful shutdown timeout sizing

Change `5*time.Second` to `10*time.Second`:

```go
shutCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
```

When to increase the timeout in ECS Fargate:

- Your API has endpoints with long-running operations (streaming, file uploads, slow queries)
  that legitimately take more than 5 seconds.
- You want more headroom within Fargate's 30-second `stopTimeout` window.
- You are doing blue/green deployments and want in-flight requests to drain completely
  before ECS deregisters the task from the target group.

Keep the timeout less than the ECS `stopTimeout` (default 30s) to guarantee Fargate gives
your process enough time to drain before SIGKILL. A rule of thumb: `gracefulTimeout < stopTimeout - 5s`.
