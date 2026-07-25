### Day 11 — Observability-as-design (SLI/SLO, tracing, metrics)

**Teardown target:** Google SRE book (SLOs & error budgets) + OpenTelemetry.
**Design brief:** make the multi-service lab stack observable *by design*.
**ADR topic:** the 3–5 SLIs and their SLO targets + error-budget policy.
**Lab:** add OTel tracing + Prometheus metrics + correlation IDs; read an end-to-end trace; find an injected fault from telemetry alone.
**When NOT this:** 100% trace sampling on a high-RPS prod path (sample intelligently); vanity metrics without an SLO are noise.
**Builds on:** Days 8–10 (the resilient services you now instrument). **Sets up for:** every later design states its SLIs; Day 17 rollback triggers on these SLOs.

> Theory: `content/day11.md`. Lab: `lab/`. This is also a **Phase-2 interview-rep
> day** — see `interview-rep.md` (45-min timed) after the lab.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day11.md` and the Day 11 entry
in `reference/real-world-case-studies.md`. Extract, one line each: what an **error
budget** lets a team *do*, and why **observability ≠ monitoring**. Log takeaways.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on:
*make the shortener (or the A→B stack) observable by design.*
1. **Requirements:** operators must localize a slow/failing request across
   services; product must know the reliability the users get.
2. **Constraints:** telemetry budget (cardinality/storage), existing Go + Docker
   stack, on-call team size.
3. **Top-3 NFRs:** observability, operability, cost (cardinality is the tension).
4. **Options:** metrics-only vs metrics+traces vs full three-pillars; head vs tail
   sampling; alert-on-threshold vs alert-on-SLO-burn.
5. **Tradeoffs:** table them (see `content/day11.md`).
6. **Decision:** RED metrics on 100% of traffic + propagated (sampled) traces +
   correlation IDs; alert on SLO burn. One-sentence why.
7. **Red-team:** *an SLO you can't actually measure with current instrumentation.*
   For each proposed SLI, prove you can compute it from what you emit.

Define **3–5 SLIs with SLO targets + an error-budget policy** (availability, p99
latency, error rate; maybe notification lag). Write the design to `design/`.
Write **one ADR** to `adr/` — suggested **ADR 0011** (`reference/adr-template.md`):
*"Adopt these SLIs/SLOs and an error-budget policy; RED + OTel traces; alert on
burn rate."* (ADR numbers are global — use the next free number.)

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Bring up `--profile obs`
(Jaeger + Prometheus), run the instrumented `svc/` as A and B, read the
end-to-end trace, measure p95 in Prometheus, then **inject a Toxiproxy latency
into B and locate it from the trace/metrics alone**. Record in `lab/results.md`.

**Beat 4 — Journal + teardown (~10m).** `docker compose --profile obs --profile
fault down -v`. Append a `journal.md` entry (key concept, "when NOT 100%
sampling", what you broke and how the trace localized it, biggest surprise).

**▶ Phase-2 interview rep (45m, timed).** After the lab, do `interview-rep.md`
(Problem 2 — resilient notification/payment system). Self-grade.

---

**Outputs checklist:**
- [ ] `design/` — SLI/SLO definitions + error-budget policy (7-step design)
- [ ] `diagrams/` — a C2/sequence `.mmd` showing trace-context flow across services
- [ ] `adr/NNNN-*.md` — the SLI/SLO + observability-approach ADR (suggested 0011)
- [ ] `lab/results.md` — trace read + p95 + the injected-fault diagnosis
- [ ] `interview-rep.md` completed + self-graded
- [ ] `journal.md` entry appended
