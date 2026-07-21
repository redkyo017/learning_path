# Day 4 — Concurrency Fundamentals

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain the M:N goroutine scheduler model and state what GOMAXPROCS controls
- Identify a goroutine leak from code and describe why it causes memory growth
- Construct a context cancellation tree and trace how cancellation propagates
- Use `context.WithCancelCause` and `context.Cause` (Go 1.20)
- Choose between `sync.Mutex`, `sync.RWMutex`, and `sync/atomic` for a given access pattern
- Use `sync.WaitGroup` and `sync.Once` correctly with deferred `Done` calls

---

## Every goroutine you launch is a contract — you own its exit condition

This is the single most important mental model in Go concurrency. Goroutines
are cheap — a few kilobytes of stack, grown as needed. It's easy to launch
thousands. But cheap does not mean free, and "launch and forget" is the
most common source of production outages in Go services.

When you write `go f()`, you are making an implicit contract: "I guarantee
that `f` will eventually return." If `f` blocks on a channel read that never
receives, or on a mutex that's never released, or loops waiting for a condition
that never becomes true — you have a goroutine leak. Leaks are insidious because
they accumulate. One leaked goroutine per request means your service's memory
grows proportionally with request count.

The discipline is simple to state and requires habit to practice: **every
goroutine must have an exit condition, and you must know who is responsible for
triggering it**. In practice, this almost always means passing a `context.Context`
into the goroutine and selecting on `<-ctx.Done()` in every blocking operation.
Think of `context.Context` as the kill switch — when you launch a goroutine,
hand it a context and honor `ctx.Done()`. When the context is cancelled (by
timeout, by the caller, or by an explicit cancel call), the goroutine must
clean up and return.

---

## The goroutine scheduler: M:N model

Go uses an M:N scheduler: M goroutines are multiplexed onto N OS threads, where
N is controlled by `GOMAXPROCS` (default: number of logical CPUs).

Three types of entities:

| Entity | Description |
|---|---|
| **G (Goroutine)** | User-space lightweight thread; starts with ~2KB stack |
| **M (Machine)** | OS thread; each M runs one G at a time |
| **P (Processor)** | Logical scheduler; one per GOMAXPROCS; M must hold a P to run Go code |

Key behaviors to understand:

**Work stealing:** When a P's run queue is empty, it steals goroutines from
other Ps' queues. This keeps all CPUs busy without programmer intervention.

**Preemption:** Since Go 1.14, goroutines are preemptible at any safe point —
they don't need to make a function call to yield. Before 1.14, a tight CPU loop
without function calls could starve other goroutines.

**Syscall parking:** When an M makes a blocking syscall, it releases its P so
another M can take the P and keep running other goroutines. The original M
is "parked" waiting for the syscall to complete.

**GOMAXPROCS in practice:**
- Default is `runtime.NumCPU()` — correct for CPU-bound work
- For I/O-heavy services, the default is also correct; the scheduler handles it
- Set `GOMAXPROCS=1` in tests when debugging race conditions (removes true
  parallelism, makes ordering deterministic)
- Never set `GOMAXPROCS` lower than 1 or higher than `runtime.NumCPU()` in
  production without a benchmark proving it helps

---

## Goroutine lifecycle and leak detection

A goroutine's lifecycle:

```
Created → Runnable → Running → (blocked on I/O / channel / mutex) → Runnable → Running → Returned
```

A goroutine leaks when it is permanently blocked: waiting on a channel that
will never send, holding a mutex it can't release, or looping without an
exit condition.

### Detecting leaks

**At test time:** Use `go.uber.org/goleak` or the built-in approach:

```go
func TestMyFunc(t *testing.T) {
    before := runtime.NumGoroutine()
    // ... run your function ...
    time.Sleep(10 * time.Millisecond) // let goroutines settle
    after := runtime.NumGoroutine()
    if after > before {
        t.Errorf("goroutine leak: started with %d, ended with %d", before, after)
    }
}
```

**At runtime:** Expose `GET /debug/pprof/goroutine` via `net/http/pprof` and
look for goroutines stuck in the same blocking call site at growing counts.

**The classic leak pattern:**

```go
// LEAKS: nobody closes results, so the goroutine blocks forever on send
func fetch(urls []string) <-chan string {
    results := make(chan string)
    for _, url := range urls {
        go func(u string) {
            resp, _ := http.Get(u)
            results <- resp.Status  // blocks if nobody reads
        }(url)
    }
    return results
}
```

**The fixed pattern** (with context):

```go
func fetch(ctx context.Context, urls []string) <-chan string {
    results := make(chan string, len(urls))  // buffered, or...
    var wg sync.WaitGroup
    for _, url := range urls {
        wg.Add(1)
        go func(u string) {
            defer wg.Done()
            req, _ := http.NewRequestWithContext(ctx, "GET", u, nil)
            resp, err := http.DefaultClient.Do(req)
            if err != nil {
                return
            }
            select {
            case results <- resp.Status:
            case <-ctx.Done():
                return
            }
        }(url)
    }
    go func() {
        wg.Wait()
        close(results)
    }()
    return results
}
```

---

## Context propagation

`context.Context` carries three things:
1. A cancellation signal (`<-ctx.Done()` closes when the context is cancelled)
2. An optional deadline (`ctx.Deadline()` returns the time)
3. Request-scoped key-value pairs (`ctx.Value(key)` — use sparingly)

### Context cancellation tree

Every derived context is a child of its parent. When a parent is cancelled, all
children are cancelled simultaneously. The converse is not true: cancelling a
child does not affect the parent.

```
context.Background()  ← root, never cancelled
  │
  ├── WithCancel(ctx) = ctx1, cancel1
  │     │
  │     ├── WithTimeout(ctx1, 5s) = ctx2, cancel2
  │     │     └── goroutine A (receives <-ctx2.Done on timeout OR when cancel1 fires)
  │     │
  │     └── WithDeadline(ctx1, t) = ctx3, cancel3
  │           └── goroutine B
  │
  └── WithCancel(ctx) = ctx4, cancel4  ← sibling; cancel1 does NOT cancel ctx4
```

Cancelling `ctx1` propagates down: `ctx2`, `ctx3`, and all goroutines listening
on them are cancelled. Cancelling `ctx2` (or the timeout firing) only affects
goroutine A — `ctx3` and goroutine B continue.

```
context.Background()
         │
     [cancel1] ──────────────────────────────────────────────┐
         │                                                     │
     [timeout 5s] ────── goroutine A                     [cancel4] ── goroutine C
         │
     [deadline t] ─────── goroutine B
```

When any ancestor fires, the cancellation propagates down — not up, not sideways.

### WithCancel, WithTimeout, WithDeadline

```go
// WithCancel: manual cancellation
ctx, cancel := context.WithCancel(parent)
defer cancel()  // ALWAYS defer cancel to release resources

// WithTimeout: auto-cancel after duration
ctx, cancel := context.WithTimeout(parent, 5*time.Second)
defer cancel()

// WithDeadline: auto-cancel at absolute time
ctx, cancel := context.WithDeadline(parent, time.Now().Add(5*time.Second))
defer cancel()
```

**Always `defer cancel()`** — even for deadline and timeout contexts. Calling
`cancel` after expiry is a no-op, but not calling it leaks a goroutine in the
context package's internal propagation machinery.

### WithCancelCause (Go 1.20)

Before 1.20, when a context was cancelled you knew it was cancelled but not
*why* — `ctx.Err()` returns either `context.Canceled` or `context.DeadlineExceeded`,
both of which lose the original business reason for the cancellation.

```go
ctx, cancel := context.WithCancelCause(parent)

// In some goroutine that discovers an error:
cancel(fmt.Errorf("upstream %s: %w", serverName, ErrUnavailable))

// In the goroutine checking cancellation:
<-ctx.Done()
cause := context.Cause(ctx)
// cause is the error passed to cancel, not context.Canceled
// ctx.Err() still returns context.Canceled
```

`context.Cause(ctx)` returns the cause error. If no cause was set,
`context.Cause` returns the same as `ctx.Err()`. This is particularly useful
for the errgroup pattern (Day 5) and anywhere you need to surface the real
reason for cancellation through a context.

---

## sync package: Mutex, RWMutex, atomic, WaitGroup, Once

### Mutex vs RWMutex

Use `sync.Mutex` when writes and reads are equally frequent, or when the
critical section is very short (lock overhead dominates).

Use `sync.RWMutex` when:
- Reads are significantly more frequent than writes
- The read critical section is non-trivial in duration
- You have concurrent readers that don't need to serialize against each other

```go
type Store struct {
    mu    sync.RWMutex
    items map[string]string
}

func (s *Store) Get(key string) (string, bool) {
    s.mu.RLock()          // multiple readers can hold RLock simultaneously
    defer s.mu.RUnlock()
    v, ok := s.items[key]
    return v, ok
}

func (s *Store) Set(key, value string) {
    s.mu.Lock()           // exclusive write lock; blocks all readers and writers
    defer s.mu.Unlock()
    s.items[key] = value
}
```

**RWMutex is not always faster than Mutex.** Under heavy write contention, the
lock overhead of `RWMutex` is higher. Benchmark before assuming.

### sync/atomic for counters and flags

For simple counters and boolean flags, `sync/atomic` avoids mutex overhead
entirely. Since Go 1.19, the preferred form uses `atomic.Int64`, `atomic.Bool`,
etc. (typed atomics) rather than `atomic.AddInt64(&counter, 1)`:

```go
var count atomic.Int64
var ready atomic.Bool

count.Add(1)
count.Load()
count.Store(0)

ready.Store(true)
ready.Load()
```

Use atomics only for primitive operations (load, store, add, CAS). Any operation
that needs to read-modify-write multiple variables in a consistent way requires
a mutex.

### WaitGroup

`sync.WaitGroup` tracks a set of goroutines and blocks until all are done:

```go
var wg sync.WaitGroup

for _, item := range items {
    wg.Add(1)
    go func(x Item) {
        defer wg.Done()  // always defer Done before any early-return
        process(x)
    }(item)
}

wg.Wait()  // blocks until all Done() calls have fired
```

Critical rules:
- Call `wg.Add(1)` **before** launching the goroutine, never inside it
- Always `defer wg.Done()` at the top of the goroutine, before any early returns
- `wg.Wait()` can only be called once the final `Add` has completed

### Once

`sync.Once` executes a function exactly once, regardless of how many goroutines
call it concurrently. The canonical use case is lazy initialization:

```go
type Config struct {
    once   sync.Once
    values map[string]string
}

func (c *Config) get(key string) string {
    c.once.Do(func() {
        c.values = loadFromEnv()  // called exactly once, even under concurrency
    })
    return c.values[key]
}
```

`sync.Once` has no `Reset`. If you need to reinitialize, use a new `Once`
instance or a mutex with an explicit initialized flag.

---

## Returning engineer: what changed since 1.16–1.18

**`context.WithCancelCause` and `context.Cause` are Go 1.20.** You didn't have
these. The old pattern was to use a shared `error` variable protected by a mutex
to communicate the cancellation reason alongside the context. The new pattern is
much cleaner for error propagation in goroutine groups.

**`sync/atomic` typed types are Go 1.19.** You may have used the function-based
API: `atomic.AddInt64(&counter, 1)`, `atomic.LoadInt64(&counter)`. The new typed
approach (`atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]`) is safer and avoids
alignment bugs that plagued the function-based API on 32-bit platforms.

**Goroutine preemption changed in Go 1.14.** Before 1.14, a goroutine with a
tight loop (no function calls) could starve the scheduler. Since 1.14, the
runtime preempts goroutines at safe points asynchronously. Code that used to
need `runtime.Gosched()` in tight loops to be cooperative no longer needs it.
Your old tight-loop code is fine, but you should understand why.

**Loop variable capture changed in Go 1.22.** Before 1.22, this was a classic bug:

```go
for _, item := range items {
    go func() {
        process(item)  // BUG in <1.22: all goroutines see the last item
    }()
}
```

The fix was `item := item` inside the loop. In Go 1.22, each loop iteration
creates a new variable, so the capture is correct by default. If you have
`item := item` in your old code, it still works — it's just a no-op now.

**`sync.Map` is for rare specific cases.** You may have heard "use `sync.Map`
for concurrent maps." In practice, a `map` + `sync.RWMutex` is the right choice
for most services. `sync.Map` is optimized for two specific scenarios: write-once
read-many, or keys that are disjoint across goroutines. If you're not in those
scenarios, it's slower than a mutex.

---

## Key concepts to memorize

- M goroutines on N OS threads; N = GOMAXPROCS = `runtime.NumCPU()` by default
- P (Processor) is the scheduler unit; M must hold a P to run; work-stealing keeps CPUs busy
- Every goroutine needs an exit condition — context cancellation is the standard mechanism
- `defer cancel()` is required for all context types, even timeout/deadline contexts
- Context cancellation propagates parent → children, never upward or sideways
- `context.Cause(ctx)` retrieves the error passed to `cancel(err)` in Go 1.20+
- `sync.RWMutex`: `RLock`/`RUnlock` for reads (concurrent); `Lock`/`Unlock` for writes (exclusive)
- `wg.Add(1)` before the goroutine; `defer wg.Done()` as first line of the goroutine
- `sync.Once.Do` calls its function exactly once — no Reset; create new Once for re-init
- `atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]` are the preferred atomic types since 1.19
- Loop variable capture bug is fixed in Go 1.22 — `item := item` is no longer needed

---

## Common mistakes

**1. Not calling `defer cancel()` on context creation.**
Why it happens: the context clearly has a timeout, so why bother? Because the
context package maintains internal goroutines and timers to propagate cancellation
through the tree. Not calling `cancel` leaks those resources until the parent is
cancelled. The rule is absolute: every `WithCancel`, `WithTimeout`, `WithDeadline`
must have a matching `cancel` call.

**2. Calling `wg.Add(1)` inside the goroutine.**
Why it happens: it seems equivalent. But there's a race: if the goroutine
is scheduled after `wg.Wait()` runs, `Wait` returns before the goroutine
completes. `Add` must be called before the goroutine that calls `Done`.

**3. Using `sync.Map` for a general-purpose cache.**
Why it happens: the docs say "safe for concurrent use" and engineers assume
"concurrent-safe = best option." In reality, for most access patterns a
`sync.RWMutex`-protected map is faster, simpler, and more predictable.
Benchmark both before choosing `sync.Map`.

**4. Forgetting that context values should only carry request-scoped metadata.**
Why it happens: `ctx.Value(key)` looks like a convenient dependency injection
mechanism. But it is untyped, unchecked at compile time, and makes function
signatures misleading. Pass loggers, databases, and configuration as explicit
function parameters — not in context. Use context values only for
request-scoped data: request IDs, trace spans, authenticated user principals.

**5. Assuming that a cancelled context prevents already-running code from completing.**
Why it happens: `ctx.Done()` closes when the context is cancelled, but it
doesn't interrupt code that isn't selecting on it. Database queries that
have already been submitted to the server will run to completion even if
the context is cancelled. Cancellation is cooperative — the goroutine must
check `ctx.Done()` to honor it.

---

## Check your understanding

1. You launch 100 goroutines, each doing `go func() { results <- compute() }()`.
   After 90 goroutines have sent their result, the receiver stops reading.
   What happens to the other 10 goroutines? How would you fix this?
2. A function creates `ctx, cancel := context.WithCancelCause(parent)` and
   passes it to three child goroutines. Goroutine 2 calls `cancel(ErrTimeout)`.
   What does `context.Cause(ctx)` return in goroutines 1 and 3? What does
   `ctx.Err()` return?
3. You have a struct with a `sync.RWMutex` and a map. A `Get` method holds
   `RLock` and calls another method that calls `Lock`. What happens?

(answers are in the code — run the lab to verify)
