Put your ADR(s) here as `NNNN-title.md` (see `reference/adr-template.md`). ADR
numbers are global across all days.

Day 6 suggested ADR **0006** — "Cache-aside with long TTL + explicit invalidation
for the URL mapping (+ singleflight)." Context: read-mostly redirects, rarely-
changing mapping, DB-load relief. Alternatives to reject: write-through (write
latency + wasted cache for rarely-read data), write-back (data loss on cache node
loss — only acceptable for click counts), no cache (DB read pressure).
Consequence to live with: reads may be stale up to the TTL for missed
invalidations; hot-key expiry needs stampede protection (singleflight/leases).
