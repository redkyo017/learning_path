# Day 5 lab — resharding pain: modulo vs consistent hashing

**Goal:** measure how many keys must **move** when you grow from 2 to 3 shards
under `hash % N` versus a consistent-hash ring, confirm the load balance, and see
the hot-key failure that no hashing scheme can fix.

The core measurement needs **no database** — it's a property of the hashing. The
optional `-pg` step routes real inserts into three Postgres shards so you can see
physical balance too.

Prereqs: Go 1.22+. Docker only for the optional `-pg` step.

---

## 1. Measure the reshard (no DB)

```bash
cd days/day05-partitioning/lab/shard
go mod tidy
go run .
```

Read the output:
- **Rebalancing cost 2→3:** modulo should report **~66.7%** of keys moved,
  consistent hashing **~33.3%** — a ~2× reduction. That gap is the entire reason
  consistent hashing exists.
- **Load balance at 3 nodes:** both schemes land ~1/3 per node; note the
  consistent-hash *imbalance* ratio (max/min).
- **Hot key:** every request for one viral code routes to a single node.

Turn the balance knob and watch the imbalance ratio tighten:

```bash
go run . -vnodes 10       # few vnodes -> lumpy ring, higher imbalance
go run . -vnodes 300      # many vnodes -> smoother, imbalance -> ~1.0
go run . -keys 1000000    # more keys -> fractions converge on 66.7% / 33.3%
```

## 2. (Optional) route into real Postgres shards

Bring up three independent shards:

```bash
cd ../../../../labs        # into labs/
export COMPOSE="docker compose -f docker-compose.yml -f ../days/day05-partitioning/lab/docker-compose.override.yml"
$COMPOSE up -d shard0 shard1 shard2
$COMPOSE ps                # shard0/1/2 running on 5441/5442/5443
```

Route keys into them using the consistent-hash ring and print per-shard counts:

```bash
cd ../days/day05-partitioning/lab/shard
go run . -pg
# -> "shard A: ~6.6k rows, shard B: ~6.6k, shard C: ~6.6k" (of the 20k sample)
#    Roughly even = balance verified on real nodes.
```

## 3. BREAK IT — the hot partition

Two ways to feel it:

- The default run already prints that a single `viral-code` routes entirely to
  one node. To make it physical, insert the *same* key many times / drive read
  load at only that key's shard and watch one shard's CPU while the others idle:

```bash
# Which shard owns the hot key? The program prints it (e.g. node "B" -> shard1:5442).
# Hammer only that shard and watch it work while the others sit idle:
$COMPOSE exec shard1 psql -U postgres -d app -c \
  "SELECT count(*) FROM links;"     # (stand-in for load; drive real reads if you like)
```

- The lesson: consistent hashing spreads *distinct keys* evenly but cannot split
  *one* key. Fixes live above the partitioner — cache the key (Day 6), key-split
  it, or serve it from that shard's replicas (Day 4). Record which you'd choose.

## 4. Learner TODO (the insight to implement yourself)

In `shard/main.go`, `Ring.Remove(node)` is a stub. Implement it (drop the node's
vnodes, re-sort `points`), then add a small `-remove` path that measures what
fraction of keys move when node **C leaves** a 3-node ring. **Predict first**
(hint: also ~1/N), then verify. Record your prediction vs measurement in
`results.md`.

## 5. TEARDOWN (only if you ran `-pg`)

```bash
cd ../../../../labs
$COMPOSE down -v
```

---

## What you should have observed

| Going 2 → 3 nodes | keys moved |
|-------------------|-----------|
| `hash % N` (modulo) | ~66.7% — reshuffles almost everything at the worst moment |
| consistent hash (vnodes) | ~33.3% — only the new node's arc moves, drawn evenly from survivors |

Consistent hashing trades a tiny bit of routing complexity (a sorted ring +
binary search) for a ~2× reduction in data movement on every topology change —
and virtual nodes keep the shards balanced. See `../../../content/day05.md` for
when a *fixed partition count* (Kafka/Dynamo style) beats a hand-rolled ring.
