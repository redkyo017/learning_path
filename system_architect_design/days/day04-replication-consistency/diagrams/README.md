Put your C4 `.mmd` diagrams here (see `reference/c4-guide.md`).

Day 4 suggestion: a C2 (container) diagram of the shortener showing the primary,
one or more replicas, and the read-routing decision — which reads go to the
replica (redirects) vs the primary (read-your-writes) — with the replication
edge labelled `async WAL streaming`.
