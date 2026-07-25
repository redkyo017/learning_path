# design/ — Day 3

Put your filled-in 7-step design here (see `reference/design-method.md`).

Expected today: `storage.md` — model the shortener lookup and the feed fan-out both
ways (normalized SQL vs denormalized KV), with a tradeoff table on read latency,
write amplification, query flexibility, and operational cost. Red-team: a new query
the chosen model can't serve cheaply.
