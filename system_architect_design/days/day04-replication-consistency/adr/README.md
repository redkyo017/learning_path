Put your ADR(s) here as `NNNN-title.md` (see `reference/adr-template.md`). ADR
numbers are global across all days.

Day 4 suggested ADR **0004** — "Read from replicas for redirects, primary for
read-your-writes." Context: reads ≫ writes; redirects tolerate staleness; the
creator must see their own new link. Alternatives to reject: primary-only reads
(no read scale), quorum/sync everywhere (latency the tolerant paths don't need).
Consequence to live with: reads may be stale up to the replication lag, and the
own-writes path must be identified and routed to the primary (or a caught-up
replica via an LSN token).
