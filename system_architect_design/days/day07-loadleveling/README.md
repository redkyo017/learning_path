### Day 7 — Load balancing, queuing & load-leveling, backpressure

**Teardown target:** AWS "Queue-Based Load Leveling" pattern + rate-limiter designs
(token bucket; Cloudflare/Stripe; AWS Builders' Library "Using load shedding").
**Design brief:** protect a write path from a 10× traffic spike.
**ADR topic:** synchronous write vs queue-buffered write; bounded vs unbounded queue
+ overflow policy (429 vs shed vs block).
**Lab:** k6-spike a sync service (watch it fall over) → add a queue + worker (watch
it absorb) → add a bound (watch it shed with 429).
**When NOT this:** queuing a request that needs a synchronous answer (a payment
authorization) — you turn a latency problem into a correctness/UX problem. Also:
don't queue before a single instance is saturated.
**Builds on:** Days 2–6 (estimation, storage, replication, sharding, caching).
**Sets up for:** Phase 2 resilience (Days 8–11).

Theory: `content/day07.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day07.md` §Real-world +
`reference/real-world-case-studies.md` (Day 7). Extract: in the AWS queue-based
load-leveling pattern, *why* does the queue let you provision the consumer for
average rather than peak — and what new failure mode did you just buy (unbounded
depth, poison messages, stuck consumers)? Log a one-line takeaway.

**Beat 2 — Design core (~50m).** Run `reference/design-method.md` in order for
"protect a write path from a 10× spike":
1. **Requirements** — the write, its normal rate, the spike shape (e.g. 300→3000
   req/s for 30s), whether the caller needs an immediate answer.
2. **Constraints** — the downstream ceiling (μ), memory budget, latency SLA.
3. **Top-3 NFRs** — availability under spike, latency of the ingress tier, cost.
4. **Options** — (A) synchronous write scaled for peak; (B) queue + workers +
   202; (C) queue + workers + **bound** + 429 backpressure.
5. **Tradeoffs** — table vs the top-3 NFRs (use `content/day07.md`'s table).
6. **Decision** — one sentence: why queue-buffered-and-bounded over sync-scaled.
7. **How it breaks (self-red-team)** — unbounded queue → OOM / latency→∞; retries
   stacking on a full queue → λ doubles; timeouts shorter than max queue wait →
   wasted work; poison message stalls a worker.
Write the design to `design/`. Write **ADR `0007`** (suggested number — confirm the
next global number in `days/*/adr/`) on queue bound + overflow policy, using
`reference/adr-template.md`. Sketch a C2 container diagram in `diagrams/`.

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Build→measure→**break**:
- Stage A: k6 spike the shared sync `echo /work?ms=50` → record p95/error blowup.
- Stage B: run the `queue` service (enqueue→202, worker drains at fixed rate) →
  re-run the spike → ingress p95 stays flat, watch queue depth absorb the burst.
- Stage C (**break-it**): run unbounded (`QUEUE_MAX=0`) under sustained overload →
  watch depth grow without limit; then set a bound → observe graceful 429 shedding.

**Beat 4 — Journal (~10m).** Append to `../../journal.md` (key concept in your own
words; "when NOT a queue"; what you broke + how you diagnosed it; biggest
surprise). Then **teardown**: `cd labs && docker compose down -v`.

**▶ Phase 1 interview rep (45m, timed).** See `interview-rep.md` — *Design a URL
shortener with a rate limiter*, method in order, produce a C2 + capacity estimate,
self-grade. Try fully before reading the solution in the bank.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (spike-protected write path)
- [ ] `diagrams/` — at least one C4 diagram (`.mmd`) — the queue + workers topology
- [ ] `adr/NNNN-*.md` — ADR on queue bound + overflow policy (suggested `0007`)
- [ ] `lab/results.md` — before/after p95, queue depth over time, what broke + fix
- [ ] `interview-rep.md` completed + self-graded
- [ ] `journal.md` entry appended, stack torn down
