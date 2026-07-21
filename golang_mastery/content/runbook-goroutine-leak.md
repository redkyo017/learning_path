# Runbook: Goroutine Leak Detection and Fix

**When to use this runbook:**
- Service memory grows over time without explanation (memory never plateaus after warm-up)
- Go runtime metrics show goroutine count climbing continuously
- `pprof` goroutine profile shows hundreds or thousands of goroutines
- Response times degrade over hours as the scheduler overhead grows

---

## Background

A goroutine leak occurs when a goroutine is started but never returns. The goroutine stays alive — consuming stack memory (~8KB initially, up to MB as it grows), holding references that prevent GC, and burning scheduler time. Unlike memory leaks in other languages, goroutine leaks are always a logic bug: somewhere a goroutine is waiting for something that will never arrive.

---

## Step 1: Detect with a pprof goroutine dump

First, confirm the leak is goroutine-based and get the count.

```bash
# Quick count — returns the number of current goroutines
curl -s "http://localhost:PORT/debug/pprof/goroutine?debug=1" | head -5

# Full stack dump — shows every goroutine with its stack trace
curl -s "http://localhost:PORT/debug/pprof/goroutine?debug=2" > goroutine-dump.txt
wc -l goroutine-dump.txt   # large file = many goroutines

# If the service does not expose pprof, add it:
# import _ "net/http/pprof"
# Then: http.ListenAndServe(":6060", nil)
```

For a more interactive analysis, use `go tool pprof`:

```bash
# Capture two profiles 60 seconds apart — a leak shows an increasing delta
curl -o g1.pprof "http://localhost:PORT/debug/pprof/goroutine"
sleep 60
curl -o g2.pprof "http://localhost:PORT/debug/pprof/goroutine"

# Compare them
go tool pprof -base g1.pprof g2.pprof
# In the pprof shell:
(pprof) top10        # shows which call sites are growing
(pprof) list worker  # annotates source for function named "worker"
```

**Healthy service**: goroutine count is stable and proportional to load (e.g., one goroutine per active HTTP connection + a handful of background workers).

**Leaking service**: goroutine count grows monotonically over time regardless of whether request rate is constant.

---

## Step 2: Read the goroutine stack trace

The `debug=2` output looks like this:

```
goroutine 5423 [chan receive, 47 minutes]:
main.processJob(0xc000198000, 0x0, 0x0)
        /app/worker.go:87 +0x6c
created by main.startWorkers
        /app/worker.go:54 +0x1a4

goroutine 5424 [chan receive, 47 minutes]:
main.processJob(0xc000198100, 0x0, 0x0)
        /app/worker.go:87 +0x6c
created by main.startWorkers
        /app/worker.go:54 +0x1a4
```

**What to look for:**

| Signal | What it means |
|---|---|
| Many goroutines with identical stacks | One code path is leaking repeatedly |
| `[chan receive, N minutes]` | Goroutine blocked waiting to receive from a channel that nobody writes to |
| `[chan send]` | Goroutine blocked sending to a channel with no reader |
| `[select]` | Goroutine stuck in a `select` — likely no `ctx.Done()` case |
| `[semacquire]` | Goroutine waiting on a mutex or semaphore |
| `[sleep]` | Goroutine in `time.Sleep` — likely an infinite loop |
| Long age (N minutes) | High suspicion — a goroutine running for 47 minutes during an HTTP handler is wrong |

**Finding the leaking goroutine count:**

```bash
# Count occurrences of identical stacks
cat goroutine-dump.txt | grep "^\[" | sort | uniq -c | sort -rn | head -20
```

The highest-count entry is almost always the leak.

---

## Step 3: Common leak patterns with fixes

### Pattern 1: Goroutine waiting on a channel with no exit path

The most common pattern. A goroutine receives from a channel but there is no `ctx.Done()` case to exit when the parent context is canceled.

```go
// BUG: goroutine leaks when caller cancels or the service shuts down
func startWorker(jobCh <-chan Job) {
    go func() {
        for {
            job := <-jobCh   // blocks here forever if jobCh is never closed
            process(job)
        }
    }()
}

// FIX: always include a context cancellation path
func startWorker(ctx context.Context, jobCh <-chan Job) {
    go func() {
        for {
            select {
            case job, ok := <-jobCh:
                if !ok {
                    return // channel closed — clean exit
                }
                process(job)
            case <-ctx.Done():
                return // context canceled — clean exit
            }
        }
    }()
}
```

### Pattern 2: Goroutine in an infinite loop without a stop signal

```go
// BUG: goroutine runs forever even after service shuts down
func startPoller() {
    go func() {
        for {
            poll()
            time.Sleep(5 * time.Second)
        }
    }()
}

// FIX: accept a context and check for cancellation
func startPoller(ctx context.Context) {
    go func() {
        ticker := time.NewTicker(5 * time.Second)
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                poll()
            case <-ctx.Done():
                return
            }
        }
    }()
}
```

### Pattern 3: Goroutine blocked on HTTP request with no timeout

```go
// BUG: goroutine hangs forever if upstream stops responding
func fetchUpstream(url string) (*http.Response, error) {
    go func() {
        resp, err := http.Get(url)  // no timeout
        resultCh <- result{resp, err}
    }()
    return <-resultCh, nil
}

// FIX: always set a deadline on outbound HTTP calls
func fetchUpstream(ctx context.Context, url string) (*http.Response, error) {
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, err
    }
    return http.DefaultClient.Do(req)
}
```

### Pattern 4: Goroutine waiting on a channel that was already closed

```go
// BUG: sending on a closed channel panics; receiving from a closed
// channel returns the zero value immediately and then loops forever
for {
    val := <-doneCh // doneCh was already closed — returns zero value in tight loop
    doSomething(val)
}

// FIX: check the ok value from channel receive
for {
    val, ok := <-doneCh
    if !ok {
        return // channel closed
    }
    doSomething(val)
}
```

### Pattern 5: `go func()` inside a request handler without a bound lifetime

```go
// BUG: goroutine outlives the request if the HTTP client disconnects
func handleRequest(w http.ResponseWriter, r *http.Request) {
    go func() {
        result := slowOperation()  // no context — runs even after client disconnects
        cache.Set(key, result)
    }()
    w.Write([]byte("accepted"))
}

// FIX: pass the request context (or a server-level context)
func handleRequest(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    go func() {
        result, err := slowOperationWithContext(ctx)
        if err != nil {
            return // context canceled — client disconnected
        }
        cache.Set(key, result)
    }()
    w.Write([]byte("accepted"))
}
```

---

## Step 4: Verify the fix

### Before deploying the fix

Record the baseline goroutine count and save a profile:

```bash
# Record count
curl -s "http://localhost:PORT/debug/pprof/goroutine?debug=1" | grep "^goroutine" | head -1
# Example output: goroutine profile: total 4712

# Save a profile for comparison
curl -o before-fix.pprof "http://localhost:PORT/debug/pprof/goroutine"
```

### After deploying the fix

Wait 5–10 minutes (or simulate load equivalent to what caused the leak), then:

```bash
# Count should be stable or lower
curl -s "http://localhost:PORT/debug/pprof/goroutine?debug=1" | grep "^goroutine" | head -1
# Expected: goroutine profile: total 42  (stable, proportional to active connections)

# Confirm the leaking stack no longer appears
curl -s "http://localhost:PORT/debug/pprof/goroutine?debug=2" | grep "main.processJob"
# Expected: no output (or count proportional to active jobs, not growing)
```

### Add a goroutine count metric

Once fixed, add a Prometheus gauge so you catch future leaks before they become incidents:

```go
import "runtime"

goroutineGauge := prometheus.NewGauge(prometheus.GaugeOpts{
    Name: "go_goroutines_total",
    Help: "Current number of goroutines.",
})
prometheus.MustRegister(goroutineGauge)

// Update in a background goroutine
go func() {
    ticker := time.NewTicker(15 * time.Second)
    for range ticker.C {
        goroutineGauge.Set(float64(runtime.NumGoroutine()))
    }
}()
```

Alert when goroutine count grows monotonically for more than 5 minutes.

---

## Quick reference

| Command | Purpose |
|---|---|
| `curl "http://HOST/debug/pprof/goroutine?debug=1"` | Count + summary |
| `curl "http://HOST/debug/pprof/goroutine?debug=2"` | Full stack dump |
| `go tool pprof http://HOST/debug/pprof/goroutine` | Interactive pprof shell |
| `(pprof) top10` | Top call sites by goroutine count |
| `(pprof) list funcname` | Annotated source for a function |
| `runtime.NumGoroutine()` | Programmatic count in code |
| `grep "\[chan receive" goroutine-dump.txt \| wc -l` | Count channel-blocked goroutines |
