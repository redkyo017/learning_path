# Interview Problem Bank — with hints & solution sketches

Timed system-design problems (the **B facet**). Do each in 45 minutes using
`reference/design-method.md` in order. **Try it fully before reading the
solution.** Hints are graduated — peek at one at a time. Solution sketches show
*one* good answer, not the only one; grade yourself on whether you ran the method
and defended tradeoffs, not on matching word-for-word.

**Self-grading rubric (score /10):**
- Requirements + scale numbers stated (2)
- Named top-3 NFRs and designed to them (2)
- ≥2 options compared, not one (1)
- A capacity estimate that drove a decision (1)
- Data model + storage choice justified (1)
- Failure modes / red-team pass (2)
- One clear "why this over the alternative" per key decision (1)

---

## Problem 1 — URL shortener + rate limiter  (Phase 1 rep, Day 7)

Design a service that shortens URLs and redirects, with per-client rate limiting.

<details><summary>Hint 1 — scope</summary>
Core: create short code, redirect, analytics (clicks). Rate-limit the create
path per API key. Out of scope: custom domains, user accounts UI.
</details>
<details><summary>Hint 2 — the pressure point</summary>
It's read-heavy (~10:1). Redirects must be fast (p99 < 50ms) and highly
available. Writes are modest — that asymmetry drives the design.
</details>
<details><summary>Hint 3 — ID generation</summary>
Options: base62 of an auto-increment counter (short, sequential → guessable,
needs a distributed counter), hash of URL + collision check, or a
key-generation service (pre-generate keys). Discuss tradeoffs.
</details>

<details><summary>Solution sketch</summary>

**Requirements/scale:** 100M creates/day → ~1.2k writes/s avg, ~6k peak; 10:1
reads → ~60k reads/s peak. 5-yr storage ≈ tens of TB → shard.

**Top-3 NFRs:** availability (redirects), latency (redirect p99), scalability (reads).

**Design:**
- **Write path:** API service → generate ID → store `code → {url, owner, created}`
  in a sharded KV / relational store (partition by code). Emit a click-topic
  later, not here.
- **ID:** base62 of a globally-unique counter from a **key-generation service**
  (pre-allocates ranges to each app server → no per-write coordination). 7 base62
  chars = 62^7 ≈ 3.5T codes.
- **Read path:** `code → URL` is the hottest lookup → **cache-aside in Redis**
  with long TTL + CDN/edge for the 301/302. DB is fallback.
- **Rate limiter:** token bucket per API key in Redis (atomic Lua: refill +
  decrement). Return 429 + `Retry-After` when empty. Sliding-window-log if you
  need precision over burst tolerance.

**Redirect choice:** 302 (temporary) so you keep serving analytics on every
click; 301 caches in the browser and skips your server (faster but no analytics).
ADR-worthy.

**How it breaks:** hot code (celebrity link) → cache absorbs it; counter service
down → app servers still have pre-allocated ranges (graceful); cache stampede on
a hot key expiry → singleflight. 10× → reads scale via cache+replicas, writes via
more shards.

**When NOT this shape:** if creates were the bottleneck (not reads), you'd invert
toward write-optimized storage and async read-model building.
</details>

---

## Problem 2 — Resilient notification / payment system  (Phase 2 rep, Day 11)

Design a system that charges a user and sends a confirmation, correctly under
retries, dependency failures, and partial outages.

<details><summary>Hint 1</summary>
The charge must be exactly-once from the user's perspective. Notifications are
at-least-once (a duplicate email is annoying, not catastrophic) — different
correctness bars for different steps.
</details>
<details><summary>Hint 2</summary>
The payment provider is an external dependency that can time out ambiguously
(did the charge go through?). Idempotency keys + status reconciliation solve this.
</details>
<details><summary>Hint 3</summary>
Decouple "charge" from "notify" with an event/queue so a notification outage
never blocks or reverses a payment.
</details>

<details><summary>Solution sketch</summary>

**Top-3 NFRs:** reliability/correctness (no double-charge), availability, observability.

**Design:**
- **Charge service:** client sends `Idempotency-Key`. Store `(key → charge
  result)` in the same DB transaction as the local charge record. On retry,
  return the stored result. Call the provider with the same idempotency key so
  the provider dedupes too.
- **Ambiguous timeout:** if the provider call times out, DO NOT retry blindly —
  reconcile by querying the provider for that idempotency key, or mark `pending`
  and let a reconciliation job resolve it.
- **Notify path:** on successful charge, write a `PaymentSucceeded` event via the
  **transactional outbox** (same tx as the charge) → relay to Kafka → notification
  consumer sends email/SMS. Consumer is idempotent (dedup on event id).
- **Resilience:** timeouts + backoff-with-jitter on the provider; circuit breaker
  with a "pending, will retry" fallback; bulkhead the provider client pool.
- **Observability:** SLIs = charge success rate, charge p99, notification lag.
  SLOs with error budget; correlation id from request → event → email.

**How it breaks:** provider down → breaker opens, charges queue as `pending`,
reconcile later; notification service down → events buffer in Kafka, drain when
back (payments unaffected); duplicate delivery → idempotent consumer dedupes.

**When NOT this:** a low-stakes internal notification could skip the outbox and
accept best-effort — the machinery here is for money-grade correctness.
</details>

---

## Problem 3 — Ride-sharing dispatch OR news feed  (Phase 3 rep, Day 17)

Pick one. Design the core: (ride) match riders to nearby drivers and track trips;
(feed) generate a personalized timeline at scale.

<details><summary>Hint — ride</summary>
Geo-indexing (geohash / S2 / H3) for "drivers near me"; a dispatch service; a
trip state machine; high write rate of driver locations (async, lossy OK).
</details>
<details><summary>Hint — feed</summary>
The fan-out question: fan-out-on-write (push to followers' feeds — great for
reads, bad for celebrities) vs fan-out-on-read (pull at query time — bad tail
latency) vs hybrid (push for most, pull for celebrities).
</details>

<details><summary>Solution sketch — news feed (hybrid)</summary>

**Top-3 NFRs:** read latency (feed load p99), scalability (fan-out), availability.

**Design:**
- **Write (post):** store post; enqueue a fan-out job. For a normal user, push
  the post id into each follower's feed cache (Redis list, capped). For a
  **celebrity** (followers > threshold), skip push.
- **Read (load feed):** merge the user's precomputed feed (push) with a
  pull-on-read of the celebrities they follow. Rank, paginate.
- **Storage:** posts in a sharded store (by post id); feed cache in Redis; social
  graph in its own store. Events on Kafka for analytics/ranking.
- **Estimate:** 500M DAU, 2 feed loads/day → ~12k loads/s avg, big peaks →
  cache-first. Avg fan-out cost drives the push/pull threshold.

**Why hybrid:** pure push dies on celebrities (one post = millions of writes);
pure pull dies on tail latency (merge hundreds of followees per read). Hybrid
pays each cost where it's cheap. **This tradeoff is the whole problem.**

**How it breaks:** celebrity posts → pull path + heavy caching; feed cache cold →
rebuild from posts store (slower, degraded); ranking service down → serve
reverse-chron fallback.
</details>

---

## Problem 4 — Capstone-grade (Day 21 options)

Full end-to-end. Pick one and produce the complete package (C4, ADRs, estimate,
red-team, tradeoff table):
- **Global ride-hailing platform** (geo, dispatch, payments, surge, multi-region).
- **Real-time collaborative editor** (OT/CRDT, presence, conflict resolution, WS fan-out).
- **LLM-powered support platform** (RAG over docs, agent actions, guardrails,
  human handoff, eval) — integrates Days 18–19.

<details><summary>Hint — how to be graded at capstone level</summary>
Depth over breadth: pick 3 subsystems and go deep (data model, consistency,
failure modes, numbers) rather than naming 12 boxes shallowly. Every major box
gets an ADR with a rejected alternative. Your red-team must cover: 10× load, a
region loss, a dependency outage, a bad deploy, a hot partition.
</details>

<details><summary>Solution approach (not a full answer — it's your capstone)</summary>
Run the method top to bottom (see `days/day21-capstone/README.md`). The
"solution" is your defended package + the mock review where you answer "why not
the alternative?" for each ADR. Log every question you couldn't answer into
`BACKLOG.md`.
</details>

---

## More reps (for `BACKLOG.md` — do 1–2/week to stay sharp)

Design, with the same rubric (solution sketches: try first, then compare to the
patterns you learned — each maps to specific days):
1. **A distributed rate limiter** (Day 7 + distributed token bucket).
2. **A chat/messaging system** (Day 5 sharding + Day 14 events + presence).
3. **A metrics/monitoring system** (Day 3 time-series + Day 7 ingestion buffering).
4. **A payment ledger** (Day 15 event sourcing + Day 8 idempotency).
5. **A multi-region key-value store** (Day 4 consistency + Day 10 cells).
6. **An e-commerce checkout** (Day 16 saga + Day 8 idempotency + Day 6 caching).
7. **A video-streaming platform** (CDN/edge + Day 6 caching + Day 3 storage).
8. **A search autocomplete** (Day 3 indexing + Day 6 caching + Day 2 estimation).

For each, the "solution" is: which patterns from which days apply, and why. If
you can map a new problem to the patterns you've drilled, the method is working.
</details>
