# Go Mastery

A 20-day, 5–6 h/day path that takes a returning senior Go engineer from
1.16-era instincts to production-ready Go 1.22+ fluency. Every day builds a
real artifact; no tutorials, no typing along with docs. See `STRATEGY.md` for
the reasoning behind this design.

## Prerequisites

- Go 1.22 or later (`go version`)
- Docker Desktop (required from Day 11 onward for containerization and Day 16 AWS ECS)
- `buf` CLI v1.x for Phase 3 gRPC codegen (`brew install bufbuild/buf/buf`)
- AWS CLI + an AWS account with ECS/ALB permissions (Day 16 only)

## Workspace bring-up

```bash
cd golang_mastery
go work sync          # verify the four-module workspace is healthy
go build ./...        # should build clean after each phase is scaffolded
```

The `go.work` file links all four phase modules so later phases can reference
earlier deliverables without publishing anything to a registry.

## Phase map

| Phase | Days | Focus | Deliverable |
|---|---|---|---|
| 1 | 1–5 | Modern Go re-calibration + concurrency | Parallel URL health checker CLI |
| 2 | 6–11 | HTTP stdlib → Gin REST microservice | Containerized REST API (Postgres, JWT, tests) |
| 3 | 12–16 | gRPC + Protobuf + service patterns | gRPC service on AWS ECS |
| 4 | 17–20 | Capstone: API gateway | Gin edge + gRPC proxy, full observability |

Extension modules E1–E4 (Kafka, K8s, AWS SDK, profiling) slot in after Day 20
without touching prior phases.

## Day index

| Day | Title | Phase module |
|---|---|---|
| 1 | Toolchain & project layout | `phase1_cli` |
| 2 | Generics | `phase1_cli` |
| 3 | Modern stdlib — slices, maps, cmp, slog, errors | `phase1_cli` |
| 4 | Concurrency fundamentals re-calibration | `phase1_cli` |
| 5 | Concurrency patterns + Phase 1 deliverable | `phase1_cli` |
| 6 | `net/http` deep dive | `phase2_rest` |
| 7 | Gin fundamentals | `phase2_rest` |
| 8 | Gin middleware | `phase2_rest` |
| 9 | Database integration | `phase2_rest` |
| 10 | Testing | `phase2_rest` |
| 11 | Containerization + graceful shutdown | `phase2_rest` |
| 12 | Protobuf + buf | `phase3_grpc` |
| 13 | gRPC server + interceptors | `phase3_grpc` |
| 14 | Streaming | `phase3_grpc` |
| 15 | Resilience + observability | `phase3_grpc` |
| 16 | AWS ECS deployment | `phase3_grpc` |
| 17 | Gateway architecture + reverse proxy | `phase4_gateway` |
| 18 | Gin at the edge + REST-to-gRPC transcoding | `phase4_gateway` |
| 19 | Observability (logs, metrics, traces) | `phase4_gateway` |
| 20 | Production gateway features | `phase4_gateway` |

Each day file is at `content/dayNN.md`. The plan with step-by-step build
instructions is at `docs/superpowers/plans/2026-07-21-golang-mastery-plan.md`.

## Daily rhythm

| Block | Time | Activity |
|---|---|---|
| Concept | 1 hr | Read official docs + one real codebase example |
| Build | 3.5 hrs | Implement the day's artifact |
| Review | 1 hr | Read idiomatic Go from a real project (stdlib, Gin, etcd, etc.) |
| Reflect | 0.5 hr | Append to `journal.md`: what surprised you, what clicked, what's unclear |

## Runbooks

Tactical references for production Go problems. Use when you hit these symptoms
during the build phases:

| Runbook | When to reach for it |
|---|---|
| `content/runbook-goroutine-leak.md` | Memory grows over time; goroutine count climbs continuously |
| `content/runbook-grpc-debugging.md` | gRPC calls fail, time out, or return unexpected status codes |
| `content/runbook-module-dependency.md` | `go build` fails with version conflicts; `go.sum` errors |
| `content/runbook-performance-profiling.md` | High latency or CPU; pprof-based investigation workflow |

## Reference

- `STRATEGY.md` — why this path is structured the way it is
- `content/GLOSSARY.md` — plain-English definitions of Go terms used in the path
- `journal.md` — daily reflect log (one entry per day, appended by you)
- `docs/superpowers/specs/2026-07-21-golang-mastery-design.md` — full design spec
