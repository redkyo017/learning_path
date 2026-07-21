# Runbook: Go Service Performance Profiling

**When to use this runbook:**
- High CPU utilization without obvious cause
- High memory / heap growth
- Slow response times or latency spikes that are not explained by downstream services
- Goroutine scheduling delays (requests queueing even when CPU is low)
- Specific function suspected as a bottleneck

---

## Background

Go ships a production-grade profiler in the standard library. The `pprof` endpoint gives you CPU, memory, goroutine, and trace profiles without any external agent. The workflow is: capture a profile while the problem is occurring, then analyze it offline.

**Four profiling tools:**
- **CPU profile** — where is time being spent on CPU?
- **Heap profile** — what is being allocated?
- **Trace** — goroutine scheduling, GC pauses, syscall waits
- **Benchmarks** — isolate and measure a specific function in a controlled environment

---

## Step 1: Enable the pprof endpoint

### Automatic (simplest)

```go
import _ "net/http/pprof"

// This import registers /debug/pprof/* handlers on http.DefaultServeMux automatically.
// If you call http.ListenAndServe(":8080", nil), pprof is now available.
```

### Custom mux (Gin / Chi / custom router)

If you use a custom `http.ServeMux` or a framework, the blank import alone is not enough — you must also mount the handlers:

```go
// Option A: run pprof on a separate port (recommended — keeps pprof off the public port)
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil)) // nil uses DefaultServeMux
}()

// Option B: mount pprof on your custom mux
import "net/http/pprof"

mux.HandleFunc("/debug/pprof/", pprof.Index)
mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
mux.HandleFunc("/debug/pprof/trace", pprof.Trace)

// For Gin:
r.GET("/debug/pprof/*action", gin.WrapF(pprof.Index))
// Or use the gin-contrib/pprof package:
// import "github.com/gin-contrib/pprof"
// pprof.Register(r)
```

**Security:** never expose the pprof port to the internet. Either bind to `localhost` or put it on a separate internal port behind a firewall / security group rule.

---

## Step 2: CPU profile

Use when: CPU is high, latency is high, you need to find hot functions.

```bash
# Capture a 30-second CPU profile while the service is under load
# The request blocks for 30 seconds while sampling
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Or save the profile to a file first, then analyze:
curl -o cpu.pprof "http://localhost:6060/debug/pprof/profile?seconds=30"
go tool pprof cpu.pprof
```

### Inside the pprof interactive shell

```
(pprof) top10
# Shows top 10 functions by CPU time
# Output:
#   flat  flat%   sum%        cum   cum%
#  1.23s 41.20% 41.20%      1.23s 41.20%  encoding/json.(*encodeState).marshal
#  0.45s 15.05% 56.25%      0.48s 16.05%  runtime.mallocgc

# flat = time spent IN this function
# cum  = time spent in this function AND all functions it calls
# A high flat% means THIS function is the bottleneck
# A high cum% with low flat% means it calls something slow

(pprof) top10 -cum
# Sort by cumulative — shows the call chain that is expensive

(pprof) list json.Marshal
# Annotated source for the json.Marshal function, showing per-line CPU cost

(pprof) web
# Opens a call graph in your browser (requires graphviz: brew install graphviz)
# Thicker edges = more CPU; red boxes = hot paths
```

### Interpreting CPU profile results

| What you see | What it means |
|---|---|
| `encoding/json` is high | JSON marshaling hot path — consider `encoding/json/v2`, easyjson, or protobuf |
| `runtime.mallocgc` is high | Heavy allocation causing GC pressure — look at heap profile |
| `syscall.Read` or `net.(*netFD).Read` is high | I/O-bound — not a CPU problem; look at trace instead |
| `sync.(*Mutex).Lock` is high | Lock contention — consider `sync.RWMutex`, finer-grained locks, or lock-free structures |
| `runtime.gcBgMarkWorker` is high | GC is taking significant CPU — reduce allocations |

---

## Step 3: Memory / heap profile

Use when: memory is growing, GC is frequent, you need to find allocations.

```bash
# Heap profile: current live objects (in-use memory)
go tool pprof http://localhost:6060/debug/pprof/heap

# Or save and analyze:
curl -o heap.pprof "http://localhost:6060/debug/pprof/heap"
go tool pprof heap.pprof
```

### `alloc_space` vs `inuse_space`

```
(pprof) top10 -inuse_space
# Memory currently held by live objects — shows what is alive right now
# Use this to find memory leaks

(pprof) top10 -alloc_space
# Total bytes allocated since process start (including already-freed objects)
# Use this to find GC pressure — frequent allocs that are quickly freed

(pprof) top10 -alloc_objects
# Number of objects allocated — useful for finding chatty allocators

(pprof) list mypackage.Handler
# Annotated source showing per-line allocation counts
```

### Common memory findings

| What you see | What it means |
|---|---|
| `bytes.(*Buffer).grow` is high | Buffers are being resized — pre-allocate with `bytes.NewBuffer(make([]byte, 0, expectedSize))` |
| `fmt.Sprintf` or `fmt.Errorf` is high | String formatting allocates — use `errors.New` for static errors; `slog` over `fmt.Sprintf` for logs |
| `encoding/json.Marshal` high alloc | JSON serialization allocates — consider streaming encoder or pre-allocated buffers |
| Slice or map growth high | Pre-size slices with `make([]T, 0, expectedLen)` and maps with `make(map[K]V, expectedLen)` |
| Your struct in `inuse_space` | You have a cache or map that is holding references and preventing GC — check expiry logic |

### Force GC before capturing heap profile

For accurate `inuse_space` numbers (exclude already-dead-but-not-collected objects):

```bash
# URL parameter gc=1 triggers a GC before returning the profile
curl -o heap.pprof "http://localhost:6060/debug/pprof/heap?gc=1"
```

---

## Step 4: Trace (goroutine scheduling and GC)

Use when: latency is variable and not explained by CPU or memory; p99 is much worse than p50; you suspect GC pauses or scheduler stalls.

```bash
# Capture a 5-second trace
curl -o trace.out "http://localhost:6060/debug/pprof/trace?seconds=5"

# Open the trace viewer (opens in browser at localhost:PORT)
go tool trace trace.out
```

### What to look for in `go tool trace`

| View | What it shows |
|---|---|
| **Goroutine analysis** | Which goroutines are running, blocked, waiting |
| **Network blocking** | Time goroutines spend waiting on network I/O |
| **Sync blocking** | Time goroutines spend waiting on mutexes/channels |
| **Syscall blocking** | Time goroutines spend in kernel syscalls |
| **Scheduler latency** | Time between a goroutine becoming runnable and actually running |
| **GC** | GC events with their duration — look for STW (stop-the-world) pauses |

### Interpreting trace results

| What you see | What it means |
|---|---|
| Long GC stop-the-world events | Allocating too much; reduce alloc_objects or increase `GOGC` |
| High scheduler latency | Too many goroutines competing for `GOMAXPROCS` threads; or `GOMAXPROCS` set too low (common in containers) |
| Goroutines blocked on network | Normal if you have many concurrent upstream calls; abnormal if connections are being created instead of reused |
| Long sync blocking | Lock contention or unbuffered channel waits |

---

## Step 5: Benchmark a specific function

Use when: you have isolated a suspected function and want to measure it precisely and repeatedly.

### Write a benchmark

```go
// In mypackage/handler_test.go
func BenchmarkParseRequest(b *testing.B) {
    payload := []byte(`{"id": "u_123", "name": "Alice"}`)
    b.ResetTimer() // reset timer after any setup
    for i := 0; i < b.N; i++ {
        _, err := parseRequest(payload)
        if err != nil {
            b.Fatal(err)
        }
    }
}

// With memory stats:
func BenchmarkParseRequestMem(b *testing.B) {
    payload := []byte(`{"id": "u_123", "name": "Alice"}`)
    b.ReportAllocs() // show allocs/op and bytes/op
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        parseRequest(payload)
    }
}
```

### Run the benchmark

```bash
# Basic run
go test -bench=BenchmarkParseRequest -benchtime=5s ./mypackage/

# With memory stats (allocs/op, bytes/op)
go test -bench=BenchmarkParseRequest -benchmem ./mypackage/

# Example output:
# BenchmarkParseRequest-8   1000000   1245 ns/op   512 B/op   7 allocs/op

# With CPU profile
go test -bench=BenchmarkParseRequest -cpuprofile=cpu.pprof ./mypackage/
go tool pprof cpu.pprof

# With memory profile
go test -bench=BenchmarkParseRequest -memprofile=mem.pprof ./mypackage/
go tool pprof -alloc_space mem.pprof

# Compare two implementations
go test -bench=. -count=5 ./mypackage/ > before.txt
# make changes
go test -bench=. -count=5 ./mypackage/ > after.txt
go install golang.org/x/perf/cmd/benchstat@latest
benchstat before.txt after.txt
```

### Benchmark output interpretation

```
BenchmarkParseRequest-8   1000000   1245 ns/op   512 B/op   7 allocs/op
                    ─┬─             ──┬──         ─┬──       ─┬────────
                     │               │             │           └── heap allocations per op
                     │               │             └── bytes allocated per op
                     │               └── nanoseconds per operation
                     └── GOMAXPROCS value (number of threads)
```

---

## Quick reference

```bash
# Enable pprof (add to main.go, use separate port)
go func() { log.Println(http.ListenAndServe("localhost:6060", nil)) }()

# CPU profile (30s)
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Heap profile (current live objects)
go tool pprof -inuse_space http://localhost:6060/debug/pprof/heap

# Heap profile (all allocations since start)
go tool pprof -alloc_space http://localhost:6060/debug/pprof/heap

# Goroutine trace (5s)
curl -o trace.out "http://localhost:6060/debug/pprof/trace?seconds=5" && go tool trace trace.out

# Goroutine dump
curl "http://localhost:6060/debug/pprof/goroutine?debug=2"

# Benchmark with memory stats
go test -bench=BenchmarkFoo -benchmem -count=5 ./...

# pprof shell commands
(pprof) top10               # top 10 by flat CPU
(pprof) top10 -cum          # top 10 by cumulative CPU
(pprof) top10 -inuse_space  # top 10 by live heap memory
(pprof) list FunctionName   # annotated source
(pprof) web                 # graph in browser (needs graphviz)
(pprof) png                 # save graph as PNG
```
