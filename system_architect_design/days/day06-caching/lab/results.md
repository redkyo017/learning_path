# Day 6 lab results

## Read load — cache vs no cache

| Scenario | p50 | p95 | p99 | hitRatio | dbQueries | total reqs |
|----------|-----|-----|-----|----------|-----------|------------|
| `CACHE=off` (baseline) | ___ | ___ | ___ | n/a | ___ | ___ |
| cache-aside (default) | ___ | ___ | ___ | ___ | ___ | ___ |

Effective-latency check (from content Ex.2): with my measured hitRatio,
`h·Cₗ + (1−h)·Dₗ` ≈ ___ ms. Matches observed p50? ___

## Stampede (break-it) and the fix

| Run | SINGLEFLIGHT | misses (burst) | dbQueries (burst) |
|-----|--------------|----------------|-------------------|
| before fix | off | ___ | ___ (expect dozens) |
| after fix | on | ___ | ___ (expect ~1) |

Reduction in DB queries: ___×

## Learner TODO — negative caching
- Implemented? ___
- dbQueries against random non-existent codes: before ___ / after ___

## Reflection
- Which shortener data did I put on cache-aside vs write-back vs no-cache? ___
- What TTL + invalidation did I choose for the URL mapping, and why? ___
- If Redis went down right now, what happens to the DB? Did I guard it? ___
