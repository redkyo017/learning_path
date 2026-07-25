### Day 12 — Boundaries: microservices vs modular monolith & DDD strategic design

**Teardown target:** Segment's monolith→microservices→monolith + Amazon Prime Video's re-monolith.
**Design brief:** decide service boundaries for a mid-size domain (e-commerce).
**ADR topic:** modular monolith vs microservices for this team/scale.
**Lab:** in Go, split two concerns into bounded contexts talking only through an interface + DTOs, with a compile-time boundary test.
**When NOT this:** microservices before you understand the domain — you cement wrong boundaries into network calls (modular monolith first; extract when a seam proves real).
**Builds on:** Phases 1–2 (the resilient services you now decide how to carve). **Sets up for:** Days 13–17 — communication between the services you carve out.

> Theory: `content/day12.md`. Lab: `lab/` (context-map worksheet + a runnable Go
> boundary refactor). Design-heavy day — the thinking is the deliverable.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day12.md` and the Day 12
entries in `reference/real-world-case-studies.md`. Extract, one line each: *why*
Segment merged back and *why* Prime Video re-monolithed. Log takeaways.

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on the
brief, using `lab/context-map-worksheet.md`:
1. **Requirements:** the e-commerce capabilities (browse, cart, checkout, pay,
   fulfill, ship). Team size + growth stage.
2. **Constraints:** current team topology (Conway), existing stack, deadline.
3. **Top-3 NFRs:** evolvability, operability, team autonomy (cost is the tension).
4. **Options:** modular monolith vs extract-some-services vs full microservices.
5. **Tradeoffs:** table them (see `content/day12.md`).
6. **Decision:** choose; one-sentence why over the runner-up.
7. **Red-team:** *the boundary that will generate the most cross-service chatter*
   — name it and mitigate (keep in-process / batch / cache / event-fed read model).
Context-map the domain (bounded contexts, aggregate roots, sync vs async edges,
ACL where a vendor/legacy model must not leak). Write the design to `design/`.
Write **one ADR** to `adr/` — suggested **ADR 0012** (`reference/adr-template.md`):
*"Build a modular monolith with enforced internal boundaries; extract service X
only when <named seam condition> holds."* (ADR numbers are global — next free.)

**Beat 3 — Hands-on lab (~55m).** `lab/README.md`. Wire `orders` and `inventory`
so they communicate **only through a consumer-defined interface + DTOs**; run the
`go list -deps` boundary test; then do the two **break-it** experiments (a public
reach compiles; an `internal/` reach does not) and reason about how a network
boundary would differ. Record in `lab/results.md`.

**Beat 4 — Journal (~10m).** No docker/AWS to tear down today (pure Go). Append a
`journal.md` entry (key concept, "when NOT microservices", what the two break-it
experiments showed, biggest surprise).

---

**Outputs checklist:**
- [ ] `design/` — the context map + 7-step design (from `lab/context-map-worksheet.md`)
- [ ] `diagrams/` — a context-map / C2 `.mmd` (bounded contexts + sync/async edges)
- [ ] `adr/NNNN-*.md` — the monolith-vs-microservices ADR (suggested 0012)
- [ ] `lab/results.md` — build/test output, the boundary-test grep, break-it results
- [ ] `journal.md` entry appended
