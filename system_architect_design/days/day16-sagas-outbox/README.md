### Day 16 — Sagas, distributed transactions, the transactional outbox

**Teardown target:** the dual-write problem + the saga pattern (orchestration vs choreography) + transactional outbox / CDC (Debezium)
**Design brief:** Order → Payment → Inventory as a saga with compensations
**ADR topic:** orchestration vs choreography; transactional outbox for reliability
**Lab:** transactional outbox (Postgres + Kafka) — kill the relay, prove no lost events; add an idempotent consumer
**When NOT this:** a real ACID transaction fits (single DB) — a saga then trades away atomicity + isolation for complexity and eventual consistency
**Builds on:** Day 14 (event-driven, the log) + Day 15 (event-sourced Orders store)  **Sets up for:** Day 17 (safely rolling out these services)

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day16.md` and
`reference/real-world-case-studies.md` → Day 16. Extract: *why* is a DB-write +
broker-publish not atomic, and what does the outbox make one system derive from
the other? Log your one-line takeaway on the dual-write problem and on
orchestration-vs-choreography.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order for the
order saga:
1. **Requirements** — place an order that must reserve payment, reserve inventory,
   confirm; each step in a different service/store.
2. **Constraints** — no cross-service ACID tx; downstream must never miss an
   `OrderPlaced`; duplicates tolerable if deduped.
3. **Top-3 NFRs** — correctness/reliability (no lost/duplicated effects),
   availability (a slow participant must not block others), observability (where
   is a stuck saga?).
4. **Options** — (a) orchestrated saga + outbox; (b) choreographed saga + outbox;
   (c) direct publish, no outbox; (d) 2PC/XA.
5. **Tradeoff table** vs the top-3 NFRs (+ cost, complexity).
6. **Decision** — one sentence: why your choice over the runner-up.
7. **How it breaks** — a compensation that itself fails; a poison message; the
   orchestrator crashing mid-saga; a duplicate publish.
Write it to `design/` and one ADR to `adr/` (see `reference/adr-template.md`).
Suggested ADR numbers (global sequence — adjust to your actual count; if you've
written ~one/day you're near here): **0016** "Transactional outbox over direct
publish", optionally **0017** "Orchestrated saga over choreography".

**Beat 3 — Hands-on lab (~55m).** Do `lab/README.md`: build the outbox end-to-end,
then **break it** — kill the relay after the DB commit but before publish, restart,
and prove the event is still published exactly once (no lost event). Then force a
duplicate publish and watch the idempotent consumer dedupe it. Finally run the
`saga` demo and trigger a compensation. Record measurements in `lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md`:
```
### Day 16 — Sagas, distributed transactions, outbox
Key concept in my own words: …
When would I NOT use this: … (ACID fits / best-effort signal)
Break-it — what I broke and how I diagnosed it: … (killed relay, checked outbox row)
Biggest surprise / open question: …
```
Then **teardown**: `cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (order saga + failure paths)
- [ ] `diagrams/` — at least one C4/sequence `.mmd` (outbox flow or saga sequence)
- [ ] `adr/NNNN-*.md` — at least one ADR (outbox vs direct publish)
- [ ] `lab/results.md` — before/after, what broke (lost vs duplicate), the fix
- [ ] `journal.md` entry appended
- [ ] docker stack torn down (`down -v`)
