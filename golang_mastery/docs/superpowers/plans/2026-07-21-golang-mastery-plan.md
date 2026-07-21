# Go Mastery — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day's session is a study/build block, not a code change made on your behalf.
> Work top to bottom, one day at a time, and check off steps as you complete
> them. Do not skip ahead; each day's deliverable feeds the next. Saving your
> work is entirely your own responsibility — nothing in this plan runs git on
> your behalf.

**Goal:** Re-sharpen Go skills for a returning senior engineer — close the
1.16→1.22+ ecosystem gap, rebuild production-grade microservice intuition, and
deliver a portfolio-quality API gateway, all through daily hands-on builds
rather than tutorials.

**Architecture:** Four self-contained phases, each ending with a running
containerized artifact. A single `go.work` workspace links all four modules so
you can reference phase deliverables from later phases without publish/import
gymnastics. Phase 1 (CLI tool) proves modern Go idioms; Phase 2 (REST service)
adds Gin and a real database; Phase 3 (gRPC service) becomes the upstream
backend; Phase 4 (API gateway) proxies all prior deliverables and is the
capstone. Extension modules E1–E4 slot in after Day 20 without touching prior
phases.

**Tech Stack:** Go 1.22+, `golang.org/x/sync` (errgroup), Gin v1.9,
`github.com/jackc/pgx/v5`, `golang-migrate/migrate/v4`,
`testcontainers-go v0.30`, `golang-jwt/jwt/v5`,
`google.golang.org/grpc v1.64`, `google.golang.org/protobuf v1.34`,
`buf v1.x` (codegen), `grpc-health-probe`, Prometheus
`client_golang v1.19`, `go.opentelemetry.io/otel v1.27`,
Docker, AWS ECS Fargate, ALB.

## Global Constraints

- 5–6 hour daily budget: concept (1 hr) → build (3.5 hrs) → codebase read (1
  hr) → journal (0.5 hr). If a step overruns, note it in `journal.md` and
  continue; don't compress tomorrow.
- No tutorial-following. Every step builds something real. Reading a doc page
  counts only if you immediately apply it in code.
- No framework before stdlib: Day 6 (`net/http`) before Day 7 (Gin). This
  constraint is in the plan order; don't reorder.
- Replace `yourname` in module paths with your GitHub username or any
  consistent string; just keep it the same across all four modules.
- Tool versions in `go.mod` / dependency files are pinned at planning time.
  Run `go get -u ./...` at the start of each phase if a patch version is stale;
  do not change major versions without reading the changelog.
- Journal file: `golang_mastery/journal.md`, one entry appended per day.
  The journal is the reflect block — not optional.

## Repository End-State Layout

Built up incrementally across 20 days — this is the target, not something to
create all at once:

```
golang_mastery/
├── go.work
├── journal.md
├── docs/superpowers/specs/2026-07-21-golang-mastery-design.md
├── docs/superpowers/plans/2026-07-21-golang-mastery-plan.md
├── phase1_cli/
│   ├── go.mod
│   ├── cmd/healthcheck/main.go
│   └── internal/
│       ├── generic/functional.go
│       ├── generic/functional_test.go
│       ├── generic/cache.go
│       ├── generic/result.go
│       ├── stdlib_tour/sorting.go
│       ├── stdlib_tour/errors.go
│       ├── stdlib_tour/logging.go
│       └── concurrency/patterns.go
├── phase2_rest/
│   ├── go.mod
│   ├── cmd/api/main.go
│   ├── internal/
│   │   ├── model/task.go
│   │   ├── repository/repository.go   (interface)
│   │   ├── repository/postgres.go
│   │   ├── repository/memory.go       (test mock)
│   │   ├── handler/task.go
│   │   ├── handler/task_test.go
│   │   └── middleware/
│   │       ├── auth.go
│   │       ├── logger.go
│   │       └── ratelimit.go
│   ├── migrations/001_create_tasks.up.sql
│   ├── Dockerfile
│   └── docker-compose.yml
├── phase3_grpc/
│   ├── go.mod
│   ├── buf.yaml
│   ├── buf.gen.yaml
│   ├── proto/task/v1/task.proto
│   ├── gen/task/v1/          (buf-generated, committed)
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── server/task.go
│   │   └── interceptor/
│   │       ├── auth.go
│   │       ├── logger.go
│   │       └── metrics.go
│   ├── Dockerfile
│   └── task-definition.json
└── phase4_gateway/
    ├── go.mod
    ├── cmd/gateway/main.go
    ├── internal/
    │   ├── proxy/upstream.go
    │   ├── proxy/reverseproxy.go
    │   ├── middleware/auth.go
    │   ├── middleware/ratelimit.go
    │   ├── middleware/circuitbreaker.go
    │   ├── middleware/metrics.go
    │   └── transcoder/grpc.go
    ├── Dockerfile
    └── docker-compose.yml
```

---

## Day 1: Toolchain, workspace, project layout

**Materials:**
- Go blog: "Go Workspaces" (go.dev/blog/get-familiar-with-workspaces)
- Go spec: build constraints (go.dev/doc/go1.17 — the `//go:build` change)
- `go help mod` and `go help work` — read both terminal outputs in full

**Builds on:** nothing (Day 1).
**Sets up:** Days 2–5 need the workspace and module scaffold in place.

- [ ] **Step 1 (15 min): Verify toolchain.**

```bash
go version
```
Expected: `go version go1.22.x` or later. If older, install from go.dev/dl.

```bash
go env GOPATH GOMODCACHE GOPROXY
```
Expected: non-empty values. Note the cache path — you'll reference it later when inspecting downloaded modules.

- [ ] **Step 2 (20 min): Read about workspace mode.**

Read the Go Workspaces blog post listed in Materials. While reading, write in
`journal.md`:
> "Workspace mode solves _____ that `replace` directives in go.mod used to
> require." (fill in the blank in your own words)

- [ ] **Step 3 (30 min): Create the workspace and four module stubs.**

```bash
cd golang_mastery
touch journal.md

mkdir -p phase1_cli/cmd/healthcheck phase1_cli/internal/generic \
         phase1_cli/internal/stdlib_tour phase1_cli/internal/concurrency
mkdir -p phase2_rest/cmd/api phase2_rest/internal \
         phase2_rest/migrations
mkdir -p phase3_grpc/cmd/server phase3_grpc/internal/server \
         phase3_grpc/internal/interceptor phase3_grpc/proto/task/v1
mkdir -p phase4_gateway/cmd/gateway phase4_gateway/internal/proxy \
         phase4_gateway/internal/middleware phase4_gateway/internal/transcoder
```

Create `phase1_cli/go.mod`:
```
module github.com/yourname/golang-mastery/phase1-cli

go 1.22

toolchain go1.22.0
```

Create `phase2_rest/go.mod`:
```
module github.com/yourname/golang-mastery/phase2-rest

go 1.22

toolchain go1.22.0
```

Create `phase3_grpc/go.mod`:
```
module github.com/yourname/golang-mastery/phase3-grpc

go 1.22

toolchain go1.22.0
```

Create `phase4_gateway/go.mod`:
```
module github.com/yourname/golang-mastery/phase4-gateway

go 1.22

toolchain go1.22.0
```

- [ ] **Step 4 (15 min): Create the workspace file.**

Create `golang_mastery/go.work`:
```
go 1.22

use (
    ./phase1_cli
    ./phase2_rest
    ./phase3_grpc
    ./phase4_gateway
)
```

Verify:
```bash
go work sync
```
Expected: exits with no output (no errors).

- [ ] **Step 5 (20 min): Old vs new build constraints — spot the difference.**

Create `phase1_cli/internal/generic/platform.go`:
```go
//go:build !windows

package generic
```

Create `phase1_cli/internal/generic/platform_windows.go`:
```go
//go:build windows

package generic
```

These files are empty stubs that demonstrate the `//go:build` syntax (Go
1.17+). The old `// +build !windows` comment-based syntax still works but is
deprecated. Run:
```bash
go vet ./phase1_cli/...
```
Expected: no output (clean).

- [ ] **Step 6 (20 min): Write a minimal main.go that builds.**

Create `phase1_cli/cmd/healthcheck/main.go`:
```go
package main

import "fmt"

func main() {
    fmt.Println("phase1: healthcheck starting")
}
```

```bash
go run ./phase1_cli/cmd/healthcheck
```
Expected: `phase1: healthcheck starting`

- [ ] **Step 7 (30 min): Codebase read.**

Run:
```bash
go env GOMODCACHE
ls $(go env GOMODCACHE)/golang.org/x/
```
Look at one cached module's directory structure. Notice the `go.mod`, the
source files, and the `.info` files. This is how Go caches modules — you are
looking at the actual read-only source the toolchain uses.

- [ ] **Step 8 (20 min): Journal.**

Append to `journal.md`:
- What is the difference between `go install` and `go get` in Go 1.17+?
- What problem does `go.work` solve that `replace` directives cannot cleanly
  solve in a multi-module repo?
- What surprised you about the module cache structure?

---

## Day 2: Generics

**Materials:**
- Go blog: "An Introduction To Generics" (go.dev/blog/intro-generics)
- Go spec: Type Parameters (go.dev/ref/spec#Type_parameter_declarations)
- Real codebase: `golang.org/x/exp/slices` (pre-stdlib version) — skim the
  source to see how the Go team wrote generic slice utilities

**Builds on:** Day 1 workspace.
**Sets up:** Day 3 refactors the generic helpers using modern stdlib.

- [ ] **Step 1 (20 min): Primer.**

Read the "An Introduction To Generics" blog post. While reading, note in
`journal.md`: the three things you can express with generics that you cannot
express cleanly with `interface{}` (the old `any`).

- [ ] **Step 2 (40 min): Generic functional helpers.**

Create `phase1_cli/internal/generic/functional.go`:
```go
package generic

// Map transforms each element of s using f.
func Map[T, U any](s []T, f func(T) U) []U {
    result := make([]U, len(s))
    for i, v := range s {
        result[i] = f(v)
    }
    return result
}

// Filter returns elements of s for which f returns true.
func Filter[T any](s []T, f func(T) bool) []T {
    var result []T
    for _, v := range s {
        if f(v) {
            result = append(result, v)
        }
    }
    return result
}

// Reduce folds s into a single value, starting from init.
func Reduce[T, U any](s []T, init U, f func(U, T) U) U {
    acc := init
    for _, v := range s {
        acc = f(acc, v)
    }
    return acc
}
```

Create `phase1_cli/internal/generic/functional_test.go`:
```go
package generic_test

import (
    "testing"

    "github.com/yourname/golang-mastery/phase1-cli/internal/generic"
)

func TestMap(t *testing.T) {
    in := []int{1, 2, 3}
    got := generic.Map(in, func(n int) int { return n * 2 })
    want := []int{2, 4, 6}
    for i, v := range want {
        if got[i] != v {
            t.Errorf("Map[%d] = %d, want %d", i, got[i], v)
        }
    }
}

func TestFilter(t *testing.T) {
    in := []int{1, 2, 3, 4, 5}
    got := generic.Filter(in, func(n int) bool { return n%2 == 0 })
    if len(got) != 2 || got[0] != 2 || got[1] != 4 {
        t.Errorf("Filter = %v, want [2 4]", got)
    }
}

func TestReduce(t *testing.T) {
    in := []int{1, 2, 3, 4}
    got := generic.Reduce(in, 0, func(acc, n int) int { return acc + n })
    if got != 10 {
        t.Errorf("Reduce = %d, want 10", got)
    }
}
```

Run:
```bash
go test ./phase1_cli/internal/generic/... -v
```
Expected: PASS for all three tests.

- [ ] **Step 3 (40 min): Generic typed cache.**

Create `phase1_cli/internal/generic/cache.go`:
```go
package generic

import "sync"

// Cache is a goroutine-safe key-value store.
// K must be comparable (usable as a map key); V can be any type.
type Cache[K comparable, V any] struct {
    mu    sync.RWMutex
    items map[K]V
}

func NewCache[K comparable, V any]() *Cache[K, V] {
    return &Cache[K, V]{items: make(map[K]V)}
}

func (c *Cache[K, V]) Set(key K, value V) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.items[key]
    return v, ok
}

func (c *Cache[K, V]) Delete(key K) {
    c.mu.Lock()
    defer c.mu.Unlock()
    delete(c.items, key)
}
```

Add to `functional_test.go`:
```go
func TestCache(t *testing.T) {
    c := generic.NewCache[string, int]()
    c.Set("a", 1)
    v, ok := c.Get("a")
    if !ok || v != 1 {
        t.Errorf("Get(a) = %d, %v; want 1, true", v, ok)
    }
    c.Delete("a")
    _, ok = c.Get("a")
    if ok {
        t.Error("expected key to be deleted")
    }
}
```

Run:
```bash
go test ./phase1_cli/internal/generic/... -v
```
Expected: 4 tests PASS.

- [ ] **Step 4 (30 min): Result type — typed error wrapper.**

Create `phase1_cli/internal/generic/result.go`:
```go
package generic

// Result holds either a value of type T or an error, never both.
type Result[T any] struct {
    value T
    err   error
}

func Ok[T any](v T) Result[T]        { return Result[T]{value: v} }
func Err[T any](err error) Result[T] { return Result[T]{err: err} }

func (r Result[T]) Unwrap() (T, error) { return r.value, r.err }
func (r Result[T]) IsOk() bool         { return r.err == nil }
func (r Result[T]) Value() T           { return r.value }
func (r Result[T]) Error() error       { return r.err }
```

Add to `functional_test.go`:
```go
import "errors"

func TestResult(t *testing.T) {
    r := generic.Ok(42)
    if !r.IsOk() || r.Value() != 42 {
        t.Error("Ok result should hold value")
    }
    e := generic.Err[int](errors.New("bad"))
    if e.IsOk() {
        t.Error("Err result should not be ok")
    }
    _, err := e.Unwrap()
    if err == nil {
        t.Error("Err result should have error")
    }
}
```

Run:
```bash
go test ./phase1_cli/internal/generic/... -v
```
Expected: 5 tests PASS.

- [ ] **Step 5 (30 min): Compare with the interface{} approach.**

In `phase1_cli/internal/generic/functional.go`, add this comment block
BELOW the existing functions — this is a study artifact, not production code:

```go
// WHY NOT interface{}: The pre-generics Map would look like:
//
//   func MapAny(s []interface{}, f func(interface{}) interface{}) []interface{}
//
// Callers lose type information; they must type-assert every element.
// The generic Map[T, U any] preserves types at compile time — the compiler
// rejects Map([]int{1,2,3}, func(s string) string {...}) at compile time,
// not at runtime.
//
// WHEN NOT TO USE GENERICS: if an interface satisfies the constraint, use
// the interface. Example: io.Writer, http.Handler, sort.Interface all use
// interfaces and are correct — they describe behavior, not type identity.
// Generics are for type-safe containers and algorithms that work on any type.
```

- [ ] **Step 6 (45 min): Codebase read.**

```bash
go doc slices
go doc slices SortFunc
```

Then read the actual source of `slices.Index` in the Go stdlib:
```bash
cat $(go env GOROOT)/src/slices/slices.go | head -80
```
Notice: the stdlib team uses generics exactly the way you just wrote them.
Write in `journal.md`: one thing the stdlib generics source does that you
wouldn't have thought to do.

- [ ] **Step 7 (20 min): Journal.**

Append to `journal.md`:
- In your own words: when should you reach for generics vs an interface?
- What would the `Cache[K, V]` type look like without generics? What's the
  runtime cost of the type-assertion approach?
- What surprised you about Go's generics implementation?

---

## Day 3: Modern stdlib — slices, maps, cmp, slog, errors

**Materials:**
- Go 1.21 release notes (go.dev/doc/go1.21) — slices, maps, cmp, slog sections
- `go doc log/slog` — read the full package doc
- Real codebase: search `github.com/gin-gonic/gin` for `slog` usage — notice
  they still use their own logger; you'll understand why after today

**Builds on:** Day 2 generic helpers.
**Sets up:** Day 5 uses `slog` for structured output in the CLI deliverable.

- [ ] **Step 1 (20 min): Primer.**

Read the Go 1.21 release notes sections for `slices`, `maps`, `cmp`, and
`log/slog`. Write in `journal.md`: three functions from `slices` that replace
patterns you used to write by hand before 1.21.

- [ ] **Step 2 (45 min): Sorting and searching with slices.**

Create `phase1_cli/internal/stdlib_tour/sorting.go`:
```go
package stdlib_tour

import (
    "cmp"
    "slices"
)

type Person struct {
    Name string
    Age  int
}

// SortByAge sorts people by age ascending.
// Pre-1.21: sort.Slice(people, func(i,j int) bool { return people[i].Age < people[j].Age })
func SortByAge(people []Person) []Person {
    slices.SortFunc(people, func(a, b Person) int {
        return cmp.Compare(a.Age, b.Age)
    })
    return people
}

// OldestOver returns the first person older than minAge, or false if none.
func OldestOver(people []Person, minAge int) (Person, bool) {
    idx := slices.IndexFunc(people, func(p Person) bool {
        return p.Age > minAge
    })
    if idx == -1 {
        return Person{}, false
    }
    return people[idx], true
}

// UniqueNames returns deduplicated names, sorted.
func UniqueNames(people []Person) []string {
    names := make([]string, len(people))
    for i, p := range people {
        names[i] = p.Name
    }
    slices.Sort(names)
    return slices.Compact(names)
}
```

Create `phase1_cli/internal/stdlib_tour/sorting_test.go`:
```go
package stdlib_tour_test

import (
    "testing"

    "github.com/yourname/golang-mastery/phase1-cli/internal/stdlib_tour"
)

func TestSortByAge(t *testing.T) {
    people := []stdlib_tour.Person{
        {"Charlie", 35}, {"Alice", 30}, {"Bob", 25},
    }
    sorted := stdlib_tour.SortByAge(people)
    if sorted[0].Name != "Bob" || sorted[2].Name != "Charlie" {
        t.Errorf("unexpected order: %v", sorted)
    }
}

func TestUniqueNames(t *testing.T) {
    people := []stdlib_tour.Person{
        {"Alice", 30}, {"Bob", 25}, {"Alice", 22},
    }
    got := stdlib_tour.UniqueNames(people)
    if len(got) != 2 || got[0] != "Alice" || got[1] != "Bob" {
        t.Errorf("UniqueNames = %v, want [Alice Bob]", got)
    }
}
```

```bash
go test ./phase1_cli/internal/stdlib_tour/... -v
```
Expected: PASS.

- [ ] **Step 3 (45 min): Error wrapping — Is, As, Unwrap.**

Create `phase1_cli/internal/stdlib_tour/errors.go`:
```go
package stdlib_tour

import (
    "errors"
    "fmt"
)

var ErrNotFound = errors.New("not found")
var ErrPermission = errors.New("permission denied")

type ResourceError struct {
    ID  string
    Err error
}

func (e *ResourceError) Error() string { return fmt.Sprintf("resource %q: %v", e.ID, e.Err) }
func (e *ResourceError) Unwrap() error { return e.Err }

// FetchResource simulates a layered error chain.
func FetchResource(id string) error {
    inner := &ResourceError{ID: id, Err: ErrNotFound}
    return fmt.Errorf("fetch: %w", inner)
}

// IsNotFound unwraps any depth to find ErrNotFound.
func IsNotFound(err error) bool {
    return errors.Is(err, ErrNotFound)
}

// ExtractResourceID unwraps to find the ResourceError and returns its ID.
func ExtractResourceID(err error) (string, bool) {
    var re *ResourceError
    if errors.As(err, &re) {
        return re.ID, true
    }
    return "", false
}
```

Create `phase1_cli/internal/stdlib_tour/errors_test.go`:
```go
package stdlib_tour_test

import (
    "testing"

    "github.com/yourname/golang-mastery/phase1-cli/internal/stdlib_tour"
)

func TestErrorChain(t *testing.T) {
    err := stdlib_tour.FetchResource("item-42")

    if !stdlib_tour.IsNotFound(err) {
        t.Error("expected IsNotFound to unwrap through fmt.Errorf %w chain")
    }

    id, ok := stdlib_tour.ExtractResourceID(err)
    if !ok || id != "item-42" {
        t.Errorf("ExtractResourceID = %q, %v; want item-42, true", id, ok)
    }
}
```

```bash
go test ./phase1_cli/internal/stdlib_tour/... -v
```
Expected: PASS.

- [ ] **Step 4 (45 min): slog structured logging.**

Create `phase1_cli/internal/stdlib_tour/logging.go`:
```go
package stdlib_tour

import (
    "log/slog"
    "os"
)

// NewJSONLogger creates a JSON-format slog logger at Info level.
func NewJSONLogger() *slog.Logger {
    return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))
}

// NewTextLogger creates a human-readable logger for local dev.
func NewTextLogger() *slog.Logger {
    return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
        Level: slog.LevelDebug,
    }))
}

// LogWithAttrs demonstrates structured key-value pairs.
func LogWithAttrs(logger *slog.Logger) {
    logger.Info("request received",
        "method", "GET",
        "path", "/api/tasks",
        "remote_addr", "10.0.0.1",
    )
    logger.Warn("slow response",
        slog.Duration("latency", 1500*1000000), // 1.5s
        slog.String("path", "/api/tasks"),
    )
    logger.Error("db query failed",
        slog.String("query", "SELECT * FROM tasks"),
        slog.Any("err", ErrNotFound),
    )
}
```

Update `phase1_cli/cmd/healthcheck/main.go` to call `NewJSONLogger` and set
it as the default:
```go
package main

import (
    "log/slog"
    "os"

    "github.com/yourname/golang-mastery/phase1-cli/internal/stdlib_tour"
)

func main() {
    logger := stdlib_tour.NewJSONLogger()
    slog.SetDefault(logger)

    stdlib_tour.LogWithAttrs(logger)
    slog.Info("phase1 ready")
}
```

```bash
go run ./phase1_cli/cmd/healthcheck
```
Expected: three JSON log lines on stdout, each with `"time"`, `"level"`,
`"msg"`, and structured key-value pairs. No plain-text prefix.

- [ ] **Step 5 (30 min): maps package.**

Add to `phase1_cli/internal/stdlib_tour/sorting.go`:
```go
import "maps"

// GroupByFirstLetter groups people by the first letter of their name.
// Returns a new map — maps.Clone avoids mutating the input accidentally.
func GroupByFirstLetter(people []Person) map[string][]Person {
    result := make(map[string][]Person)
    for _, p := range people {
        key := string(p.Name[0])
        result[key] = append(result[key], p)
    }
    return result
}

// MapKeys returns all keys of a map, deterministically sorted.
func MapKeys[K cmp.Ordered, V any](m map[K]V) []K {
    keys := make([]K, 0, len(m))
    for k := range maps.Keys(m) {
        keys = append(keys, k)
    }
    slices.Sort(keys)
    return keys
}
```

- [ ] **Step 6 (45 min): Codebase read.**

```bash
cat $(go env GOROOT)/src/log/slog/handler.go | head -100
```
Read how the stdlib JSON handler is implemented. Notice: it uses `sync.Mutex`,
not `sync.RWMutex` — why? (Writes are the common case; reads during output are
rare. Write in journal.)

- [ ] **Step 7 (20 min): Journal.**

Append to `journal.md`:
- What did you use before `slices.SortFunc`? What's the ergonomic difference?
- What is the difference between `errors.Is` and `==` for error comparison?
- Why is `log/slog` in stdlib now, and what does it replace?

---

## Day 4: Concurrency fundamentals re-calibration

**Materials:**
- Go blog: "Go Concurrency Patterns: Context" (go.dev/blog/context)
- Go blog: "Concurrency is not parallelism" (go.dev/blog/waza-talk) — watch
  the linked talk if you haven't
- `go doc sync` — read the full package doc including all types

**Builds on:** Days 1–3.
**Sets up:** Day 5 uses worker pool + errgroup for the CLI deliverable.

- [ ] **Step 1 (20 min): Primer.**

Read the Context blog post. Write in `journal.md`: the two things `context`
carries (deadline/cancellation signal AND key-value pairs) and why the key-value
pairs should only be used for request-scoped data, never for optional function
parameters.

- [ ] **Step 2 (45 min): Deliberately leaky goroutine — write then fix.**

Create `phase1_cli/internal/concurrency/patterns.go`:
```go
package concurrency

import (
    "context"
    "log/slog"
    "time"
)

// LeakyWorker launches goroutines that never stop — DO NOT USE IN PRODUCTION.
// This is a study artifact to make goroutine leaks visible.
func LeakyWorker(items []string, process func(string)) {
    for _, item := range items {
        item := item // capture loop variable (required pre-Go 1.22)
        go func() {
            for {
                process(item)
                time.Sleep(100 * time.Millisecond)
            }
            // BUG: no exit condition — this goroutine runs forever
        }()
    }
}

// BoundedWorker is the fixed version: every goroutine exits when ctx is done.
func BoundedWorker(ctx context.Context, items []string, process func(string)) {
    for _, item := range items {
        item := item
        go func() {
            for {
                select {
                case <-ctx.Done():
                    slog.Info("worker exiting", "item", item, "reason", ctx.Err())
                    return
                default:
                    process(item)
                    time.Sleep(100 * time.Millisecond)
                }
            }
        }()
    }
}
```

Create `phase1_cli/internal/concurrency/patterns_test.go`:
```go
package concurrency_test

import (
    "context"
    "sync/atomic"
    "testing"
    "time"

    "github.com/yourname/golang-mastery/phase1-cli/internal/concurrency"
)

func TestBoundedWorkerExits(t *testing.T) {
    ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
    defer cancel()

    var count atomic.Int64
    concurrency.BoundedWorker(ctx, []string{"a", "b", "c"}, func(s string) {
        count.Add(1)
    })

    <-ctx.Done()
    time.Sleep(50 * time.Millisecond) // let final iterations settle

    before := count.Load()
    time.Sleep(200 * time.Millisecond)
    after := count.Load()

    if after > before+3 {
        t.Errorf("goroutines still running after context cancel: count grew from %d to %d", before, after)
    }
}
```

```bash
go test ./phase1_cli/internal/concurrency/... -v
```
Expected: PASS.

- [ ] **Step 3 (40 min): sync.Once, RWMutex, atomic.**

Add to `phase1_cli/internal/concurrency/patterns.go`:
```go
import "sync"

// LazyConfig demonstrates sync.Once for safe lazy initialization.
// The inner init runs exactly once, even under concurrent access.
type LazyConfig struct {
    once   sync.Once
    config map[string]string
}

func (c *LazyConfig) Get(key string) string {
    c.once.Do(func() {
        c.config = map[string]string{
            "host": "localhost",
            "port": "5432",
        }
    })
    return c.config[key]
}

// RWCounter shows RWMutex: many readers can proceed concurrently,
// but a writer takes exclusive access.
type RWCounter struct {
    mu    sync.RWMutex
    value int
}

func (c *RWCounter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value++
}

func (c *RWCounter) Get() int {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.value
}
```

Add to `patterns_test.go`:
```go
import "sync"

func TestLazyConfig(t *testing.T) {
    cfg := &concurrency.LazyConfig{}
    var wg sync.WaitGroup
    for range 10 {
        wg.Add(1)
        go func() {
            defer wg.Done()
            v := cfg.Get("host")
            if v != "localhost" {
                t.Errorf("unexpected value: %s", v)
            }
        }()
    }
    wg.Wait()
}

func TestRWCounter(t *testing.T) {
    c := &concurrency.RWCounter{}
    var wg sync.WaitGroup
    for range 100 {
        wg.Add(1)
        go func() {
            defer wg.Done()
            c.Inc()
        }()
    }
    wg.Wait()
    if c.Get() != 100 {
        t.Errorf("counter = %d, want 100", c.Get())
    }
}
```

```bash
go test ./phase1_cli/internal/concurrency/... -v -race
```
Expected: PASS with race detector enabled. If race detector fires, the mutex
usage is wrong — fix before moving on.

- [ ] **Step 4 (30 min): context.WithCancelCause (Go 1.20).**

Add to `patterns.go`:
```go
// CancelWithCause demonstrates the Go 1.20 addition: you can attach a
// specific error to a cancellation, not just signal done.
func RunWithCause(ctx context.Context) {
    ctx, cancel := context.WithCancelCause(ctx)

    go func() {
        time.Sleep(50 * time.Millisecond)
        cancel(ErrNotFound) // attach a specific cause
    }()

    <-ctx.Done()
    cause := context.Cause(ctx) // retrieves ErrNotFound, not context.Canceled
    slog.Info("cancelled", "cause", cause)
}

// ErrNotFound is a sentinel used in this demo.
var ErrNotFound = errors.New("resource not found")
```

Add the `errors` import. Run:
```bash
go build ./phase1_cli/...
```
Expected: builds cleanly.

- [ ] **Step 5 (30 min): channel direction types.**

Add to `patterns.go`:
```go
// Pipeline demonstrates typed channel directions — send-only and receive-only.
// This prevents callers from accidentally closing the wrong end.

func producer(ctx context.Context, items []int) <-chan int {
    out := make(chan int, len(items))
    go func() {
        defer close(out)
        for _, v := range items {
            select {
            case out <- v:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

func doubler(ctx context.Context, in <-chan int) <-chan int {
    out := make(chan int, cap(in))
    go func() {
        defer close(out)
        for v := range in {
            select {
            case out <- v * 2:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// RunPipeline chains producer → doubler and collects results.
func RunPipeline(ctx context.Context, items []int) []int {
    ch := producer(ctx, items)
    ch = doubler(ctx, ch)
    var results []int
    for v := range ch {
        results = append(results, v)
    }
    return results
}
```

Add to `patterns_test.go`:
```go
func TestPipeline(t *testing.T) {
    ctx := context.Background()
    got := concurrency.RunPipeline(ctx, []int{1, 2, 3})
    want := []int{2, 4, 6}
    for i, v := range want {
        if got[i] != v {
            t.Errorf("Pipeline[%d] = %d, want %d", i, got[i], v)
        }
    }
}
```

```bash
go test ./phase1_cli/internal/concurrency/... -v -race
```
Expected: all PASS, no races.

- [ ] **Step 6 (45 min): Codebase read.**

```bash
cat $(go env GOROOT)/src/context/context.go | head -200
```
Read the `cancelCtx` implementation. Notice: `context.WithCancel` uses a mutex
and a map of children for propagation. Write in `journal.md`: how does
cancellation propagate from a parent to all children? (Trace the `propagateCancel`
function mentally.)

- [ ] **Step 7 (20 min): Journal.**

Append to `journal.md`:
- What is the difference between `context.WithDeadline` and
  `context.WithTimeout`?
- Why does `sync.Once` not expose a `Reset` method?
- What is `context.Cause` and why was it added in 1.20?

---

## Day 5: Concurrency patterns + Phase 1 deliverable

**Materials:**
- `go doc golang.org/x/sync/errgroup`
- etcd source: `github.com/etcd-io/etcd/client/v3/concurrency` — skim worker
  pool usage in a real infrastructure codebase

**Builds on:** Days 1–4.
**Sets up:** Phase 1 deliverable — the URL health checker used to validate all
Day 1–4 concepts in a single runnable tool.

- [ ] **Step 1 (15 min): Add errgroup dependency.**

```bash
cd phase1_cli
go get golang.org/x/sync@latest
```

Verify `go.mod` now lists `golang.org/x/sync`. Then:
```bash
go doc golang.org/x/sync/errgroup Group.SetLimit
```
Expected: shows the `SetLimit` doc. `SetLimit` bounds how many goroutines the
group runs concurrently — this is the idiomatic worker pool in modern Go.

- [ ] **Step 2 (40 min): errgroup bounded worker pool pattern.**

Add to `phase1_cli/internal/concurrency/patterns.go`:
```go
import "golang.org/x/sync/errgroup"

// BoundedPool runs process on each item using at most maxWorkers goroutines.
// If any call returns an error, remaining work is cancelled.
func BoundedPool[T any](
    ctx context.Context,
    items []T,
    maxWorkers int,
    process func(context.Context, T) error,
) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(maxWorkers)
    for _, item := range items {
        item := item
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

Add to `patterns_test.go`:
```go
func TestBoundedPool(t *testing.T) {
    ctx := context.Background()
    items := []int{1, 2, 3, 4, 5}
    var mu sync.Mutex
    var processed []int
    err := concurrency.BoundedPool(ctx, items, 2, func(ctx context.Context, n int) error {
        mu.Lock()
        processed = append(processed, n)
        mu.Unlock()
        return nil
    })
    if err != nil {
        t.Fatal(err)
    }
    if len(processed) != 5 {
        t.Errorf("processed %d items, want 5", len(processed))
    }
}
```

```bash
go test ./phase1_cli/internal/concurrency/... -v -race
```
Expected: PASS.

- [ ] **Step 3 (90 min): Build the URL health checker.**

Replace `phase1_cli/cmd/healthcheck/main.go` with the full implementation:

```go
package main

import (
    "bufio"
    "context"
    "flag"
    "log/slog"
    "net/http"
    "os"
    "strings"
    "sync"
    "time"

    "golang.org/x/sync/errgroup"
)

type result struct {
    URL        string `json:"url"`
    StatusCode int    `json:"status_code,omitempty"`
    LatencyMs  int64  `json:"latency_ms"`
    Err        string `json:"error,omitempty"`
}

func checkURL(ctx context.Context, client *http.Client, url string) result {
    start := time.Now()
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return result{URL: url, LatencyMs: time.Since(start).Milliseconds(), Err: err.Error()}
    }
    resp, err := client.Do(req)
    latencyMs := time.Since(start).Milliseconds()
    if err != nil {
        return result{URL: url, LatencyMs: latencyMs, Err: err.Error()}
    }
    defer resp.Body.Close()
    return result{URL: url, StatusCode: resp.StatusCode, LatencyMs: latencyMs}
}

func main() {
    workers := flag.Int("workers", 10, "number of concurrent workers")
    timeout := flag.Duration("timeout", 30*time.Second, "global timeout")
    flag.Parse()

    logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
    slog.SetDefault(logger)

    ctx, cancel := context.WithTimeout(context.Background(), *timeout)
    defer cancel()

    // Read URLs from stdin before starting workers
    var urls []string
    scanner := bufio.NewScanner(os.Stdin)
    for scanner.Scan() {
        if u := strings.TrimSpace(scanner.Text()); u != "" {
            urls = append(urls, u)
        }
    }

    if len(urls) == 0 {
        slog.Warn("no URLs provided on stdin")
        return
    }

    var (
        mu      sync.Mutex
        results []result
    )

    client := &http.Client{Timeout: 10 * time.Second}
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(*workers)

    for _, url := range urls {
        url := url
        g.Go(func() error {
            r := checkURL(ctx, client, url)
            mu.Lock()
            results = append(results, r)
            mu.Unlock()
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        slog.Error("worker group error", "err", err)
    }

    var failed int
    for _, r := range results {
        if r.Err != "" {
            failed++
            slog.Error("check failed",
                "url", r.URL,
                "error", r.Err,
                "latency_ms", r.LatencyMs,
            )
        } else {
            slog.Info("check ok",
                "url", r.URL,
                "status_code", r.StatusCode,
                "latency_ms", r.LatencyMs,
            )
        }
    }

    slog.Info("summary",
        "total", len(results),
        "failed", failed,
        "passed", len(results)-failed,
    )

    if failed > 0 {
        os.Exit(1)
    }
}
```

- [ ] **Step 4 (20 min): Run the health checker.**

```bash
go build -o ./bin/healthcheck ./phase1_cli/cmd/healthcheck
printf "https://go.dev\nhttps://pkg.go.dev\nhttps://invalid.local\n" | \
  ./bin/healthcheck -workers 3 -timeout 10s
```
Expected: two `check ok` JSON lines, one `check failed` line for the invalid
URL, and a `summary` line. Exit code 1 (because one failed).

Test timeout:
```bash
printf "https://go.dev\n" | ./bin/healthcheck -timeout 1ms
```
Expected: the request either fails or the summary shows a timeout error. Exit
code 1.

- [ ] **Step 5 (30 min): Write a test for checkURL.**

Create `phase1_cli/cmd/healthcheck/main_test.go`:
```go
package main

import (
    "context"
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestCheckURL_OK(t *testing.T) {
    srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))
    defer srv.Close()

    client := srv.Client()
    r := checkURL(context.Background(), client, srv.URL)
    if r.Err != "" {
        t.Fatalf("unexpected error: %s", r.Err)
    }
    if r.StatusCode != 200 {
        t.Errorf("status = %d, want 200", r.StatusCode)
    }
}

func TestCheckURL_Cancel(t *testing.T) {
    srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))
    defer srv.Close()

    ctx, cancel := context.WithCancel(context.Background())
    cancel() // cancel immediately

    client := srv.Client()
    r := checkURL(ctx, client, srv.URL)
    if r.Err == "" {
        t.Error("expected error for cancelled context")
    }
}
```

```bash
go test ./phase1_cli/cmd/healthcheck/... -v
```
Expected: PASS.

- [ ] **Step 6 (45 min): Codebase read.**

Skim `golang.org/x/sync/errgroup/errgroup.go` (after `go get` it's in the
module cache):
```bash
cat $(go env GOMODCACHE)/golang.org/x/sync@*/errgroup/errgroup.go
```
Read `SetLimit`, `Go`, and `Wait`. Notice: `SetLimit` uses a buffered channel
as a semaphore — the same pattern you'd use manually. Write in `journal.md`:
how does the buffered channel work as a semaphore?

- [ ] **Step 7 (20 min): Journal — Phase 1 close-out.**

Append to `journal.md`:
- What is the difference between `sync.WaitGroup` and `errgroup.Group`? When
  does `errgroup` add value?
- Which Day 1–4 concept felt rustiest when you had to actually use it in the
  health checker?
- What would you change about the health checker design if you had to make it
  production-ready? (Don't implement it — just write the list.)

---

## Day 6: net/http deep dive

**Materials:**
- `go doc net/http` — read Handler, HandlerFunc, ServeMux, Server
- Go blog: "Writing Web Applications" (go.dev/doc/articles/wiki)
- Real codebase: `$(go env GOROOT)/src/net/http/server.go` lines 1–100

**Builds on:** Phase 1 complete.
**Sets up:** Day 7 Gin makes sense only after you understand what it wraps.

- [ ] **Step 1 (15 min): Add phase2 to workspace (already in go.work). Create first files.**

```bash
mkdir -p phase2_rest/cmd/api phase2_rest/internal/{model,repository,handler,middleware}
mkdir -p phase2_rest/migrations
```

- [ ] **Step 2 (30 min): Primer — read http.Handler interface.**

```bash
go doc net/http Handler
go doc net/http HandlerFunc
go doc net/http ServeMux
```

Key insight to write in `journal.md`: `http.Handler` is a single-method
interface. `http.HandlerFunc` is a function type that implements it. Every
middleware in Go wraps one `http.Handler` in another — this is the entire
pattern Gin is built on.

- [ ] **Step 3 (45 min): Build a zero-dependency task API.**

Create `phase2_rest/internal/model/task.go`:
```go
package model

import "time"

type Task struct {
    ID        string    `json:"id"`
    Title     string    `json:"title"`
    Done      bool      `json:"done"`
    CreatedAt time.Time `json:"created_at"`
}
```

Create `phase2_rest/internal/handler/stdlib_task.go` — a raw `net/http`
handler, no frameworks:
```go
package handler

import (
    "encoding/json"
    "net/http"
    "sync"
    "time"

    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

// StdlibTaskHandler demonstrates a handler using only net/http.
// Day 7 will replace this with Gin.
type StdlibTaskHandler struct {
    mu    sync.RWMutex
    tasks map[string]model.Task
}

func NewStdlibTaskHandler() *StdlibTaskHandler {
    return &StdlibTaskHandler{tasks: make(map[string]model.Task)}
}

func (h *StdlibTaskHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        h.list(w, r)
    case http.MethodPost:
        h.create(w, r)
    default:
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
    }
}

func (h *StdlibTaskHandler) list(w http.ResponseWriter, r *http.Request) {
    h.mu.RLock()
    tasks := make([]model.Task, 0, len(h.tasks))
    for _, t := range h.tasks {
        tasks = append(tasks, t)
    }
    h.mu.RUnlock()
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(tasks)
}

func (h *StdlibTaskHandler) create(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Title string `json:"title"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    if req.Title == "" {
        http.Error(w, "title required", http.StatusBadRequest)
        return
    }
    t := model.Task{
        ID:        time.Now().Format("20060102150405.000"),
        Title:     req.Title,
        CreatedAt: time.Now(),
    }
    h.mu.Lock()
    h.tasks[t.ID] = t
    h.mu.Unlock()
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(t)
}
```

- [ ] **Step 4 (30 min): Middleware as handler wrappers.**

Create `phase2_rest/internal/middleware/logger.go`:
```go
package middleware

import (
    "log/slog"
    "net/http"
    "time"
)

// Logger wraps next, logging method, path, status, and latency for every request.
func Logger(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
        next.ServeHTTP(rw, r)
        slog.Info("request",
            "method", r.Method,
            "path", r.URL.Path,
            "status", rw.status,
            "latency_ms", time.Since(start).Milliseconds(),
        )
    })
}

type responseWriter struct {
    http.ResponseWriter
    status int
}

func (rw *responseWriter) WriteHeader(status int) {
    rw.status = status
    rw.ResponseWriter.WriteHeader(status)
}
```

- [ ] **Step 5 (30 min): Wire up and run.**

Create `phase2_rest/cmd/api/main.go`:
```go
package main

import (
    "log/slog"
    "net/http"
    "os"

    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
    "github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    taskHandler := handler.NewStdlibTaskHandler()

    mux := http.NewServeMux()
    mux.Handle("/tasks", taskHandler)

    srv := &http.Server{
        Addr:    ":8080",
        Handler: middleware.Logger(mux),
    }
    slog.Info("listening", "addr", srv.Addr)
    if err := srv.ListenAndServe(); err != nil {
        slog.Error("server error", "err", err)
        os.Exit(1)
    }
}
```

```bash
go run ./phase2_rest/cmd/api &
sleep 1
curl -s -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"buy milk"}' | jq .
curl -s http://localhost:8080/tasks | jq .
kill %1
```
Expected: POST returns a task with an `id`; GET returns a list containing it.
Server logs show JSON request lines.

- [ ] **Step 6 (45 min): Codebase read.**

```bash
cat $(go env GOROOT)/src/net/http/server.go | grep -A 20 "type ServeMux struct"
```
Read the `ServeMux` type and its `Handle` method. Notice: it's just a map of
pattern strings to handlers with a mutex. This is why third-party routers
exist — trie-based routers are faster and support path params. Write in
`journal.md`: what does `ServeMux` *not* support that you'd need in a real API?

- [ ] **Step 7 (15 min): Journal.**

Append to `journal.md`:
- What is the type signature of an HTTP middleware in Go?
- Why does wrapping handlers (vs a global before/after hook) compose better?

---

## Day 7: Gin fundamentals

**Materials:**
- Gin README (github.com/gin-gonic/gin) — skim the examples section
- `go doc github.com/gin-gonic/gin Context`

**Builds on:** Day 6 stdlib handler (Day 7 rewrites it in Gin).
**Sets up:** Day 8 adds middleware on top of today's router.

- [ ] **Step 1 (15 min): Add Gin dependency.**

```bash
cd phase2_rest
go get github.com/gin-gonic/gin@latest
```

- [ ] **Step 2 (20 min): Primer.**

```bash
go doc github.com/gin-gonic/gin Engine
go doc github.com/gin-gonic/gin Context
```
Write in `journal.md`: three things `gin.Context` provides that you had to
build manually in the Day 6 handler (`responseWriter` wrapper, JSON decode,
JSON encode).

- [ ] **Step 3 (60 min): Rewrite the task handler in Gin.**

Create `phase2_rest/internal/handler/task.go`:
```go
package handler

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

type TaskHandler struct {
    mu    sync.RWMutex
    tasks map[string]model.Task
}

func NewTaskHandler() *TaskHandler {
    return &TaskHandler{tasks: make(map[string]model.Task)}
}

type createTaskRequest struct {
    Title string `json:"title" binding:"required,min=1,max=200"`
}

func (h *TaskHandler) List(c *gin.Context) {
    h.mu.RLock()
    tasks := make([]model.Task, 0, len(h.tasks))
    for _, t := range h.tasks {
        tasks = append(tasks, t)
    }
    h.mu.RUnlock()
    c.JSON(http.StatusOK, tasks)
}

func (h *TaskHandler) Create(c *gin.Context) {
    var req createTaskRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    t := model.Task{
        ID:        time.Now().Format("20060102150405.000"),
        Title:     req.Title,
        CreatedAt: time.Now(),
    }
    h.mu.Lock()
    h.tasks[t.ID] = t
    h.mu.Unlock()
    c.JSON(http.StatusCreated, t)
}

func (h *TaskHandler) Get(c *gin.Context) {
    id := c.Param("id")
    h.mu.RLock()
    t, ok := h.tasks[id]
    h.mu.RUnlock()
    if !ok {
        c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"error": "task not found"})
        return
    }
    c.JSON(http.StatusOK, t)
}

func (h *TaskHandler) Complete(c *gin.Context) {
    id := c.Param("id")
    h.mu.Lock()
    t, ok := h.tasks[id]
    if ok {
        t.Done = true
        h.tasks[id] = t
    }
    h.mu.Unlock()
    if !ok {
        c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"error": "task not found"})
        return
    }
    c.JSON(http.StatusOK, t)
}
```

- [ ] **Step 4 (30 min): Wire the Gin router.**

Update `phase2_rest/cmd/api/main.go`:
```go
package main

import (
    "log/slog"
    "os"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    r := gin.New()
    r.Use(gin.Recovery())

    h := handler.NewTaskHandler()
    v1 := r.Group("/api/v1")
    {
        v1.GET("/tasks", h.List)
        v1.POST("/tasks", h.Create)
        v1.GET("/tasks/:id", h.Get)
        v1.PATCH("/tasks/:id/complete", h.Complete)
    }

    slog.Info("listening", "addr", ":8080")
    if err := r.Run(":8080"); err != nil {
        slog.Error("server error", "err", err)
        os.Exit(1)
    }
}
```

```bash
go run ./phase2_rest/cmd/api &
sleep 1
# create
ID=$(curl -s -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"buy milk"}' | jq -r .id)
# get by id
curl -s http://localhost:8080/api/v1/tasks/$ID | jq .
# complete
curl -s -X PATCH http://localhost:8080/api/v1/tasks/$ID/complete | jq .done
# validation error
curl -s -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
kill %1
```
Expected: created task, get returns it, complete returns `true`, empty title
returns `{"error":"Key: 'createTaskRequest.Title' Error:..."}`.

- [ ] **Step 5 (30 min): Handler test with httptest.**

Create `phase2_rest/internal/handler/task_test.go`:
```go
package handler_test

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

func setupRouter() *gin.Engine {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    h := handler.NewTaskHandler()
    r.GET("/api/v1/tasks", h.List)
    r.POST("/api/v1/tasks", h.Create)
    r.GET("/api/v1/tasks/:id", h.Get)
    r.PATCH("/api/v1/tasks/:id/complete", h.Complete)
    return r
}

func TestCreateAndGet(t *testing.T) {
    r := setupRouter()

    body, _ := json.Marshal(map[string]string{"title": "test task"})
    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    r.ServeHTTP(w, req)

    if w.Code != http.StatusCreated {
        t.Fatalf("create status = %d, want 201", w.Code)
    }

    var created model.Task
    json.Unmarshal(w.Body.Bytes(), &created)
    if created.ID == "" {
        t.Fatal("expected non-empty ID")
    }

    w2 := httptest.NewRecorder()
    req2, _ := http.NewRequest(http.MethodGet, "/api/v1/tasks/"+created.ID, nil)
    r.ServeHTTP(w2, req2)
    if w2.Code != http.StatusOK {
        t.Errorf("get status = %d, want 200", w2.Code)
    }
}

func TestCreateValidation(t *testing.T) {
    r := setupRouter()
    body := bytes.NewBufferString(`{}`)
    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodPost, "/api/v1/tasks", body)
    req.Header.Set("Content-Type", "application/json")
    r.ServeHTTP(w, req)
    if w.Code != http.StatusBadRequest {
        t.Errorf("status = %d, want 400", w.Code)
    }
}
```

```bash
go test ./phase2_rest/internal/handler/... -v
```
Expected: PASS.

- [ ] **Step 6 (45 min): Codebase read.**

```bash
cat $(go env GOMODCACHE)/github.com/gin-gonic/gin@*/tree.go | head -100
```
Read the radix tree router. Notice: path params (`:id`) are stored as tree
nodes. Write in `journal.md`: why is a trie faster than `ServeMux`'s linear
map lookup for large route tables?

- [ ] **Step 7 (15 min): Journal.**

Append to `journal.md`:
- What does `c.ShouldBindJSON` do that `json.NewDecoder(r.Body).Decode` does
  not?
- What is `c.AbortWithStatusJSON` and why is `Abort` needed in a middleware
  chain?

---

## Day 8: Gin middleware

**Materials:**
- `go doc github.com/gin-gonic/gin HandlerFunc`
- JWT: github.com/golang-jwt/jwt/v5 README

**Builds on:** Day 7 Gin router.
**Sets up:** Day 9 DB layer sits behind the auth middleware from today.

- [ ] **Step 1 (10 min): Add JWT dependency.**

```bash
cd phase2_rest
go get github.com/golang-jwt/jwt/v5@latest
```

- [ ] **Step 2 (50 min): JWT auth middleware.**

Create `phase2_rest/internal/middleware/auth.go`:
```go
package middleware

import (
    "net/http"
    "os"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

var jwtSecret = []byte(getEnvOrDefault("JWT_SECRET", "dev-secret-change-in-prod"))

func getEnvOrDefault(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}

type Claims struct {
    UserID string `json:"user_id"`
    jwt.RegisteredClaims
}

// GenerateToken creates a signed JWT for the given userID (used in tests).
func GenerateToken(userID string) (string, error) {
    claims := Claims{
        UserID: userID,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(jwtSecret)
}

// Auth validates the Bearer token in Authorization header and attaches
// the userID to the Gin context under the key "userID".
func Auth() gin.HandlerFunc {
    return func(c *gin.Context) {
        header := c.GetHeader("Authorization")
        if !strings.HasPrefix(header, "Bearer ") {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
            return
        }
        raw := strings.TrimPrefix(header, "Bearer ")
        var claims Claims
        token, err := jwt.ParseWithClaims(raw, &claims, func(t *jwt.Token) (any, error) {
            if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, jwt.ErrSignatureInvalid
            }
            return jwtSecret, nil
        })
        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
            return
        }
        c.Set("userID", claims.UserID)
        c.Next()
    }
}
```

- [ ] **Step 3 (40 min): Request logger and rate limiter middleware.**

Update `phase2_rest/internal/middleware/logger.go` — replace the stdlib version
with a Gin-native one:
```go
package middleware

import (
    "log/slog"
    "time"

    "github.com/gin-gonic/gin"
)

// GinLogger replaces gin.Logger() with a structured slog version.
func GinLogger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        slog.Info("request",
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "latency_ms", time.Since(start).Milliseconds(),
            "client_ip", c.ClientIP(),
        )
    }
}
```

Create `phase2_rest/internal/middleware/ratelimit.go`:
```go
package middleware

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
)

type tokenBucket struct {
    mu       sync.Mutex
    tokens   float64
    max      float64
    rate     float64 // tokens per second
    lastFill time.Time
}

func (b *tokenBucket) allow() bool {
    b.mu.Lock()
    defer b.mu.Unlock()
    now := time.Now()
    elapsed := now.Sub(b.lastFill).Seconds()
    b.tokens = min(b.max, b.tokens+elapsed*b.rate)
    b.lastFill = now
    if b.tokens < 1 {
        return false
    }
    b.tokens--
    return true
}

// RateLimit limits each client IP to maxRPS requests per second.
func RateLimit(maxRPS float64) gin.HandlerFunc {
    buckets := make(map[string]*tokenBucket)
    var mu sync.Mutex

    return func(c *gin.Context) {
        ip := c.ClientIP()
        mu.Lock()
        b, ok := buckets[ip]
        if !ok {
            b = &tokenBucket{tokens: maxRPS, max: maxRPS, rate: maxRPS, lastFill: time.Now()}
            buckets[ip] = b
        }
        mu.Unlock()

        if !b.allow() {
            c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
            return
        }
        c.Next()
    }
}
```

- [ ] **Step 4 (30 min): Wire all middleware into the router.**

Update `phase2_rest/cmd/api/main.go`:
```go
package main

import (
    "log/slog"
    "os"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
    "github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    r := gin.New()
    r.Use(gin.Recovery(), middleware.GinLogger(), middleware.RateLimit(100))

    h := handler.NewTaskHandler()

    r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

    v1 := r.Group("/api/v1")
    v1.Use(middleware.Auth())
    {
        v1.GET("/tasks", h.List)
        v1.POST("/tasks", h.Create)
        v1.GET("/tasks/:id", h.Get)
        v1.PATCH("/tasks/:id/complete", h.Complete)
    }

    slog.Info("listening", "addr", ":8080")
    if err := r.Run(":8080"); err != nil {
        slog.Error("server", "err", err)
        os.Exit(1)
    }
}
```

Test the full stack:
```bash
go run ./phase2_rest/cmd/api &
sleep 1
# health check (no auth)
curl -s http://localhost:8080/healthz
# no token → 401
curl -s http://localhost:8080/api/v1/tasks
# generate token inline (Go one-liner)
TOKEN=$(go run -v ./phase2_rest/cmd/token 2>/dev/null || \
  echo "generate a token using GenerateToken(\"user1\") in a small main")
kill %1
```

Create a tiny token-gen helper `phase2_rest/cmd/token/main.go`:
```go
package main

import (
    "fmt"
    "github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
)

func main() {
    token, err := middleware.GenerateToken("user1")
    if err != nil {
        panic(err)
    }
    fmt.Println(token)
}
```

```bash
go run ./phase2_rest/cmd/api &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)
curl -s -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"authenticated task"}' | jq .
kill %1
```
Expected: task created with 201. Without token: 401.

- [ ] **Step 5 (30 min): Middleware test.**

Add to `phase2_rest/internal/handler/task_test.go`:
```go
func TestAuthRequired(t *testing.T) {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.Use(middleware.Auth())
    h := handler.NewTaskHandler()
    r.GET("/api/v1/tasks", h.List)

    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
    r.ServeHTTP(w, req)
    if w.Code != http.StatusUnauthorized {
        t.Errorf("status = %d, want 401", w.Code)
    }
}

func TestAuthValid(t *testing.T) {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.Use(middleware.Auth())
    h := handler.NewTaskHandler()
    r.GET("/api/v1/tasks", h.List)

    token, _ := middleware.GenerateToken("user1")
    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
    req.Header.Set("Authorization", "Bearer "+token)
    r.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want 200", w.Code)
    }
}
```

Add `middleware` to the import. Run:
```bash
go test ./phase2_rest/... -v
```
Expected: all PASS.

- [ ] **Step 6 (40 min): Codebase read.**

```bash
cat $(go env GOMODCACHE)/github.com/gin-gonic/gin@*/gin.go | grep -A 30 "func.*Use"
```
Read `Engine.Use` and `RouterGroup.Use`. Notice: middleware is just a slice of
`HandlerFunc` prepended before route handlers. `c.Next()` advances the index.
Write in `journal.md`: what happens if you call `c.Abort()` — which handlers
still run?

- [ ] **Step 7 (15 min): Journal.**

Append to `journal.md`:
- What is the difference between `c.Abort()` and `return` in a middleware?
- Where should you NOT put business logic in a middleware? Give a concrete
  example.

---

## Day 9: Database integration

**Materials:**
- `go doc database/sql`
- pgx v5 README: github.com/jackc/pgx
- golang-migrate README: github.com/golang-migrate/migrate

**Builds on:** Day 8 handler + middleware.
**Sets up:** Day 10 tests the DB layer via interface mocks and real containers.

- [ ] **Step 1 (15 min): Add dependencies.**

```bash
cd phase2_rest
go get github.com/jackc/pgx/v5@latest
go get github.com/jackc/pgx/v5/stdlib@latest
go get github.com/golang-migrate/migrate/v4@latest
go get github.com/golang-migrate/migrate/v4/database/postgres@latest
go get github.com/golang-migrate/migrate/v4/source/file@latest
```

- [ ] **Step 2 (30 min): Repository interface.**

Create `phase2_rest/internal/repository/repository.go`:
```go
package repository

import (
    "context"

    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

// TaskRepository is the interface the handler depends on.
// Concrete implementations: PostgresTaskRepository (prod), MemoryTaskRepository (tests).
type TaskRepository interface {
    List(ctx context.Context) ([]model.Task, error)
    Get(ctx context.Context, id string) (model.Task, error)
    Create(ctx context.Context, title string) (model.Task, error)
    Complete(ctx context.Context, id string) (model.Task, error)
}
```

- [ ] **Step 3 (50 min): In-memory repository (used in tests without a DB).**

Create `phase2_rest/internal/repository/memory.go`:
```go
package repository

import (
    "context"
    "fmt"
    "sync"
    "time"

    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

var ErrNotFound = fmt.Errorf("task not found")

type MemoryTaskRepository struct {
    mu    sync.RWMutex
    tasks map[string]model.Task
    seq   int
}

func NewMemoryTaskRepository() *MemoryTaskRepository {
    return &MemoryTaskRepository{tasks: make(map[string]model.Task)}
}

func (r *MemoryTaskRepository) List(_ context.Context) ([]model.Task, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    out := make([]model.Task, 0, len(r.tasks))
    for _, t := range r.tasks {
        out = append(out, t)
    }
    return out, nil
}

func (r *MemoryTaskRepository) Get(_ context.Context, id string) (model.Task, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    t, ok := r.tasks[id]
    if !ok {
        return model.Task{}, ErrNotFound
    }
    return t, nil
}

func (r *MemoryTaskRepository) Create(_ context.Context, title string) (model.Task, error) {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.seq++
    t := model.Task{
        ID:        fmt.Sprintf("task-%d", r.seq),
        Title:     title,
        CreatedAt: time.Now(),
    }
    r.tasks[t.ID] = t
    return t, nil
}

func (r *MemoryTaskRepository) Complete(_ context.Context, id string) (model.Task, error) {
    r.mu.Lock()
    defer r.mu.Unlock()
    t, ok := r.tasks[id]
    if !ok {
        return model.Task{}, ErrNotFound
    }
    t.Done = true
    r.tasks[id] = t
    return t, nil
}
```

- [ ] **Step 4 (60 min): PostgreSQL repository.**

Create `phase2_rest/migrations/001_create_tasks.up.sql`:
```sql
CREATE TABLE IF NOT EXISTS tasks (
    id         TEXT PRIMARY KEY,
    title      TEXT NOT NULL,
    done       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Create `phase2_rest/migrations/001_create_tasks.down.sql`:
```sql
DROP TABLE IF EXISTS tasks;
```

Create `phase2_rest/internal/repository/postgres.go`:
```go
package repository

import (
    "context"
    "database/sql"
    "fmt"
    "time"

    _ "github.com/jackc/pgx/v5/stdlib"
)

type PostgresTaskRepository struct {
    db *sql.DB
}

func NewPostgresTaskRepository(db *sql.DB) *PostgresTaskRepository {
    return &PostgresTaskRepository{db: db}
}

func OpenPostgres(dsn string) (*sql.DB, error) {
    db, err := sql.Open("pgx", dsn)
    if err != nil {
        return nil, err
    }
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("ping: %w", err)
    }
    return db, nil
}

func (r *PostgresTaskRepository) List(ctx context.Context) ([]model.Task, error) {
    rows, err := r.db.QueryContext(ctx,
        `SELECT id, title, done, created_at FROM tasks ORDER BY created_at DESC`)
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    var tasks []model.Task
    for rows.Next() {
        var t model.Task
        if err := rows.Scan(&t.ID, &t.Title, &t.Done, &t.CreatedAt); err != nil {
            return nil, err
        }
        tasks = append(tasks, t)
    }
    return tasks, rows.Err()
}

func (r *PostgresTaskRepository) Get(ctx context.Context, id string) (model.Task, error) {
    var t model.Task
    err := r.db.QueryRowContext(ctx,
        `SELECT id, title, done, created_at FROM tasks WHERE id = $1`, id).
        Scan(&t.ID, &t.Title, &t.Done, &t.CreatedAt)
    if err == sql.ErrNoRows {
        return model.Task{}, ErrNotFound
    }
    return t, err
}

func (r *PostgresTaskRepository) Create(ctx context.Context, title string) (model.Task, error) {
    t := model.Task{
        ID:        fmt.Sprintf("task-%d", time.Now().UnixNano()),
        Title:     title,
        CreatedAt: time.Now(),
    }
    _, err := r.db.ExecContext(ctx,
        `INSERT INTO tasks (id, title, done, created_at) VALUES ($1,$2,$3,$4)`,
        t.ID, t.Title, t.Done, t.CreatedAt)
    return t, err
}

func (r *PostgresTaskRepository) Complete(ctx context.Context, id string) (model.Task, error) {
    _, err := r.db.ExecContext(ctx,
        `UPDATE tasks SET done=TRUE WHERE id=$1`, id)
    if err != nil {
        return model.Task{}, err
    }
    return r.Get(ctx, id)
}
```

Fix missing import for `model` package in `postgres.go` — add:
```go
import "github.com/yourname/golang-mastery/phase2-rest/internal/model"
```

- [ ] **Step 5 (30 min): Update handler to use the repository interface.**

Replace the in-memory map in `phase2_rest/internal/handler/task.go` with the
repository:
```go
package handler

import (
    "errors"
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

type TaskHandler struct {
    repo repository.TaskRepository
}

func NewTaskHandler(repo repository.TaskRepository) *TaskHandler {
    return &TaskHandler{repo: repo}
}

type createTaskRequest struct {
    Title string `json:"title" binding:"required,min=1,max=200"`
}

func (h *TaskHandler) List(c *gin.Context) {
    tasks, err := h.repo.List(c.Request.Context())
    if err != nil {
        c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusOK, tasks)
}

func (h *TaskHandler) Create(c *gin.Context) {
    var req createTaskRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    t, err := h.repo.Create(c.Request.Context(), req.Title)
    if err != nil {
        c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusCreated, t)
}

func (h *TaskHandler) Get(c *gin.Context) {
    t, err := h.repo.Get(c.Request.Context(), c.Param("id"))
    if errors.Is(err, repository.ErrNotFound) {
        c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"error": "task not found"})
        return
    }
    if err != nil {
        c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusOK, t)
}

func (h *TaskHandler) Complete(c *gin.Context) {
    t, err := h.repo.Complete(c.Request.Context(), c.Param("id"))
    if errors.Is(err, repository.ErrNotFound) {
        c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"error": "task not found"})
        return
    }
    if err != nil {
        c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusOK, t)
}
```

Update `phase2_rest/cmd/api/main.go` to pass `repository.NewMemoryTaskRepository()`
for now (Postgres wired on Day 11 after Docker):
```go
import "github.com/yourname/golang-mastery/phase2-rest/internal/repository"
// ...
repo := repository.NewMemoryTaskRepository()
h := handler.NewTaskHandler(repo)
```

```bash
go build ./phase2_rest/...
```
Expected: clean build.

- [ ] **Step 6 (15 min): Journal.**

Append to `journal.md`:
- Why is `db.SetMaxOpenConns` important for a service that handles concurrent
  requests? What happens without it?
- What is the repository pattern and what does it buy you in testing?

---

## Day 10: Testing

**Materials:**
- `go doc testing`
- testcontainers-go quickstart: testcontainers.com/guides/getting-started-with-testcontainers-for-go
- Go blog: "The Go Blog: Testing Flags" — `go test -race` and `-count`

**Builds on:** Day 9 repository interface + memory mock.
**Sets up:** Day 11 wires the real DB after containers prove it works.

- [ ] **Step 1 (15 min): Add testcontainers.**

```bash
cd phase2_rest
go get github.com/testcontainers/testcontainers-go@latest
go get github.com/testcontainers/testcontainers-go/modules/postgres@latest
```

- [ ] **Step 2 (30 min): Table-driven unit tests for the handler.**

Update `phase2_rest/internal/handler/task_test.go` — replace the two tests
with a proper table-driven suite:
```go
package handler_test

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
    "github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
    "github.com/yourname/golang-mastery/phase2-rest/internal/model"
    "github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

func setupRouter() (*gin.Engine, *repository.MemoryTaskRepository) {
    gin.SetMode(gin.TestMode)
    repo := repository.NewMemoryTaskRepository()
    h := handler.NewTaskHandler(repo)
    r := gin.New()
    r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
    v1 := r.Group("/api/v1")
    v1.Use(middleware.Auth())
    v1.GET("/tasks", h.List)
    v1.POST("/tasks", h.Create)
    v1.GET("/tasks/:id", h.Get)
    v1.PATCH("/tasks/:id/complete", h.Complete)
    return r, repo
}

func authHeader() string {
    token, _ := middleware.GenerateToken("user1")
    return "Bearer " + token
}

func TestTaskEndpoints(t *testing.T) {
    r, _ := setupRouter()

    var createdID string

    tests := []struct {
        name       string
        method     string
        path       string
        body       string
        wantStatus int
        check      func(t *testing.T, body []byte)
    }{
        {
            name: "create task",
            method: http.MethodPost, path: "/api/v1/tasks",
            body: `{"title":"buy milk"}`, wantStatus: http.StatusCreated,
            check: func(t *testing.T, body []byte) {
                var task model.Task
                json.Unmarshal(body, &task)
                if task.ID == "" {
                    t.Error("expected ID")
                }
                createdID = task.ID
            },
        },
        {
            name: "create empty title",
            method: http.MethodPost, path: "/api/v1/tasks",
            body: `{}`, wantStatus: http.StatusBadRequest,
        },
        {
            name: "list tasks",
            method: http.MethodGet, path: "/api/v1/tasks",
            wantStatus: http.StatusOK,
            check: func(t *testing.T, body []byte) {
                var tasks []model.Task
                json.Unmarshal(body, &tasks)
                if len(tasks) == 0 {
                    t.Error("expected at least one task")
                }
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            var bodyReader *bytes.Reader
            if tt.body != "" {
                bodyReader = bytes.NewReader([]byte(tt.body))
            } else {
                bodyReader = bytes.NewReader(nil)
            }
            w := httptest.NewRecorder()
            req, _ := http.NewRequest(tt.method, tt.path, bodyReader)
            req.Header.Set("Content-Type", "application/json")
            req.Header.Set("Authorization", authHeader())
            r.ServeHTTP(w, req)
            if w.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d (body: %s)",
                    w.Code, tt.wantStatus, w.Body.String())
            }
            if tt.check != nil {
                tt.check(t, w.Body.Bytes())
            }
        })
    }

    // get by id — depends on createdID from first test
    if createdID != "" {
        w := httptest.NewRecorder()
        req, _ := http.NewRequest(http.MethodGet,
            fmt.Sprintf("/api/v1/tasks/%s", createdID), nil)
        req.Header.Set("Authorization", authHeader())
        r.ServeHTTP(w, req)
        if w.Code != http.StatusOK {
            t.Errorf("get by id status = %d, want 200", w.Code)
        }
    }
}
```

```bash
go test ./phase2_rest/internal/handler/... -v -race
```
Expected: PASS.

- [ ] **Step 3 (60 min): Integration test with testcontainers.**

Create `phase2_rest/internal/repository/postgres_integration_test.go`:
```go
//go:build integration

package repository_test

import (
    "context"
    "database/sql"
    "testing"

    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
    "github.com/testcontainers/testcontainers-go/wait"
)

func TestPostgresRepository(t *testing.T) {
    ctx := context.Background()

    pgContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:16-alpine"),
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections").
                WithOccurrence(2)),
    )
    if err != nil {
        t.Fatalf("start postgres: %v", err)
    }
    t.Cleanup(func() { pgContainer.Terminate(ctx) })

    dsn, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
    if err != nil {
        t.Fatal(err)
    }

    db, err := sql.Open("pgx", dsn)
    if err != nil {
        t.Fatal(err)
    }
    defer db.Close()

    // Run migration manually for the test
    _, err = db.ExecContext(ctx, `
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            done BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )`)
    if err != nil {
        t.Fatal(err)
    }

    repo := repository.NewPostgresTaskRepository(db)

    t.Run("create and get", func(t *testing.T) {
        task, err := repo.Create(ctx, "integration test task")
        if err != nil {
            t.Fatal(err)
        }
        got, err := repo.Get(ctx, task.ID)
        if err != nil {
            t.Fatal(err)
        }
        if got.Title != "integration test task" {
            t.Errorf("title = %q, want %q", got.Title, "integration test task")
        }
    })

    t.Run("complete", func(t *testing.T) {
        task, _ := repo.Create(ctx, "to complete")
        done, err := repo.Complete(ctx, task.ID)
        if err != nil {
            t.Fatal(err)
        }
        if !done.Done {
            t.Error("expected done=true")
        }
    })

    t.Run("not found", func(t *testing.T) {
        _, err := repo.Get(ctx, "nonexistent")
        if !errors.Is(err, repository.ErrNotFound) {
            t.Errorf("expected ErrNotFound, got %v", err)
        }
    })
}
```

Add missing imports (`errors`, `repository`). Run integration tests (requires Docker):
```bash
go test ./phase2_rest/internal/repository/... -tags integration -v
```
Expected: PASS (Docker must be running). If Docker is unavailable, this test is
skipped by the build tag — unit tests still run without `-tags integration`.

- [ ] **Step 4 (20 min): Benchmark test.**

Add to `phase2_rest/internal/handler/task_test.go`:
```go
func BenchmarkCreateTask(b *testing.B) {
    r, _ := setupRouter()
    token, _ := middleware.GenerateToken("bench-user")
    auth := "Bearer " + token

    b.ResetTimer()
    for range b.N {
        body := bytes.NewReader([]byte(`{"title":"bench task"}`))
        w := httptest.NewRecorder()
        req, _ := http.NewRequest(http.MethodPost, "/api/v1/tasks", body)
        req.Header.Set("Content-Type", "application/json")
        req.Header.Set("Authorization", auth)
        r.ServeHTTP(w, req)
    }
}
```

```bash
go test ./phase2_rest/internal/handler/... -bench=. -benchmem
```
Expected: shows ns/op and B/op numbers. Note them in `journal.md` — you'll
compare against the gateway benchmark on Day 19.

- [ ] **Step 5 (15 min): Journal.**

Append to `journal.md`:
- What is the `//go:build integration` tag doing and why use a build tag
  instead of `t.Skip`?
- What is the difference between `testing.T` and `testing.B`?
- What did the benchmark show in ns/op? Is the bottleneck JWT parsing or JSON?

---

## Day 11: Containerization + Phase 2 deliverable

**Materials:**
- Docker multi-stage build docs (docs.docker.com/build/building/multi-stage)
- distroless images: github.com/GoogleContainerTools/distroless

**Builds on:** Days 6–10 full Gin service.
**Sets up:** Phase 3 will deploy the same pattern to AWS ECS.

- [ ] **Step 1 (30 min): Graceful shutdown.**

Update `phase2_rest/cmd/api/main.go` — add graceful shutdown:
```go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase2-rest/internal/handler"
    "github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
    "github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    repo := repository.NewMemoryTaskRepository()
    h := handler.NewTaskHandler(repo)

    r := gin.New()
    r.Use(gin.Recovery(), middleware.GinLogger(), middleware.RateLimit(100))
    r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
    r.GET("/readyz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

    v1 := r.Group("/api/v1")
    v1.Use(middleware.Auth())
    v1.GET("/tasks", h.List)
    v1.POST("/tasks", h.Create)
    v1.GET("/tasks/:id", h.Get)
    v1.PATCH("/tasks/:id/complete", h.Complete)

    srv := &http.Server{Addr: ":8080", Handler: r}

    go func() {
        slog.Info("listening", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("listen", "err", err)
            os.Exit(1)
        }
    }()

    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    <-ctx.Done()
    stop()

    slog.Info("shutting down")
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()
    if err := srv.Shutdown(shutdownCtx); err != nil {
        slog.Error("shutdown", "err", err)
    }
    slog.Info("stopped")
}
```

```bash
go run ./phase2_rest/cmd/api &
sleep 1
curl -s http://localhost:8080/healthz
kill -SIGTERM %1
```
Expected: server logs "shutting down" then "stopped" cleanly.

- [ ] **Step 2 (30 min): Multi-stage Dockerfile.**

Create `phase2_rest/Dockerfile`:
```dockerfile
# Stage 1: build
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/api ./cmd/api

# Stage 2: minimal runtime
FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/api /api
EXPOSE 8080
ENTRYPOINT ["/api"]
```

- [ ] **Step 3 (30 min): docker-compose for local dev.**

Create `phase2_rest/docker-compose.yml`:
```yaml
services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      JWT_SECRET: local-dev-secret
      DATABASE_URL: postgres://dev:dev@postgres:5432/tasks?sslmode=disable
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: tasks
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev -d tasks"]
      interval: 5s
      timeout: 5s
      retries: 5
```

```bash
cd phase2_rest
docker compose build
docker compose up -d
sleep 3
curl -s http://localhost:8080/healthz
docker compose down
cd ..
```
Expected: build succeeds, `/healthz` returns `{"status":"ok"}`, compose down
cleans up.

- [ ] **Step 4 (20 min): Verify image size.**

```bash
docker images | grep phase2
```
Expected: distroless image is under 15 MB. Compare: if you used `golang:1.22`
as the final stage it would be ~1 GB. Write in `journal.md`: why does image
size matter in Kubernetes?

- [ ] **Step 5 (20 min): Journal — Phase 2 close-out.**

Append to `journal.md`:
- What is `signal.NotifyContext` and what signal does Kubernetes send when
  terminating a pod?
- What is the difference between `/healthz` (liveness) and `/readyz`
  (readiness)? What happens if liveness fails?
- What is the distroless image and why is it preferred over Alpine for
  production containers?

---

## Day 12: Protobuf + buf

**Materials:**
- proto3 language guide (protobuf.dev/programming-guides/proto3)
- buf docs (buf.build/docs/introduction)
- `go doc google.golang.org/protobuf/proto`

**Builds on:** Phase 2 task model — Phase 3 re-exposes it over gRPC.
**Sets up:** Day 13 implements the gRPC server using generated code from today.

- [ ] **Step 1 (15 min): Install buf.**

```bash
brew install bufbuild/buf/buf   # macOS
buf --version
```
Expected: `1.x.x`. On Linux: `go install github.com/bufbuild/buf/cmd/buf@latest`.

- [ ] **Step 2 (15 min): Add gRPC dependencies.**

```bash
cd phase3_grpc
go get google.golang.org/grpc@latest
go get google.golang.org/protobuf@latest
go get google.golang.org/grpc/health@latest
```

- [ ] **Step 3 (30 min): Write the proto file.**

Create `phase3_grpc/proto/task/v1/task.proto`:
```protobuf
syntax = "proto3";

package task.v1;

option go_package = "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1;taskv1";

import "google/protobuf/timestamp.proto";

message Task {
  string id = 1;
  string title = 2;
  bool done = 3;
  google.protobuf.Timestamp created_at = 4;
}

message ListTasksRequest {}
message ListTasksResponse { repeated Task tasks = 1; }

message GetTaskRequest  { string id = 1; }
message GetTaskResponse { Task task = 1; }

message CreateTaskRequest  { string title = 1; }
message CreateTaskResponse { Task task = 1; }

message CompleteTaskRequest  { string id = 1; }
message CompleteTaskResponse { Task task = 1; }

message StreamTasksRequest {}

service TaskService {
  rpc ListTasks(ListTasksRequest)     returns (ListTasksResponse);
  rpc GetTask(GetTaskRequest)         returns (GetTaskResponse);
  rpc CreateTask(CreateTaskRequest)   returns (CreateTaskResponse);
  rpc CompleteTask(CompleteTaskRequest) returns (CompleteTaskResponse);
  rpc StreamTasks(StreamTasksRequest) returns (stream Task);
}
```

- [ ] **Step 4 (30 min): Configure buf.**

Create `phase3_grpc/buf.yaml`:
```yaml
version: v2
modules:
  - path: proto
deps:
  - buf.build/googleapis/googleapis
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE
```

Create `phase3_grpc/buf.gen.yaml`:
```yaml
version: v2
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt:
      - paths=source_relative
  - remote: buf.build/grpc/go
    out: gen
    opt:
      - paths=source_relative
```

```bash
cd phase3_grpc
buf dep update
buf generate
```
Expected: `gen/task/v1/task.pb.go` and `gen/task/v1/task_grpc.pb.go` created.
No errors.

- [ ] **Step 5 (20 min): Read the generated code.**

```bash
grep -n "interface\|func\|type" phase3_grpc/gen/task/v1/task_grpc.pb.go | head -40
```
Identify: `TaskServiceServer` interface (what you implement), `TaskServiceClient`
interface (what callers use), `RegisterTaskServiceServer` (how you register with
gRPC). Write in `journal.md`: the three generated artifacts and what each is
for.

- [ ] **Step 6 (30 min): Buf lint and breaking change detection.**

```bash
cd phase3_grpc
buf lint
```
Expected: no output (clean).

Now deliberately break the proto — rename `title` to `name` in `Task`, run:
```bash
buf breaking --against '.git#branch=main,subdir=phase3_grpc'
```
Expected: error about field rename being a breaking change. Revert the rename.
This is why `buf breaking` is in CI pipelines. Write in `journal.md`: what
makes a Protobuf change "breaking" vs backwards-compatible?

- [ ] **Step 7 (20 min): Journal.**

Append to `journal.md`:
- What is the difference between proto field numbers and field names? Which
  one must never change in a deployed schema?
- When would you use binary Protobuf vs JSON? What's the tradeoff?

---

## Day 13: gRPC server + interceptors

**Materials:**
- gRPC-go examples: github.com/grpc/grpc-go/examples/helloworld
- `go doc google.golang.org/grpc Server`
- `go doc google.golang.org/grpc/status`

**Builds on:** Day 12 generated code.
**Sets up:** Day 14 adds streaming RPCs on top of today's server.

- [ ] **Step 1 (60 min): Implement the TaskService server.**

Create `phase3_grpc/internal/server/task.go`:
```go
package server

import (
    "context"
    "fmt"
    "sync"
    "time"

    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/protobuf/types/known/timestamppb"

    taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
)

type TaskServer struct {
    taskv1.UnimplementedTaskServiceServer
    mu    sync.RWMutex
    tasks map[string]*taskv1.Task
    seq   int
}

func NewTaskServer() *TaskServer {
    return &TaskServer{tasks: make(map[string]*taskv1.Task)}
}

func (s *TaskServer) ListTasks(_ context.Context, _ *taskv1.ListTasksRequest) (*taskv1.ListTasksResponse, error) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    tasks := make([]*taskv1.Task, 0, len(s.tasks))
    for _, t := range s.tasks {
        tasks = append(tasks, t)
    }
    return &taskv1.ListTasksResponse{Tasks: tasks}, nil
}

func (s *TaskServer) GetTask(_ context.Context, req *taskv1.GetTaskRequest) (*taskv1.GetTaskResponse, error) {
    if req.Id == "" {
        return nil, status.Error(codes.InvalidArgument, "id is required")
    }
    s.mu.RLock()
    t, ok := s.tasks[req.Id]
    s.mu.RUnlock()
    if !ok {
        return nil, status.Errorf(codes.NotFound, "task %q not found", req.Id)
    }
    return &taskv1.GetTaskResponse{Task: t}, nil
}

func (s *TaskServer) CreateTask(_ context.Context, req *taskv1.CreateTaskRequest) (*taskv1.CreateTaskResponse, error) {
    if req.Title == "" {
        return nil, status.Error(codes.InvalidArgument, "title is required")
    }
    s.mu.Lock()
    s.seq++
    t := &taskv1.Task{
        Id:        fmt.Sprintf("task-%d", s.seq),
        Title:     req.Title,
        CreatedAt: timestamppb.New(time.Now()),
    }
    s.tasks[t.Id] = t
    s.mu.Unlock()
    return &taskv1.CreateTaskResponse{Task: t}, nil
}

func (s *TaskServer) CompleteTask(_ context.Context, req *taskv1.CompleteTaskRequest) (*taskv1.CompleteTaskResponse, error) {
    if req.Id == "" {
        return nil, status.Error(codes.InvalidArgument, "id is required")
    }
    s.mu.Lock()
    t, ok := s.tasks[req.Id]
    if ok {
        t.Done = true
    }
    s.mu.Unlock()
    if !ok {
        return nil, status.Errorf(codes.NotFound, "task %q not found", req.Id)
    }
    return &taskv1.CompleteTaskResponse{Task: t}, nil
}
```

- [ ] **Step 2 (50 min): Interceptors — auth, logger, recovery.**

Create `phase3_grpc/internal/interceptor/logger.go`:
```go
package interceptor

import (
    "context"
    "log/slog"
    "time"

    "google.golang.org/grpc"
)

func UnaryLogger(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    slog.Info("grpc",
        "method", info.FullMethod,
        "latency_ms", time.Since(start).Milliseconds(),
        "err", err,
    )
    return resp, err
}
```

Create `phase3_grpc/internal/interceptor/auth.go`:
```go
package interceptor

import (
    "context"
    "os"
    "strings"

    "github.com/golang-jwt/jwt/v5"
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/metadata"
    "google.golang.org/grpc/status"
)

var jwtSecret = []byte(getEnvOrDefault("JWT_SECRET", "dev-secret-change-in-prod"))

func getEnvOrDefault(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}

func UnaryAuth(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "missing metadata")
    }
    vals := md.Get("authorization")
    if len(vals) == 0 {
        return nil, status.Error(codes.Unauthenticated, "missing authorization header")
    }
    raw := strings.TrimPrefix(vals[0], "Bearer ")
    _, err := jwt.Parse(raw, func(t *jwt.Token) (any, error) {
        if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, jwt.ErrSignatureInvalid
        }
        return jwtSecret, nil
    })
    if err != nil {
        return nil, status.Errorf(codes.Unauthenticated, "invalid token: %v", err)
    }
    return handler(ctx, req)
}
```

- [ ] **Step 3 (40 min): Wire server with reflection.**

```bash
cd phase3_grpc
go get google.golang.org/grpc/reflection@latest
```

Create `phase3_grpc/cmd/server/main.go`:
```go
package main

import (
    "log/slog"
    "net"
    "os"

    "google.golang.org/grpc"
    "google.golang.org/grpc/health"
    healthpb "google.golang.org/grpc/health/grpc_health_v1"
    "google.golang.org/grpc/reflection"

    taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
    "github.com/yourname/golang-mastery/phase3-grpc/internal/interceptor"
    "github.com/yourname/golang-mastery/phase3-grpc/internal/server"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        slog.Error("listen", "err", err)
        os.Exit(1)
    }

    s := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            interceptor.UnaryLogger,
            interceptor.UnaryAuth,
        ),
    )

    taskv1.RegisterTaskServiceServer(s, server.NewTaskServer())

    // Health check (required by ECS and grpc-health-probe)
    healthSrv := health.NewServer()
    healthSrv.SetServingStatus("task.v1.TaskService", healthpb.HealthCheckResponse_SERVING)
    healthpb.RegisterHealthServer(s, healthSrv)

    // Reflection (enables grpcurl without proto files)
    reflection.Register(s)

    slog.Info("gRPC listening", "addr", lis.Addr())
    if err := s.Serve(lis); err != nil {
        slog.Error("serve", "err", err)
        os.Exit(1)
    }
}
```

```bash
go build ./phase3_grpc/...
```
Expected: clean build.

- [ ] **Step 4 (30 min): Smoke test with grpcurl.**

```bash
brew install grpcurl   # or: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
go run ./phase3_grpc/cmd/server &
sleep 1

# List services (reflection)
grpcurl -plaintext localhost:50051 list

# Create a task (no auth — expect UNAUTHENTICATED)
grpcurl -plaintext -d '{"title":"test"}' localhost:50051 task.v1.TaskService/CreateTask

# Create with token
TOKEN=$(go run ./phase2_rest/cmd/token)
grpcurl -plaintext \
  -H "authorization: Bearer $TOKEN" \
  -d '{"title":"grpc task"}' \
  localhost:50051 task.v1.TaskService/CreateTask

kill %1
```
Expected: no-auth call returns UNAUTHENTICATED error; with-auth call returns
created task JSON.

- [ ] **Step 5 (20 min): Journal.**

Append to `journal.md`:
- What is `UnimplementedTaskServiceServer` embedded in the server and why is
  it important for forward compatibility?
- What is the difference between `codes.NotFound` and HTTP 404? Can they be
  mapped 1:1?
- Why is gRPC reflection useful and when would you disable it in production?

---

## Day 14: gRPC streaming

**Materials:**
- gRPC-go streaming examples: github.com/grpc/grpc-go/examples/route_guide
- `go doc google.golang.org/grpc TaskService_StreamTasksServer`

**Builds on:** Day 13 TaskServer.
**Sets up:** Day 18 gateway uses server-streaming to demonstrate transcoding.

- [ ] **Step 1 (40 min): Server streaming — StreamTasks.**

Add to `phase3_grpc/internal/server/task.go`:
```go
func (s *TaskServer) StreamTasks(
    _ *taskv1.StreamTasksRequest,
    stream taskv1.TaskService_StreamTasksServer,
) error {
    s.mu.RLock()
    tasks := make([]*taskv1.Task, 0, len(s.tasks))
    for _, t := range s.tasks {
        tasks = append(tasks, t)
    }
    s.mu.RUnlock()

    for _, t := range tasks {
        // Check if client disconnected before each send
        select {
        case <-stream.Context().Done():
            return stream.Context().Err()
        default:
        }
        if err := stream.Send(t); err != nil {
            return err
        }
    }
    return nil
}
```

Test streaming with grpcurl:
```bash
go run ./phase3_grpc/cmd/server &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)
# Create a few tasks first
for i in 1 2 3; do
  grpcurl -plaintext \
    -H "authorization: Bearer $TOKEN" \
    -d "{\"title\":\"task $i\"}" \
    localhost:50051 task.v1.TaskService/CreateTask
done
# Stream all tasks
grpcurl -plaintext \
  -H "authorization: Bearer $TOKEN" \
  localhost:50051 task.v1.TaskService/StreamTasks
kill %1
```
Expected: three task messages streamed back one by one.

- [ ] **Step 2 (30 min): Stream interceptor for logging.**

Update `phase3_grpc/internal/interceptor/logger.go` — add stream interceptor:
```go
func StreamLogger(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
    start := time.Now()
    err := handler(srv, ss)
    slog.Info("grpc-stream",
        "method", info.FullMethod,
        "latency_ms", time.Since(start).Milliseconds(),
        "err", err,
    )
    return err
}
```

Update `phase3_grpc/cmd/server/main.go` — add stream interceptor to the server:
```go
s := grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        interceptor.UnaryLogger,
        interceptor.UnaryAuth,
    ),
    grpc.ChainStreamInterceptor(
        interceptor.StreamLogger,
    ),
)
```

- [ ] **Step 3 (40 min): Write a gRPC server test.**

Create `phase3_grpc/internal/server/task_test.go`:
```go
package server_test

import (
    "context"
    "testing"

    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"

    taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
    "github.com/yourname/golang-mastery/phase3-grpc/internal/server"
)

func TestCreateAndGet(t *testing.T) {
    s := server.NewTaskServer()
    ctx := context.Background()

    resp, err := s.CreateTask(ctx, &taskv1.CreateTaskRequest{Title: "test"})
    if err != nil {
        t.Fatal(err)
    }
    if resp.Task.Id == "" {
        t.Error("expected non-empty ID")
    }

    got, err := s.GetTask(ctx, &taskv1.GetTaskRequest{Id: resp.Task.Id})
    if err != nil {
        t.Fatal(err)
    }
    if got.Task.Title != "test" {
        t.Errorf("title = %q, want %q", got.Task.Title, "test")
    }
}

func TestCreateEmptyTitle(t *testing.T) {
    s := server.NewTaskServer()
    _, err := s.CreateTask(context.Background(), &taskv1.CreateTaskRequest{})
    st, _ := status.FromError(err)
    if st.Code() != codes.InvalidArgument {
        t.Errorf("code = %v, want InvalidArgument", st.Code())
    }
}

func TestGetNotFound(t *testing.T) {
    s := server.NewTaskServer()
    _, err := s.GetTask(context.Background(), &taskv1.GetTaskRequest{Id: "nonexistent"})
    st, _ := status.FromError(err)
    if st.Code() != codes.NotFound {
        t.Errorf("code = %v, want NotFound", st.Code())
    }
}
```

```bash
go test ./phase3_grpc/internal/server/... -v
```
Expected: PASS.

- [ ] **Step 4 (20 min): Journal.**

Append to `journal.md`:
- What happens to a server-streaming RPC if the client disconnects
  mid-stream? How does the server detect it?
- When would you use bidirectional streaming vs server streaming vs unary?
  Give a one-line real use case for each.

---

## Day 15: Resilience + observability

**Materials:**
- `go doc google.golang.org/grpc/keepalive`
- Prometheus Go client: github.com/prometheus/client_golang

**Builds on:** Day 14 gRPC server.
**Sets up:** Day 16 deploys the fully observable service to AWS ECS.

- [ ] **Step 1 (15 min): Add Prometheus dependency.**

```bash
cd phase3_grpc
go get github.com/prometheus/client_golang@latest
```

- [ ] **Step 2 (50 min): Metrics interceptor.**

Create `phase3_grpc/internal/interceptor/metrics.go`:
```go
package interceptor

import (
    "context"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "google.golang.org/grpc"
    "google.golang.org/grpc/status"
)

var (
    grpcRequests = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "grpc_requests_total",
        Help: "Total gRPC requests by method and code.",
    }, []string{"method", "code"})

    grpcDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "grpc_duration_seconds",
        Help:    "gRPC request duration.",
        Buckets: prometheus.DefBuckets,
    }, []string{"method"})
)

func UnaryMetrics(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    st, _ := status.FromError(err)
    grpcRequests.WithLabelValues(info.FullMethod, st.Code().String()).Inc()
    grpcDuration.WithLabelValues(info.FullMethod).Observe(time.Since(start).Seconds())
    return resp, err
}
```

- [ ] **Step 3 (40 min): Expose /metrics and add keepalive.**

Update `phase3_grpc/cmd/server/main.go`:
```go
package main

import (
    "context"
    "log/slog"
    "net"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/prometheus/client_golang/prometheus/promhttp"
    "google.golang.org/grpc"
    "google.golang.org/grpc/health"
    healthpb "google.golang.org/grpc/health/grpc_health_v1"
    "google.golang.org/grpc/keepalive"
    "google.golang.org/grpc/reflection"

    taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
    "github.com/yourname/golang-mastery/phase3-grpc/internal/interceptor"
    "github.com/yourname/golang-mastery/phase3-grpc/internal/server"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        slog.Error("listen", "err", err)
        os.Exit(1)
    }

    s := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            interceptor.UnaryMetrics,
            interceptor.UnaryLogger,
            interceptor.UnaryAuth,
        ),
        grpc.ChainStreamInterceptor(interceptor.StreamLogger),
        grpc.KeepaliveParams(keepalive.ServerParameters{
            MaxConnectionIdle: 15 * time.Second,
            Time:              5 * time.Second,
            Timeout:           1 * time.Second,
        }),
    )

    taskv1.RegisterTaskServiceServer(s, server.NewTaskServer())
    healthSrv := health.NewServer()
    healthSrv.SetServingStatus("task.v1.TaskService", healthpb.HealthCheckResponse_SERVING)
    healthpb.RegisterHealthServer(s, healthSrv)
    reflection.Register(s)

    // Metrics HTTP server on separate port
    metricsSrv := &http.Server{
        Addr:    ":9090",
        Handler: promhttp.Handler(),
    }
    go func() {
        slog.Info("metrics listening", "addr", metricsSrv.Addr)
        if err := metricsSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("metrics", "err", err)
        }
    }()

    go func() {
        slog.Info("gRPC listening", "addr", lis.Addr())
        if err := s.Serve(lis); err != nil {
            slog.Error("serve", "err", err)
        }
    }()

    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    <-ctx.Done()
    stop()

    slog.Info("shutting down")
    s.GracefulStop()
    shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    metricsSrv.Shutdown(shutCtx)
    slog.Info("stopped")
}
```

```bash
go run ./phase3_grpc/cmd/server &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)
grpcurl -plaintext -H "authorization: Bearer $TOKEN" \
  -d '{"title":"metrics test"}' localhost:50051 task.v1.TaskService/CreateTask
curl -s http://localhost:9090/metrics | grep grpc_requests
kill %1
```
Expected: `grpc_requests_total{code="OK",method="...CreateTask"}` counter
visible in Prometheus output.

- [ ] **Step 4 (20 min): Journal.**

Append to `journal.md`:
- What is a gRPC deadline and how does it differ from a connection timeout?
- Why are Prometheus histograms more useful than averages for latency?

---

## Day 16: AWS ECS deployment + Phase 3 deliverable

**Materials:**
- AWS ECS Fargate documentation (docs.aws.amazon.com/AmazonECS/latest/developerguide)
- AWS ALB gRPC support docs (search "ALB gRPC target group")

**Builds on:** Day 15 fully observable gRPC server.
**Sets up:** Phase 4 gateway proxies to the ALB DNS from today's deployment.

- [ ] **Step 1 (30 min): Multi-stage Dockerfile for gRPC.**

Create `phase3_grpc/Dockerfile`:
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/grpc-server ./cmd/server

FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/grpc-server /grpc-server
EXPOSE 50051 9090
ENTRYPOINT ["/grpc-server"]
```

```bash
docker build -t phase3-grpc ./phase3_grpc
docker run --rm -p 50051:50051 -p 9090:9090 phase3-grpc &
sleep 2
grpcurl -plaintext localhost:50051 list
docker stop $(docker ps -q --filter ancestor=phase3-grpc)
```
Expected: service list shows `task.v1.TaskService` and health service.

- [ ] **Step 2 (30 min): ECS task definition.**

Create `phase3_grpc/task-definition.json`:
```json
{
  "family": "phase3-grpc-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "grpc-server",
      "image": "YOUR_ACCOUNT.dkr.ecr.YOUR_REGION.amazonaws.com/phase3-grpc:latest",
      "portMappings": [
        {"containerPort": 50051, "protocol": "tcp"},
        {"containerPort": 9090, "protocol": "tcp"}
      ],
      "environment": [
        {"name": "JWT_SECRET", "value": "replace-with-ssm-in-prod"}
      ],
      "healthCheck": {
        "command": [
          "CMD", "grpc-health-probe",
          "-addr=:50051",
          "-service=task.v1.TaskService"
        ],
        "interval": 10,
        "timeout": 5,
        "retries": 3
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/phase3-grpc",
          "awslogs-region": "YOUR_REGION",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

Replace `YOUR_ACCOUNT` and `YOUR_REGION` with your values before deploying.

- [ ] **Step 3 (40 min): Deploy to ECS (manual steps).**

```bash
# 1. Create ECR repo
aws ecr create-repository --repository-name phase3-grpc --region YOUR_REGION

# 2. Authenticate Docker to ECR
aws ecr get-login-password --region YOUR_REGION | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT.dkr.ecr.YOUR_REGION.amazonaws.com

# 3. Build and push
docker build -t phase3-grpc ./phase3_grpc
docker tag phase3-grpc:latest \
  YOUR_ACCOUNT.dkr.ecr.YOUR_REGION.amazonaws.com/phase3-grpc:latest
docker push YOUR_ACCOUNT.dkr.ecr.YOUR_REGION.amazonaws.com/phase3-grpc:latest

# 4. Register task definition
aws ecs register-task-definition \
  --cli-input-json file://phase3_grpc/task-definition.json

# 5. Create ECS service (assumes existing VPC, subnets, security group)
# Do this in the AWS console the first time — it's clearer than CLI for setup
```

ALB target group key settings (set in console):
- Protocol: HTTPS (required for gRPC)
- Protocol version: gRPC
- Health check path: `/grpc.health.v1.Health/Check`

- [ ] **Step 4 (20 min): Verify deployed service.**

```bash
ALB_DNS=your-alb.us-east-1.elb.amazonaws.com
TOKEN=$(go run ./phase2_rest/cmd/token)

grpcurl -H "authorization: Bearer $TOKEN" \
  -d '{"title":"deployed task"}' \
  $ALB_DNS:443 task.v1.TaskService/CreateTask
```
Expected: task created. If you skip AWS deployment for now, note in
`journal.md` and complete it as a stretch step — the Day 17+ gateway exercises
can use `localhost:50051` instead.

- [ ] **Step 5 (20 min): Journal — Phase 3 close-out.**

Append to `journal.md`:
- Why does gRPC over ALB require HTTPS, not HTTP?
- What is `grpc-health-probe` and why can't ECS use a plain TCP health check
  for gRPC?
- What surprised you most about deploying a gRPC service vs a REST service?

---

## Day 17: Gateway architecture + reverse proxy foundations

**Materials:**
- `go doc net/http/httputil ReverseProxy`
- `go doc net/http Transport`

**Builds on:** Phase 2 REST service + Phase 3 gRPC service.
**Sets up:** Day 18 adds Gin routing on top of today's raw proxy.

- [ ] **Step 1 (20 min): Upstream registry interface.**

Create `phase4_gateway/internal/proxy/upstream.go`:
```go
package proxy

import "net/http"

// Upstream describes a backend service the gateway can route to.
type Upstream struct {
    Name    string
    BaseURL string // e.g. "http://localhost:8080"
}

// Registry holds named upstreams.
type Registry struct {
    upstreams map[string]*Upstream
}

func NewRegistry(upstreams ...*Upstream) *Registry {
    r := &Registry{upstreams: make(map[string]*Upstream)}
    for _, u := range upstreams {
        r.upstreams[u.Name] = u
    }
    return r
}

func (r *Registry) Get(name string) (*Upstream, bool) {
    u, ok := r.upstreams[name]
    return u, ok
}

// Transport returns an *http.Transport tuned for gateway upstream connections.
func Transport() *http.Transport {
    return &http.Transport{
        MaxIdleConns:        200,
        MaxIdleConnsPerHost: 20,
        IdleConnTimeout:     90,
        DisableKeepAlives:   false,
    }
}
```

- [ ] **Step 2 (50 min): Reverse proxy handler.**

Create `phase4_gateway/internal/proxy/reverseproxy.go`:
```go
package proxy

import (
    "fmt"
    "log/slog"
    "net/http"
    "net/http/httputil"
    "net/url"
)

// Handler returns an http.Handler that proxies requests to the named upstream.
func Handler(upstream *Upstream) http.Handler {
    target, err := url.Parse(upstream.BaseURL)
    if err != nil {
        panic(fmt.Sprintf("invalid upstream URL %q: %v", upstream.BaseURL, err))
    }

    rp := httputil.NewSingleHostReverseProxy(target)
    rp.Transport = Transport()

    rp.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
        slog.Error("proxy error",
            "upstream", upstream.Name,
            "path", r.URL.Path,
            "err", err,
        )
        http.Error(w, "bad gateway", http.StatusBadGateway)
    }

    // Rewrite strips the path prefix so upstream sees clean paths
    original := rp.Director
    rp.Director = func(req *http.Request) {
        original(req)
        req.Header.Set("X-Forwarded-Host", req.Host)
        req.Header.Set("X-Gateway", "phase4-gateway")
    }

    return rp
}
```

- [ ] **Step 3 (40 min): Minimal stdlib gateway — no Gin yet.**

Create `phase4_gateway/cmd/gateway/main.go`:
```go
package main

import (
    "log/slog"
    "net/http"
    "os"
    "strings"

    "github.com/yourname/golang-mastery/phase4-gateway/internal/proxy"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    restUpstream := &proxy.Upstream{
        Name:    "rest",
        BaseURL: getEnv("REST_UPSTREAM", "http://localhost:8080"),
    }

    reg := proxy.NewRegistry(restUpstream)

    mux := http.NewServeMux()
    mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.Write([]byte(`{"status":"ok"}`))
    })

    // Route /api/v1/* to the REST upstream
    mux.Handle("/api/v1/", http.StripPrefix("", func() http.Handler {
        up, _ := reg.Get("rest")
        return proxy.Handler(up)
    }()))

    srv := &http.Server{Addr: ":9000", Handler: mux}

    slog.Info("gateway listening", "addr", srv.Addr)
    if err := srv.ListenAndServe(); err != nil {
        slog.Error("server", "err", err)
        os.Exit(1)
    }
}

func getEnv(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}
```

Add `phase4_gateway/go.mod`:
```
module github.com/yourname/golang-mastery/phase4-gateway

go 1.22
```

```bash
# Start the REST upstream
go run ./phase2_rest/cmd/api &
sleep 1
# Start the gateway
go run ./phase4_gateway/cmd/gateway &
sleep 1
# Hit the gateway
TOKEN=$(go run ./phase2_rest/cmd/token)
curl -s -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:9000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"via gateway"}' | jq .
curl -s http://localhost:9000/healthz
kill %2 %1
```
Expected: task created via the gateway proxying to the REST service. Health
check returns ok directly from the gateway (not proxied).

- [ ] **Step 4 (20 min): Journal.**

Append to `journal.md`:
- What does `http.StripPrefix` do and why is it useful in a gateway?
- What does `X-Forwarded-Host` tell the upstream service? Why does it matter?

---

## Day 18: Gin at the edge + REST-to-gRPC transcoding

**Materials:**
- grpc-gateway docs (grpc-ecosystem.github.io/grpc-gateway) — skim the
  overview after building the manual version

**Builds on:** Day 17 stdlib gateway.
**Sets up:** Day 19 adds observability middleware on top of the Gin router.

- [ ] **Step 1 (15 min): Add Gin and gRPC client deps.**

```bash
cd phase4_gateway
go get github.com/gin-gonic/gin@latest
go get google.golang.org/grpc@latest
go get google.golang.org/protobuf@latest
```

Since `phase4_gateway` is in the same workspace as `phase3_grpc`, import the
generated proto package directly:
```bash
# Verify workspace resolves it
go list github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1
```
Expected: no error.

- [ ] **Step 2 (60 min): REST-to-gRPC transcoder.**

Create `phase4_gateway/internal/transcoder/grpc.go`:
```go
package transcoder

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    "google.golang.org/grpc/metadata"

    taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
)

// TaskTranscoder translates HTTP/JSON requests to gRPC calls on TaskService.
type TaskTranscoder struct {
    client taskv1.TaskServiceClient
}

func NewTaskTranscoder(grpcAddr string) (*TaskTranscoder, error) {
    conn, err := grpc.NewClient(grpcAddr,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    if err != nil {
        return nil, err
    }
    return &TaskTranscoder{client: taskv1.NewTaskServiceClient(conn)}, nil
}

func (t *TaskTranscoder) forwardAuth(c *gin.Context) metadata.MD {
    md := metadata.New(nil)
    if auth := c.GetHeader("Authorization"); auth != "" {
        md.Set("authorization", auth)
    }
    return md
}

func (t *TaskTranscoder) ListTasks(c *gin.Context) {
    ctx := metadata.NewOutgoingContext(c.Request.Context(), t.forwardAuth(c))
    resp, err := t.client.ListTasks(ctx, &taskv1.ListTasksRequest{})
    if err != nil {
        c.AbortWithStatusJSON(grpcStatusToHTTP(err), gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusOK, resp.Tasks)
}

func (t *TaskTranscoder) CreateTask(c *gin.Context) {
    var req struct {
        Title string `json:"title" binding:"required"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    ctx := metadata.NewOutgoingContext(c.Request.Context(), t.forwardAuth(c))
    resp, err := t.client.CreateTask(ctx, &taskv1.CreateTaskRequest{Title: req.Title})
    if err != nil {
        c.AbortWithStatusJSON(grpcStatusToHTTP(err), gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusCreated, resp.Task)
}
```

Create `phase4_gateway/internal/transcoder/status.go`:
```go
package transcoder

import (
    "net/http"

    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

func grpcStatusToHTTP(err error) int {
    st, _ := status.FromError(err)
    switch st.Code() {
    case codes.OK:
        return http.StatusOK
    case codes.NotFound:
        return http.StatusNotFound
    case codes.InvalidArgument:
        return http.StatusBadRequest
    case codes.Unauthenticated:
        return http.StatusUnauthorized
    case codes.PermissionDenied:
        return http.StatusForbidden
    case codes.AlreadyExists:
        return http.StatusConflict
    case codes.ResourceExhausted:
        return http.StatusTooManyRequests
    default:
        return http.StatusInternalServerError
    }
}
```

- [ ] **Step 3 (40 min): Wire Gin router with both proxy and transcoder.**

Replace `phase4_gateway/cmd/gateway/main.go`:
```go
package main

import (
    "log/slog"
    "os"

    "github.com/gin-gonic/gin"
    "github.com/yourname/golang-mastery/phase4-gateway/internal/proxy"
    "github.com/yourname/golang-mastery/phase4-gateway/internal/transcoder"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    restUpstream := &proxy.Upstream{
        Name:    "rest",
        BaseURL: getEnv("REST_UPSTREAM", "http://localhost:8080"),
    }
    reg := proxy.NewRegistry(restUpstream)

    tc, err := transcoder.NewTaskTranscoder(getEnv("GRPC_UPSTREAM", "localhost:50051"))
    if err != nil {
        slog.Error("grpc client", "err", err)
        os.Exit(1)
    }

    r := gin.New()
    r.Use(gin.Recovery())

    r.GET("/healthz", func(c *gin.Context) {
        c.JSON(200, gin.H{"status": "ok"})
    })

    // REST proxy route group
    rest := r.Group("/api/v1")
    {
        up, _ := reg.Get("rest")
        restHandler := proxy.Handler(up)
        rest.Any("/*path", func(c *gin.Context) {
            restHandler.ServeHTTP(c.Writer, c.Request)
        })
    }

    // gRPC transcoded routes
    grpcRoutes := r.Group("/grpc/v1")
    {
        grpcRoutes.GET("/tasks", tc.ListTasks)
        grpcRoutes.POST("/tasks", tc.CreateTask)
    }

    slog.Info("gateway listening", "addr", ":9000")
    if err := r.Run(":9000"); err != nil {
        slog.Error("server", "err", err)
        os.Exit(1)
    }
}

func getEnv(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}
```

```bash
go run ./phase2_rest/cmd/api &
go run ./phase3_grpc/cmd/server &
sleep 1
go run ./phase4_gateway/cmd/gateway &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)

# REST proxy path
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:9000/api/v1/tasks | jq .

# gRPC transcoded path
curl -s -X POST http://localhost:9000/grpc/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"via transcoder"}' | jq .

kill %3 %2 %1
```
Expected: both paths return tasks. The gRPC path shows the Protobuf-native
`id`/`title`/`done`/`created_at` fields (as JSON-serialized Protobuf).

- [ ] **Step 4 (20 min): Journal.**

Append to `journal.md`:
- What does `grpc-gateway` automate that you did manually today?
- What is `metadata.NewOutgoingContext` and why forward the `Authorization`
  header to the gRPC upstream via metadata, not an HTTP header?

---

## Day 19: Observability

**Materials:**
- OpenTelemetry Go docs (opentelemetry.io/docs/languages/go)
- `go doc github.com/prometheus/client_golang/prometheus/promhttp`

**Builds on:** Day 18 Gin gateway.
**Sets up:** Day 20 adds circuit breaking and rate limiting; observability makes
those features testable.

- [ ] **Step 1 (15 min): Add observability dependencies.**

```bash
cd phase4_gateway
go get github.com/prometheus/client_golang@latest
go get go.opentelemetry.io/otel@latest
go get go.opentelemetry.io/otel/trace@latest
go get go.opentelemetry.io/otel/sdk@latest
go get go.opentelemetry.io/otel/exporters/stdout/stdouttrace@latest
```

- [ ] **Step 2 (50 min): Prometheus metrics middleware.**

Create `phase4_gateway/internal/middleware/metrics.go`:
```go
package middleware

import (
    "strconv"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "gateway_http_requests_total",
        Help: "Total HTTP requests handled by the gateway.",
    }, []string{"method", "path", "status"})

    httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "gateway_http_duration_seconds",
        Help:    "HTTP request duration at the gateway.",
        Buckets: prometheus.DefBuckets,
    }, []string{"method", "path"})
)

func Metrics() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        httpRequests.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
            strconv.Itoa(c.Writer.Status()),
        ).Inc()
        httpDuration.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
        ).Observe(time.Since(start).Seconds())
    }
}
```

- [ ] **Step 3 (50 min): Structured logger middleware.**

Create `phase4_gateway/internal/middleware/logger.go`:
```go
package middleware

import (
    "log/slog"
    "time"

    "github.com/gin-gonic/gin"
)

func Logger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        slog.Info("gateway request",
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "latency_ms", time.Since(start).Milliseconds(),
            "client_ip", c.ClientIP(),
            "user_agent", c.Request.UserAgent(),
        )
    }
}
```

- [ ] **Step 4 (30 min): Expose /metrics and wire middleware.**

Update `phase4_gateway/cmd/gateway/main.go` — add Prometheus handler and
new middleware:
```go
import (
    // existing imports...
    "net/http"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    gw_middleware "github.com/yourname/golang-mastery/phase4-gateway/internal/middleware"
)

// In main(), after gin.New():
r.Use(gin.Recovery(), gw_middleware.Logger(), gw_middleware.Metrics())

// Add metrics endpoint (no auth, separate from API routes)
r.GET("/metrics", gin.WrapH(promhttp.Handler()))
```

```bash
go run ./phase2_rest/cmd/api &
go run ./phase3_grpc/cmd/server &
go run ./phase4_gateway/cmd/gateway &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)

# Make some requests
for i in $(seq 5); do
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:9000/api/v1/tasks > /dev/null
done

# Check metrics
curl -s http://localhost:9000/metrics | grep gateway_http
kill %3 %2 %1
```
Expected: `gateway_http_requests_total` and `gateway_http_duration_seconds`
counters visible in Prometheus format.

- [ ] **Step 5 (20 min): Journal.**

Append to `journal.md`:
- What are the three Prometheus metric types (counter, gauge, histogram) and
  when do you use each?
- Why is latency measured as a histogram rather than a gauge or counter?

---

## Day 20: Production features — rate limiting, circuit breaker, graceful shutdown

**Materials:**
- `go doc golang.org/x/time/rate` — token bucket from the Go team
- Circuit breaker pattern: Martin Fowler's bliki post on CircuitBreaker

**Builds on:** Days 17–19 full gateway.
**Sets up:** Phase 4 deliverable — a production-hardened gateway you can deploy.

- [ ] **Step 1 (15 min): Add rate limiter dependency.**

```bash
cd phase4_gateway
go get golang.org/x/time/rate@latest
```

- [ ] **Step 2 (45 min): Per-client rate limiter using golang.org/x/time/rate.**

Replace `phase4_gateway/internal/middleware/ratelimit.go` (create it):
```go
package middleware

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
    "golang.org/x/time/rate"
)

type clientLimiter struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

// RateLimit limits each client IP to rps requests per second with burst b.
// Clients not seen for 3 minutes are evicted from memory.
func RateLimit(rps float64, burst int) gin.HandlerFunc {
    clients := make(map[string]*clientLimiter)
    var mu sync.Mutex

    // Background cleanup goroutine
    go func() {
        for range time.Tick(time.Minute) {
            mu.Lock()
            for ip, cl := range clients {
                if time.Since(cl.lastSeen) > 3*time.Minute {
                    delete(clients, ip)
                }
            }
            mu.Unlock()
        }
    }()

    return func(c *gin.Context) {
        ip := c.ClientIP()
        mu.Lock()
        cl, ok := clients[ip]
        if !ok {
            cl = &clientLimiter{limiter: rate.NewLimiter(rate.Limit(rps), burst)}
            clients[ip] = cl
        }
        cl.lastSeen = time.Now()
        lim := cl.limiter
        mu.Unlock()

        if !lim.Allow() {
            c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
                "error": "rate limit exceeded",
            })
            return
        }
        c.Next()
    }
}
```

- [ ] **Step 3 (50 min): Circuit breaker.**

Create `phase4_gateway/internal/middleware/circuitbreaker.go`:
```go
package middleware

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
)

type cbState int

const (
    cbClosed   cbState = iota // normal: requests pass through
    cbOpen                    // tripped: requests fail fast
    cbHalfOpen                // probe: one request allowed to test recovery
)

type CircuitBreaker struct {
    mu           sync.Mutex
    state        cbState
    failures     int
    threshold    int
    resetTimeout time.Duration
    openedAt     time.Time
}

func NewCircuitBreaker(threshold int, resetTimeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{threshold: threshold, resetTimeout: resetTimeout}
}

func (cb *CircuitBreaker) Middleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        cb.mu.Lock()
        switch cb.state {
        case cbOpen:
            if time.Since(cb.openedAt) > cb.resetTimeout {
                cb.state = cbHalfOpen
            } else {
                cb.mu.Unlock()
                c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
                    "error": "service unavailable (circuit open)",
                })
                return
            }
        }
        cb.mu.Unlock()

        c.Next()

        cb.mu.Lock()
        defer cb.mu.Unlock()

        if c.Writer.Status() >= 500 {
            cb.failures++
            if cb.failures >= cb.threshold {
                cb.state = cbOpen
                cb.openedAt = time.Now()
            }
        } else {
            cb.failures = 0
            cb.state = cbClosed
        }
    }
}
```

- [ ] **Step 4 (40 min): Wire everything and add graceful shutdown.**

Final `phase4_gateway/cmd/gateway/main.go`:
```go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    gw_middleware "github.com/yourname/golang-mastery/phase4-gateway/internal/middleware"
    "github.com/yourname/golang-mastery/phase4-gateway/internal/proxy"
    "github.com/yourname/golang-mastery/phase4-gateway/internal/transcoder"
)

func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    restUpstream := &proxy.Upstream{
        Name:    "rest",
        BaseURL: getEnv("REST_UPSTREAM", "http://localhost:8080"),
    }
    reg := proxy.NewRegistry(restUpstream)

    tc, err := transcoder.NewTaskTranscoder(getEnv("GRPC_UPSTREAM", "localhost:50051"))
    if err != nil {
        slog.Error("grpc client", "err", err)
        os.Exit(1)
    }

    cb := gw_middleware.NewCircuitBreaker(5, 30*time.Second)

    r := gin.New()
    r.Use(
        gin.Recovery(),
        gw_middleware.Logger(),
        gw_middleware.Metrics(),
        gw_middleware.RateLimit(100, 20),
        cb.Middleware(),
    )

    r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
    r.GET("/readyz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
    r.GET("/metrics", gin.WrapH(promhttp.Handler()))

    rest := r.Group("/api/v1")
    {
        up, _ := reg.Get("rest")
        restHandler := proxy.Handler(up)
        rest.Any("/*path", func(c *gin.Context) {
            restHandler.ServeHTTP(c.Writer, c.Request)
        })
    }

    grpcRoutes := r.Group("/grpc/v1")
    {
        grpcRoutes.GET("/tasks", tc.ListTasks)
        grpcRoutes.POST("/tasks", tc.CreateTask)
    }

    srv := &http.Server{Addr: ":9000", Handler: r}

    go func() {
        slog.Info("gateway listening", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("listen", "err", err)
            os.Exit(1)
        }
    }()

    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    <-ctx.Done()
    stop()

    slog.Info("gateway shutting down")
    shutCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
    defer cancel()
    if err := srv.Shutdown(shutCtx); err != nil {
        slog.Error("shutdown", "err", err)
    }
    slog.Info("gateway stopped")
}

func getEnv(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}
```

```bash
go run ./phase2_rest/cmd/api &
go run ./phase3_grpc/cmd/server &
go run ./phase4_gateway/cmd/gateway &
sleep 1
TOKEN=$(go run ./phase2_rest/cmd/token)

# Full stack smoke test
curl -s -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:9000/grpc/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"production ready"}' | jq .
curl -s http://localhost:9000/metrics | grep gateway
curl -s http://localhost:9000/healthz

# Test graceful shutdown
kill -SIGTERM %3
# Expected: "gateway shutting down" then "gateway stopped" logged
kill %2 %1
```

- [ ] **Step 5 (20 min): Final build and test.**

```bash
go build ./phase4_gateway/...
go test ./phase4_gateway/... -v -race
```
Expected: clean build, tests pass.

- [ ] **Step 6 (20 min): Journal — Phase 4 close-out.**

Append to `journal.md`:
- What is the state machine for a circuit breaker? What are the three states?
- Why does the rate limiter use a background goroutine to evict old clients?
  What happens if you skip cleanup?
- What is `srv.Shutdown` vs `srv.Close`? What is the difference for in-flight
  requests?

---

## Extension Module E1: Kafka Integration

**Goal:** Publish gateway request events to Kafka as an async audit log.
Connects directly to your Kafka mastery plan.

**Builds on:** Phase 4 gateway + your existing Kafka knowledge.

- [ ] Read `kafka_practice/docs/superpowers/plans/` for the Kafka client
  pattern you already built.
- [ ] Add `github.com/segmentio/kafka-go` to `phase4_gateway/go.mod`.
- [ ] Create `phase4_gateway/internal/middleware/audit.go` — a Gin middleware
  that publishes `{method, path, status, user_id, ts}` to a Kafka topic
  `gateway-audit` on every response, non-blocking (fire-and-forget goroutine).
- [ ] Start a local Kafka container (from your Kafka plan's docker-compose)
  and verify audit messages arrive with a consumer.

---

## Extension Module E2: Kubernetes Deployment

**Goal:** Deploy the full stack (gateway + REST + gRPC) to Kubernetes with
proper health checks and autoscaling.

- [ ] Write a `Deployment`, `Service`, and `HorizontalPodAutoscaler` manifest
  for each of the three services.
- [ ] Expose the gateway via an `Ingress` (AWS ALB Ingress Controller or
  nginx-ingress).
- [ ] Configure `livenessProbe` and `readinessProbe` for each service.
- [ ] Test that the gateway scales under load with `hey` or `k6`.

---

## Extension Module E3: AWS SDK v2

**Goal:** Replace hardcoded config with AWS-native config management.

- [ ] Add `github.com/aws/aws-sdk-go-v2/config` and `ssm` to dependencies.
- [ ] Replace `getEnv("JWT_SECRET", ...)` in the gateway with an SSM Parameter
  Store fetch at startup.
- [ ] Add upstream discovery via AWS Cloud Map (Service Discovery) instead of
  hardcoded `REST_UPSTREAM` env vars.

---

## Extension Module E4: Performance Profiling

**Goal:** Find and fix real bottlenecks in the gateway under load.

- [ ] Add `net/http/pprof` import to the gateway's HTTP server (this
  registers `/debug/pprof/*` routes automatically).
- [ ] Use `hey -n 10000 -c 100` to generate load.
- [ ] Run `go tool pprof http://localhost:9000/debug/pprof/profile?seconds=10`
  and identify the hottest function.
- [ ] Write a benchmark for the `grpcStatusToHTTP` function and verify it
  allocates zero bytes per call.

---

## Success Criteria Checklist

- [ ] Write idiomatic modern Go (1.22+) that a senior Go engineer would approve
  in code review
- [ ] Build and deploy a production-quality gRPC microservice on AWS ECS
- [ ] Build and deploy an API gateway with full observability (Prometheus,
  structured logs, tracing)
- [ ] Explain Go's concurrency model, goroutine scheduler, and context
  propagation under interview conditions
- [ ] Read and contribute to real Go codebases (Gin, gRPC-go, Kubernetes
  controllers) without friction
- [ ] Extend the plan with E1–E4 modules independently
