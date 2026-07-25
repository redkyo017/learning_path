# Day 9 lab results

## Environment
- Machine / CPU:
- Go version:
- Date:

## Cascade vs contain (B degraded to +3000ms, A pool = 10, λ = 200/s)

| Metric | Stage A (PROTECT=off) | Stage B (PROTECT=on) |
|--------|-----------------------|----------------------|
| p50 (ms) |  |  |
| p95 (ms) |  |  |
| p99 (ms) |  |  |
| error rate (%) |  |  |
| served_live |  |  |
| served_fallback |  |  |
| served_error |  |  |

Expected: Stage A p95/p99 explode + errors climb (pool exhaustion cascade). Stage B
p95 stays low; requests shift to `served_fallback` (degraded but 200).

## Little's Law check
- In-flight A needs when B = 3s: λ × W = 200 × 3 = 600; pool = 10 → __ requests block.
- With TIMEOUT_MS=200: W = 0.2s → in-flight = 200 × 0.2 = 40 → still > pool 10, but
  the breaker opens and sheds to fallback, so live calls stay ≤ bulkhead. Observed:

## Breaker state transitions (from gateway logs + /state)
| Event | State before | State after | Notes |
|-------|--------------|-------------|-------|
| B degraded (>20 reqs, >50% fail) | closed | open |  |
| after sleep window (5s) | open | half-open |  |
| B healed, probes succeed | half-open | closed |  |
| B degraded again | closed | open |  |

## When-NOT observation
- `/get` before warming cache while B down → 503. What this proves about breakers
  with no safe fallback:

## Takeaways
- Why slow was worse than a fast failure here:
- What the bulkhead added on top of the timeout + breaker:
- One thing I'd tune differently (thresholds/timeout/bulkhead) and why:
