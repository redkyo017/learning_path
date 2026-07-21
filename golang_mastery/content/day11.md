# Day 11 — Containerization & Graceful Shutdown

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Write a multi-stage Dockerfile that produces a minimal, non-root production image
- Explain the difference between distroless and Alpine images and when to choose each
- Implement graceful shutdown using `signal.NotifyContext` and `http.Server.Shutdown`
- Implement `/healthz` and `/readyz` endpoints with correct semantics for Kubernetes/ECS
- Inject all configuration via environment variables following the 12-factor app principle

---

## Core mental model: a container is a process

Strip away the Docker vocabulary and what you have is a Linux process running in an isolated namespace with a filesystem snapshot. Your Go binary is the process. PID 1 is your binary (or `tini` if you use an init wrapper). Signals sent to the container are sent to PID 1.

When Kubernetes or ECS wants to stop your container, it sends `SIGTERM` to PID 1. If the process does not exit within the grace period (typically 30 seconds), the orchestrator sends `SIGKILL`. SIGKILL cannot be caught — the process is killed immediately. In-flight requests are dropped.

The analogy: think of your service as a restaurant. When closing time comes (SIGTERM), a well-run restaurant finishes serving the customers already seated, stops accepting new customers at the door, then locks up (graceful shutdown). A badly-run restaurant slams the door on customers mid-meal (SIGKILL). `signal.NotifyContext` is how you listen for the closing-time bell. `srv.Shutdown(ctx)` is how you finish serving and lock up.

---

## Multi-stage Dockerfile

A multi-stage build separates the build environment from the runtime environment. The compiler, Go toolchain, source code, and test dependencies never appear in the production image:

```dockerfile
# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy dependency manifests first (Docker layer caching)
# If go.mod and go.sum are unchanged, this layer is cached
COPY go.mod go.sum ./
RUN go mod download

# Copy source last — changes here invalidate only later layers
COPY . .

# Build a statically linked binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -trimpath \
    -o /app/server \
    ./cmd/server

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

# Copy only the binary
COPY --from=builder /app/server /server

# Distroless nonroot image already runs as uid 65532 (nonroot)
# No USER directive needed — already non-root

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### Layer caching: the key optimization

```dockerfile
COPY go.mod go.sum ./    # copied first
RUN go mod download      # cached as long as go.mod/go.sum are unchanged
COPY . .                 # source copied after — only invalidates from here
```

If you copy all source files before `go mod download`, every source change busts the dependency cache and re-downloads all modules. Always copy manifests first.

### Build flags explained

| Flag | Effect |
|---|---|
| `CGO_ENABLED=0` | Disables C bindings — produces a fully static binary that runs in distroless/scratch |
| `GOOS=linux GOARCH=amd64` | Cross-compile for the target platform |
| `-ldflags="-w -s"` | Strip DWARF debug info (`-w`) and symbol table (`-s`) — reduces binary size 30-40% |
| `-trimpath` | Removes local build path from stack traces — prevents leaking developer machine paths in logs |

---

## distroless vs Alpine

Both are small base images. The choice is a trade-off between debuggability and attack surface:

| | Alpine | distroless/static |
|---|---|---|
| Base size | ~5 MB | ~2 MB |
| Shell | `/bin/sh` (busybox) | None |
| Package manager | `apk` | None |
| libc | musl libc | None (static only) |
| Debug access | `docker exec -it container sh` | Not possible (no shell) |
| Attack surface | Busybox + musl + your binary | Your binary only |
| CVE exposure | Periodic alpine CVEs | Near-zero (no OS packages) |
| Use case | When you need `exec` into the container | Production services with static Go binaries |
| Variant for debugging | — | `gcr.io/distroless/static-debian12:debug` (has busybox) |

For Go services with `CGO_ENABLED=0`, `gcr.io/distroless/static-debian12:nonroot` is the production standard. The `:nonroot` variant runs as uid `65532` automatically — no `USER` instruction needed and no root-to-non-root ownership issues.

Use `distroless/static-debian12:debug` during incident investigation — it includes `busybox` for shell access — then switch back to `:nonroot` after.

---

## Graceful shutdown

The shutdown sequence must:
1. Stop accepting new connections
2. Allow in-flight requests to complete
3. Close database connections and other resources cleanly
4. Exit before the orchestrator's grace period (SIGKILL deadline)

```go
package main

import (
    "context"
    "errors"
    "log/slog"
    "net/http"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    // Build server
    srv := &http.Server{
        Addr:              ":8080",
        Handler:           buildRouter(),
        ReadTimeout:       5 * time.Second,
        WriteTimeout:      10 * time.Second,
        IdleTimeout:       120 * time.Second,
        ReadHeaderTimeout: 2 * time.Second,
    }

    // signal.NotifyContext returns a context that is cancelled
    // when SIGTERM or SIGINT is received
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
    defer stop()

    // Start server in a goroutine
    go func() {
        slog.Info("server starting", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            slog.Error("server failed", "error", err)
        }
    }()

    // Block until signal received (ctx cancelled)
    <-ctx.Done()
    stop() // release signal resources immediately
    slog.Info("shutdown signal received, draining connections")

    // Give in-flight requests time to complete
    // Must be < Kubernetes terminationGracePeriodSeconds
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
    defer cancel()

    if err := srv.Shutdown(shutdownCtx); err != nil {
        slog.Error("shutdown error", "error", err)
    }

    // Close other resources: database pool, message bus, etc.
    slog.Info("server stopped")
}
```

### Why `signal.NotifyContext` over `signal.Notify`

`signal.Notify` requires a `chan os.Signal` and manual goroutine management. `signal.NotifyContext` (Go 1.16) returns a `context.Context` that integrates naturally with the rest of Go's cancellation model. One `<-ctx.Done()` blocks until the signal arrives.

### The timing contract with Kubernetes

```
SIGTERM sent
     │
     ├─ 0s  : signal.NotifyContext cancels → Shutdown begins
     │         └ new connections rejected
     │         └ in-flight requests continue
     │
     ├─ 25s : shutdownCtx times out → Shutdown returns ErrShutdownTimeout
     │         (you should log this as a warning)
     │
     └─ 30s : Kubernetes sends SIGKILL → process killed
```

Always set the `Shutdown` context timeout to 5 seconds less than `terminationGracePeriodSeconds`. This gives the process a chance to log and clean up before being killed.

---

## Health check endpoints

Kubernetes (and ECS) use health checks to decide when to route traffic to a pod and when to restart it. There are two semantically distinct probes:

| | `/healthz` (liveness) | `/readyz` (readiness) |
|---|---|---|
| Question asked | "Is this process alive?" | "Can this process serve traffic?" |
| Failure action | Kubernetes restarts the pod | Kubernetes removes the pod from Service endpoints (no restart) |
| What to check | Is the process not deadlocked? Is memory not OOM? | Is the DB connection pool healthy? Is the cache warmed? |
| What NOT to check | Database connectivity | Internal process health only |
| Response on degraded dependency | 200 (process is fine) | 503 (not ready to serve) |
| Startup probe | Separate `/startupz` or use readiness with `failureThreshold` | Same `/readyz`, higher `failureThreshold` |

```go
// /healthz — always returns 200 unless the process is stuck
r.GET("/healthz", func(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{"status": "ok"})
})

// /readyz — checks actual dependencies
r.GET("/readyz", func(c *gin.Context) {
    ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        c.JSON(http.StatusServiceUnavailable, gin.H{
            "status": "not ready",
            "reason": "database unreachable",
        })
        return
    }
    c.JSON(http.StatusOK, gin.H{"status": "ready"})
})
```

### Why liveness must not check the database

If liveness checks the database and the database goes down, every pod restarts. Restarting pods does not fix the database — it just amplifies the blast radius. A liveness failure should mean "this process needs to be replaced", not "a dependency is degraded". Keep liveness simple.

### Routing health checks outside the middleware chain

Health checks must not require authentication tokens or pass through rate limiting middleware. Register them on the router before adding auth/rate-limit middleware, or use a separate `gin.Engine` on a different port:

```go
r := gin.New()

// Health endpoints — no auth, no rate limiting
r.GET("/healthz", healthzHandler)
r.GET("/readyz", readyzHandler)

// API endpoints — auth + rate limiting
api := r.Group("/api/v1", JWTMiddleware(secret), RateLimiter(10, 20))
{
    api.GET("/users", listUsers)
}
```

---

## 12-factor config via environment variables

12-factor app principle III: store config in the environment. No hardcoded ports, DSNs, secrets, or feature flags in source code.

```go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

type Config struct {
    Port            string
    DatabaseURL     string
    JWTSecret       []byte
    ShutdownTimeout time.Duration
    LogLevel        string
}

func Load() (*Config, error) {
    port := getEnv("PORT", "8080")
    dbURL := mustGetEnv("DATABASE_URL")    // fail fast if required config is missing
    jwtSecret := mustGetEnv("JWT_SECRET")
    shutdownSecs := getEnvInt("SHUTDOWN_TIMEOUT_SECS", 25)

    return &Config{
        Port:            port,
        DatabaseURL:     dbURL,
        JWTSecret:       []byte(jwtSecret),
        ShutdownTimeout: time.Duration(shutdownSecs) * time.Second,
        LogLevel:        getEnv("LOG_LEVEL", "info"),
    }, nil
}

func mustGetEnv(key string) string {
    v := os.Getenv(key)
    if v == "" {
        panic(fmt.Sprintf("required env var %s is not set", key))
    }
    return v
}

func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}

func getEnvInt(key string, fallback int) int {
    if v := os.Getenv(key); v != "" {
        if n, err := strconv.Atoi(v); err == nil {
            return n
        }
    }
    return fallback
}
```

`panic` on missing required config is intentional. Fail at startup with a clear message rather than failing later with a cryptic nil pointer dereference. This is the "fail fast" principle.

For more complex config, `github.com/caarlos0/env` or `github.com/kelseyhightower/envconfig` provide struct tag-based config loading with type conversion and validation.

---

## Returning engineer: what changed since 1.16–1.18

**`signal.NotifyContext` is new to you** (Go 1.16): it was added in Go 1.16, so you may have used the older `signal.Notify` pattern with a channel. Migrate to `signal.NotifyContext` — it integrates with `context.Context` and removes the goroutine boilerplate.

**`gcr.io/distroless` matured significantly**: in 2018-2019, distroless images were less common in Go projects. Alpine was the default. By 2022, distroless became the production default for Go services due to security scanning requirements (SOC 2, PCI, etc.) that penalize unnecessary packages.

**`log/slog` replaces `log` for structured logging** (Go 1.21): the stdlib `log` package writes unstructured text. `log/slog` writes structured JSON (`slog.Info("server starting", "addr", ":8080")`) without a third-party library. New codebases use `slog`; existing codebases use `zap` or `logrus`. Know both.

**`//go:embed` for static assets** (Go 1.16): if your service serves static files or OpenAPI specs, embed them in the binary with `//go:embed static/*`. No runtime filesystem reads, no missing files in containers. This works with `distroless` because there is no filesystem to read from anyway.

**Multi-arch builds**: Apple Silicon (ARM64) development vs AMD64 production is now standard. Add `--platform=linux/amd64` to your builder stage or use `docker buildx build --platform linux/amd64,linux/arm64` for multi-arch images. Without this, building on an M-series Mac produces ARM binaries that will not run in your x86 cluster.

---

## Key concepts to memorize
- Multi-stage Dockerfile: `builder` compiles, `runtime` runs — source code and toolchain never reach production
- Copy `go.mod`/`go.sum` before source code — this caches the dependency download layer
- `CGO_ENABLED=0` produces a static binary that runs in `distroless/static` or `scratch`
- `signal.NotifyContext(ctx, syscall.SIGTERM, syscall.SIGINT)` is the modern signal handling idiom (Go 1.16)
- Shutdown context timeout must be shorter than Kubernetes `terminationGracePeriodSeconds` by at least 5 seconds
- `/healthz` (liveness): is the process alive? Never check external dependencies
- `/readyz` (readiness): can the process serve traffic? Check DB, cache, etc.
- 12-factor: all config via env vars; panic on missing required config — fail at startup, not at request time

---

## Common mistakes

**1. Checking the database in the liveness probe**
A database outage triggers pod restarts. Restarting pods cannot fix the database. Liveness must only check the process itself — deadlock detection, memory limits, internal invariants. External dependency checks belong only in readiness.

**2. Not waiting for Shutdown to return before exiting**
```go
// Bad — exits immediately after Shutdown is called, may not drain
go srv.Shutdown(shutdownCtx)
os.Exit(0)  // kills in-flight requests

// Good — waits for Shutdown to drain
err := srv.Shutdown(shutdownCtx)
// now close DB pool and exit
```
`srv.Shutdown` is synchronous — it blocks until all active connections are closed or the context expires. Do not call it in a goroutine if you need to wait for completion.

**3. Using `os.Exit` in the signal handler**
`os.Exit` does not run deferred functions. If your DB pool close, metric flush, or log sync is in a `defer`, calling `os.Exit` bypasses it. Use structured shutdown (return from `main`) rather than `os.Exit`.

**4. Building on Apple Silicon without `--platform linux/amd64`**
The Docker builder will use the native architecture by default. A binary built on ARM64 silently copies into the image but panics or is not found when deployed to an x86 node. Always specify `FROM --platform=linux/amd64 golang:1.23-alpine AS builder` or use `docker buildx`.

**5. Routing health checks through auth middleware**
If `/readyz` requires a `Bearer` token, Kubernetes cannot call it. If `/readyz` counts against the rate limiter, it can trigger false positive 503s. Register health endpoints before adding auth and rate limit middleware to the router.

---

## Check your understanding

1. Your container runs in Kubernetes with `terminationGracePeriodSeconds: 30`. What timeout should you pass to `srv.Shutdown(ctx)`, and why?
2. A team member argues that checking database connectivity in `/healthz` gives better visibility into service health. Explain exactly what failure mode this creates in a production Kubernetes cluster.
3. Your Go binary is built on a MacBook Pro M3 with `docker build -t myapp .` and deployed to an ECS cluster running x86. Describe what happens at runtime and what one Dockerfile change fixes it.
