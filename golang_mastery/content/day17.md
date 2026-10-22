# Day 17 — Gateway Architecture + Reverse Proxy

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Explain how `httputil.ReverseProxy` implements `http.Handler` and trace request flow from client to upstream
- Configure `http.Transport` connection pool settings for production load and understand why defaults cause problems
- Design a clean upstream registry interface with separation from routing logic
- Implement path-based routing and request rewriting via the `Rewrite` hook (and know why `Director` is deprecated)
- Handle proxy-layer errors gracefully with `ErrorHandler` without leaking upstream details

---

## Core mental model

**A reverse proxy is just an `http.Handler` that makes an outbound request instead of generating a response locally.**

That's it. When `ServeHTTP` is called, `httputil.ReverseProxy` does four things:

1. Copies the incoming `*http.Request`
2. Calls `Rewrite` with the inbound request and a fresh outbound copy (set the target scheme, host, path)
3. Calls `Transport.RoundTrip` to make the outbound call
4. Copies the upstream response back to the `http.ResponseWriter`

Every complexity you add — routing, auth, rate limiting — wraps around this core loop.

---

## The `httputil.ReverseProxy` struct

The key fields you will configure:

```go
type ReverseProxy struct {
    // Rewrite turns the inbound request into the outbound one (Go 1.20+).
    // Mandatory (or the deprecated Director): at minimum, choose the target.
    Rewrite func(*httputil.ProxyRequest)

    // Director is the legacy hook — deprecated in Go 1.26 as insecure.
    // Mutually exclusive with Rewrite. See the box below.
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
      ├─ strip hop-by-hop + client X-Forwarded-* headers
      ├─ call Rewrite(pr)             ← you set scheme/host/path here
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
            Rewrite:      buildRewrite(upstream.URL()),
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

## The `Rewrite` hook

`Rewrite` is your request rewriting hook ([Go 1.20](https://pkg.go.dev/net/http/httputil#ReverseProxy), the only non-deprecated option since [Go 1.26](https://go.dev/doc/go1.26)). It receives a `*httputil.ProxyRequest` with two requests: `pr.In` (the unmodified inbound request — treat as read-only) and `pr.Out` (the outbound request you mutate). Before `Rewrite` runs, the proxy has already removed hop-by-hop headers and the client's `X-Forwarded-*` headers from `pr.Out`.

```go
func buildRewrite(target *url.URL) func(*httputil.ProxyRequest) {
    return func(pr *httputil.ProxyRequest) {
        // Route to the target's scheme, host and base path; joins target.Path
        // with the incoming path and rewrites the outbound Host header.
        pr.SetURL(target)

        // Set X-Forwarded-For/-Host/-Proto from the real client connection.
        pr.SetXForwarded()

        // Headers the gateway adds go on pr.Out.
        pr.Out.Header.Set("X-Gateway", "phase4-gateway")
    }
}
```

Two helpers do the work you would otherwise hand-write: `SetURL` handles scheme, host, path joining and `Host`; `SetXForwarded` sets `X-Forwarded-For` (client IP, appended to any existing value), `X-Forwarded-Host` and `X-Forwarded-Proto`. Do not append to `X-Forwarded-For` yourself — it double-appends, and because `Rewrite` already dropped the client-sent value, there is nothing to preserve.

### What NOT to do in Rewrite

- Do not read `pr.In.Body` — it is the live inbound body and you will break streaming uploads
- Do not mutate `pr.In` — it is the original request, shared with the caller
- Do not touch the `ProxyRequest` or its contents after `Rewrite` returns

> **Legacy: why `Director` was deprecated (Go 1.26).** `Director` mutates the outbound request, and the proxy removes hop-by-hop headers *after* it returns. A malicious client can list a header your `Director` added in its `Connection` header, and the proxy strips it as hop-by-hop — silently removing, say, your identity header. `httputil.NewSingleHostReverseProxy` is built on `Director` and also keeps client-sent `X-Forwarded-*` headers, so a client can spoof its IP. The [Go 1.26 release notes](https://go.dev/doc/go1.26) call `Director` "fundamentally unsafe"; the [`ReverseProxy` docs](https://pkg.go.dev/net/http/httputil#ReverseProxy) say to use `Rewrite`. You will still meet `Director` in older code — migrate it.

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
| `httputil.ReverseProxy` | `Rewrite` field added (safe replacement for `Director`) | Go 1.20 |
| `httputil.ReverseProxy` | `Director` deprecated as insecure; `NewSingleHostReverseProxy` (not itself deprecated) is documented as using `Director` and keeping client `X-Forwarded-*` — build `ReverseProxy{Rewrite: ...}` instead | Go 1.26 |
| `net/http` | `http.ResponseController` for per-request deadline and flush control | Go 1.20 |

`Rewrite` and `Director` are mutually exclusive — set one or the other. Use `Rewrite` (see above).

---

## Key concepts to memorize

- `ReverseProxy` is an `http.Handler` — it fits into any middleware chain
- `Rewrite` mutates the outbound request (`pr.Out`); `ModifyResponse` mutates the inbound response. `Director` is deprecated
- Headers the gateway sets belong in `Rewrite` (`pr.Out`), never `Director` — a client can strip them via `Connection`
- `ErrorHandler` is called when the Transport fails (connection refused, timeout) — not when the upstream returns a 4xx/5xx
- `MaxIdleConnsPerHost` defaults to 2; for a gateway this must be much higher
- Always share a single `Transport` per upstream — it holds the connection pool
- `http.DefaultTransport` is a global variable with no connection-per-host limit suitable for proxy workloads

---

## Common mistakes

1. **Creating a new `http.Transport` per request.** The connection pool lives on the Transport. Creating one per request means zero connection reuse — every request pays the TCP + TLS handshake cost.

2. **Building the outbound URL by hand and forgetting the `Host` header.** `pr.SetURL` sets it for you; without it, the `Host` header sent to the upstream is the gateway's hostname. Many upstreams reject requests with the wrong `Host`.

3. **Calling `pr.In.Body.Read()` in Rewrite.** The Body is shared with the original caller. Reading it here will corrupt streaming uploads.

4. **Using `ErrorHandler` to mask all 5xx responses.** `ErrorHandler` only fires on transport-level errors. A 503 from the upstream still flows through `ModifyResponse`. If you want to rewrite upstream 5xx responses, use `ModifyResponse`.

5. **Ignoring `context.Canceled` in ErrorHandler.** When a client disconnects mid-request, the context is canceled and the Transport returns `context.Canceled`. Logging this as an error creates noise. Detect and handle it separately.

---

## Check your understanding

1. You deploy your gateway and notice that under load, p99 latency spikes every few seconds but p50 is fine. The upstream service is healthy. Which Transport setting is most likely the culprit, and what would you change?

2. Your upstream registry returns the same `Upstream` for `/api/v1/users` and `/api/v1/users/profile`. A client requests `/api/v1/users/profile/avatar`. Which entry wins, and why does the ordering of entries in the registry matter?

3. A client sends a request that the upstream processes successfully and returns 200. An hour later, ops reports that some clients are seeing 502 errors with the message "upstream unavailable". Is `ErrorHandler` involved? What is the most likely cause?

---

## Lab

Open `docs/superpowers/plans/2026-07-21-golang-mastery-plan.md` and follow the **Day 17** section for the hands-on build steps.
