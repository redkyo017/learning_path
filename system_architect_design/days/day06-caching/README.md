### Day 6 — Caching strategies

**Teardown target:** Facebook's "Scaling Memcache at Facebook" (leases, thundering herd, invalidation).
**Design brief:** add caching to the URL shortener's redirect path.
**ADR topic:** cache-aside vs write-through; TTL & invalidation policy.
**Lab:** Redis cache-aside; measure hit ratio & latency; trigger a stampede; fix it with singleflight.
**When NOT this:** caching write-heavy or strongly-consistent data — invalidation cost and staleness bugs outweigh the hit-rate gain.
**Builds on:** Day 3 (the store) + Day 4 (consistency). **Sets up for:** Day 7 (cache + queue together).

Theory: `../../content/day06.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read the Facebook memcache entry in
`../../content/day06.md` (Real-world) and `reference/real-world-case-studies.md`
(Day 6). Extract: leases kill the thundering herd (one recompute, not thousands);
invalidation is the hard, first-class problem. **Write your takeaway** into
`reference/real-world-case-studies.md`.

**Beat 2 — Design core (~50m).** Run `reference/design-method.md` in order on
"add caching to the redirect path":
1. **Requirements** — redirect reads dominate (10:1); URL mapping rarely changes;
   click counts are write-heavy but loss-tolerant.
2. **Constraints** — Redis as the shared cache; cache is derived/disposable, DB
   is truth.
3. **Top-3 NFRs** — likely latency, scalability (DB load relief), consistency-
   where-it-matters. Targets each.
4. **Options (≥2)** — cache-aside, read-through, write-through, write-back — chosen
   **per data type** (mapping vs counts). (See the table in `content/day06.md`.)
5. **Tradeoff table** — patterns × read latency / write latency / freshness /
   failure exposure.
6. **Decision** — one sentence: *why this over the runner-up.*
7. **How it breaks** — red-team **mass key expiry after a deploy** (avalanche) and
   a **hot-key stampede**.
Write the design to `design/`. Write **one ADR** to `adr/` using
`reference/adr-template.md` — suggested **ADR 0006** (caching strategy + TTL/
invalidation). You write the ADR; numbers are global.

**Beat 3 — Hands-on lab (~55m).** Follow `lab/README.md`:
- Run the `cacheapp` service (cache-aside over Redis + Postgres).
- Measure p95 **without** cache vs **with** cache, and the hit ratio (`/stats`).
- **Break-it (core):** bust the hot key and blast it with `k6/stampede.js` →
  watch `dbQueries` explode (the herd).
- **Fix:** restart with `SINGLEFLIGHT=on`, repeat → `dbQueries` ≈ 1.
- **Learner TODO:** implement negative caching for penetration.
Record before/after in `lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 6 — Caching strategies
Key concept in my own words: …
When would I NOT use this: … (write-heavy / strongly-consistent data)
Break-it — what I broke and how I diagnosed it: … (hot-key stampede -> dbQueries spike)
Biggest surprise / open question: …
```
Then **teardown:** `cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (pattern per data type)
- [ ] `diagrams/` — cache-aside flow / placement diagram (`.mmd`)
- [ ] `adr/0006-*.md` — cache-aside vs write-through + TTL/invalidation policy
- [ ] `lab/results.md` — hit ratio, p95 with/without cache, stampede before/after
- [ ] `journal.md` entry appended
- [ ] stack torn down (`down -v`)
