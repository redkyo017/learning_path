# Day 17: Building a Go Reverse Proxy with a Middleware Chain

## Why

WSO2 API Manager's gateway core is a handler chain that sits in front of every backend call.
Day 16 showed how that chain works conceptually. Today you build the Go equivalent: a
`httputil.ReverseProxy` wrapped in a composable middleware chain, with request-ID correlation
matching WSO2's `activityid` header pattern.

---

## WSO2 Source Reading

WSO2 sets an `activityid` header on every upstream (backend) request. This header is a
correlation ID that links gateway logs, analytics events, and backend traces together. You can
find it in the gateway's `AbstractHandler` or in the `DigestAuthUtils` correlation propagation
code. The pattern:

```java
String activityID = correlationId;  // derived from the message context
axis2MsgContext.setProperty("activityid", activityID);
```

In Go you replicate this by setting `activityid` in the `ReverseProxy.Director` function,
reading the value from the `X-Request-ID` header that your middleware already attached.

---

## Core Concepts

### `httputil.ReverseProxy`

The standard library type that forwards HTTP requests to a backend:

```go
import "net/http/httputil"

proxy := httputil.NewSingleHostReverseProxy(targetURL)
```

Two hooks you will always override:

| Hook | Purpose |
|------|---------|
| `Director func(*http.Request)` | Mutate the request before it is sent upstream — rewrite host, add headers |
| `ModifyResponse func(*http.Response) error` | Mutate or inspect the response before it is returned to the client |

**Always reset `req.Host`** in your Director, or the backend receives the client's original
`Host` header (which may fail virtual-host routing):

```go
proxy.Director = func(req *http.Request) {
    original(req)         // apply NewSingleHostReverseProxy defaults
    req.Host = target.Host  // override Host header
}
```

### Middleware Pattern

A middleware is a function that wraps one handler with another:

```go
type Middleware func(http.Handler) http.Handler
```

Each middleware receives the next handler in the chain and returns a new handler that can
run code before calling `next.ServeHTTP`, after it, or skip it entirely (short-circuit).

Example — logging middleware:

```go
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        slog.Info("request",
            "method", r.Method,
            "path",   r.URL.Path,
            "duration_ms", time.Since(start).Milliseconds(),
        )
    })
}
```

### The `Chain` Function and Right-to-Left Ordering

`Chain` composes a list of middlewares around a core handler. The key rule:
**middlewares are applied right-to-left so that the first middleware listed runs first**.

```go
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}
```

**Concrete example** with three middlewares — m1, m2, m3:

```
Chain(proxy, m1, m2, m3)
```

Iteration step by step (starting from i = len-1 = 2):

```
step 1 (i=2): h = m3(proxy)
step 2 (i=1): h = m2(m3(proxy))
step 3 (i=0): h = m1(m2(m3(proxy)))
```

Final: `h = m1(m2(m3(proxy)))`

When a request arrives, execution flows:

```
m1.before → m2.before → m3.before → proxy → m3.after → m2.after → m1.after
```

So **m1 runs outermost** (first to see the request, last to see the response) — exactly the
order you listed in `Chain`. This matches WSO2's handler chain: the first handler listed in
`api-manager.xml` runs first.

### Request ID and `activityid` Correlation

```go
func requestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.Header.Get("X-Request-ID") == "" {
            r.Header.Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
        }
        next.ServeHTTP(w, r)
    })
}

func newReverseProxy(target string) *httputil.ReverseProxy {
    u, _ := url.Parse(target)
    proxy := httputil.NewSingleHostReverseProxy(u)
    original := proxy.Director
    proxy.Director = func(req *http.Request) {
        original(req)
        req.Host = u.Host
        // Mirror WSO2's activityid pattern: propagate the correlation ID upstream
        req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
    }
    return proxy
}
```

By the time `Director` runs, `requestIDMiddleware` has already set `X-Request-ID`, so the
Director can read it and copy it to `activityid`.

---

## Lab

See `labs/phase2/day17/` — write and run the reverse proxy with the middleware chain.

```
BACKEND_URL=https://httpbin.org go run main.go
```

Then in another terminal:

```bash
curl -s http://localhost:9090/get | jq .
curl -s -H "X-Request-ID: test-123" http://localhost:9090/get | jq .headers
```

Observe that the slog output shows `method`, `path`, and `duration_ms` for each request.

---

## Exercises

**Exercise 1:** Write a logging middleware that records `method`, `path`, and `duration_ms`
for every request using `log/slog`.

**Hint:** Capture `time.Now()` before calling `next.ServeHTTP`, then call
`time.Since(start).Milliseconds()` in the log statement after `next` returns.

**Solution sketch:**

```go
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        slog.Info("request",
            "method",      r.Method,
            "path",        r.URL.Path,
            "duration_ms", time.Since(start).Milliseconds(),
        )
    })
}
```

---

**Exercise 2:** Write a `Chain` function that applies middlewares right-to-left so that the
first argument in the variadic list runs outermost (first on the way in).

**Hint:** Iterate `middlewares` from the last index (`len-1`) down to `0`, wrapping `h` at
each step.

**Solution sketch:**

```go
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}
```

With `Chain(proxy, m1, m2)` the final result is `m1(m2(proxy))`. A request hits `m1` first.

---

**Exercise 3:** What does `ReverseProxy.Director` need to do if you want the backend to
receive the client's original `Host` header rewritten to the backend's host?

**Hint:** After calling the original Director (from `NewSingleHostReverseProxy`), set
`req.Host = target.Host` explicitly. The default Director sets `req.URL.Host` but not
`req.Host`.

**Solution sketch:**

```go
proxy.Director = func(req *http.Request) {
    original(req)          // sets URL scheme, host, path
    req.Host = u.Host      // overwrite the HTTP Host header sent to the backend
}
```

Without this, HTTP/1.1 sends the client's original `Host` header upstream, which breaks
many backends that do virtual-host routing.

---

## Anti-patterns

- **Not capturing the original Director** — `httputil.NewSingleHostReverseProxy` sets a
  Director that rewrites URL fields. If you replace it entirely, you lose those rewrites.
  Always capture `original := proxy.Director` and call it inside your replacement.

- **Middleware order confusion** — Writing `Chain(proxy, logging, auth)` means logging runs
  before auth. An unauthenticated request still gets logged. This may be intentional (log
  everything) or a security concern (log PII before rejecting). Be explicit about order.

- **Logging after next.ServeHTTP with a plain ResponseWriter** — You cannot read the status
  code from `http.ResponseWriter` after the fact. Wrap it in a struct that records
  `WriteHeader` calls if you need to log the status code.

---

## Teardown

Stop the gateway with `Ctrl+C`. No containers or external processes are started.
