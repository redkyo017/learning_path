# Day 17 — Gateway Architecture + Reverse Proxy

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Explain how `httputil.ReverseProxy` implements `http.Handler` and trace request flow from client to upstream
- Configure `http.Transport` connection pool settings for production load and understand why defaults cause problems
- Design a clean upstream registry interface with separation from routing logic
- Implement path-based routing and request rewriting via the `Director` function
- Handle proxy-layer errors gracefully with `ErrorHandler` without leaking upstream details

---

## Core mental model

**A reverse proxy is just an `http.Handler` that makes an outbound request instead of generating a response locally.**

That's it. When `ServeHTTP` is called, `httputil.ReverseProxy` does four things:

1. Copies the incoming `*http.Request`
2. Calls `Director` to mutate the copy (set the target scheme, host, path)
3. Calls `Transport.RoundTrip` to make the outbound call
4. Copies the upstream response back to the `http.ResponseWriter`

Every complexity you add — routing, auth, rate limiting — wraps around this core loop.

---

## The `httputil.ReverseProxy` struct

The key fields you will configure:

```go
type ReverseProxy struct {
    // Director mutates the cloned request before it is sent upstream.
    // Mandatory: set Scheme, Host, and Path at minimum.
    Director func(*http.Request)

    // Transport is used to make outbound requests.
    // If nil, http.DefaultTransport is used — never acceptable in production.
    Transport http.RoundTripper

    // ErrorHandler is called when Transport.RoundTrip fails.
    // If nil, the default writes a 502 Bad Gateway with an error in the body.
    // Override this to control error format and avoid leaking internals.
    ErrorHandler func(http.ResponseWriter, *http.Request, error)

    // ModifyResponse is called after a successful upstream response.
    // Return an error to abort and call ErrorHandler.
    ModifyResponse func(*http.Response) error

    // FlushInterval controls response streaming flush cadence.
    // -1 flushes after each write (for SSE / streaming APIs).
    FlushInterval time.Duration
}
```

### Request flow step by step

```
Incoming request
      │
      ▼
ReverseProxy.ServeHTTP
      │
      ├─ clone request
      ├─ call Director(cloned)        ← you set scheme/host/path here
      ├─ call Transport.RoundTrip     ← outbound HTTP call
      │       │
      │       ├── success → call ModifyResponse (optional)
      │       │             copy headers + body to ResponseWriter
      │       │
      │       └── error   → call ErrorHandler
      │
      └─ done
```

---

## `http.Transport` connection pool settings

The default `http.DefaultTransport` has settings designed for a browser, not a gateway. Under any real load you will exhaust connections or hit unnecessary overhead.

| Setting | Default | Recommended for gateway | What it controls |
|---|---|---|---|
| `MaxIdleConns` | 100 | 500–1000 | Total idle connections across all hosts |
| `MaxIdleConnsPerHost` | 2 | 50–200 per upstream | Idle connections kept per host — **this is the one that bites you** |
| `MaxConnsPerHost` | 0 (unlimited) | 200–500 | Hard cap on active connections per host |
| `IdleConnTimeout` | 90s | 90s | How long idle connections live before being closed |
| `TLSHandshakeTimeout` | 10s | 5–10s | TLS handshake deadline |
| `ResponseHeaderTimeout` | 0 (none) | 10–30s | Time to wait for upstream response headers |
| `DisableKeepAlives` | false | false | Never set true for a proxy |

### Why `MaxIdleConnsPerHost` matters

Each proxy request hits the same upstream host. With the default of 2 idle connections, a burst of 50 concurrent requests forces 48 new TCP+TLS handshakes. At scale this adds 50–200ms of latency per cold connection.

```go
func newTransport() *http.Transport {
    return &http.Transport{
        MaxIdleConns:          500,
        MaxIdleConnsPerHost:   100,
        MaxConnsPerHost:       300,
        IdleConnTimeout:       90 * time.Second,
        TLSHandshakeTimeout:   5 * time.Second,
        ResponseHeaderTimeout: 15 * time.Second,
        // Tune keepalive for long-lived connections
        DialContext: (&net.Dialer{
            Timeout:   5 * time.Second,
            KeepAlive: 30 * time.Second,
        }).DialContext,
    }
}
```

---

## Upstream registry design

Separate the concern of "which upstream handles this request" from the proxy mechanics. Use an interface so you can swap implementations (static config, service discovery, database-backed).

```go
// Upstream represents one backend service.
type Upstream interface {
    URL() *url.URL   // base URL: scheme + host + optional path prefix
    Name() string    // identifier for logging and metrics
}

// Registry maps routing keys to upstreams.
type Registry interface {
    Lookup(path string) (Upstream, bool)
}
```

A simple prefix-based implementation:

```go
type prefixRegistry struct {
    entries []prefixEntry // ordered: most specific first
}

type prefixEntry struct {
    prefix   string
    upstream Upstream
}

func (r *prefixRegistry) Lookup(path string) (Upstream, bool) {
    for _, e := range r.entries {
        if strings.HasPrefix(path, e.prefix) {
            return e.upstream, true
        }
    }
    return nil, false
}
```

Keep entries sorted longest-prefix first. `/api/v2/users` must win over `/api/v2` which wins over `/api`.

---

## Path-based routing

Wire the registry into the router. The gateway's job is to inspect the request path, look up the upstream, build a `ReverseProxy`, and hand off.

```go
func NewGatewayHandler(reg Registry) http.Handler {
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        upstream, ok := reg.Lookup(r.URL.Path)
        if !ok {
            http.Error(w, "no upstream for path", http.StatusNotFound)
            return
        }
        proxy := &httputil.ReverseProxy{
            Director:     buildDirector(upstream.URL()),
            Transport:    newTransport(),
            ErrorHandler: buildErrorHandler(upstream.Name()),
        }
        proxy.ServeHTTP(w, r)
    })
    return mux
}
```

In practice, cache the `ReverseProxy` instances per upstream rather than constructing them per request — construction itself is cheap, but the `Transport` carries the connection pool and must be shared.

---

## The `Director` function

`Director` is your request rewriting hook. It receives a copy of the original request and mutates it before the outbound call. The mutation must at minimum set `URL.Scheme` and `URL.Host`.

```go
func buildDirector(target *url.URL) func(*http.Request) {
    return func(req *http.Request) {
        // Set the target scheme and host
        req.URL.Scheme = target.Scheme
        req.URL.Host = target.Host

        // Join the target prefix path with the incoming path
        req.URL.Path = singleJoiningSlash(target.Path, req.URL.Path)

        // Set Host header to the upstream host (not the gateway's hostname)
        req.Host = target.Host

        // Add X-Forwarded-For (httputil does this, but be explicit)
        if clientIP, _, err := net.SplitHostPort(req.RemoteAddr); err == nil {
            prior, ok := req.Header["X-Forwarded-For"]
            if ok {
                clientIP = strings.Join(prior, ", ") + ", " + clientIP
            }
            req.Header.Set("X-Forwarded-For", clientIP)
        }
    }
}

func singleJoiningSlash(a, b string) string {
    aSlash := strings.HasSuffix(a, "/")
    bSlash := strings.HasPrefix(b, "/")
    switch {
    case aSlash && bSlash:
        return a + b[1:]
    case !aSlash && !bSlash:
        return a + "/" + b
    }
    return a + b
}
```

### What NOT to do in Director

- Do not read `req.Body` — it may be nil after cloning and you'll break streaming uploads
- Do not set `req.RequestURI` — it is set automatically and must be empty for client requests
- Do not mutate `req.Header` after Director returns (a race with the Transport goroutine)

---

## Error handling with `ErrorHandler`

The default error handler writes a plaintext error message into the response body. That leaks internal hostnames and error details to clients. Always override it.

```go
func buildErrorHandler(upstreamName string) func(http.ResponseWriter, *http.Request, error) {
    return func(w http.ResponseWriter, r *http.Request, err error) {
        // Client disconnected — not our fault, don't log as error
        if errors.Is(err, context.Canceled) {
            w.WriteHeader(http.StatusServiceUnavailable)
            return
        }

        // Log with upstream context for debugging
        slog.Error("proxy error",
            "upstream", upstreamName,
            "path", r.URL.Path,
            "error", err,
        )

        // Return a clean error response — no upstream details
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusBadGateway)
        w.Write([]byte(`{"error":"upstream unavailable"}`))
    }
}
```

---

## Returning engineer: what changed since 1.16–1.18

| Area | Change | Version |
|---|---|---|
| `net/http` routing | Method-based routing in stdlib mux (`GET /path`, `POST /path`) | Go 1.22 |
| `net/http` routing | Wildcard path segments (`/users/{id}`) in stdlib mux | Go 1.22 |
| Structured logging | `slog` added to standard library | Go 1.21 |
| `httputil.ReverseProxy` | `Rewrite` field added as a cleaner alternative to `Director+ModifyResponse` | Go 1.20 |
| `net/http` | `http.ResponseController` for per-request deadline and flush control | Go 1.20 |

The `Rewrite` field (Go 1.20) is worth knowing. It replaces `Director` with a function that receives a `ProxyRequest` value exposing both the incoming and outbound requests:

```go
proxy.Rewrite = func(pr *httputil.ProxyRequest) {
    pr.SetURL(target)          // sets scheme + host
    pr.SetXForwarded()         // sets X-Forwarded-For/Host/Proto
    pr.Out.Header.Set("X-Request-ID", requestID)
}
```

`Rewrite` and `Director` are mutually exclusive — set one or the other.

---

## Key concepts to memorize

- `ReverseProxy` is an `http.Handler` — it fits into any middleware chain
- `Director` mutates the outbound request; `ModifyResponse` mutates the inbound response
- `ErrorHandler` is called when the Transport fails (connection refused, timeout) — not when the upstream returns a 4xx/5xx
- `MaxIdleConnsPerHost` defaults to 2; for a gateway this must be much higher
- Always share a single `Transport` per upstream — it holds the connection pool
- `http.DefaultTransport` is a global variable with no connection-per-host limit suitable for proxy workloads

---

## Common mistakes

1. **Creating a new `http.Transport` per request.** The connection pool lives on the Transport. Creating one per request means zero connection reuse — every request pays the TCP + TLS handshake cost.

2. **Forgetting to set `req.Host` in Director.** Without it, the `Host` header sent to the upstream is the gateway's hostname. Many upstreams reject requests with the wrong `Host`.

3. **Calling `r.Body.Read()` in Director.** Director receives a shallow copy of the request. The Body is shared with the original caller. Reading it here will corrupt streaming uploads.

4. **Using `ErrorHandler` to mask all 5xx responses.** `ErrorHandler` only fires on transport-level errors. A 503 from the upstream still flows through `ModifyResponse`. If you want to rewrite upstream 5xx responses, use `ModifyResponse`.

5. **Ignoring `context.Canceled` in ErrorHandler.** When a client disconnects mid-request, the context is canceled and the Transport returns `context.Canceled`. Logging this as an error creates noise. Detect and handle it separately.

---

## Check your understanding

1. You deploy your gateway and notice that under load, p99 latency spikes every few seconds but p50 is fine. The upstream service is healthy. Which Transport setting is most likely the culprit, and what would you change?

2. Your upstream registry returns the same `Upstream` for `/api/v1/users` and `/api/v1/users/profile`. A client requests `/api/v1/users/profile/avatar`. Which entry wins, and why does the ordering of entries in the registry matter?

3. A client sends a request that the upstream processes successfully and returns 200. An hour later, ops reports that some clients are seeing 502 errors with the message "upstream unavailable". Is `ErrorHandler` involved? What is the most likely cause?
