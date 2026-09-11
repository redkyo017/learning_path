# Go Mastery — Strategy

Why this path is designed the way it is.

---

## The returning engineer problem

A senior engineer who has been away from Go for three or four years does not
need a beginner path. They need a targeted gap-closing path. The risk is not
"doesn't know Go" — it is "codes 2019-style Go in 2026 without realizing it."
That shows up in code review: `sort.Slice` where `slices.SortFunc` exists,
`log.Printf` where `slog` is stdlib, `replace` directives in `go.mod` where
`go.work` is the right tool. These are invisible until someone points them out,
and they signal to a team that you have not kept up.

Phase 1 (Days 1–5) is non-negotiable even for a confident returner. Four years
of ecosystem drift will quietly pollute every phase after it if not addressed
first. The investment is five days; the payoff is clean modern Go for the
remaining fifteen.

---

## Ecosystem-gap first

The 1.16→1.22 gap is larger than it looks:

| Area | What changed |
|---|---|
| Workspace mode | `go.work` replaces `replace` directives for local multi-module dev |
| Toolchain directive | `go.mod` can now pin the exact toolchain version (1.21+) |
| Generics | Type parameters and constraints arrived in 1.18 |
| `slices` / `maps` / `cmp` | New stdlib packages in 1.21 replace hand-rolled sort/search idioms |
| `log/slog` | Structured logging is now in stdlib (1.21); replaces most logrus/zap use |
| `errors.Is` / `errors.As` | Error wrapping model was finalized; the old `==` comparison is wrong |
| `context.WithCancelCause` | Richer cancellation reason attached at call site (1.20) |
| Build constraints | `//go:build` replaces `// +build`; `go vet` enforces it |

None of these are optional upgrades. A production codebase in 2026 uses all of
them. Skipping Phase 1 and jumping to HTTP or gRPC means building on a cracked
foundation.

---

## Build-to-learn, not tutorial-follow

Every day has a concrete deliverable. Reading about generics while writing
`Map[T, U any]` is categorically different from reading about generics while
nodding along with a blog post. The difference compounds over 20 days.

The daily rhythm (5–6 hrs):

1. **Concept (1 hr)** — read the official doc page or release note for the day's topic
2. **Build (3.5 hrs)** — write real code that uses the concept; no copying from a tutorial
3. **Review (1 hr)** — read how the Go team or a major project uses the same concept in production
4. **Reflect (0.5 hr)** — write three sentences in `journal.md`: what surprised you, what clicked, what's unclear

The reflect block is not optional. Writing forces retrieval. A note you write
at the end of Day 4 will save you 30 minutes on Day 14 when the same
concurrency pattern reappears in a gRPC interceptor context.

---

## Read production codebases

The top 1% of Go engineers learn by reading production Go, not just writing it.
Docs tell you what a function does. Real code tells you how the people who built
the language use it.

Each day's "codebase read" block assigns a specific file and a specific
question. Examples:

- Day 3: read `slog/handler.go` — why does it use `sync.Mutex` not `sync.RWMutex`?
- Day 4: read `context/context.go` — trace how cancellation propagates to children
- Day 5: read `golang.org/x/sync/errgroup/errgroup.go` — how does `SetLimit` use a buffered channel as a semaphore?
- Day 7: read `gin/tree.go` — why is a radix trie faster than `ServeMux`'s map?

The goal is not to memorize these implementations. The goal is to develop the
instinct to read unfamiliar Go code fluently — which is the skill that
distinguishes a returner from someone who never left.

---

## Stdlib before framework

Day 6 is raw `net/http`: write a working API with zero dependencies. Day 7 is
Gin. The diff between Day 6 and Day 7 is the entire Gin value proposition made
concrete. Without Day 6, Gin is a magic black box. With Day 6, every Gin
abstraction maps to something you already understand: `gin.Context` is the
`ResponseWriter` + `Request` pair you wrapped manually; `c.ShouldBindJSON` is
the `json.NewDecoder(r.Body).Decode` + validation step you wrote by hand;
`c.Abort()` is the `return` you had to remember to call yourself.

This pattern — stdlib first, then the framework that wraps it — applies to
gRPC too. Phase 3 starts with raw Protobuf and `buf` before touching Go's gRPC
library, so the generated code is readable rather than mysterious.

---

## Ship something every phase

Each phase ends with a running, containerized artifact:

- **Phase 1:** URL health checker CLI — proves every Day 1–4 concept in one binary
- **Phase 2:** Gin REST API — Postgres, JWT auth, integration tests, multi-stage Dockerfile
- **Phase 3:** gRPC service — interceptors, streaming, health probe, deployed on AWS ECS
- **Phase 4:** API gateway — Gin edge + gRPC proxy, rate limiting, circuit breaker, OTel tracing

These are not toy examples. Each one is portfolio-quality code you would not be
embarrassed to show in a technical interview or a code review.

---

## Mistakes the top 1% avoid (that returners commonly make)

1. **Generics everywhere.** The most common 1.18+ misuse. If an interface solves
   it cleanly, use the interface. Generics are for type-safe algorithms over
   collections and for typed containers. `io.Writer` and `http.Handler` are
   correct as interfaces — they describe behavior, not type identity.

2. **Goroutine leaks.** The single most common production incident in Go services.
   Every goroutine you launch needs a defined exit condition. Context cancellation
   via `ctx.Done()` is how you do it. Phase 1 deliberately writes a leaky
   goroutine and then fixes it so this mistake is visceral before it's theoretical.

3. **HTTP status codes in gRPC.** gRPC has its own status code system
   (`codes.NotFound`, `codes.Internal`, etc.). Returning HTTP 404 from a gRPC
   handler is a type error the compiler won't catch.

4. **`context.Background()` deep in call stacks.** Every handler should thread the
   request context through every downstream call. `context.Background()` inside a
   handler breaks cancellation, timeout propagation, and distributed tracing.

5. **Testing with mocks of concrete types.** Mock the interface, not the struct.
   If you cannot mock it with an interface, the abstraction boundary is wrong.

6. **Skipping the ecosystem gap.** Addressed by Phase 1. Cannot be skipped.

---

## Extension modules (post Day 20)

After the capstone, four self-contained modules slot in without restructuring
anything:

| Module | Focus |
|---|---|
| E1 — Kafka Integration | Publish gateway request events; async audit log pattern |
| E2 — Kubernetes | Helm chart for the full stack, HPA, pod disruption budgets |
| E3 — AWS SDK v2 | Gateway config from SSM/Secrets Manager; upstream discovery via Cloud Map |
| E4 — Performance | `pprof` endpoints, benchmark tests, escape analysis, leak detection under load |
