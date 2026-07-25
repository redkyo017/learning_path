# Day 5 lab results

## Rebalancing cost — 2 → 3 shards

| Scheme | Keys | Keys moved | % moved | Expected |
|--------|------|------------|---------|----------|
| Modulo `hash % N` | ___ | ___ | ___ % | ~66.7% |
| Consistent hash (vnodes=___) | ___ | ___ | ___ % | ~33.3% |

Reduction factor (modulo ÷ consistent): ___×

## Load balance at 3 nodes

| Scheme | shard A | shard B | shard C | imbalance (max/min) |
|--------|---------|---------|---------|---------------------|
| Modulo | ___ | ___ | ___ | ___ |
| Consistent hash | ___ | ___ | ___ | ___ |

vnodes sweep — imbalance ratio:

| vnodes | imbalance |
|--------|-----------|
| 10 | ___ |
| 150 | ___ |
| 300 | ___ |

## Optional — real Postgres shards (`-pg`)

| Shard | Port | Row count |
|-------|------|-----------|
| A | 5441 | ___ |
| B | 5442 | ___ |
| C | 5443 | ___ |

## Break-it — hot key
- Which shard owned `viral-code`? ___
- What did I observe / would I mitigate with? ___ (cache / key-split / replicas)

## Learner TODO — node removal (Ring.Remove)
- My prediction for % moved when C leaves a 3-node ring: ___
- Measured: ___
- Where did the moved keys go? ___

## Reflection
- Would I hand-roll a ring or use fixed partitions (Kafka/Dynamo) here? Why? ___
- What single-node saturation signal would actually make me shard? ___
