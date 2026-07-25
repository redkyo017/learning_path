### Day 5 — Partitioning / sharding & consistent hashing

**Teardown target:** Discord's message-store sharding (`channel_id + time bucket`) + Uber Ringpop.
**Design brief:** shard the URL shortener's key space across nodes.
**ADR topic:** hash (modulo) vs range vs consistent-hash partitioning.
**Lab:** client-side sharding across 2 → 3 Postgres nodes; measure the key movement (modulo vs consistent hashing); feel the reshard.
**When NOT this:** sharding before a single node is saturated — it adds cross-shard query pain and rebalancing risk for no benefit. Vertical-scale, replicate, and cache first.
**Builds on:** Day 4 (the replicated store). **Sets up for:** Day 7 (load-levels the sharded writes).

Theory: `../../content/day05.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read the Discord and Ringpop entries in
`../../content/day05.md` (Real-world) and `reference/real-world-case-studies.md`
(Day 5). Extract: Discord's partition key spreads load *and* matches the dominant
query *and* bounds partition size; Ringpop uses consistent hashing + gossip to
shard **work**, not just data. **Write your takeaway** into
`reference/real-world-case-studies.md`.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on
"shard the shortener's key space":
1. **Requirements** — point lookup by `short_code`; no range scans on the code;
   capacity grows → you will add nodes.
2. **Constraints** — must keep serving during rebalancing; operability of the
   routing tier.
3. **Top-3 NFRs** — likely scalability (write/storage), operability
   (rebalancing), latency. Targets each.
4. **Options (≥2)** — modulo-N, range, consistent hash (+vnodes), fixed
   partitions. (See the table in `content/day05.md`.)
5. **Tradeoff table** — options × rebalancing cost / hot-spotting / range-query
   support / complexity.
6. **Decision** — one sentence: *why this over the runner-up.*
7. **How it breaks** — red-team a **celebrity/hot key** (one shard sinks) and a
   **node addition** (how much moves, can you serve during the move).
Write the design to `design/`. Write **one ADR** to `adr/` using
`reference/adr-template.md` — suggested **ADR 0005** (partitioning scheme). You
write the ADR; numbers are global.

**Beat 3 — Hands-on lab (~55m).** Follow `lab/README.md`:
- Run the Go `shard` program (no DB) to measure **~66.7%** (modulo) vs **~33.3%**
  (consistent hash) key movement on a 2→3 reshard, and the load balance.
- Optional: bring up `shard0/1/2` Postgres and route real inserts with `-pg`.
- **Break-it:** force all traffic to one key → watch one shard own 100%.
- **Learner TODO:** implement `Ring.Remove` and measure removal rebalancing.
Record everything in `lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 5 — Partitioning & consistent hashing
Key concept in my own words: …
When would I NOT use this: … (before a single node is saturated)
Break-it — what I broke and how I diagnosed it: … (hot key -> one shard 100%)
Biggest surprise / open question: …
```
Then **teardown** (only if you ran `-pg`): `docker compose ... down -v` (see lab README).

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (partition key + scheme)
- [ ] `diagrams/` — a diagram of the routing layer + shards (`.mmd`)
- [ ] `adr/0005-*.md` — modulo vs range vs consistent hash
- [ ] `lab/results.md` — the two movement fractions + balance + hot-key observation
- [ ] `journal.md` entry appended
- [ ] shards torn down if brought up
