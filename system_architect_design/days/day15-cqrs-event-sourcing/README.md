### Day 15 — CQRS / event sourcing

**Teardown target:** event-sourcing case studies (ledgers / audit-heavy domains) + explicit "when NOT" writeups (Fowler, Greg Young).
**Design brief:** event-source the Orders aggregate; build a separate read projection.
**ADR topic:** event sourcing vs CRUD for Orders; snapshotting policy.
**Lab:** append events to Postgres (append-only), fold to rebuild state, project a read model; then fix a projection bug and replay to correct the read models.
**When NOT this:** a simple CRUD domain — you pay versioning/projection/replay complexity for no benefit. Reserve for audit/temporal needs.
**Builds on:** Day 14 log. **Sets up for:** Day 16 outbox/saga on the same store.

Theory: `content/day15.md`. Method: `reference/design-method.md`. ADR format: `reference/adr-template.md`.
Shared stack: `labs/README.md` (this day uses the `postgres` service).

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day15.md` §Real-world +
`reference/real-world-case-studies.md` Day 15. Extract: *why* is a double-entry
ledger "already event-sourced," and what's the single most repeated practitioner
caution about event sourcing? Log both takeaways.

**Beat 2 — Design core (~50m).** Run `reference/design-method.md` on the Orders
aggregate:
1. **Requirements** — commands PlaceOrder/PayOrder/ShipOrder/CancelOrder; query
   "current status + total"; a full audit trail of how each order reached its state.
2. **Constraints** — single Postgres; small team; must support fixing read-model
   bugs safely.
3. **Top-3 NFRs** — e.g. auditability/evolvability, consistency (accept eventual on
   reads?), operability. Justify.
4. **Options** — CRUD vs CQRS-without-ES vs event-sourcing (+CQRS). Generate ≥2.
5. **Tradeoff table** — options × {history, read/write scaling, complexity, staleness}.
6. **Decision** — choose, one-sentence why over the runner-up; state a snapshot policy.
7. **How it breaks** — projection lags (stale reads); a non-deterministic fold; a
   read-model bug (which you fix by replay in the lab).
Write to `design/`. Write **ADR `0015`** (suggested) on event-sourcing-vs-CRUD for
Orders + snapshotting. Draw the C2 (command → event store → projections → query) in
`diagrams/`.

**Beat 3 — Hands-on lab (~60m).** `lab/README.md` — append Order events to an
append-only Postgres table, fold to rebuild an order's state, project
`order_status_view`, prove replay reconstructs identical state; then **fix the
seeded projection bug and replay** to correct every read model. Record in
`lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md` (template in
`templates/day-template.md`). **Teardown:** `cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (ES vs CRUD, snapshot policy)
- [ ] `diagrams/` — at least one C2 `.mmd` (command → event store → projection → query)
- [ ] `adr/0015-*.md` — event-sourcing-vs-CRUD + snapshotting ADR
- [ ] `lab/results.md` — replay reconstructs state; projection bug fixed by replay
- [ ] `journal.md` entry appended; docker stack torn down

**Suggested ADR number:** `0015` (confirm the next free global number).
