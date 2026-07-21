# Day 5 — Concurrency Patterns

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Implement a worker pool with bounded concurrency using `errgroup.SetLimit`
- Build a fan-out/fan-in pipeline with typed channel directions
- Explain the difference between `sync.WaitGroup` and `errgroup.Group` and choose between them
- Identify the three most common pipeline mistakes and explain why each causes the problems it does
- Write channel function signatures with explicit send-only and receive-only directions

---

## Goroutines are cheap but not free — design the flow before writing the code

Go makes concurrency syntactically easy. `go f()` launches a goroutine, channels
connect goroutines, and the select statement handles multiple channels. The
danger is that this ease of expression tempts you to start writing concurrent
code before you understand the data flow.

Before writing a single goroutine, draw the pipeline on paper. Every concurrent
system is a graph: nodes are goroutines, edges are channels. Identify:
- How many goroutines will be running concurrently at peak?
- What is the backpressure mechanism? (Buffered channels, `SetLimit`, or semaphore)
- Who closes each channel? (The producer closes, never the consumer)
- What happens when one goroutine fails? (Does it cancel the rest? propagate error?)
- Who waits for all goroutines to finish? (`WaitGroup` or `errgroup.Wait`)

Once you can answer these five questions, the code writes itself. Most
concurrency bugs in Go are the result of writing code without answering them
first — a goroutine leaks because nobody thought about its exit condition, a
channel deadlocks because the wrong end closes it, errors are silently dropped
because nobody collected them.

The patterns below — worker pool, fan-out, fan-in, pipeline — are templates for
answering these questions in common configurations. Learn them, then adapt.

---

## Worker pool with errgroup

The worker pool is the most common concurrency pattern in services: you have N
items to process and want to process them with at most K concurrent goroutines.

### sync.WaitGroup approach (pre-errgroup)

```go
func processAll(ctx context.Context, items []Item) error {
    sem := make(chan struct{}, 10)  // semaphore: max 10 concurrent
    var wg sync.WaitGroup
    var mu sync.Mutex
    var firstErr error

    for _, item := range items {
        item := item
        sem <- struct{}{}   // acquire
        wg.Add(1)
        go func() {
            defer wg.Done()
            defer func() { <-sem }()  // release
            if err := process(ctx, item); err != nil {
                mu.Lock()
                if firstErr == nil {
                    firstErr = err
                }
                mu.Unlock()
            }
        }()
    }
    wg.Wait()
    return firstErr
}
```

This works but is verbose: a semaphore channel for backpressure, a WaitGroup
for completion, a mutex for error collection. Every team has a slightly different
version of this pattern.

### errgroup approach (idiomatic since ~2020)

`golang.org/x/sync/errgroup` provides a Group that wraps WaitGroup + error
collection + optional context cancellation:

```go
func processAll(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10)  // max 10 concurrent goroutines

    for _, item := range items {
        item := item
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

`g.Go` blocks if the limit is reached, resuming when a goroutine completes.
`g.Wait` returns the first non-nil error from any goroutine. The derived context
is cancelled when any goroutine returns an error — remaining goroutines should
check `ctx.Done()` and return early.

### WaitGroup vs errgroup — decision table

| Concern | `sync.WaitGroup` | `errgroup.Group` |
|---|---|---|
| Collect errors | Manual (mutex + variable) | Built-in: returns first error |
| Bound concurrency | Manual (semaphore channel) | `g.SetLimit(n)` |
| Cancel on first error | Manual (cancel func + mutex) | Automatic with `errgroup.WithContext` |
| Propagate context | Manual | Returns derived cancellable ctx |
| Use when | You need fine-grained control, or you never need error collection | Standard bounded concurrent work |
| Dependency | stdlib | `golang.org/x/sync` (non-stdlib) |

The rule: use `errgroup` by default for any concurrent work that can fail.
Fall back to `WaitGroup` only when you need behavior `errgroup` doesn't
support (e.g., continuing after errors, collecting all errors not just the first).

---

## Fan-out / fan-in pipeline

The pipeline pattern connects a sequence of stages where each stage reads from
an input channel and writes to an output channel. Fan-out sends work to multiple
goroutines; fan-in merges their outputs into one channel.

```
Input → [Stage 1] → chan A → [Stage 2 x N workers] (fan-out) → [merge] → chan B → [Stage 3]
                                   ↑ fan-in when merged
```

### Channel direction types

Functions should declare the narrowest channel type possible:

```go
// Producer: returns receive-only channel — callers can read but not send or close
func produce(ctx context.Context, items []int) <-chan int {
    out := make(chan int, len(items))
    go func() {
        defer close(out)  // producer closes the channel
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

// Stage: receives from receive-only, returns receive-only
func double(ctx context.Context, in <-chan int) <-chan int {
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

// Fan-out: distribute work across N workers
func fanOut(ctx context.Context, in <-chan int, n int) []<-chan int {
    outputs := make([]<-chan int, n)
    for i := range n {
        outputs[i] = double(ctx, in)  // each worker reads from the same input channel
    }
    return outputs
}

// Fan-in: merge N channels into one
func merge(ctx context.Context, inputs ...<-chan int) <-chan int {
    out := make(chan int, len(inputs))
    var wg sync.WaitGroup
    for _, ch := range inputs {
        ch := ch
        wg.Add(1)
        go func() {
            defer wg.Done()
            for v := range ch {
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }()
    }
    go func() {
        wg.Wait()
        close(out)  // close after all inputs are drained
    }()
    return out
}
```

### Channel direction type summary

| Type | Can send | Can receive | Can close |
|---|---|---|---|
| `chan T` | Yes | Yes | Yes |
| `chan<- T` (send-only) | Yes | No | Yes |
| `<-chan T` (receive-only) | No | Yes | No |

The rule: functions that create channels return `<-chan T` (receive-only).
Functions that consume channels accept `<-chan T`. Functions that need to
send into a channel accept `chan<- T`. A bidirectional `chan T` is only used
inside the function that owns (creates) the channel.

---

## errgroup.SetLimit deep dive

`SetLimit` was added to `errgroup` in a 2022 release of `golang.org/x/sync`.
It uses a buffered channel as a semaphore internally — the same pattern you
would write manually:

```go
// Conceptual implementation inside errgroup:
type Group struct {
    sem chan struct{}  // buffered; len = limit
    ...
}

func (g *Group) SetLimit(n int) {
    g.sem = make(chan struct{}, n)
}

func (g *Group) Go(f func() error) {
    g.sem <- struct{}{}  // acquire (blocks if at limit)
    go func() {
        defer func() { <-g.sem }()  // release
        ...
    }()
}
```

Implications:
- `g.Go` **blocks the calling goroutine** until a slot is available. This means
  your loop is naturally backpressured — you don't need a separate semaphore.
- `SetLimit` must be called before any `g.Go` call.
- `SetLimit(-1)` removes the limit (unlimited goroutines).
- The limit bounds the number of **running** goroutines, not the number of
  queued work items. If you have 1000 items and a limit of 10, at most 10
  goroutines run at once; the calling goroutine blocks between submissions
  when the pool is full.

---

## Common pipeline mistakes

### Mistake 1: Consumer closes the channel instead of producer

```go
// WRONG: consumer closes
go func() {
    for v := range results {
        process(v)
    }
    close(results)  // BUG: producer may still be writing; panic on send to closed channel
}()
```

Rule: **the producer (sender) closes the channel, never the consumer (receiver)**.
The producer knows when it is done sending. The consumer does not.

### Mistake 2: Unbuffered channel with no concurrent reader

```go
// WRONG: blocks forever if nobody reads immediately
results := make(chan int)
go func() {
    results <- compute()  // blocks until someone reads
}()
// ... if the reader is not started yet, this goroutine leaks
doOtherWork()  // this runs first, but nobody is reading from results
for v := range results { ... }
```

Either buffer the channel (`make(chan int, n)`) or ensure the reader goroutine
starts before the writer goroutine. The common pattern for a single-result
goroutine: buffer size 1.

### Mistake 3: Forgetting to drain the channel when cancelling

```go
g, ctx := errgroup.WithContext(ctx)
ch := produce(ctx, items)
g.Go(func() error {
    for v := range ch {
        if err := process(v); err != nil {
            return err  // returns error — ctx is cancelled — producer may block on send
        }
    }
    return nil
})
g.Wait()
```

When `g.Go` returns an error, `ctx` is cancelled. But the `produce` goroutine
may be blocked on `ch <- v` because the consumer goroutine has returned. Fix:
producers must select on `ctx.Done()` alongside the send, so they exit when
cancelled. This is shown in the `produce` function above.

### Mistake 4: Range over channel with no close

```go
for v := range ch {  // blocks forever if ch is never closed
    process(v)
}
```

`range` over a channel terminates only when the channel is **closed**.
If the producer never calls `close(ch)`, the consumer blocks forever. Every
channel used with `range` must be closed by its producer.

### Mistake 5: Starting goroutines in a loop without capturing the loop variable (pre-1.22)

```go
// BUG in Go < 1.22:
for _, item := range items {
    go func() {
        process(item)  // all goroutines capture the same 'item' variable
    }()
}

// Fix (still required in pre-1.22 code):
for _, item := range items {
    item := item  // new variable per iteration
    go func() {
        process(item)
    }()
}

// Go 1.22+: loop variable is per-iteration; no fix needed
```

---

## Returning engineer: what changed since 1.16–1.18

**`errgroup.SetLimit` is new (2022 in `golang.org/x/sync`).** The pattern you
used before was a manual semaphore channel. `SetLimit` replaces that entirely.
If you have code that uses a semaphore channel alongside errgroup, simplify it.

**The loop variable capture fix (Go 1.22):** You will have muscle memory for
`item := item` inside loops. In Go 1.22+, this is a no-op — loop variables are
per-iteration. In code that must support older Go versions, keep it. In 1.22+
code, remove it to reduce noise.

**`errgroup.WithContext` returns a cancellable context tied to the group.** If
you use `errgroup.Group{}` directly (without `WithContext`), the group has no
context cancellation on error — all goroutines run to completion regardless of
errors. This is the old pattern. For anything where "first error cancels the
rest" is the right behavior, always use `errgroup.WithContext`.

**Channel direction types existed before 1.18** — these are not new. But many
engineers who weren't writing Go day-to-day didn't develop the habit of declaring
direction types on function signatures. Use them everywhere — they are enforced
by the compiler and prevent the "wrong end closes the channel" class of bugs.

**`for range n` (integer range) is Go 1.22.** Before 1.22, you wrote
`for i := 0; i < n; i++`. In Go 1.22, you can write `for i := range n`.
You'll see this in code written after 1.22. Both forms work; the new form is
more idiomatic for index-only loops.

---

## Key concepts to memorize

- `errgroup.WithContext` returns a group AND a derived context that cancels on first error
- `g.SetLimit(n)` blocks `g.Go` when n goroutines are running — the calling goroutine provides backpressure
- Producer closes the channel; consumer never does
- `range ch` blocks until the channel is closed — always close
- `<-chan T`: receive-only (callers can read, not send); `chan<- T`: send-only (callers can send, not read)
- Fan-out: multiple goroutines read from one channel; fan-in: one goroutine merges multiple channels
- `errgroup.Wait()` returns the first non-nil error; all errors after the first are discarded
- Use `sync.WaitGroup` when you need all errors, not just the first; use errgroup for "fail-fast"
- `SetLimit(-1)` removes the bound (unlimited goroutines)
- Every `select` in a stage goroutine must include `case <-ctx.Done(): return` for cancellation

---

## Common mistakes

**1. Using `errgroup.Group{}` (struct literal) instead of `errgroup.WithContext`.**
Why it happens: the struct literal is simpler. But without `WithContext`, an
error in one goroutine does not cancel the others — they all run to completion.
For most work queues this is wrong. Use `errgroup.WithContext` unless you
genuinely want all goroutines to complete regardless of errors.

**2. Calling `g.SetLimit` after the first `g.Go`.**
Why it happens: the limit seems like configuration that can be set at any time.
`SetLimit` after `Go` panics. Set the limit before starting any goroutines.

**3. Sharing a single `errgroup.Group` for unrelated work.**
Why it happens: reusing the group saves allocations. But if the first batch of
work fails and cancels the context, the second batch's goroutines see a
cancelled context and return errors immediately. Use a fresh group per
independent unit of work.

**4. Not selecting on `ctx.Done()` in pipeline stage sends.**
Why it happens: the send `out <- v` seems safe. But if the downstream consumer
has returned (due to error or cancellation), the send blocks forever. Every
send in a pipeline stage must select on both the send and `ctx.Done()`.

**5. Collecting results into a shared slice without a mutex.**
Why it happens: slices feel like value types. But `append` to a shared slice
from multiple goroutines is a data race. Either use a mutex around the append,
or use a channel to collect results into a single goroutine.

---

## Check your understanding

1. You have 1000 URLs to fetch. You want at most 20 concurrent HTTP requests.
   If any request returns a 5xx status, cancel the remaining requests. Sketch
   the `errgroup` call structure (no need for full code — just the structural
   pattern: `errgroup.WithContext`, `g.SetLimit`, `g.Go`, `g.Wait`).
2. A function signature is `func process(in <-chan Job, out chan<- Result)`.
   Can the function close `out`? Can it send to `in`? What compile-time
   guarantee does this signature provide?
3. You have a `merge` function that combines 5 input channels into one output
   channel. The merge function launches 5 goroutines, one per input. Who
   closes the output channel, and how does the function know when all 5 inputs
   are drained?

(answers are in the code — run the lab to verify)
