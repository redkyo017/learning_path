# Interview rep — Phase 2 (Day 11, 45 min, timed)

**Problem 2 — Resilient notification / payment system.**
Full statement, graduated hints, and a solution sketch are in
`reference/interview-problems.md` → **Problem 2**.

> Design a system that charges a user and sends a confirmation, correctly under
> retries, dependency failures, and partial outages.

## How to run this rep

1. **Set a 45-minute timer. Try it fully before reading anything.** The hints and
   the solution sketch live in the bank — do **not** peek until you've produced
   your own design end-to-end. Peeking first turns a diagnostic into a lecture.
2. Work `reference/design-method.md` **in order**: requirements + scale →
   constraints → top-3 NFRs → ≥2 options → tradeoff table → decision (one-sentence
   why) → how-it-breaks (red-team). Whiteboard or markdown.
3. Produce, at minimum:
   - a **C2 container diagram** (charge service, provider, outbox, queue,
     notification consumer, stores),
   - the **exactly-once-charge** mechanism (idempotency key stored in the same tx),
   - the **ambiguous-timeout reconciliation** story,
   - the **charge↔notify decoupling** (transactional outbox → queue → idempotent
     consumer),
   - the **SLIs/SLOs** (charge success rate, charge p99, notification lag) — tie
     this to today's observability work,
   - a **red-team**: provider down, notification service down, duplicate delivery.
4. This rep folds in Days 8–11: idempotency/retries (8), breakers/bulkheads (9),
   blast radius (10), and today's SLIs/error budgets (11). Explicitly name where
   each shows up.

## Self-grade (score /10) — from `reference/interview-problems.md`

- Requirements + scale numbers stated (2)
- Named top-3 NFRs and designed to them (2)
- ≥2 options compared, not one (1)
- A capacity estimate that drove a decision (1)
- Data model + storage choice justified (1)
- Failure modes / red-team pass (2)
- One clear "why this over the alternative" per key decision (1)

Grade yourself on **whether you ran the method and defended tradeoffs**, not on
matching the sketch word-for-word. Then open the Problem-2 solution sketch and
diff it against yours — log any gap you couldn't answer into `BACKLOG.md`.

Save your worked answer alongside this file (e.g. `interview-rep-answer.md`) or in
`design/`.
