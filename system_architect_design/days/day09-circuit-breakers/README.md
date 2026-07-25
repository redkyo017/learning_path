### Day 9 — Circuit breakers, bulkheads, graceful degradation

**Teardown target:** Netflix Hystrix + the bulkhead pattern (and the contrarian
AWS "Avoiding fallback in distributed systems").
**Design brief:** protect service A from a failing dependency B.
**ADR topic:** breaker thresholds (error %, min volume, sleep window, half-open
probes) + the fallback behavior.
**Lab:** inject latency/failure into B with Toxiproxy → watch A's pool exhaust and
cascade → add a `sony/gobreaker` breaker + timeout + bulkhead + cached fallback →
watch A stay responsive with degraded results.
**When NOT this:** a breaker on a call with no safe fallback (fraud-check, the
actual charge) — you just fail faster; a breaker without a timeout (blind).
**Builds on:** Day 8 (timeouts/retries). **Sets up for:** Day 10 blast-radius / cells.

Theory: `content/day09.md`. Lab: `lab/`.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day09.md` §Real-world +
`reference/real-world-case-studies.md` (Day 9). Extract: from Hystrix, why is the
**bulkhead** (per-dependency pool) as important as the breaker itself? From the AWS
"Avoiding fallback" article, why can a fallback be *dangerous* (untested path that
fails in the same outage)? Log a one-liner.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order for A→B:
1. **Requirements** — A must stay responsive when B degrades; define B's normal
   error rate + p99 and A's pool size + λ.
2. **Constraints** — finite connection/goroutine pool; is there a safe degraded
   answer for B's data?
3. **Top-3 NFRs** — availability (A survives B), latency (bounded tail), operability.
4. **Options** — timeout-only vs timeout+breaker vs timeout+breaker+bulkhead+fallback.
5. **Tradeoffs** — breaker-knob table + fallback-options table from the content.
6. **Decision** — one sentence: the full stack over timeout-only, and why.
7. **How it breaks (self-red-team)** — the half-open probe stampede; a fallback
   that itself calls a down service; a shared pool defeating the bulkhead.
Write the design to `design/`. Write **ADR `0009`** (suggested — confirm next free
number) on breaker thresholds + fallback. Draw the breaker state machine and/or the
A→(bulkhead→breaker→B / fallback) flow in `diagrams/`.

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Build→measure→**break**:
- Two echo services A→B; put B behind Toxiproxy; add a +3000ms latency toxic.
- Drive load at A with a small pool → observe A's pool exhaust and A's latency
  collapse (the cascade). Record before p95 + error rate.
- Wrap A's B-client in the `gateway` service: `gobreaker` + per-call timeout +
  bulkhead (semaphore) + cached fallback. Re-run → A stays responsive, serves
  degraded results. Record after p95 + error rate.
- **Break-it (also core):** flap B up/down (add/remove the toxic) and watch the
  breaker transition open → half-open → closed via `/state`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md` (key concept; when NOT a
breaker; what you broke + how you diagnosed it; surprise). Then **teardown**:
`cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (A protected from B)
- [ ] `diagrams/` — breaker state machine and/or the protected-call flow (`.mmd`)
- [ ] `adr/NNNN-*.md` — ADR on breaker thresholds + fallback (suggested `0009`)
- [ ] `lab/results.md` — before/after p95 + error rate, breaker state transitions
- [ ] `journal.md` entry appended, stack torn down
