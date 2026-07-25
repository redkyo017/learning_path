### Day 4 — Replication & consistency; CAP / PACELC

**Teardown target:** Google Spanner (PACELC PC/EC) + Amazon Dynamo eventual consistency.
**Design brief:** add read replicas to the URL shortener; decide read consistency per path.
**ADR topic:** read-from-replica vs read-from-primary for the redirect path.
**Lab:** Postgres primary + streaming replica; induce lag; observe stale reads; fix read-your-writes.
**When NOT this:** strong consistency for a like-count / view counter — you pay latency & availability you don't need. Match consistency to the *business cost of staleness*.
**Builds on:** Day 3 (the chosen store). **Sets up for:** Day 5 (partition the replicated store).

Theory: `../../content/day04.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read the Spanner and Dynamo entries in
`../../content/day04.md` (Real-world) and `reference/real-world-case-studies.md`
(Day 4). Extract: Spanner chose consistency and pays latency (PC/EC); Dynamo
chose availability and accepts staleness (PA/EL). **Write your takeaway** into
`reference/real-world-case-studies.md` (the "My takeaway" lines): *consistency is
a per-operation choice, not a per-database one.*

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on
"add read replicas to the shortener":
1. **Requirements** — redirects (read-heavy, staleness-tolerant); "my links" list
   (read-your-writes for the creator); admin/moderation reads (safety-sensitive).
2. **Constraints** — single region to start; a modest primary; read QPS ≫ write QPS.
3. **Top-3 NFRs** — pick from `reference/nfr-checklist.md` (likely: latency,
   scalability of reads, consistency-where-it-matters). Give each a target.
4. **Options (≥2)** — primary-only reads; async replica reads; replica reads +
   read-your-writes routing; sync/quorum. (See the table in `content/day04.md`.)
5. **Tradeoff table** — options × top-3 NFRs (+ cost + complexity).
6. **Decision** — one sentence: *why this over the runner-up.*
7. **How it breaks** — red-team a **failover mid-write** (async → data loss / RPO;
   split brain) and a **lag spike under load** (stale reads for everyone).
Write the design to `design/` (start from `design/README.md`). Write **one ADR**
to `adr/` using `reference/adr-template.md` — suggested **ADR 0004**
(read-from-replica vs read-from-primary for redirects; note read-your-writes
exception). You write the ADR; the number is global.

**Beat 3 — Hands-on lab (~55m).** Follow `lab/README.md`:
- Extend the stack with `postgres-replica` (streaming replication) via the
  provided `lab/docker-compose.override.yml`.
- Write a row to the primary, read it from the replica — usually fine.
- **Break-it (core):** pause WAL replay on the replica
  (`SELECT pg_wal_replay_pause();`) — or add latency with Toxiproxy — then write
  to the primary and read the replica → observe the **stale read /
  read-your-writes violation**.
- Fix it by routing that read to the primary; record the lag window and the fix
  in `lab/results.md`. Optional: run `lab/lagcheck` to measure the lag window in ms.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 4 — Replication & consistency
Key concept in my own words: …
When would I NOT use this: … (strong consistency for a like-count)
Break-it — what I broke and how I diagnosed it: … (paused WAL replay → stale read)
Biggest surprise / open question: …
```
Then **teardown:** `docker compose -f docker-compose.yml -f ../days/day04-replication-consistency/lab/docker-compose.override.yml down -v` (see lab README for the exact command).

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (redirects vs my-links consistency)
- [ ] `diagrams/` — a C2 diagram showing primary + replica + read routing (`.mmd`)
- [ ] `adr/0004-*.md` — read-from-replica vs primary for redirects
- [ ] `lab/results.md` — measured lag window + the stale read + the read-your-writes fix
- [ ] `journal.md` entry appended
- [ ] stack torn down (`down -v`)
