# Day 2 — Back-of-envelope estimation & workload characterization

**Teardown target:** Jeff Dean, "Numbers Everyone Should Know" (Google) — the latency
table that anchors all capacity reasoning.
**Design brief:** size a URL shortener at **100M new URLs/day, 10:1 read:write**.
**ADR topic:** the chosen ID scheme (base62 counter vs hash-of-URL vs
key-generation service) and why — grounded in the numbers.
**Lab:** estimate write/read QPS, storage, bandwidth, and cache working set, then
**validate observed throughput with k6** against a real service.
**When NOT this:** premature capacity math for a product with no users — estimate to
the order of magnitude that changes the design, not to 3 significant figures.
**Builds on:** the Day-1 method. **Sets up for:** every later design now leads with
numbers (Day 3 sizing → shard/cache decisions).

Theory: `content/day02.md`. Cheatsheet: `reference/estimation-cheatsheet.md`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day02.md` and skim
`reference/estimation-cheatsheet.md`. Extract: the `daily / 10^5` shortcut,
peak-vs-average multipliers, Little's Law (`L = λ × W`) for concurrency, and the
working-set/cache rule. Log a takeaway on the Jeff Dean entry in
`reference/real-world-case-studies.md` (memory ≫ SSD ≫ disk ≫ cross-continent RT).

**Beat 2 — Design core (~60m).** Run the method on the shortener → `design/sizing.md`:
1. **Requirements/scale:** 100M creates/day, 10:1 reads. State assumptions
   (payload ≈ 500 B logical, ~1 KB on disk with indexes; RF 3; 5-yr retention).
2. **Constraints:** redirect p99 target, availability target, budget posture.
3. **Top-3 NFRs:** (suggested) availability + latency + scalability for the read path.
4. **Compute:** write QPS avg (`~1.2k/s`) + peak (`×5 ≈ 6k/s`); read QPS peak
   (`×10 ≈ 60k/s`); 5-yr storage (`≈ 270 TB` at RF 3); read bandwidth (`≈ 30 MB/s`);
   cache working set (hot 20%). Translate **each** number into a decision.
5. **Options:** ≥2 ID-generation schemes with a tradeoff table (see `content/day02.md`).
6. **Decision:** pick the ID scheme; one-sentence why over the runner-up.
7. **How it breaks:** what breaks at **10×**? (Which number crosses a threshold first?)
   Name your riskiest assumption — the one that, wrong by 10×, changes the design.

**Beat 3 — Hands-on lab (~50m).** See `lab/README.md`. Bring up the shared
`labs/` Postgres, run the provided `shortener` Go service (`POST /shorten`,
`GET /r/{code}`), then drive your **estimated peak write QPS** with the provided
`lab/k6/shorten.js` for 60s. Record achieved RPS + p95 in `lab/results.md`.
**Break-it:** ramp VUs until p95 blows past your latency budget; find the single-instance
RPS ceiling and compare it to your estimate — *was the estimate right?*

**Beat 4 — Journal (~10m) + teardown.** Append to `../../journal.md` (template in
`templates/day-template.md`). Then **`cd labs && docker compose down -v`**.

---

**Suggested ADR number:** `0002` — the ID scheme decision. (You write it; numbers are
global. See `adr/` stub.)

**Outputs checklist:**
- [ ] `design/sizing.md` — the full estimate, each number → a decision, + 10× red-team
- [ ] `adr/0002-*.md` — the ID-scheme ADR with rejected alternatives
- [ ] `lab/results.md` — estimated vs achieved RPS, p95, the observed ceiling
- [ ] `../../journal.md` entry appended
- [ ] teardown done (`docker compose down -v`)
