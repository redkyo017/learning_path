# Go Mastery — Glossary

Plain-English definitions of Go terms used in this path. Each entry is 2–3
sentences. For deeper reading, `go doc <package>` is authoritative.

---

## Language fundamentals

**any**
An alias for `interface{}` introduced in Go 1.18. It represents a value of any
type. Prefer `any` over `interface{}` in new code — they are identical at
compile time, but `any` is less noisy.

**blank identifier (`_`)**
A write-only variable that discards a value. Used to ignore return values
(`_, err := f()`) or to trigger a side-effect import (`import _ "net/http/pprof"`).
The compiler rejects unused variables but allows `_` anywhere.

**build constraint (`//go:build`)**
A directive on the first line of a `.go` file that controls which platforms or
tags include it in a build. The modern form uses Go boolean operators:
`//go:build linux && amd64`. The old `// +build` form is deprecated as of
Go 1.17; `go vet` will warn about files that only use the old form.

**defer**
Schedules a function call to run when the surrounding function returns, in
LIFO order. Used to release resources regardless of how the function exits
(normal return, panic, early return). Arguments to the deferred call are
evaluated immediately, not at call time.

**embedding**
Including a type inside a struct or interface without naming it. The outer
type automatically promotes the embedded type's methods. It is Go's mechanism
for code reuse without inheritance; it is not subtyping.

**interface**
A named set of method signatures. Any type that implements all the methods
satisfies the interface — there is no explicit declaration. Interfaces are the
primary abstraction boundary in Go; they are how you decouple packages and
enable testing without mocks of concrete types.

**panic / recover**
`panic` stops normal execution and unwinds the stack, running deferred
functions. `recover` inside a deferred function catches the panic and returns
its value, allowing the program to continue. Used sparingly — errors should be
returned, not panicked. Gin's recovery middleware uses `recover` to turn
unhandled panics into 500 responses.

**struct**
A composite type with named fields. Structs are the primary data-holding type
in Go; they have no inheritance. Method sets are attached to structs (or their
pointers) with the `func (r ReceiverType) MethodName()` syntax.

---

## Concurrency

**channel (`chan`)**
A typed conduit for sending values between goroutines. Sending blocks until a
receiver is ready (unbuffered) or until the buffer is full (buffered). Closing
a channel signals all receivers that no more values will be sent.

**channel direction types (`<-chan`, `chan<-`)**
Restricting a channel parameter to send-only (`chan<-`) or receive-only
(`<-chan`) prevents callers from accidentally closing the wrong end of a
pipeline. The compiler enforces these restrictions at compile time.

**context (`context.Context`)**
A value that carries a cancellation signal, a deadline, and a key-value bag
across API boundaries. Every handler should accept a `context.Context` as its
first argument and propagate it to all downstream calls. Never use
`context.Background()` deep in a call stack — it severs cancellation and
tracing.

**context.WithCancelCause (Go 1.20)**
Like `context.WithCancel` but lets you attach a specific error to the
cancellation: `cancel(ErrServiceShutdown)`. `context.Cause(ctx)` retrieves
that error, giving cancellation context beyond just "done."

**errgroup (`golang.org/x/sync/errgroup`)**
A higher-level synchronization primitive over `sync.WaitGroup`. It collects
the first non-nil error from a group of goroutines and cancels a shared context
when any goroutine fails. `SetLimit(n)` bounds concurrency using a buffered
channel as an internal semaphore.

**fan-in / fan-out**
Fan-out: one goroutine distributes work across multiple worker goroutines.
Fan-in: multiple goroutines send results into a single collector channel. The
URL health checker (Phase 1) is a fan-out/fan-in pipeline.

**goroutine**
A lightweight concurrency unit managed by the Go runtime, not the OS. Starting
one costs ~8 KB of stack (which grows dynamically). The critical rule: every
goroutine you launch must have a defined exit condition, usually a `ctx.Done()`
select case — otherwise it is a goroutine leak.

**goroutine leak**
A goroutine that runs forever because it is waiting for something that will
never arrive. Symptoms: memory grows continuously; pprof shows ever-increasing
goroutine count. Fix: all goroutines must select on `ctx.Done()`. See
`content/runbook-goroutine-leak.md`.

**select**
A statement that waits on multiple channel operations simultaneously, choosing
whichever is ready. If multiple cases are ready, Go picks one at random.
`select { case <-ctx.Done(): return }` is the idiomatic cancellation exit.

**sync.Mutex / sync.RWMutex**
`Mutex` provides exclusive access (one goroutine at a time for both read and
write). `RWMutex` allows multiple concurrent readers but exclusive writers. Use
`RWMutex` when reads dominate and the critical section is short; the overhead
is not worth it for short write-heavy sections.

**sync.Once**
Guarantees that a function runs exactly once, even under concurrent access.
Used for safe lazy initialization of expensive resources (config, connections,
singletons). It has no `Reset` method by design — once is once.

**worker pool**
A fixed-size set of goroutines that process jobs from a shared queue. In modern
Go: `errgroup.Group.SetLimit(n)` is the idiomatic worker pool; it bounds
concurrency without writing a pool manually.

---

## Module system

**go.mod**
The module manifest: declares the module path, minimum Go version, required
dependencies, and their checksums. Committed to version control. Never add
local-path `replace` directives to a committed `go.mod` — use `go.work` instead.

**go.work (workspace mode)**
A workspace file that links multiple local modules so they can reference each
other without publishing to a registry. Lives at the repo root; typically
gitignored. The `use ./phase1_cli` directive overrides the published version of
that module with the local directory. Introduced in Go 1.18.

**module cache (`$GOMODCACHE`)**
The on-disk cache of downloaded module source trees, located at
`$GOPATH/pkg/mod` by default. Directories are read-only by design — the Go
toolchain sets `chmod 555` to prevent accidental edits. `go clean -modcache`
clears it.

**toolchain directive**
A `go.mod` directive (Go 1.21+) that names the exact Go toolchain version the
module was developed with: `toolchain go1.22.4`. Distinct from the `go`
directive, which sets the minimum required version. With `GOTOOLCHAIN=auto`,
Go 1.21+ will download the declared toolchain if your installed version is older.

---

## Modern stdlib (Go 1.18–1.22)

**cmp package**
A stdlib package (Go 1.21) providing ordered comparison utilities. `cmp.Compare`
returns -1, 0, or 1 for any ordered type. Used with `slices.SortFunc` to replace
verbose `sort.Slice` closures.

**maps package**
A stdlib package (Go 1.21) with generic map helpers: `maps.Clone`, `maps.Copy`,
`maps.Delete`, `maps.DeleteFunc`, `maps.Equal`. `maps.Keys` and `maps.Values`
returning `iter.Seq` were added in Go 1.23 — on Go 1.22, collect keys with a
plain range loop then `slices.Sort`.

**slices package**
A stdlib package (Go 1.21) with generic slice utilities: `slices.Sort`,
`slices.SortFunc`, `slices.Index`, `slices.IndexFunc`, `slices.Contains`,
`slices.Compact`. Replaces most hand-rolled `sort.Slice` patterns.

**slog (`log/slog`)**
Structured logging in stdlib as of Go 1.21. Replaces most `logrus`/`zap`
use cases for new services. Two built-in handlers: `JSONHandler` (for
production log aggregation) and `TextHandler` (for local dev). Key: set a
default logger at startup with `slog.SetDefault(logger)` and then call
`slog.Info(...)` from anywhere.

---

## Generics (Go 1.18+)

**constraint**
An interface used as a type parameter bound. It declares which operations the
type must support. The predeclared constraints are `any` (any type) and
`comparable` (types that can be used as map keys). Custom constraints are
regular interfaces.

**type inference**
The compiler's ability to deduce type arguments from call-site arguments so
you do not have to write them explicitly. `Map([]int{1,2,3}, double)` works;
you do not need `Map[int, int](...)`.

**type parameter**
A placeholder type declared in brackets: `func Map[T, U any](s []T, f func(T) U) []U`.
`T` and `U` are type parameters — they are substituted with concrete types at
compile time (or sometimes via code generation at compile time), not at runtime.

**when to use generics vs interfaces**
The rule: if an interface solves it, use the interface. Generics are for
type-safe algorithms over collections (`Map`, `Filter`, `Reduce`) and for typed
containers (`Cache[K, V]`). `io.Writer`, `http.Handler`, and `sort.Interface`
are correct as interfaces because they describe behavior, not a collection of
values of the same type.

---

## HTTP and Gin

**gin.Context**
Gin's request/response container. Wraps `*http.Request` and
`http.ResponseWriter` with helpers: `c.ShouldBindJSON` (decode + validate
request body), `c.JSON` (write JSON response), `c.Param` (path parameter),
`c.AbortWithStatusJSON` (short-circuit the middleware chain with an error
response).

**graceful shutdown**
Stopping an HTTP server cleanly: stop accepting new connections, wait for
in-flight requests to complete (up to a drain timeout), then exit. The pattern:
`signal.NotifyContext` catches SIGTERM/SIGINT; `server.Shutdown(ctx)` drains.
Required for zero-downtime container rolling updates.

**http.Handler**
The single interface at the core of Go's HTTP stack: `ServeHTTP(ResponseWriter,
*Request)`. Every Gin middleware, Gin router, and stdlib `ServeMux` implements
it. Understanding this interface makes every Go HTTP framework instantly
readable.

**middleware (HTTP)**
A function that wraps an `http.Handler` in another `http.Handler`. The wrapper
runs before and/or after the inner handler. In Gin, middleware is a
`gin.HandlerFunc` added via `r.Use(...)`. The `c.Next()` call advances the
chain; `c.Abort()` short-circuits it.

**ServeMux**
The stdlib HTTP router. It stores a map of URL pattern strings to handlers and
dispatches requests by longest-prefix match. Limitations: no path parameters,
no method-based dispatch, linear lookup for large route tables. These
limitations are why Gin's radix-trie router exists.

---

## gRPC and Protobuf

**buf**
A modern build tool for Protobuf: linting, breaking-change detection, and
codegen config via `buf.yaml` + `buf.gen.yaml`. Replaces raw `protoc` invocations.
Used throughout Phase 3.

**gRPC interceptor**
The gRPC equivalent of HTTP middleware. A function that wraps a handler to add
cross-cutting behavior (auth, logging, metrics). Unary interceptors wrap
single-call RPCs; streaming interceptors wrap stream RPCs. Chain them with
`grpc.ChainUnaryInterceptor`.

**gRPC status codes**
gRPC's own error taxonomy: `codes.OK`, `codes.NotFound`, `codes.Internal`,
`codes.Unauthenticated`, etc. Completely separate from HTTP status codes.
Using HTTP status codes (like 404) in a gRPC handler is a bug — the compile
won't catch it, but clients will be confused.

**protobuf (proto3)**
Google's binary serialization format. Smaller and faster than JSON for
service-to-service traffic; not human-readable. The `.proto` file is the source
of truth; `buf` generates Go structs and gRPC service stubs from it.

**streaming RPC**
A gRPC call where either the client, server, or both send a sequence of
messages rather than a single request/response. Server streaming is used for
event feeds and large dataset pagination. Always select on `ctx.Done()` inside
a streaming handler to avoid goroutine leaks when the client disconnects.

---

## Patterns

**circuit breaker**
A proxy-level pattern that stops forwarding to a failing upstream and
immediately returns an error (503) instead. Prevents cascading failures when
one downstream service is slow or down. Phase 4 gateway implements one in
`phase4_gateway/internal/middleware/circuitbreaker.go`.

**repository pattern**
An abstraction layer over data storage: define an interface
(`TaskRepository`) and provide multiple implementations (Postgres for
production, in-memory for tests). Handlers depend on the interface, not the
concrete type — this is how you test database code without a running database.

**reverse proxy**
An HTTP server that forwards requests to an upstream and returns the upstream's
response to the original client. Go stdlib provides `httputil.ReverseProxy`.
The Phase 4 gateway uses this as its forwarding engine.

**token bucket (rate limiter)**
An algorithm that grants a fixed number of tokens per second. Each request
consumes one token. If the bucket is empty, the request is rejected (429).
The bucket refills at the configured rate. Phase 2 and Phase 4 implement
per-client token buckets.

---

## Testing

**httptest**
A stdlib package (`net/http/httptest`) for testing HTTP handlers without
starting a real server. `httptest.NewRecorder()` captures the response;
`httptest.NewServer()` starts a local server on a random port for client tests.

**table-driven tests**
Go's idiomatic test structure: a slice of `{name, input, expected}` structs
iterated in a loop. One test function covers many cases; a failing case names
itself via `t.Run(tc.name, ...)`. Standard across the Go stdlib and all major
Go projects.

**testcontainers-go**
A library that starts real Docker containers (Postgres, Redis, etc.) inside
`go test`. Used for integration tests of the database layer. Slower than a
mock but catches real driver bugs and schema issues that mocks miss.

**`-race` flag**
Enables Go's built-in race detector: `go test -race ./...`. Instruments memory
accesses and reports data races at runtime. Always run with `-race` when testing
concurrent code; a test that passes without `-race` and fails with it has a real
bug.
