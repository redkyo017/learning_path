Put your C4 `.mmd` diagrams here (see `reference/c4-guide.md`).

Day 6 suggestion: a component/flow diagram of the cache-aside path — app → cache
(hit returns; miss falls through) → DB → set-with-TTL — plus where singleflight
sits to coalesce concurrent misses. Optionally show the cache placement tiers
(client / CDN / distributed Redis).
