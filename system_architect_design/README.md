# Software System Architecture Design — Mastery Workspace

A 21-day, self-contained, offline-first program to reach production-credible
competence in software system architecture design. You execute it yourself, one
day at a time. Everything you need to study and build is in this repo.

## How to use this repo

Each day has **four beats** (~2–3 hrs total):

1. **Teardown warm-up** (~20m) — read the day's real-world case study.
2. **Design core** (~60–75m) — design a system, **self-red-team** it, write an ADR.
3. **Hands-on lab** (~40–60m) — build → measure → **break** one concept.
4. **Journal** (~10m) — narrate what you learned as if teaching a junior.

**Daily flow:**
1. Read `content/dayNN.md` (the theory — your study material).
2. Open `days/dayNN-*/README.md` (the filled-in day plan) and work the steps.
3. Put your outputs in that day's folder: `design/`, `diagrams/`, `adr/`, `lab/`.
4. Append a `journal.md` entry.

## Map

| Phase | Days | Focus |
|-------|------|-------|
| 0 — The architect's operating system | 1 | Method, NFRs, C4, ADRs |
| 1 — Scale & data foundations | 2–7 | Estimation, storage, replication, sharding, caching, load-leveling |
| 2 — Resilience & failure | 8–11 | Idempotency, breakers, cells, observability |
| 3 — Modern distributed patterns | 12–17 | Boundaries/DDD, gRPC, events, CQRS, sagas, rollout |
| 4 — AI/LLM system design | 18–19 | RAG, agents, guardrails, eval |
| 5 — Integration & mastery | 20–21 | Security, cost, capstone + mock review |

## Directory guide

```
reference/   Read-once cheatsheets you reuse daily (the design method lives here)
templates/   The day-template you copy to add a new day
labs/        The shared docker-compose stack + reusable Go services + k6 scripts
content/     dayNN.md — the theory / study material for each day
days/         dayNN-*/ — your workspace per day (README + design/diagrams/adr/lab)
docs/         The spec and this plan
journal.md   One narrate-to-consolidate entry per day
BACKLOG.md   Future topics; pull from here to extend past Day 21
```

## The single most important habit

**Run the design method (in `reference/design-method.md`) every single day, in
order, even when the answer feels obvious.** The method is the skill. The topics
are just reps.

## How to extend (past Day 21, or insert a topic)

1. Pick a topic from `BACKLOG.md`.
2. `cp templates/day-template.md days/dayNN-<slug>/README.md` and fill it in.
3. Create `content/dayNN.md` for the theory (use the same structure as existing
   days).
4. Reuse `labs/` for the hands-on lab.
5. Tick the topic off `BACKLOG.md`.

Nothing is hardcoded to 21 days.

## Prerequisites

Docker 24+, `docker compose` v2, Go 1.22+, k6. Optional per specific days: `buf`
(Day 13), AWS CLI v2 (Days 10, 17), an LLM/embedding API (Days 18–19). See
`labs/README.md` to bring the stack up.

## Anchor references (for going deeper — not required to complete a day)

- *Designing Data-Intensive Applications* — Martin Kleppmann (the data/distributed core)
- *System Design Interview* vol 1 & 2 — Alex Xu (interview reps)
- *Building Microservices* — Sam Newman (boundaries & modern patterns)
- **AWS Builders' Library** (resilience, cell-based, retries/backoff) — free online
- *Site Reliability Engineering* — Google (observability, SLOs)
- Engineering blogs: Uber, Netflix, Discord, Shopify, Stripe, Segment
