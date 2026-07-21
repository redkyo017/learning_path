# Day 20 — Production Gateway Features

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Implement per-client token bucket rate limiting using the `golang.org/x/time/rate` package with memory cleanup
- Explain the circuit breaker state machine and implement the three transitions
- Drain in-flight connections on shutdown using `srv.Shutdown` and distinguish it from `srv.Close`
- Validate JWTs at the gateway edge and forward validated claims to upstreams
- Apply a production deployment checklist before releasing a gateway service

---

## Core mental model

**A circuit breaker is a failure detector — it stops amplifying a downstream failure into an upstream cascade.**

Without a circuit breaker, when your `users` service goes down, every request to your gateway instantly blocks for the full timeout (e.g., 30 seconds), holding a goroutine and an upstream connection. Under load, you run out of goroutines and connections — the gateway itself falls over even though the problem is downstream.

A circuit breaker detects the failure fast and immediately rejects subsequent requests without attempting the downstream call. This is the difference between a cascade and a graceful degradation.

---

## Token bucket rate limiting

### The algorithm

A token bucket has a capacity (burst size) and a refill rate (tokens per second). Each incoming request consumes one token. If no tokens are available, the request is rejected (or waits).

```
Rate: 10 req/s, Burst: 20

t=0s  tokens=20 ████████████████████  request arrives → tokens=19
t=0.1 tokens=20 ████████████████████  (refilled 1 token)
t=0.1 20 requests arrive → tokens=0   (burst absorbed)
t=0.1 request 21 arrives → REJECTED   (no tokens)
t=1.0 tokens=10 (10 tokens refilled)
```

The burst allows short traffic spikes while the rate limits sustained throughput.

### Using `golang.org/x/time/rate`

```go
import "golang.org/x/time/rate"

// Create a limiter: 10 requests/second, burst of 20
limiter := rate.NewLimiter(rate.Limit(10), 20)

// Non-blocking check — returns false immediately if no token available
if !limiter.Allow() {
    http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
    return
}

// Blocking wait — respects context cancellation
if err := limiter.Wait(ctx); err != nil {
    // context canceled or deadline exceeded
    return
}
```

### Per-client limiting

A single global limiter throttles all clients together. You need one limiter per client, keyed by IP address or API key.

```go
type clientLimiter struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

type RateLimiter struct {
    mu      sync.Mutex
    clients map[string]*clientLimiter
    rate    rate.Limit
    burst   int
}

func NewRateLimiter(r rate.Limit, b int) *RateLimiter {
    rl := &RateLimiter{
        clients: make(map[string]*clientLimiter),
        rate:    r,
        burst:   b,
    }
    go rl.cleanup()
    return rl
}

func (rl *RateLimiter) getLimiter(key string) *rate.Limiter {
    rl.mu.Lock()
    defer rl.mu.Unlock()

    entry, exists := rl.clients[key]
    if !exists {
        entry = &clientLimiter{
            limiter: rate.NewLimiter(rl.rate, rl.burst),
        }
        rl.clients[key] = entry
    }
    entry.lastSeen = time.Now()
    return entry.limiter
}

// cleanup removes clients not seen for 3 minutes — prevents unbounded map growth
func (rl *RateLimiter) cleanup() {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()
    for range ticker.C {
        rl.mu.Lock()
        for key, entry := range rl.clients {
            if time.Since(entry.lastSeen) > 3*time.Minute {
                delete(rl.clients, key)
            }
        }
        rl.mu.Unlock()
    }
}
```

Memory cleanup is mandatory. Without it, a gateway that has served millions of distinct IPs over days will accumulate millions of `*rate.Limiter` entries in memory.

---

## Circuit breaker state machine

### States and transitions

```
                  failure count >= threshold
    ┌─────────────────────────────────────────────────────────┐
    │                                                         ▼
┌───┴───┐                                               ┌─────────┐
│       │                                               │         │
│CLOSED │  Normal operation.                            │  OPEN   │  Fail-fast.
│       │  Requests pass through.                       │         │  No calls to upstream.
│       │  Failures are counted.                        │         │  Returns error immediately.
└───────┘                                               └────┬────┘
    ▲                                                        │
    │                                                        │ timeout elapsed
    │ probe request succeeds                                 ▼
    │                                               ┌──────────────┐
    └───────────────────────────────────────────────┤  HALF-OPEN   │
                                                    │              │
                                                    │  One probe   │
                                                    │  request     │
                probe request fails                 │  allowed.    │
                ──────────────────────────────────→ └──────────────┘
                returns to OPEN
```

| State | What happens | Transition out |
|---|---|---|
| **Closed** | All requests pass to upstream. Failures are counted. | `failures >= threshold` → Open |
| **Open** | All requests fail immediately. Upstream not called. | `time since opened >= timeout` → Half-Open |
| **Half-Open** | One request allowed through as a probe. | Success → Closed; Failure → Open |

### Implementation sketch

```go
type State int

const (
    StateClosed   State = iota
    StateOpen
    StateHalfOpen
)

type CircuitBreaker struct {
    mu           sync.Mutex
    state        State
    failures     int
    threshold    int           // failures before opening
    timeout      time.Duration // how long to stay open before probing
    openedAt     time.Time
}

func (cb *CircuitBreaker) Allow() bool {
    cb.mu.Lock()
    defer cb.mu.Unlock()

    switch cb.state {
    case StateClosed:
        return true
    case StateOpen:
        if time.Since(cb.openedAt) >= cb.timeout {
            cb.state = StateHalfOpen
            return true // one probe
        }
        return false
    case StateHalfOpen:
        return false // only one probe at a time
    }
    return false
}

func (cb *CircuitBreaker) RecordSuccess() {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    cb.failures = 0
    cb.state = StateClosed
}

func (cb *CircuitBreaker) RecordFailure() {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    cb.failures++
    if cb.state == StateHalfOpen || cb.failures >= cb.threshold {
        cb.state = StateOpen
        cb.openedAt = time.Now()
        cb.failures = 0
    }
}
```

In production, use a well-tested library such as `github.com/sony/gobreaker` rather than rolling your own. The implementation above illustrates the state machine — production code needs atomic counters, configurable policies (consecutive failures vs error rate), and metrics.

---

## Graceful shutdown with connection draining

### `srv.Shutdown` vs `srv.Close`

| Method | What it does |
|---|---|
| `srv.Close()` | Immediately closes all connections and the listener. In-flight requests are dropped. |
| `srv.Shutdown(ctx)` | Stops accepting new connections. Waits for in-flight requests to complete. Honors the context deadline for a maximum wait. |

Use `srv.Shutdown` for production. Use `srv.Close` in tests where you want instant teardown.

### Shutdown sequence

```go
func runServer(srv *http.Server) error {
    // Start serving in background
    errCh := make(chan error, 1)
    go func() {
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            errCh <- err
        }
        close(errCh)
    }()

    // Wait for termination signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

    select {
    case err := <-errCh:
        return fmt.Errorf("server error: %w", err)
    case sig := <-quit:
        slog.Info("shutdown initiated", "signal", sig)
    }

    // Give in-flight requests up to 30s to complete
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        slog.Error("shutdown error", "error", err)
        return err
    }

    slog.Info("shutdown complete")
    return nil
}
```

### Why 30 seconds?

Match your longest expected request timeout. If your slowest upstream has a 25s timeout and a request is in flight when the signal arrives, you need at least 25s to let it complete. Kubernetes default grace period is 30s — align with it or configure `terminationGracePeriodSeconds` accordingly.

### Draining gRPC connections

`srv.Shutdown` drains HTTP connections. If you also have gRPC client connections, close them too:

```go
defer func() {
    if err := grpcConn.Close(); err != nil {
        slog.Error("grpc conn close error", "error", err)
    }
}()
```

---

## JWT validation at the edge

### The principle: validate once, forward claims

The gateway validates the JWT signature, expiry, issuer, and audience. Upstreams trust the gateway's verdict and do not re-validate. The gateway forwards the verified claims as HTTP headers or gRPC metadata.

```
Client → [JWT] → Gateway → [validate] → forward user_id + roles → Upstream
```

This avoids each upstream duplicating key distribution, validation logic, and clock-skew handling.

### Validation in middleware

```go
import (
    "github.com/golang-jwt/jwt/v5"
)

type GatewayClaims struct {
    UserID string   `json:"sub"`
    Roles  []string `json:"roles"`
    jwt.RegisteredClaims
}

func JWTMiddleware(publicKey *rsa.PublicKey) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if !strings.HasPrefix(authHeader, "Bearer ") {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
            return
        }
        tokenStr := strings.TrimPrefix(authHeader, "Bearer ")

        claims := &GatewayClaims{}
        token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
            // Enforce RS256 — reject HS256 (the "alg:none" attack vector)
            if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
            }
            return publicKey, nil
        },
            jwt.WithExpirationRequired(),
            jwt.WithIssuedAt(),
            jwt.WithIssuer("https://auth.example.com"),
            jwt.WithAudience("gateway"),
        )
        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
            return
        }

        // Store claims for downstream handlers
        c.Set("user_id", claims.UserID)
        c.Set("roles", claims.Roles)
        c.Next()
    }
}
```

### Forwarding claims to upstreams

```go
// As HTTP headers for HTTP upstreams
r.Header.Set("X-User-ID", userID)
r.Header.Set("X-User-Roles", strings.Join(roles, ","))

// As gRPC metadata for gRPC upstreams
ctx = metadata.AppendToOutgoingContext(ctx, "x-user-id", userID)
```

### RS256 vs HS256

| Algorithm | Key type | Use case |
|---|---|---|
| HS256 | Shared secret | Development, internal services where all parties share the secret |
| RS256 | RSA key pair | Production: auth service signs with private key, gateway verifies with public key |

RS256 is preferred for gateways because the gateway only needs the public key. The private key never leaves the auth service.

---

## Production deployment checklist

Before deploying a gateway to production, verify:

### Connection and timeout configuration

- [ ] `http.Transport.MaxIdleConnsPerHost` set ≥ 50 (not the default 2)
- [ ] `http.Transport.ResponseHeaderTimeout` set (default is 0 = infinite)
- [ ] All gRPC client connections have `grpc.WithKeepaliveParams` configured
- [ ] Circuit breakers on all upstream dependencies

### Request handling

- [ ] Rate limiting enabled per client (IP or API key)
- [ ] Request ID injected and forwarded (`X-Request-ID`)
- [ ] JWT validation in middleware (not per-handler)
- [ ] Authorization header not logged (PII + secret)

### Observability

- [ ] `/metrics` endpoint exposed for Prometheus scraping
- [ ] Prometheus histogram for request latency (not gauge)
- [ ] `slog` JSON handler configured (not TextHandler)
- [ ] Log level set to `Info` (not `Debug`)
- [ ] OpenTelemetry tracer configured with OTLP exporter
- [ ] `/healthz` and `/readyz` endpoints responding correctly

### Operational

- [ ] Graceful shutdown wired to `SIGTERM`
- [ ] Kubernetes `terminationGracePeriodSeconds` ≥ your Shutdown timeout
- [ ] `GOMAXPROCS` not set to 1 in containers (or use `automaxprocs`)
- [ ] `pprof` endpoint enabled on a non-public port

### Security

- [ ] JWT signing algorithm explicitly enforced (RS256, not `alg:none`)
- [ ] Public key loaded from config or secrets manager (not hardcoded)
- [ ] Upstream URLs from config (not hardcoded)
- [ ] TLS enabled for all upstream connections in production

---

## Returning engineer: what changed since 1.16–1.18

| Area | Change | Version |
|---|---|---|
| `os/signal` | `signal.NotifyContext` — cleaner shutdown pattern; returns a context canceled on signal | Go 1.16 |
| JWT libraries | `github.com/golang-jwt/jwt/v5` replaced `dgrijalva/jwt-go` (unmaintained) | v5 (2023) |
| `sync` | `sync.Map` performance improvements; still prefer `sync.Mutex` + `map` for write-heavy workloads | Go 1.19 |
| `automaxprocs` | `go.uber.org/automaxprocs` — reads container CPU quota and sets GOMAXPROCS correctly | stable ~2020 |
| Circuit breakers | `gobreaker` v2 API; `go-resilience` ecosystem matured | 2022–2023 |

`signal.NotifyContext` (Go 1.16 — just barely outside your window) simplifies shutdown:

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
defer stop()
<-ctx.Done()
// ctx is now canceled — start shutdown
```

---

## Key concepts to memorize

- Token bucket: tokens refill at the rate; burst absorbs spikes; per-client requires cleanup
- Circuit breaker: Closed (normal) → Open (fail-fast) → Half-Open (probe) → Closed (recovered)
- `srv.Shutdown`: stops accepting new connections, waits for in-flight requests. `srv.Close`: drops everything immediately
- JWT: validate at the gateway edge (once), forward claims as headers/metadata to upstreams
- RS256 = asymmetric, public key only needed at gateway. HS256 = shared secret
- GOMAXPROCS defaults to the host's CPU count — in containers, set it to the CPU quota or use `automaxprocs`

---

## Common mistakes

1. **Forgetting memory cleanup for per-client limiters.** A `sync.Map` or `map` entry is created for every unique client. Without cleanup, memory grows indefinitely. Add a background goroutine that deletes entries not seen for N minutes.

2. **Circuit breaker threshold too low.** A threshold of 1 failure opens the circuit on every transient error. Set thresholds based on your upstream's expected error rate — typically 5 consecutive failures or a 10% error rate over 30 seconds.

3. **Not handling `http.ErrServerClosed` after calling `Shutdown`.** After `srv.Shutdown()` is called, `srv.ListenAndServe()` returns `http.ErrServerClosed`. This is expected and must not be treated as an error.

4. **Accepting `alg:none` in JWT validation.** Some JWT libraries (especially older versions) allow tokens with `alg: none` — no signature — to pass validation. Always explicitly validate the signing method.

5. **Setting `terminationGracePeriodSeconds` shorter than the Shutdown timeout.** If Kubernetes kills the process after 5 seconds but your `Shutdown` waits up to 30 seconds, Kubernetes wins with a `SIGKILL`. The graceful drain never completes. Always make `terminationGracePeriodSeconds` ≥ shutdown timeout + a 5-second buffer.

---

## Check your understanding

1. Your gateway uses per-client rate limiting keyed by IP address. After running for 7 days, you notice memory usage has grown from 50MB to 2GB. The cleanup goroutine runs every minute and removes entries not seen for 3 minutes. What could cause it to fail silently, and how would you diagnose it?

2. Your circuit breaker is configured with threshold=5, timeout=30s. Upstream starts failing at 14:00:00 exactly. Walk through the timeline: what happens to requests at 14:00:04, 14:00:05, 14:00:06, 14:00:35, and 14:00:36 (assuming the upstream is still down)?

3. During a rolling deploy, Kubernetes sends `SIGTERM` to the old pod. The pod has 20 in-flight requests averaging 8 seconds each. Your `Shutdown` timeout is 15 seconds. What happens to the in-flight requests, and what should you change?
