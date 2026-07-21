# Day 19 — Observability

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Distinguish logs, metrics, and traces and choose the right tool for each operational question
- Select the correct Prometheus metric type for a given use case
- Design structured log output with `slog`: key-value pairs, log levels, and handler selection
- Propagate OpenTelemetry trace context via W3C `traceparent` headers and create spans correctly
- Implement a health check aggregation endpoint that reflects real upstream status

---

## Core mental model

**Observability is about asking questions of a system in production — logs answer "what happened", metrics answer "how much", traces answer "where did time go".**

You cannot add observability after a production incident and wish you had it earlier. These three signals are not interchangeable:

- A log tells you that user `u_123` got a 502 at 14:32:05. It does not tell you whether this is happening to 1% or 80% of users.
- A metric tells you that your error rate is 3%. It does not tell you which request failed or why.
- A trace tells you that 450ms of a 500ms request was spent waiting on the `users` gRPC service. It does not tell you the error message from the upstream.

You need all three.

---

## The three pillars

### Logs — "what happened"

Logs are discrete, timestamped events. Each log line captures a specific occurrence with enough context to understand it in isolation.

Good log: `time=2026-07-21T14:32:05Z level=ERROR msg="upstream call failed" upstream=users path=/v1/users/123 error="deadline exceeded" request_id=req_abc123 latency_ms=5001`

Bad log: `ERROR: upstream call failed` — no context, not machine-parseable.

Use logs for:
- Request-level error detail (which request failed, with what error)
- Audit trail (who did what, when)
- Debug output during incident investigation

### Metrics — "how much"

Metrics are numeric measurements aggregated over time. They are cheap to store and fast to query.

Use metrics for:
- Alerting thresholds ("error rate > 1% for 5 minutes → page on-call")
- Capacity planning ("p99 latency is trending up over 7 days")
- SLO dashboards ("99.9% of requests in under 200ms this week")

### Traces — "where did time go"

A trace is a causal graph of spans. Each span represents one unit of work (an HTTP request, a database call, a gRPC call). Spans are linked by a shared trace ID.

Use traces for:
- Root-cause analysis of latency ("the slow requests all have a slow `redis.Get` span")
- Service dependency mapping ("which services does this endpoint actually call?")
- Distributed debugging across service boundaries

---

## Prometheus metric types

| Type | Definition | Use Case | Example metric name |
|---|---|---|---|
| **Counter** | Monotonically increasing integer; never decreases (except on process restart) | Counting events that accumulate: requests, errors, bytes sent | `http_requests_total`, `gateway_upstream_errors_total` |
| **Gauge** | Value that can go up or down freely | Current state or level: active connections, goroutines, queue depth | `goroutines_active`, `upstream_pool_idle_connections` |
| **Histogram** | Samples observations in configurable buckets; exposes `_count`, `_sum`, and `_bucket` series | Latency, request size, response size distributions — when you need percentiles | `http_request_duration_seconds`, `grpc_call_duration_seconds` |
| **Summary** | Like histogram but pre-computes quantiles client-side | Rarely used in new code; prefer histogram for server-side aggregation | `go_gc_duration_seconds` (stdlib) |

### Choosing between counter, gauge, and histogram

**Use a counter when:** you are counting something that only goes up. Request counts, errors, retries, bytes sent.

```go
var httpRequestsTotal = prometheus.NewCounterVec(
    prometheus.CounterOpts{
        Name: "http_requests_total",
        Help: "Total number of HTTP requests by method, path, and status.",
    },
    []string{"method", "path", "status"},
)

// In your handler:
httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(statusCode)).Inc()
```

**Use a gauge when:** you are measuring something that fluctuates. Connection pool sizes, queue depth, in-flight requests.

```go
var inFlightRequests = prometheus.NewGauge(
    prometheus.GaugeOpts{
        Name: "gateway_requests_in_flight",
        Help: "Number of requests currently being processed.",
    },
)

// In middleware:
inFlightRequests.Inc()
defer inFlightRequests.Dec()
```

**Use a histogram when:** you care about the distribution. Latency is the canonical example — the mean hides the tail. A histogram lets Prometheus compute `histogram_quantile(0.99, ...)` on the server.

```go
var requestDuration = prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
        Name:    "http_request_duration_seconds",
        Help:    "HTTP request latency distribution.",
        // Buckets: tune to your SLO. These cover 1ms–10s.
        Buckets: prometheus.DefBuckets, // .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10
    },
    []string{"method", "path"},
)

// In middleware:
start := time.Now()
defer func() {
    requestDuration.WithLabelValues(r.Method, r.URL.Path).
        Observe(time.Since(start).Seconds())
}()
```

### Registering metrics

Always register metrics at package init time or in a dedicated `metrics.go` file. Registering in a request handler causes a panic (duplicate registration) on the second request.

```go
func init() {
    prometheus.MustRegister(httpRequestsTotal, inFlightRequests, requestDuration)
}
```

---

## `slog` structured logging (Go 1.21)

`slog` is the standard library's structured logging package. It replaced the ad-hoc ecosystem of `logrus`, `zap`, and `zerolog` for new code.

### Core concepts

- **Logger**: the public API. `slog.Info(msg, args...)`, `slog.Error(msg, args...)`, `slog.InfoContext(ctx, msg, args...)`
- **Handler**: the backend. `slog.TextHandler` (logfmt), `slog.JSONHandler` (JSON). Swap the handler without changing logging call sites.
- **Attrs**: typed key-value pairs. `slog.String("key", "val")`, `slog.Int("n", 42)`, `slog.Duration("latency", d)`
- **Level**: `Debug`, `Info`, `Warn`, `Error` — levels are integers, easy to extend

### Setting up JSON logging for production

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
    // AddSource adds file:line — useful in staging, overhead in prod
    AddSource: false,
}))
slog.SetDefault(logger)
```

Once `slog.SetDefault` is called, the package-level functions (`slog.Info`, `slog.Error`) use this logger.

### Key-value logging patterns

```go
// Inline key-value (alternating string key, any value)
slog.Info("request completed",
    "method", r.Method,
    "path", r.URL.Path,
    "status", statusCode,
    "latency_ms", latency.Milliseconds(),
    "request_id", requestID,
)

// Typed attrs — preferred for performance (avoids interface{} boxing)
slog.Info("request completed",
    slog.String("method", r.Method),
    slog.String("path", r.URL.Path),
    slog.Int("status", statusCode),
    slog.Int64("latency_ms", latency.Milliseconds()),
)

// Context-aware — carries trace ID from context automatically if wired up
slog.InfoContext(ctx, "gRPC call complete",
    "upstream", upstreamName,
    "duration_ms", duration.Milliseconds(),
)
```

### Request-scoped logger

Create a child logger with request-specific fields at the start of each request. Pass it via context. All log calls within that request automatically carry the request ID.

```go
func withRequestLogger(ctx context.Context, requestID string) context.Context {
    logger := slog.Default().With(
        "request_id", requestID,
        "trace_id", traceIDFromContext(ctx),
    )
    return context.WithValue(ctx, loggerKey{}, logger)
}

func loggerFromContext(ctx context.Context) *slog.Logger {
    if l, ok := ctx.Value(loggerKey{}).(*slog.Logger); ok {
        return l
    }
    return slog.Default()
}
```

---

## OpenTelemetry trace context propagation

### W3C TraceContext header

The `traceparent` header is the W3C standard for propagating trace context across service boundaries. Format:

```
traceparent: 00-<trace-id>-<parent-span-id>-<flags>
             ┬─  ────┬───  ──────┬────────   ──┬──
             │       │           │              └── 01 = sampled, 00 = not sampled
             │       │           └── 16-byte parent span ID (hex)
             │       └── 32-hex-char trace ID (globally unique per request)
             └── version (always 00 currently)
```

Example: `traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`

### Setting up OpenTelemetry in Go

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/trace"
)

// At startup: configure the global propagator
otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
    propagation.TraceContext{}, // W3C traceparent
    propagation.Baggage{},      // W3C baggage (optional)
))

// Configure a TracerProvider (e.g., OTLP exporter to Jaeger or Tempo)
// ... omitted: provider setup depends on your backend
```

### Creating spans in middleware

```go
import "go.opentelemetry.io/otel/semconv/v1.21.0"

func TracingMiddleware() gin.HandlerFunc {
    tracer := otel.Tracer("gateway")
    return func(c *gin.Context) {
        // Extract incoming trace context from HTTP headers
        ctx := otel.GetTextMapPropagator().Extract(
            c.Request.Context(),
            propagation.HeaderCarrier(c.Request.Header),
        )

        // Start a new span for this request
        ctx, span := tracer.Start(ctx, c.FullPath(),
            trace.WithSpanKind(trace.SpanKindServer),
        )
        defer span.End()

        // Add standard HTTP attributes
        span.SetAttributes(
            semconv.HTTPRequestMethodKey.String(c.Request.Method),
            semconv.URLPath(c.Request.URL.Path),
        )

        // Store in context and continue
        c.Request = c.Request.WithContext(ctx)
        c.Next()

        // Record response status after handler runs
        span.SetAttributes(semconv.HTTPResponseStatusCode(c.Writer.Status()))
    }
}
```

### Propagating trace context to gRPC upstreams

When making a gRPC call from within a traced request, inject the trace context into the gRPC metadata:

```go
import "go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"

// At gRPC client creation: add the OTel interceptor
conn, err := grpc.NewClient(addr,
    grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
)
```

The `otelgrpc` interceptor automatically:
1. Extracts the trace context from the outgoing context
2. Injects it as gRPC metadata (`traceparent`)
3. Creates a child span for the gRPC call

---

## Health check aggregation

A gateway should expose two health endpoints that load balancers and orchestrators use:

| Endpoint | Purpose | Returns unhealthy when |
|---|---|---|
| `GET /healthz` | **Liveness**: is the process alive? | Never (if it can respond, it's alive) |
| `GET /readyz` | **Readiness**: can it serve traffic? | Any upstream is unreachable |

```go
type HealthChecker struct {
    upstreams []UpstreamCheck
}

type UpstreamCheck struct {
    Name string
    URL  string // e.g., "https://users-svc:8080/healthz"
}

type HealthResponse struct {
    Status  string                 `json:"status"`            // "ok" or "degraded"
    Checks  map[string]CheckResult `json:"checks"`
}

type CheckResult struct {
    Status  string `json:"status"`            // "ok" or "error"
    Message string `json:"message,omitempty"`
}

func (h *HealthChecker) Readyz(c *gin.Context) {
    results := make(map[string]CheckResult, len(h.upstreams))
    allOK := true

    for _, u := range h.upstreams {
        ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
        defer cancel()

        req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.URL, nil)
        resp, err := http.DefaultClient.Do(req)
        if err != nil || resp.StatusCode >= 300 {
            results[u.Name] = CheckResult{Status: "error", Message: err.Error()}
            allOK = false
        } else {
            results[u.Name] = CheckResult{Status: "ok"}
        }
    }

    status := http.StatusOK
    statusStr := "ok"
    if !allOK {
        status = http.StatusServiceUnavailable
        statusStr = "degraded"
    }

    c.JSON(status, HealthResponse{Status: statusStr, Checks: results})
}
```

### Health check design principles

- **Liveness never fails** (if the process can answer, it is alive). Kubernetes uses liveness to decide whether to restart a pod.
- **Readiness fails when the service cannot do useful work.** Kubernetes uses readiness to stop sending traffic without restarting the pod.
- **Aggregate, don't chain.** Check all upstreams in parallel with a short timeout (1–2s). A slow upstream should not slow down the health check.
- **Do not call database-heavy paths** in health checks. Use a simple ping or a dedicated `/ping` endpoint on upstreams.

---

## Returning engineer: what changed since 1.16–1.18

| Area | Change | Version |
|---|---|---|
| Structured logging | `slog` added to the standard library — replaces logrus/zap for new code | Go 1.21 |
| OpenTelemetry | OTel Go SDK reached stable (1.0) — safe to adopt in production | otel v1.0 (Oct 2021) |
| Prometheus | `prometheus/client_golang` v1.12+ uses a new `NewRegistry` model; `MustRegister` still works | v1.12 (2022) |
| W3C TraceContext | Became the dominant standard — replace Zipkin `b3` headers for new services | ~2020 onwards |
| `expvar` / `pprof` | `net/http/pprof` still present — now often alongside `promhttp.Handler()` | unchanged |

The biggest practical change: `slog` replaces the need for third-party logging libraries in most projects. If you have existing `logrus` code, migration is mechanical but not urgent — `logrus` still works. For new services, use `slog` from day one.

---

## Key concepts to memorize

- Logs = events (what happened); Metrics = numbers (how much/many); Traces = graphs (where did time go)
- Counter: goes up only. Gauge: goes up and down. Histogram: distribution with configurable buckets
- `slog.SetDefault` makes a logger the global default used by `slog.Info/Error/etc`
- `W3C traceparent` format: `version-traceID-parentSpanID-flags` — 32-hex trace ID
- Health check: `/healthz` = liveness (never fails), `/readyz` = readiness (fails when upstreams are down)
- `prometheus.DefBuckets` covers .005 to 10 seconds — suitable for HTTP latency; tune for your SLO

---

## Common mistakes

1. **Putting latency in a gauge instead of a histogram.** A gauge can only show the current value — you lose the ability to compute percentiles. Latency is always a histogram.

2. **Creating high-cardinality labels.** Adding `user_id` or `request_id` as a Prometheus label creates one time series per unique value. With millions of users, this blows up Prometheus memory. Labels should have low cardinality (method, path, status, upstream — not user IDs).

3. **Not propagating the trace context to outgoing gRPC calls.** If you forget to pass the `ctx` that carries the trace context, each gRPC call starts a new root span. The distributed trace breaks and you cannot see the full request chain.

4. **Making the readiness check too strict.** If `/readyz` fails when any optional cache is warming up, Kubernetes never routes traffic to the pod and it thrashes. Only mark unready when the service truly cannot serve requests.

5. **Logging at DEBUG level in production with `slog.SetDefault`.** If you set the level to `Debug`, every log line fires, including framework internals. Set level to `Info` in production and `Debug` in development.

---

## Check your understanding

1. Your gateway serves 10,000 requests per second. You want to alert when p99 latency exceeds 500ms. Which Prometheus metric type do you use, and write the PromQL query that computes p99 latency over a 5-minute window.

2. A distributed trace shows a 400ms gap between the end of a Gin handler span and the start of the downstream gRPC span. The gRPC call itself takes 50ms. What does this gap likely indicate, and what would you look at first?

3. Your `/readyz` endpoint checks all three downstream services. Service C is non-critical (a recommendation engine). When Service C is unhealthy, Kubernetes stops sending traffic to your gateway pod even though it can still serve requests without Service C. How do you fix this?
