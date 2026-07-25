Put your filled-in 7-step design here (see `reference/design-method.md`).

Day 6 brief: add caching to the shortener's redirect path. Choose a pattern
**per data type** (URL mapping: cache-aside + long TTL + invalidate on edit;
click counts: write-back). Include the tradeoff table (cache-aside vs
write-through vs write-back on read/write latency, freshness, failure exposure)
and a "how it breaks" section covering a hot-key stampede and a post-deploy
avalanche (mass expiry). See `../../../content/day06.md`.
