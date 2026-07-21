# Day 15 — gRPC Resilience + Observability

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Explain how gRPC deadlines propagate transitively through service chains and why HTTP timeouts do not
- Configure retry with exponential backoff using the gRPC service config
- Set keepalive parameters on both client and server to prevent silent connection drops
- Implement the gRPC health checking protocol (`grpc_health_v1`) for load balancer integration
- Add request count and latency histogram metrics via a Prometheus interceptor
- Write a structured logging interceptor that captures method, status, and duration

---

## Core mental model

**A deadline is a contract between caller and callee — set it once at the edge, and it flows through every hop automatically.**

When an API gateway sets a 2-second deadline on a request, that deadline is embedded in the gRPC metadata and forwarded to every downstream service the handler calls. Each downstream service sees the *remaining* time, not a fresh timeout. If Service A consumes 1.5 seconds, Service B automatically gets only 0.5 seconds before its context is already cancelled.

```
Client (sets deadline: 2s)
  │
  ▼ 0ms elapsed
Service A  [deadline remaining: 2000ms]
  │  A processes 1500ms
  ▼ 1500ms elapsed
Service B  [deadline remaining: 500ms]
  │  B processes 600ms
  ▼ 2100ms elapsed — DEADLINE_EXCEEDED
```

With HTTP timeouts, each hop sets its own independent timeout. A 2-second timeout at the gateway plus a 5-second timeout at Service A means a request can take up to 7 seconds end-to-end before the gateway gives up. The user sees a 2-second failure, but backend resources were consumed for 7 seconds.

---

## Deadline propagation

### Setting a deadline on the client

```go
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()

resp, err := client.GetOrder(ctx, &pb.GetOrderRequest{Id: orderID})
if status.Code(err) == codes.DeadlineExceeded {
    log.Error("deadline exceeded calling GetOrder")
}
```

### Forwarding a deadline to a downstream client

```go
func (s *server) ProcessOrder(ctx context.Context, req *pb.ProcessOrderRequest) (*pb.ProcessOrderResponse, error) {
    // DO NOT derive a new timeout here — propagate the incoming context
    // The incoming ctx already carries the remaining deadline from the caller
    inventory, err := s.inventoryClient.CheckStock(ctx, &inventorypb.CheckStockRequest{
        ProductId: req.ProductId,
    })
    // ...
}
```

The key insight: pass `ctx` directly to downstream calls. Do not create `context.WithTimeout(ctx, 5*time.Second)` inside a handler unless you have a specific reason to *shorten* the deadline for that hop. Extending it is impossible — deadlines can only shrink.

### Checking remaining deadline before expensive work

```go
func (s *server) HeavyOperation(ctx context.Context, req *pb.Req) (*pb.Resp, error) {
    if deadline, ok := ctx.Deadline(); ok {
        if time.Until(deadline) < 100*time.Millisecond {
            return nil, status.Error(codes.DeadlineExceeded, "insufficient time remaining")
        }
    }
    // proceed with expensive work
}
```

---

## HTTP timeout vs gRPC deadline: propagation comparison

| Behaviour | HTTP timeout | gRPC deadline |
|-----------|-------------|---------------|
| Where it lives | Client config, per-hop | Request metadata (`grpc-timeout` header), end-to-end |
| Propagated to downstream? | No — each hop sets its own | Yes — remaining time propagates automatically |
| Can be extended by a hop? | Yes (downstream sets a longer timeout) | No — deadlines can only decrease |
| Client receives error after? | Gateway timeout (504) at edge | `DEADLINE_EXCEEDED` anywhere in the chain |
| Remaining time visible to server? | No | Yes — `ctx.Deadline()` returns it |
| What happens if forwarding context? | Timeout is lost | Deadline is carried |
| Resource waste on timeout | High (downstreams keep running) | Low (all hops cancel together) |

---

## Retry with exponential backoff

Use gRPC's service config to declare retry policy — this is declarative and lives in the dial config, not scattered across call sites.

```go
serviceConfig := `{
  "methodConfig": [{
    "name": [{"service": "payments.v1.PaymentService"}],
    "retryPolicy": {
      "maxAttempts": 4,
      "initialBackoff": "0.1s",
      "maxBackoff": "2s",
      "backoffMultiplier": 2.0,
      "retryableStatusCodes": ["UNAVAILABLE", "RESOURCE_EXHAUSTED"]
    }
  }]
}`

conn, err := grpc.NewClient(
    target,
    grpc.WithDefaultServiceConfig(serviceConfig),
    grpc.WithTransportCredentials(insecure.NewCredentials()),
)
```

**Retryable status codes — the safe list:**

- `UNAVAILABLE` — server is not reachable or temporarily overloaded (safe to retry)
- `RESOURCE_EXHAUSTED` — rate limit hit (retry after backoff)

**Do not retry:**

- `INTERNAL` — may have succeeded before failing; retrying can cause duplicate side effects
- `DEADLINE_EXCEEDED` — the deadline has passed; a retry would fail immediately
- `NOT_FOUND` / `INVALID_ARGUMENT` / `PERMISSION_DENIED` — retrying won't change the outcome

---

## Keepalive

TCP connections can appear live at the OS level while being silently dead (e.g., a firewall dropped the connection without sending RST). Keepalive probes detect this.

### Server keepalive parameters

```go
import "google.golang.org/grpc/keepalive"

grpc.NewServer(
    grpc.KeepaliveParams(keepalive.ServerParameters{
        MaxConnectionIdle:     15 * time.Minute,  // close idle connection after 15min
        MaxConnectionAge:      30 * time.Minute,  // max connection lifetime (forces reconnect)
        MaxConnectionAgeGrace: 5 * time.Second,   // grace period after MaxConnectionAge
        Time:                  5 * time.Minute,   // send keepalive ping after 5min idle
        Timeout:               20 * time.Second,  // close if ping not ACKed in 20s
    }),
    grpc.KeepaliveEnforcementPolicy(keepalive.EnforcementPolicy{
        MinTime:             5 * time.Second,  // minimum interval between client pings
        PermitWithoutStream: true,             // allow pings with no active streams
    }),
)
```

### Client keepalive parameters

```go
grpc.NewClient(
    target,
    grpc.WithKeepaliveParams(keepalive.ClientParameters{
        Time:                10 * time.Second,  // send ping after 10s idle
        Timeout:             20 * time.Second,  // close if no response within 20s
        PermitWithoutStream: true,
    }),
)
```

**Practical tuning:**
- `MaxConnectionAge` forces periodic reconnection — important for load balancer connection draining during deployments.
- If the client pings more frequently than `MinTime` on the server, the server will send a `GOAWAY` and close the connection. Always set client `Time` ≥ server `MinTime`.

---

## gRPC health checking protocol

The `grpc_health_v1` protocol is the standard way for load balancers and orchestrators (ECS, Kubernetes) to check service health. It is a real gRPC service defined by Google.

### Implementing the health server

```go
import (
    "google.golang.org/grpc/health"
    healthpb "google.golang.org/grpc/health/grpc_health_v1"
)

s := grpc.NewServer()

// Register your service
pb.RegisterPaymentServiceServer(s, &paymentServer{})

// Register the health server
healthSrv := health.NewServer()
healthpb.RegisterHealthServer(s, healthSrv)

// Set initial status
healthSrv.SetServingStatus("payments.v1.PaymentService", healthpb.HealthCheckResponse_SERVING)

// Update status dynamically when dependencies change
go func() {
    for {
        if db.Ping() != nil {
            healthSrv.SetServingStatus("payments.v1.PaymentService", healthpb.HealthCheckResponse_NOT_SERVING)
        } else {
            healthSrv.SetServingStatus("payments.v1.PaymentService", healthpb.HealthCheckResponse_SERVING)
        }
        time.Sleep(10 * time.Second)
    }
}()
```

### Testing the health endpoint

```bash
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
# {"status":"SERVING"}

grpc-health-probe -addr=localhost:50051 -service=payments.v1.PaymentService
# status: SERVING
```

`grpc-health-probe` is a standalone binary used in ECS health checks (covered in Day 16).

---

## Prometheus metrics via interceptors

### Metrics to collect

| Metric | Type | Labels |
|--------|------|--------|
| `grpc_server_started_total` | Counter | `grpc_service`, `grpc_method`, `grpc_type` |
| `grpc_server_handled_total` | Counter | `grpc_service`, `grpc_method`, `grpc_type`, `grpc_code` |
| `grpc_server_handling_seconds` | Histogram | `grpc_service`, `grpc_method`, `grpc_type` |

### Writing a metrics interceptor

```go
var (
    rpcDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "grpc_server_handling_seconds",
        Help:    "Histogram of response latency for gRPC calls.",
        Buckets: prometheus.DefBuckets,
    }, []string{"grpc_service", "grpc_method", "grpc_code"})

    rpcTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
        Name: "grpc_server_handled_total",
        Help: "Total number of RPCs completed.",
    }, []string{"grpc_service", "grpc_method", "grpc_code"})
)

func MetricsInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {
    start := time.Now()
    resp, err := handler(ctx, req)

    // info.FullMethod = "/payments.v1.PaymentService/GetPayment"
    parts := strings.SplitN(strings.TrimPrefix(info.FullMethod, "/"), "/", 2)
    svc, method := parts[0], parts[1]
    code := status.Code(err).String()

    rpcDuration.WithLabelValues(svc, method, code).Observe(time.Since(start).Seconds())
    rpcTotal.WithLabelValues(svc, method, code).Inc()

    return resp, err
}
```

In practice, use `go-grpc-prometheus` or `grpc-ecosystem/go-grpc-middleware/providers/prometheus` — they implement all three metrics with correct label handling and streaming support. Write the above once from scratch to understand the shape, then use the library.

### Exposing the metrics endpoint

```go
// Serve Prometheus metrics on a separate port (not your gRPC port)
go func() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":9090", nil)
}()
```

---

## Structured logging in interceptors

```go
func LoggingInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {
    start := time.Now()

    // Extract trace ID from metadata for correlation
    md, _ := metadata.FromIncomingContext(ctx)
    traceID := ""
    if vals := md.Get("x-trace-id"); len(vals) > 0 {
        traceID = vals[0]
    }

    resp, err := handler(ctx, req)

    fields := []slog.Attr{
        slog.String("method", info.FullMethod),
        slog.String("code", status.Code(err).String()),
        slog.Duration("duration", time.Since(start)),
        slog.String("trace_id", traceID),
    }
    if err != nil {
        fields = append(fields, slog.String("error", err.Error()))
        slog.LogAttrs(ctx, slog.LevelError, "rpc completed", fields...)
    } else {
        slog.LogAttrs(ctx, slog.LevelInfo, "rpc completed", fields...)
    }

    return resp, err
}
```

Log `status.Code(err)` not `err.Error()`. The code is structured and queryable in log aggregators. The error message is human-readable context.

---

## Returning engineer: what changed since 1.16–1.18

- **`slog` is the standard library structured logger (Go 1.21).** The `log` package and `log.Printf` are now legacy for server code. `slog` has structured attributes, levelled output, and JSON handlers — use it in all interceptors.
- **gRPC service config retry is production-ready.** In the 1.16 era, retry was experimental or required manual implementation. The `retryPolicy` service config field is now stable and the preferred approach.
- **`grpc.Dial` is deprecated in favour of `grpc.NewClient`.** The semantic difference: `grpc.Dial` began connecting immediately; `grpc.NewClient` is lazy (connects on first use). Most production code should use `grpc.NewClient`.
- **`grpc-ecosystem/go-grpc-middleware/v2` is the 2024 standard for interceptor libraries.** v1 is still widely used but the v2 rewrite has better composition, streaming support, and uses the modern gRPC interceptor types. If you're starting a new service, use v2.
- **`grpc_health_v1` is built into the `google.golang.org/grpc/health` package.** In the 1.16 era it sometimes required a separate proto compilation step. It ships with the gRPC module now.
- **`context/slog` zero-allocation logging path.** `slog.LogAttrs` avoids allocations compared to `slog.With(...).Info(...)`. In a high-throughput interceptor, this matters.

---

## Key concepts to memorize

- Deadline propagates transitively via context; HTTP timeout does not — it is per-hop
- Deadlines can only shrink downstream; passing `ctx` directly preserves the contract
- Retry safe codes: `UNAVAILABLE`, `RESOURCE_EXHAUSTED`; never retry `INTERNAL` or `DEADLINE_EXCEEDED`
- Client keepalive `Time` must be ≥ server `MinTime` or server sends `GOAWAY`
- `MaxConnectionAge` forces periodic reconnect — essential for graceful deployment draining
- `grpc_health_v1` is a real gRPC service; register it alongside your business services
- Log `status.Code(err)` (structured) not `err.Error()` (unstructured) in interceptors

---

## Common mistakes

**1. Creating a new timeout context in every handler instead of forwarding the incoming context**

*Why it matters:* `context.WithTimeout(ctx, 5*time.Second)` inside a handler caps the downstream call at 5 seconds even if the incoming deadline is 100ms. The service might succeed from its own perspective while the client has already timed out and moved on. Worse, 5 seconds of wasted work accumulates under load.

*How to avoid:* Pass `ctx` directly to all downstream calls. Only shorten a deadline (with `context.WithTimeout`) when you have a specific SLA reason to do so — and document it.

**2. Retrying `DEADLINE_EXCEEDED`**

*Why it matters:* A retried call under an expired deadline fails immediately with `DEADLINE_EXCEEDED` again — you've added latency without any chance of success. In a retry loop, this creates a burst of failing calls.

*How to avoid:* `DEADLINE_EXCEEDED` is not in the safe retry list. Check `ctx.Err()` before retrying — if the context is already cancelled, return immediately.

**3. Setting client keepalive `Time` shorter than server `MinTime`**

*Why it matters:* The server interprets this as a misbehaving client and sends a `GOAWAY` frame, forcibly closing the connection. Your client reconnects, hits the same policy, and disconnects again — creating a reconnect storm.

*How to avoid:* Set client `Time` ≥ server `MinTime`. A safe default: server `MinTime = 5s`, client `Time = 10s`.

**4. Registering the health server with `SetServingStatus("")` but not the specific service name**

*Why it matters:* Load balancers query with the specific service name (e.g., `"payments.v1.PaymentService"`). If you only set the empty-string service status, the health check returns `NOT_FOUND` for the specific service, and ECS marks your task as unhealthy.

*How to avoid:* Call `healthSrv.SetServingStatus("your.package.ServiceName", SERVING)` with the exact proto service name. Also set the empty string as a catch-all: `healthSrv.SetServingStatus("", SERVING)`.

**5. Exposing the Prometheus `/metrics` endpoint on the same port as gRPC**

*Why it matters:* gRPC uses HTTP/2 exclusively. Prometheus scraping uses HTTP/1.1. Serving both on the same port requires protocol negotiation (ALPN), which complicates TLS setup significantly. Most cloud scrapers don't support HTTP/2 anyway.

*How to avoid:* Always serve `/metrics` on a separate HTTP port (conventionally 9090 or a dedicated sidecar port). Two listeners, two goroutines, no conflict.

---

## Check your understanding

1. Service A receives a request with a 3-second deadline. It spends 2.8 seconds processing, then calls Service B. Service B has a local timeout configured to 2 seconds. What deadline does Service B's context have, and what happens when Service B tries to make a downstream call to Service C?

2. Your retry policy includes `INTERNAL` in `retryableStatusCodes`. A payment handler returns `INTERNAL` because it partially committed a database transaction before failing. What is the concrete production risk of retrying this, and what should you do instead?

3. You notice that under load, some gRPC connections silently stop receiving messages even though no error is returned. No new connections are being created. Which configuration parameter is most likely the root cause, and what values would you set on both the server and client to diagnose and fix it?
