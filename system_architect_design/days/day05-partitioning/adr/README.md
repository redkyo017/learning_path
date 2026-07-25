Put your ADR(s) here as `NNNN-title.md` (see `reference/adr-template.md`). ADR
numbers are global across all days.

Day 5 suggested ADR **0005** — "Partition the key space with consistent hashing
(virtual nodes)" (or fixed partitions, if you chose that). Context: point-lookup
access, growth requires adding nodes, must serve during rebalancing. Alternatives
to reject: modulo-N (reshuffles ~2/3 on any node change), range (no range need +
hot-spot risk on sequential keys). Consequence to live with: no cheap cross-shard
range queries; a celebrity key still sinks one shard and needs a layer above the
partitioner (cache / key-split / replicas).
