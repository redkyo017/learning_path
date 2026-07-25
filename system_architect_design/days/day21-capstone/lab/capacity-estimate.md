# Capstone — Capacity estimate

Use `reference/estimation-cheatsheet.md`. The goal is **order-of-magnitude numbers
that change the design** — and **every number must end in a decision** ("→ therefore
X"), or it's decoration.

## Assumptions stated out loud

- DAU: __________ ; actions/user/day: __________ ; payload size: __________
- Peak multiplier (spikiness): ×______

## Throughput

| Quantity | Formula | Value | → Decision |
|----------|---------|-------|-----------|
| Avg write QPS | daily_writes / 86,400 | | → |
| Peak write QPS | avg × peak_mult | | → |
| Avg read QPS | writes × read:write | | → |
| Peak read QPS | avg × peak_mult | | → |

## Storage

| Quantity | Formula | Value | → Decision |
|----------|---------|-------|-----------|
| Bytes/record | sum of fields | | |
| Storage/year | writes/day × 365 × bytes × RF × retention | | → (single box / shard?) |
| Working set (cache) | hot% × total | | → (cacheable?) |

## Bandwidth / connections

| Quantity | Formula | Value | → Decision |
|----------|---------|-------|-----------|
| Read bandwidth (peak) | read_QPS × avg_resp_bytes | | → (CDN / LB?) |
| Concurrent connections | QPS × avg_latency_s (Little's Law) | | → (pool size?) |

## The three decisions this estimate forced

1.
2.
3.

## The riskiest assumption

The number that, if wrong by 10×, would break the design: __________________
→ how I'd validate it early: __________________
