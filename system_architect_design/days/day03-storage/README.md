# Day 3 — Storage selection (SQL / NoSQL / NewSQL, access patterns, indexing)

**Teardown target:** Uber's storage evolution (MySQL → Schemaless) + DynamoDB
single-table design.
**Design brief:** choose storage for the shortener lookup **and** a social feed's data.
**ADR topic:** Postgres vs a KV store for the read-heavy lookup path.
**Lab:** run the same access pattern on Postgres (indexed) vs Redis-as-KV; measure both.
**When NOT this:** reaching for NoSQL for relational data with ad-hoc/evolving queries
— you'll rebuild joins in the app layer. NoSQL wins on *known* access patterns at scale.
**Builds on:** Day 2 sizing (270 TB → shard; 60k reads/s → hot lookup). **Sets up for:**
Day 4 replicates the store you choose here.

Theory: `content/day03.md`. Method: `reference/design-method.md`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day03.md` (access-pattern-driven
modeling, B-tree vs LSM, indexing costs, single-table design). Extract: *why* Uber
built Schemaless on MySQL, and *why* DynamoDB single-table forbids joins. Log takeaways
on the Day-3 entries (Uber Schemaless; DynamoDB single-table) in
`reference/real-world-case-studies.md`.

**Beat 2 — Design core (~60m).** Run the method → `design/storage.md`:
1. **Query list first.** Write the shortener's access patterns with frequencies
   (Q1 `code→URL` ~60k/s; Q2 create ~6k/s; Q3 "my URLs"; Q4 "codes created today")
   and the feed's ("load my timeline", "post").
2. **Model the feed both ways:** normalized SQL (users/follows/posts + join at read)
   vs denormalized KV/wide-column (fan-out on write). Give read cost + write cost of each.
3. **Top-3 NFRs** for the lookup path (suggested: latency, scalability, durability).
4. **Options + tradeoff table** on read latency, write amplification, query
   flexibility, operational cost (see the table in `content/day03.md`).
5. **Decision:** Postgres-as-record + Redis-as-cache for the lookup; the feed's
   push/pull choice. One-sentence why each.
6. **How it breaks (red-team):** name a **new query the chosen model can't serve
   cheaply** (e.g. an ad-hoc cross-partition scan) and what you'd do about it.

**Beat 3 — Hands-on lab (~50m).** See `lab/README.md`. Bring up shared `labs/`
Postgres + Redis. Seed **1M** `code→URL` rows into Postgres (indexed) with the provided
SQL, mirror them into Redis with the provided loader, then run the provided Go
benchmark hitting random keys against each. Record p50/p95 per store in `lab/results.md`.
**Break-it:** run a **range query** ("all codes created today") — trivial + fast on the
indexed Postgres column, but on Redis it forces a full `SCAN` (no secondary index).
Feel the missing-index pain and note which workload each store wins.

**Beat 4 — Journal (~10m) + teardown.** Append to `../../journal.md`. Then
**`cd labs && docker compose down -v`**.

---

**Suggested ADR number:** `0003` — Postgres vs KV for the lookup path, decided with the
lab's measured numbers. (You write it; numbers are global. See `adr/` stub.)

**Outputs checklist:**
- [ ] `design/storage.md` — query list, feed modeled both ways, tradeoff table, red-team
- [ ] `diagrams/` — (optional) a C2 showing store-per-path + a data-model sketch
- [ ] `adr/0003-*.md` — the storage ADR citing the lab's p50/p95 numbers
- [ ] `lab/results.md` — Postgres vs Redis p50/p95 + the range-query break-it
- [ ] `../../journal.md` entry appended
- [ ] teardown done (`docker compose down -v`)
