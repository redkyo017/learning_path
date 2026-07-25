Put your filled-in 7-step design here (see `reference/design-method.md`).

Day 5 brief: shard the shortener's `short_code → long_url` key space. Choose a
partition key and scheme (modulo vs range vs consistent-hash vs fixed
partitions), with a tradeoff table on rebalancing cost, hot-spotting, and
range-query support. "How it breaks" must cover a celebrity/hot key and a node
addition (how much data moves, can you serve during the move). See
`../../../content/day05.md`.
