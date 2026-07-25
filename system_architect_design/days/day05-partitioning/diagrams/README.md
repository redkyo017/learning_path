Put your C4 `.mmd` diagrams here (see `reference/c4-guide.md`).

Day 5 suggestion: a C2/component diagram of the routing layer — client (or proxy)
computing `key → shard` over a consistent-hash ring — in front of N shard nodes,
each shard itself a primary+replica set (carried over from Day 4). Show the
"add a node" arc that moves ~1/N of the keys.
