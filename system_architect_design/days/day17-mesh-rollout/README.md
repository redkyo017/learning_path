### Day 17 — Service mesh + deployment / rollout architecture

**Teardown target:** Istio + progressive delivery (canary / blue-green, feature flags)
**Design brief:** safely roll out v2 of the Orders service
**ADR topic:** blue-green vs canary vs rolling; the automated rollback trigger
**Lab:** weighted/canary routing — shift 10% to v2, watch metrics, promote or roll back; make v2 fail health checks mid-canary
**When NOT this:** a full service mesh for 3 services — the sidecar/ops complexity isn't justified until you have many services and real cross-cutting needs
**Builds on:** Days 12–16 (the services being rolled out) + Day 11 (the SLIs the rollback triggers on)  **Sets up for:** the capstone

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day17.md` and
`reference/real-world-case-studies.md` → Day 17. Extract: what does a mesh give
you *and at what cost*, and why does progressive delivery decouple deploy from
release? Log your takeaway and your "when NOT a mesh" line.

**Beat 2 — Design core (~50m).** Run `reference/design-method.md` for the v1→v2
rollout:
1. **Requirements** — ship Orders v2 with a bounded blast radius and a fast, ideally
   automatic, rollback.
2. **Constraints** — you have the Day-11 SLIs (availability, p99, error rate); a
   small canary footprint; the change *may* include a schema touch.
3. **Top-3 NFRs** — availability (limit blast radius), observability (must measure
   v2 vs v1 per-version), operability (rollback must be cheap/automatic).
4. **Options** — rolling vs blue-green vs canary (weighted).
5. **Tradeoff table** vs the top-3 (+ cost, rollback speed).
6. **Decision** — one sentence: why canary over the runner-up here.
7. **How it breaks (red-team)** — the canary that looks healthy but **corrupts
   data** (schema mismatch); session affinity skewing the split; an absolute-vs-
   relative rollback threshold masking a bad v2.
Write to `design/` + one ADR to `adr/`. Suggested ADR number (global sequence —
adjust to your real count; ~one/day puts you near here): **0018** "Canary rollout
with automated SLO-burn rollback".

**Beat 3 — Hands-on lab (~60m).** Do `lab/README.md`: run orders-v1 + orders-v2
behind Traefik with **weighted upstreams (90/10)**, drive traffic and confirm
~10% hits v2, watch v2's error rate, **promote to 100%**, then **simulate v2
errors and roll back**. **Break-it:** make v2 fail its health check mid-canary and
confirm the router serves 100% v1. Record the split + rollback in `lab/results.md`.
(AWS alternative: ALB weighted target groups — noted in the lab.)

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 17 — Service mesh + rollout
Key concept in my own words: …
When would I NOT use this: … (mesh for 3 services / canary for a correctness bug)
Break-it — what I broke and how I diagnosed it: … (v2 health fail → 100% v1)
Biggest surprise / open question: …
```
Then **teardown**: `docker compose -f lab/docker-compose.yml down -v` (and any AWS
resources if you did the ALB alternative).

**Also today (Phase-3 interview rep):** do `interview-rep.md` — a 45-minute timed
design of a ride-sharing dispatch **or** a news feed (Problem 3 in the interview
bank). Try it fully before reading the hints/solution.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (v1→v2 rollout)
- [ ] `diagrams/` — at least one C4/flow `.mmd` (router + weighted upstreams)
- [ ] `adr/NNNN-*.md` — at least one ADR (canary + automated rollback trigger)
- [ ] `lab/results.md` — traffic split, error-rate observation, rollback, health-fail behavior
- [ ] `interview-rep.md` attempted + self-graded
- [ ] `journal.md` entry appended
- [ ] stack torn down (`down -v`)
