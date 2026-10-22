# Refresh Log

## 2026-10-22
Checked: whole path — Days 1–20, 4 runbooks, GLOSSARY, README, STRATEGY, the 4 phase modules (go.mod, code,
Dockerfiles, compose, buf configs, ECS task definition) and a version check of spec extensions E1–E4. Sources:
go.dev/dl + release notes go1.22–go1.27 (current: go1.27.3, go1.26.10), govulncheck v1.9.0 (vuln DB
2026-10-21), module proxy `@latest` + module sources, pkg.go.dev, protobuf.dev, buf docs (buf v1.75.0), Docker
Hub / distroless, AWS ELB + ECS docs, OpenTelemetry releases. Full version table: spec → "Target Versions & Sources".

Changed:
- WRONG NOW (labs): workspace did not build (non-existent module `google.golang.org/grpc/health` required in
  all four go.mod) — removed. Reachable vulns in jwt v5.2.1, pgx v5.6.0, grpc v1.64.0, x/net, x/text and
  (after bump) quic-go — bumped; this forces `go 1.26.0` in go.mod/go.work (toolchain line dropped). go.sum
  files added. Dockerfiles → golang:1.27-alpine (old tags fail with GOTOOLCHAIN=local), $BUILDPLATFORM/
  TARGETARCH cross-compile, distroless static-debian13:nonroot (phase2 previously ran as root). phase3 image
  now installs grpc-health-probe v0.4.60 (task definition called a missing binary); auth interceptor skips
  health/reflection RPCs (probe got UNAUTHENTICATED → ECS restart loop); `healthSrv.Shutdown()` before
  GracefulStop. JWT: no fallback secret, ≥32-byte check at startup, `WithValidMethods` + `WithExpirationRequired`;
  task definition reads JWT_SECRET from SSM `secrets`. Gin `SetTrustedProxies(nil)` in phase2 + phase4 (per-IP
  rate limit was bypassable via X-Forwarded-For). phase4 proxy: deprecated `Director` → `Rewrite` +
  `SetXForwarded`. phase2 http.Server timeouts. Loop-var copies removed. Integration test → `postgres.Run` +
  `BasicWaitStrategies`. buf: plugins pinned (protocolbuffers/go v1.36.12, grpc/go v1.6.2), lint STANDARD,
  unused googleapis dep removed.
- WRONG NOW (content): ~45 factual fixes — e.g. ServeMux "no params/methods" (day06/07, GLOSSARY), GOMAXPROCS
  and automaxprocs (day04/20, perf runbook), GONOSUMCHECK (module runbook), r.Context() leak "fix" (leak
  runbook), slog argument evaluation (day03), go get 1.17→1.18 and go-line semantics (day01), validator
  `required`, gin Keys type, MustBindWith (day07), alg:none framing + sync.Map generic (day08), pgx named
  args/JSONB/MaxIdleConns/Scanner (day09), testcontainers wait (day10), ErrShutdownTimeout (day11), proto3
  optional/enums/require_unimplemented_servers (day12), UnaryInterceptor panic + panic recovery (day13),
  deadline inheritance (day15), ALB gRPC protocol version + health check, docker --entrypoint, kms:Decrypt
  (day16), Director (day17), metadata.Pairs + wrong port (gRPC runbook).
- OUTDATED: tool directive, toolchain line, b.Loop, slices.Sorted(maps.Keys), loopvar/go fix, distroless 13,
  multi-arch builds, startupProbe, postgres 18, gin v1.12 text, buf pinning, generic stream aliases, BDP
  windows, go-grpc-prometheus archived, NewClient semantics, reflection v1, aws-sdk-go v1 EOS, semconv
  v1.37.0 + span naming, otelgrpc stats handlers, OTel logs status, client_golang row, gobreaker v2, RS256
  comment. All non-vulnerable deps bumped to latest (gin, otel, prometheus, migrate, testcontainers, x/*).
- MISSING (approved, no new days/labs): "What changed since Go 1.22" box (day01), generic methods (day02),
  iterators/range-over-func + errors.AsType (day03), goroutineleak profile + synctest + WaitGroup.Go +
  WithoutCancel/t.Context (day04), json v2 in 1.27 + CrossOriginProtection (day06), password hashing + iss/aud
  (day08), SQL injection (day09), newer testing helpers (day10), LB-aware shutdown (day11), editions (day12),
  OTel stats handlers + health draining (day15), ALB/Service Connect notes (day16), OTel SDK setup + otelgin +
  otelslog (day19), trusted proxies + edge trust model (day20), runtime tooling paragraph (perf runbook),
  Kafka client + SDK v1 EOS (spec E1/E3).

Deferred:
- phase2 per-IP rate limiter still has no eviction (phase4 shows the pattern) — lab improvement, not drift.
- phase4 requires otel but has no tracing middleware; Day 19 now leaves wiring it as an exercise.
- `buf lint` (STANDARD) flags `StreamTasks` returning `Task` (RPC response naming) — pre-existing, not drift.
- gofmt nit in phase2 `internal/handler/task_test.go` (pre-existing).
- Plan doc (`docs/superpowers/plans/2026-07-21-golang-mastery-plan.md`) is historical and not refreshed; its
  embedded versions/commands are superseded by the day files and lab sources.
- Not changed because unconfirmed: "go mod download no longer writes go.sum" (local test contradicted it),
  "workspace … conflicting requirements" message, pprof `top10 -inuse_space`, sarama/kafka-go maintenance.
- OTel Go logs status: GitHub v1.47.0 notes say stable, opentelemetry.io still says RC — day19 states both.

Not verified:
- Docker daemon was not running: `docker compose build/up` (phase2), the testcontainers integration test
  (`go test -tags integration`, compiled and vetted only), and both image builds were NOT run.
- Day 16 AWS lab (ECR/ECS/ALB) not deployed — checked against AWS docs only.
- Verified: all 4 modules build, vet (incl. `-tags integration`) and `go test -race` on go1.26.10 and
  go1.27.3; govulncheck clean (no reachable vulns); `buf lint`/`buf generate` with pinned remote plugins
  (buf v1.75.0); new day snippets for iterators, synctest, WaitGroup.Go, errors.AsType, OTel SDK/otelgin/
  otelgrpc/otelslog, semconv v1.37.0, gobreaker v2 and slog.NewMultiHandler compiled against current modules.
