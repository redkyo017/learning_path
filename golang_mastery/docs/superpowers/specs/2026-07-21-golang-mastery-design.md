# Go Mastery Plan — Design Spec

**Date:** 2026-07-21  
**Duration:** 20+ days (extendable), 5–6 hrs/day  
**Audience:** Returning senior Go engineer (3–4 years away, was on Go 1.16–1.18)

---

## Context & Goals

The learner is a senior backend/Go engineer who moved into engineering management and is now returning to individual contributor work. The goal is to sharpen Go skills as fast as possible — not from scratch, but by:

1. Closing the 1.16→1.22+ ecosystem gap (generics, `slog`, `slices`/`maps`, workspace mode, new toolchain)
2. Re-establishing Go muscle memory through daily hands-on builds
3. Reaching production-ready depth in microservices and cloud-native Go (AWS)
4. Delivering a portfolio-quality capstone: an API gateway

The plan is **not strictly 15 days** — it is extendable. Each phase is a self-contained module. Extension modules slot in after the core without restructuring.

---

## Constraints

- 5–6 hours per day
- AWS as target cloud (consistent with existing learning plans in this repo)
- Must be extendable: new phases or modules can be added without changing existing ones
- No tutorial-following: every day involves building something real, not typing along with docs
- No framework-first: stdlib before abstractions, always

---

## Core Design Principles

1. **Ecosystem-gap first** — Phase 1 is non-negotiable even for a senior returner. Four years of drift will silently pollute every phase after it if not addressed upfront.
2. **Ship something every phase** — Each phase ends with a running, containerized artifact suitable for a portfolio.
3. **Build-to-learn** — Each day: read the concept (1 hr) → implement a real use case (3.5 hrs) → review idiomatic examples from real Go projects (1 hr) → write a short note on what surprised you (0.5 hr).
4. **Unconventional approach** — The top 1% learn by reading production codebases (stdlib, Gin, etcd, Kubernetes source), not just docs. One real codebase read per day.
5. **Gin gets real depth** — Full 2-day block (Days 7–8), not a survey. Framework after stdlib so it maps to something understood.
6. **Extendable by design** — Core phases are independent modules. Extensions (E1–E4) slot in cleanly after Day 20.

---

## Daily Rhythm (5–6 hrs)

| Block | Time | Activity |
|---|---|---|
| Concept | 1 hr | Read official docs + one real codebase example |
| Build | 3.5 hrs | Hands-on implementation of the day's artifact |
| Review | 1 hr | Read idiomatic Go from a real project (stdlib, Gin, etcd, etc.) |
| Reflect | 0.5 hr | Short written note: what surprised you, what clicked, what's unclear |

---

## Phase Map

| Phase | Days | Focus | Deliverable |
|---|---|---|---|
| 1 | 1–5 | Modern Go re-calibration + concurrency | Concurrent CLI tool (parallel URL health checker) |
| 2 | 6–11 | HTTP stdlib + Gin REST microservice | Containerized REST API (PostgreSQL, JWT, tests) |
| 3 | 12–16 | gRPC + Protobuf + service patterns | gRPC service deployed on AWS ECS |
| 4 | 17–20+ | Capstone: API Gateway | Gin edge + gRPC proxy, full observability |
| E1–E4 | Optional | Kafka, K8s, AWS SDK, profiling | Modular extensions |

---

## Phase 1 — Modern Go Re-calibration (Days 1–5)

**Goal:** Rebuild muscle memory and close the 1.16→1.22+ gap before touching any framework.

**Deliverable:** Concurrent CLI tool — a parallel URL health checker that fans out goroutines, respects context cancellation, uses `errgroup`, outputs structured logs via `slog`, and uses post-1.18 idioms throughout.

### Day 1 — Toolchain & Project Layout

- Workspace mode (`go.work`) — new in 1.18, critical for multi-module repos
- `go.mod` toolchain directive (1.21+)
- New build constraint syntax (`//go:build` replaces `// +build`)
- `go install` vs `go get` separation
- Standard project layout: `cmd/`, `internal/`, `pkg/`
- **Setup:** Create the repo workspace (`go.work`) that will hold all four phase modules

### Day 2 — Generics

- Type parameters, constraints (`comparable`, `any`, custom interfaces as constraints)
- Type inference
- Real patterns: generic `Map`/`Filter`/`Reduce`, typed cache, result/error wrapper
- **Critical judgment:** when generics vs interfaces — the rule: if an interface solves it, use an interface; generics are for algorithms over collections and type-safe containers
- Common mistake to avoid: writing generic functions where a concrete type with methods is cleaner

### Day 3 — Modern Stdlib

- `slices` package — replaces `sort.Slice` boilerplate entirely
- `maps` package
- `cmp` package (ordered comparison, `cmp.Compare`)
- `slog` — structured logging now in stdlib; replaces most `logrus`/`zap` use cases for new projects
- `errors.Is` / `errors.As` / `errors.Unwrap` — the Go error wrapping model, fully internalized

### Day 4 — Concurrency Fundamentals Re-calibration

- Goroutines, channels, `select`
- `sync` package: `Mutex`, `RWMutex`, `WaitGroup`, `Once`, `atomic`
- `context` propagation patterns: cancellation trees, deadline inheritance, `context.WithCancelCause` (1.20)
- Goroutine leak detection — write a deliberately leaky program, then fix it
- `sync.Mutex` vs `sync/atomic` tradeoffs

### Day 5 — Concurrency Patterns + Deliverable

- Worker pool pattern
- Fan-in/fan-out pipeline
- `errgroup` (golang.org/x/sync) — idiomatic N-goroutine error collection
- Timeout patterns with context
- **Build deliverable:** parallel URL health checker
  - Accepts URLs from stdin
  - Fan-out with configurable worker pool size
  - Global timeout via context
  - Results collected with `errgroup`
  - Structured JSON output via `slog`

---

## Phase 2 — HTTP + Gin Microservice (Days 6–11)

**Goal:** Build a production-quality REST API with real middleware, auth, database, tests, and container deployment.

**Deliverable:** Containerized REST API — a resource service (e.g. task or inventory) with Gin, JWT auth, PostgreSQL, integration tests, graceful shutdown, and multi-stage Dockerfile. This becomes the upstream REST service the Phase 4 gateway sits in front of.

### Day 6 — `net/http` Deep Dive

- `http.Handler` interface — the single abstraction everything Go HTTP is built on
- `http.ServeMux` and its limitations (why routers exist)
- Middleware as handler wrappers — the pattern Gin's middleware is built on
- Full request lifecycle: parsing → routing → handling → response
- **Exercise:** Build a small working API from scratch with zero dependencies
- **Goal:** On Day 7, every Gin abstraction maps to something already understood

### Day 7 — Gin Fundamentals

- What Gin adds over stdlib: radix tree router, `gin.Context`, param binding, validation helpers
- Router groups, path params, query params
- `ShouldBindJSON` with struct validation tags (`binding:"required,email"`)
- `c.AbortWithStatusJSON` error flow
- **Exercise:** Rewrite the Day 6 API in Gin — the diff makes the value clear

### Day 8 — Gin Middleware (Gin Day 2)

- Writing custom middleware from scratch: auth, request logging with `slog`, CORS
- JWT authentication middleware end-to-end: generate + validate tokens, attach claims to context
- Rate limiting with token bucket
- Gin's abort mechanism: how `c.Abort()` short-circuits the middleware chain
- Gin's built-in recovery middleware
- **Rule:** No business logic in middleware — enforced by design
- **Outcome:** A reusable middleware stack ready to ship

### Day 9 — Database Integration

- `database/sql` + `pgx` as PostgreSQL driver
- Connection pool configuration: `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`
- Repository pattern with interfaces — enables Day 10 testing without a live DB
- Schema migrations with `golang-migrate`
- **Exercise:** Write a repository with a concrete `*sql.DB` implementation and an in-memory mock behind the same interface

### Day 10 — Testing

- Table-driven tests — the Go idiom, used everywhere
- `httptest.NewRecorder` for HTTP handler tests without a server
- Mocking via interfaces (no `gomock`/`mockery` needed for most cases)
- `testcontainers-go` for database integration tests with a real PostgreSQL container
- Benchmark tests (`testing.B`) — relevant for gateway later
- **Rule:** Unit tests with interface mocks for business logic; integration tests with real containers for DB layer

### Day 11 — Containerization + Graceful Shutdown + Deliverable

- Multi-stage Dockerfile: Alpine builder + `distroless` runtime (image size matters in K8s)
- Health check endpoints: `/healthz` (liveness), `/readyz` (readiness)
- Graceful shutdown: `signal.NotifyContext` + context cancellation through the server
- 12-factor config via env vars
- `docker-compose` for local dev with PostgreSQL
- **Deliverable:** Service runs identically locally and in container

---

## Phase 3 — gRPC + Protobuf (Days 12–16)

**Goal:** Build a gRPC backend service. Understand not just how to write gRPC in Go, but why cloud-native systems default to it — and where it's wrong for the job.

**Deliverable:** gRPC service (same domain as Phase 2, now served over gRPC) with interceptors, streaming, health checking, and deployed on AWS ECS with ALB gRPC support. This becomes the upstream gRPC target for the Phase 4 gateway.

### Day 12 — Protobuf + `buf`

- proto3 syntax: messages, enums, services, RPC definitions
- `buf` — modern replacement for raw `protoc`; used by real teams for linting, breaking-change detection, and codegen config
- `buf.yaml` + `buf.gen.yaml` configuration
- Reading generated Go code: interfaces, structs, registration code
- Well-known types: `Timestamp`, `Duration`, `Empty`
- Protobuf vs JSON tradeoff: when binary encoding matters, when it doesn't

### Day 13 — gRPC Server + Interceptors

- gRPC server setup in Go
- Implementing generated service interfaces
- Unary interceptors: auth, logging, recovery
- Chaining with `grpc.ChainUnaryInterceptor`
- JWT auth interceptor mirroring the Day 8 Gin middleware (same pattern, different framework)
- gRPC status codes and `status.Errorf` — distinct from HTTP status codes
- gRPC reflection for debugging with `grpcurl` and `grpcui`
- **Mistake to avoid:** Using HTTP status codes in gRPC responses

### Day 14 — Streaming

- Server streaming: real use case — event feeds, large dataset pagination
- Client streaming: real use case — batch uploads, telemetry ingestion
- Bidirectional streaming: real use case — real-time channels; also when *not* to use it
- Detecting client disconnect via `ctx.Done()` in streaming handlers — goroutine leak prevention
- **Exercise:** Implement a server-streaming endpoint on the Phase 2 service domain (e.g. stream resource updates)

### Day 15 — Resilience + Observability

- Deadline propagation through context — gRPC deadlines propagate transitively across service calls
- Retry interceptors with exponential backoff
- gRPC health checking protocol (`grpc_health_v1` — used by `grpc-health-probe` for K8s and ECS)
- Prometheus metrics via interceptors: request count, latency histograms
- Structured logging in gRPC handlers via `slog`

### Day 16 — AWS Deployment + Deliverable

- AWS ECS Fargate deployment
- ALB configuration for gRPC: HTTP/2 on target group, HTTPS listener (required for gRPC passthrough)
- ECS health checks with `grpc-health-probe` as container health check command
- Environment config via SSM Parameter Store or Secrets Manager
- Multi-stage Dockerfile adapted for gRPC binary
- **Deliverable:** gRPC service reachable at ALB DNS, health-checked by ECS, queryable with `grpcurl`

---

## Phase 4 — Capstone: API Gateway (Days 17–20+)

**Goal:** Build an API gateway that ties all prior phases together. This is Go's concurrency strengths at their peak: thousands of concurrent connections, fast proxying, composable middleware, and failure isolation.

**Deliverable:** Production-grade API gateway — Gin at the REST edge, proxying to the Phase 3 gRPC backend, with auth, rate limiting, circuit breaking, distributed tracing, Prometheus metrics, and graceful shutdown. Deployable on AWS ECS behind an ALB.

### Day 17 — Gateway Architecture + Reverse Proxy Foundations

- `httputil.ReverseProxy` from stdlib — Go's built-in reverse proxy
- Upstream registry design: clean interface for managing multiple upstream targets
- `http.Transport` configuration for upstream connection pooling: `MaxIdleConns`, `IdleConnTimeout`, `DisableKeepAlives`
- Path-based routing logic
- **Exercise:** Minimal working proxy routing `/api/v1/*` to Phase 2 REST service and `/grpc/*` to Phase 3 gRPC service — raw stdlib, no Gin yet

### Day 18 — Gin at the Edge + REST-to-gRPC Transcoding

- Gin as the edge router over the Day 17 proxy foundation
- REST-to-gRPC transcoding: translate HTTP/JSON request → gRPC call → Protobuf response → JSON
- Build simplified transcoding manually first, then understand `grpc-gateway` as the code-generation tool that automates it
- Request/response transformation middleware: header normalization, request ID injection, content-type negotiation

### Day 19 — Observability

Three pillars:
- **Structured logging:** `slog` request logs with latency, upstream target, status code, trace ID
- **Prometheus metrics:** requests/sec, latency histograms by route, upstream error rates — via Gin middleware
- **Distributed tracing:** OpenTelemetry trace context propagation from gateway through to gRPC upstream
- Health check aggregation: gateway `/healthz` returns unhealthy if gRPC upstream health probe fails

### Day 20 — Production Gateway Features

- Rate limiting at gateway level: per-client token bucket (keyed by client IP or JWT subject)
- JWT validation at the edge: validate once at gateway, pass claims downstream as headers; upstreams trust gateway
- Circuit breaker: stop forwarding to a failing upstream, return 503 immediately — prevents cascading failures
- Graceful shutdown with connection draining: wait for in-flight requests before exiting, configurable drain timeout
- **Outcome:** Gateway behaves correctly under failure conditions, not just happy-path load

---

## Extension Modules (Post Day 20)

Each extension is self-contained and slots in without modifying prior phases.

| Module | Content | Connects to |
|---|---|---|
| E1 — Kafka Integration | Publish gateway request events to Kafka; async audit log pattern | Existing Kafka mastery plan |
| E2 — Kubernetes Deployment | Helm chart for full stack (gateway + REST + gRPC), HPA, pod disruption budgets | Natural next cloud-native step |
| E3 — AWS SDK v2 | Gateway config from SSM/Secrets Manager, upstream discovery via AWS Cloud Map | Existing AWS network plan |
| E4 — Performance Profiling | `pprof` endpoints, benchmark tests, escape analysis, goroutine leak detection under load | Performance specialization |

---

## Mistakes to Avoid (Top 1% Guidance)

These are the patterns that waste 80% of returning engineers' time:

1. **Framework before stdlib** — Starting with Gin/Fiber before understanding `net/http` means you never understand what the framework does. Two days of stdlib unlocks every framework instantly.
2. **Generics everywhere** — The most common misuse of Go 1.18+. If an interface solves it cleanly, use an interface. Generics are for algorithms and type-safe containers.
3. **Goroutine leaks** — The single most common production incident in Go services. Every goroutine you launch must have a defined exit condition. `context` cancellation is how you do it.
4. **HTTP status codes in gRPC** — gRPC has its own status code system (`codes.NotFound`, `codes.Internal`, etc.). Returning HTTP 404 from a gRPC handler is a type error you won't catch at compile time.
5. **Skipping the ecosystem gap** — Coding 2019-style Go in 2026 is invisible until code review. `sort.Slice` when `slices.SortFunc` exists, `log.Printf` when `slog` is stdlib — it signals you haven't kept up.
6. **Testing with mocks of concrete types** — Mock the interface, not the struct. If you can't mock it with an interface, your abstraction boundary is wrong.
7. **`context.Background()` deep in call stacks** — Every handler should propagate the request context. `context.Background()` inside a handler is a cancellation escape hatch that breaks timeout and tracing.

---

## Success Criteria

By end of Phase 4, the learner can:

- [ ] Write idiomatic modern Go (1.22+) that a senior Go engineer would approve in code review
- [ ] Build and deploy a production-quality gRPC microservice on AWS ECS
- [ ] Build and deploy an API gateway with full observability
- [ ] Explain Go's concurrency model, goroutine scheduler, and context propagation under interview conditions
- [ ] Read and contribute to real Go codebases (Gin, gRPC-go, Kubernetes controllers) without friction
- [ ] Extend the plan with E1–E4 modules independently

---

## Repository Structure

```
golang_mastery/
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-07-21-golang-mastery-design.md
│       └── plans/          # written-plans output goes here
├── phase1_cli/             # Phase 1 deliverable: URL health checker
├── phase2_rest/            # Phase 2 deliverable: Gin REST microservice
├── phase3_grpc/            # Phase 3 deliverable: gRPC service
├── phase4_gateway/         # Phase 4 deliverable: API gateway
└── go.work                 # workspace file linking all four modules
```
