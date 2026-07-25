### Day 14 — Event-driven architecture & the log as source of truth

**Teardown target:** Kleppmann "Turning the Database Inside Out" + LinkedIn's log (Jay Kreps).
**Design brief:** make Orders emit domain events consumed independently by Inventory & Analytics.
**ADR topic:** event notification vs event-carried state transfer; topic key + partition design.
**Lab (Kafka):** produce keyed `OrderPlaced` events; two consumer groups each get all events; replay Analytics from earliest; poison message → dead-letter.
**When NOT this:** a request needing an immediate synchronous answer; where you actually need a transaction across consumers (→ saga, Day 16).
**Builds on:** Day 13. **Sets up for:** Days 15–16 (CQRS, outbox on this log).

Theory: `content/day14.md`. Method: `reference/design-method.md`. ADR format: `reference/adr-template.md`.
Shared stack: `labs/README.md` (this day uses the `kafka` service).

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day14.md` §Real-world +
`reference/real-world-case-studies.md` Day 14. Extract: *why* is N producers × M
consumers as direct calls O(N×M) glue, and how does a shared log make it O(N+M)?
What does "the log is the source of truth, everything else is a derived view" buy
you when a read model's schema changes? Log both takeaways.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` on the `orders`
topic:
1. **Requirements** — Orders announces `OrderPlaced`; Inventory decrements stock;
   Analytics counts; new consumers must be addable without touching Orders.
2. **Constraints** — single-broker lab Kafka; independent consumer deploys.
3. **Top-3 NFRs** — e.g. evolvability, availability (producer decoupled from
   consumers), scalability. Justify.
4. **Options** — notification vs ECST payload; key by order_id vs none; partition
   count. Generate ≥2 per axis.
5. **Tradeoff table** — payload style × {consumer autonomy, payload size, staleness}.
6. **Decision** — payload style, key, partition count, retention; one-sentence why each.
7. **How it breaks** — a poison message wedges a partition; a consumer commits
   before processing (data loss); retention too short to bootstrap a new consumer.
Write to `design/`. Write **ADR `0014`** (suggested) on notification-vs-ECST +
topic key/partition design. Draw the C2 (topic → two consumer groups) in `diagrams/`.

**Beat 3 — Hands-on lab (~55m).** `lab/README.md` — produce keyed events; run the
`inventory` and `analytics` groups and confirm both see every event; replay
Analytics from earliest; then send a poison message, watch the naive consumer stall
the partition, and enable the dead-letter path. Record in `lab/results.md`.

**Beat 4 — Journal (~10m).** Append to `../../journal.md` (template in
`templates/day-template.md`). **Teardown:** `cd labs && docker compose down -v`.

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (payload style, key, partitions, retention)
- [ ] `diagrams/` — at least one C2 `.mmd` (topic + two independent groups)
- [ ] `adr/0014-*.md` — notification-vs-ECST + topic/partition design ADR
- [ ] `lab/results.md` — fan-out proof + replay + poison-message stall & DLQ fix
- [ ] `journal.md` entry appended; docker stack town down

**Suggested ADR number:** `0014` (confirm the next free global number).
