Put your filled-in 7-step design here (see `reference/design-method.md`).

Day 4 brief: add read replicas to the URL shortener and decide read consistency
**per path** — redirects (staleness-tolerant, replica reads) vs the creator's
"my links" list (read-your-writes, primary/caught-up read). Include the tradeoff
table (primary-only vs replica reads vs replica+RYW routing vs quorum) and a
"how it breaks" section covering failover-mid-write (RPO/split brain) and a lag
spike under load. See `../../../content/day04.md`.
