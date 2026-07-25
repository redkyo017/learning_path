# Day 7 lab results

Fill this in as you run the lab. The point is the *deltas*, not absolute numbers
(they depend on your machine).

## Environment
- Machine / CPU:
- Go version:
- Date:

## Stage A vs Stage B — ingress latency under the same 10× spike

| Metric | Stage A (sync echo) | Stage B (queue, bounded 2000) |
|--------|---------------------|-------------------------------|
| p50 (ms) |  |  |
| p95 (ms) |  |  |
| p99 (ms) |  |  |
| error rate (%) |  |  |
| requests completed |  |  (202s) |

Expected: Stage B ingress p95 stays low and flat (handler only LPUSHes); Stage A
p95/p99 explode and errors rise during the spike.

## Stage B — queue depth over time (sampled `LLEN day7:jobs`)

| t (s) | depth |
|-------|-------|
| spike start |  |
| +10 |  |
| +20 (spike end) |  |
| +40 |  |
| drained at t = |  |

- μ (service rate) = WORKERS / WORK_MS = 4 / 0.05 = **80 jobs/s**
- Observed drain rate ≈ ______ /s  (Little's Law check: ≈ 80?)

## Stage C — break it (unbounded) then fix it (bounded)

| Run | QUEUE_MAX | ending depth | shed (429) | est. tail latency = depth/μ |
|-----|-----------|--------------|------------|-----------------------------|
| unbounded |
| bounded |

- What broke (unbounded): depth grew to ______; a job enqueued late would wait
  ______ s — longer than any client timeout ⇒ wasted work.
- The fix (bounded): depth pinned at ______; ______ requests got 429; max added
  latency chosen = depth/μ = ______ s.

## Takeaways
- The queue converted a **capacity** problem into a **latency** problem: ...
- The bound + 429 converted an **OOM/latency→∞** failure into **graceful shedding**: ...
- When I would NOT have queued this: ...
