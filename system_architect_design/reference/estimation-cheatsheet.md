# Back-of-Envelope Estimation Cheatsheet

The goal is **order-of-magnitude** numbers that change the design — not
precision. If your estimate tells you "single box" vs "needs sharding" vs "needs
a CDN", it did its job.

## Latency numbers every engineer should know (Jeff Dean, rounded)

| Operation | Time | Intuition |
|-----------|------|-----------|
| L1 cache reference | 0.5 ns | — |
| Branch mispredict | 5 ns | — |
| L2 cache reference | 7 ns | — |
| Mutex lock/unlock | 25 ns | — |
| Main memory reference | 100 ns | 200× L1 |
| Compress 1 KB (Zippy/Snappy) | 3 μs | — |
| Send 1 KB over 1 Gbps network | 10 μs | — |
| Read 4 KB randomly from SSD | 150 μs | ~1 GB/s |
| Read 1 MB sequentially from memory | 250 μs | — |
| Round trip within same datacenter | 500 μs | 0.5 ms |
| Read 1 MB sequentially from SSD | 1 ms | 4× memory |
| Disk seek (spinning) | 10 ms | 20× datacenter RT |
| Read 1 MB sequentially from disk | 20 ms | 80× memory |
| Round trip CA ↔ Netherlands | 150 ms | speed of light tax |

**Takeaways:** memory is ~100× faster than SSD random read; a cross-continent
round trip (150 ms) dominates everything — cache/CDN near the user. Sequential
beats random by orders of magnitude — design for sequential I/O.

## Throughput & sizing formulas

```
average QPS   = daily_requests / 86,400        (86.4k seconds/day)
peak QPS      ≈ average QPS × 2 to 10           (pick by spikiness; 2 steady, 10 bursty)
storage/yr    = writes/day × 365 × bytes/record × replication_factor × retention_years
read bandwidth= read_QPS × avg_response_bytes
cache size    ≈ working_set = hot_fraction (~20%) × total_data   (Pareto rule of thumb)
connections   ≈ QPS × avg_latency_seconds       (Little's Law: L = λ × W)
```

## Handy round numbers

| Quantity | Use |
|----------|-----|
| 1 day ≈ 86,400 s ≈ **~100k s** | QPS from daily counts (round up) |
| 1 month ≈ 2.5M s | monthly → per-second |
| 2^10 = 1K, 2^20 = 1M, 2^30 = 1B ≈ 1 GB | data sizing |
| char = 1 byte, int = 4 B, timestamp = 8 B, UUID = 16 B | record sizing |
| 1 M writes/day ≈ **~12 writes/s** average | sanity check |
| 1 B writes/day ≈ **~12k writes/s** average | sanity check |

## Worked example — a URL shortener

- 100 M new URLs/day → avg write QPS = 100M / 86.4k ≈ **~1,160/s**; peak ×5 ≈ **~5,800/s**.
- 10:1 read:write → read QPS avg ≈ **~11,600/s**; peak ≈ **~58,000/s**.
- Record ≈ 500 B (short code + long URL + metadata). 5-yr storage =
  100M × 365 × 5 × 500 B ≈ **~91 TB** (×replication). → needs sharding, not one box.
- Read bandwidth (peak) = 58k/s × 500 B ≈ **~29 MB/s** → fine for a single LB,
  but reads are the pressure → **cache the hot 20%** (~18 TB working set is huge →
  cache only truly-hot keys, not all).

**What the estimate decided:** reads dominate (→ cache + read replicas); storage
is large (→ shard); writes are modest (→ a queue can smooth peaks). You reached
three architecture decisions before drawing a single box.

## Process

1. State assumptions out loud (DAU, actions/user/day, payload size).
2. Compute average, then apply a peak multiplier.
3. Translate each number into a **decision** ("→ needs X"), not just a figure.
4. Note the number that, if wrong by 10×, would break the design — that's your
   riskiest assumption to validate.
