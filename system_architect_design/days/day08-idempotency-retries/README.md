### Day 8 — Timeouts, retries, idempotency, backoff + jitter

**Teardown target:** Stripe idempotency keys + AWS Builders' Library "Timeouts,
retries, and backoff with jitter."
**Design brief:** a payment/charge endpoint that stays correct under client retries.
**ADR topic:** idempotency-key storage + retention; the retry policy (attempts,
backoff, jitter, budget).
**Lab:** Go charge service with idempotency keys in Postgres; fire the same key
100× concurrently and prove exactly one charge; break it; then compare fixed vs
jittered backoff against a Toxiproxy-flaky downstream.
**When NOT this:** retrying a non-idempotent write without a key (double-charge);
retrying at multiple layers (amplification); retrying 4xx. Reconcile, don't blindly
retry, when the outcome is ambiguous.
**Builds on:** Phase 1 (Day 7 backpressure — 429s must trigger *backoff*).
**Sets up for:** Day 9 circuit breakers.

Theory: `content/day08.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day08.md` §Real-world +
`reference/real-world-case-studies.md` (Day 8). Extract: from the AWS jitter
article, *why* does plain exponential backoff still overload a recovering service,
and what exactly does full jitter change about the load *shape*? From Stripe: why
is the idempotency key **client-chosen** rather than a body hash? Log a one-liner.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order for the
charge flow:
1. **Requirements** — charge once per logical operation even under N retries;
   client sends `Idempotency-Key`; ambiguous-timeout handling.
2. **Constraints** — external provider that can time out ambiguously; Postgres.
3. **Top-3 NFRs** — correctness/reliability (no double-charge), availability,
   observability.
4. **Options** — key storage: same-DB-same-tx vs Redis-with-TTL vs provider-side.
5. **Tradeoffs** — table (atomicity, speed, retention, failure modes).
6. **Decision** — one sentence: why same-tx Postgres key over Redis.
7. **How it breaks (self-red-team)** — two concurrent requests, same key (race);
   crash between charge and key-store; TTL eviction mid-retry; retry storm.
Write the design to `design/`. Write **ADR `0008`** (suggested — confirm next free
number) on idempotency-key storage/retention + retry policy. Draw the idempotent
`/charge` sequence in `diagrams/`.

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Build→measure→**break**:
- Run the Go `/charge` service against Postgres (schema in `lab/sql/schema.sql`).
- Fire the **same** idempotency key 100× concurrently (`fire` client) → assert
  exactly one `charges` row.
- **Break-it:** run with `IDEMPOTENT=false` (drops the ON CONFLICT guard) → fire
  100× → observe up to 100 charge rows.
- Add backoff+jitter against a Toxiproxy-flaky downstream and compare fixed vs
  full-jitter retry behavior (completion time / provider load shape).

**Beat 4 — Journal (~10m).** Append to `../../journal.md` (key concept; when NOT to
retry; what you broke + how; surprise). Then **teardown**:
`cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (charge flow)
- [ ] `diagrams/` — the idempotent `/charge` sequence diagram (`.mmd`)
- [ ] `adr/NNNN-*.md` — ADR on key storage/retention + retry policy (suggested `0008`)
- [ ] `lab/results.md` — 1-vs-N charge counts, fixed-vs-jitter retry behavior
- [ ] `journal.md` entry appended, stack torn down
