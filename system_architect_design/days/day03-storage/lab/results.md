# Day 3 Lab Results — Postgres vs Redis

Dataset: 1,000,000 `code → URL` rows. Lookups: n = ______.

## Point-lookup latency (random existing keys)
| Store | mean | p50 | p95 | p99 | max |
|-------|------|-----|-----|-----|-----|
| Postgres (indexed PK) |  |  |  |  |  |
| Redis (KV GET)        |  |  |  |  |  |

Observations:
- Redis p50 vs Postgres p50 gap: ______ (bigger/smaller than you expected?)
- Was Postgres closer than you assumed? What keeps it fast? (PK btree + buffer cache) ______

## Break-it — range query "codes created today"
| Store | Time | Rows returned | Could it even answer? |
|-------|------|---------------|-----------------------|
| Postgres (idx_short_urls_created_at) |  |  | yes — index range scan |
| Redis (SCAN keyspace) |  | n/a | no — no timestamp, no secondary index |

`EXPLAIN ANALYZE` plan for the Postgres range query (paste the top line):
```
```

## Verdict per query shape
| Query shape | Winner | Why |
|-------------|--------|-----|
| point lookup by key |  |  |
| range / "created today" |  |  |
| ad-hoc relational (join, filter on non-key) |  |  |

## Conclusion for ADR-0003
- The lookup path should use: ______ (store of record) + ______ (cache), because ______.
- The query Redis-as-KV can't serve cheaply: ______ → mitigation: ______.
- Biggest surprise: ______
