# Software System Architecture Design Mastery Plan

**Date:** 2026-07-24
**Status:** Approved design

## Purpose

Reach production-credible competence in software system architecture design in
~21 days (2–3 hours/day, ~42–63 hours total), flexible to extend. The goal is not
a certificate or an interview pass alone — it is the ability to **design, review,
red-team, and defend real production systems** under load, failure, and changing
constraints, and to communicate those designs in artifacts an org can align on.

The learner's center of gravity is **real production distributed-systems
architecture (A)**. Three other facets are woven in as recurring beats rather than
separate tracks:

- **B — system-design interviews:** compact, timed reps of production design.
- **C — enterprise/solution architecture:** the artifacts (C4, ADRs, NFRs) that
  make a design communicable and governable.
- **D — software/code-level design:** the same reasoning one altitude lower (DDD
  boundaries, patterns, module design in the learner's Go code).

Learning interview problems (B) is treated as a *compression* of production design,
not a parallel skill; C and D are facets of the same reasoning at different
altitudes. This keeps A as the single spine.

## Learner context

- Background: Integration platform engineer. Strong builder who has built and
  operated real distributed systems and made design calls, but informally — no
  deliberate framework. Comfortable with services, messaging, and data flow;
  gaps in capacity estimation, consistency models, CAP/PACELC in practice, and
  formal tradeoff analysis. Baseline sits **between "strong builder, informal
  architect" and "solid fundamentals, gaps in the -ilities."**
- Existing strengths to leverage: AWS (networking, compute, load balancing),
  Kafka / event-driven multi-service infrastructure, Go, and Bedrock AgentCore
  (AI/agent) work. The plan deliberately builds on these — especially Kafka for
  the event-driven/log-as-source-of-truth days and Bedrock for the AI/LLM days.
- Motivation: Turn existing intuition into **defensible, repeatable** architecture
  judgment. Close the A→B gap by installing an explicit method plus quantitative
  and failure-mode reasoning on top of existing instinct.
- Time: ~2–3 hrs/day, ~21 days, flexible calendar and extendable. Spacing is
  intentional — architecture reasoning consolidates through spaced reps, not
  cramming.
- Tooling: Mostly free and local (docker-compose stacks reused across days, k6
  for load, Postgres / Redis / Kafka containers, Go services). 2–3 days use the
  personal AWS sandbox where the cloud itself is the point; resources torn down
  at end of each day to control cost.

## Unconventional strategy — what the top 1% actually do

Most learners read books and watch "design Twitter" videos, then can recite
patterns but freeze in a real review. Architecture is a **reasoning skill learned
by producing designs and having them attacked** — not by reading. The accelerated
approach has six rules:

**1. A repeatable design method, not memorized solutions.**
Every design runs the same loop: *requirements → constraints → NFRs → options →
tradeoffs → decision → how it breaks.* Beginners memorize reference architectures;
architects run a method that transfers to novel problems. Day 1 installs it and
every later day rehearses it.

**2. Self-red-team every design.**
After each design, attack it: where does it break under load, partial failure,
network partition, or a 10× traffic change? The skill that separates architects
from builders is anticipating failure *before* it happens. Every day includes an
explicit "how it breaks" pass.

**3. "When would I NOT use this?" discipline.**
For every pattern and technology, reason about the alternative and its breaking
point. Anyone can say what a queue or CQRS does; few can say when *not* to.
That is exactly what reviews and incidents demand. Every day has a "when NOT
this" note.

**4. Build / measure / break — hands-on every day.**
Reading a pattern and *watching it behave* are different neurons. Each day proves
ONE concept with a cheap local lab: build it, measure it with load, then break it
on purpose and diagnose. Grounding theory in a running system is the single
biggest aid to comprehension and retention.

**5. Narrate-to-consolidate.**
After every session, write 3–5 sentences in `journal.md` explaining the day's
concept as if to a junior engineer. If you cannot explain it simply, you have not
learned it yet. Highest-leverage daily habit.

**6. Learn from real production systems, not toys.**
Every day anchors to a real published architecture or a battle-tested practice
(AWS Builders' Library, Netflix, Stripe, Uber, Discord, Shopify, Segment,
Amazon Prime Video). Reality carries the tradeoffs that toy examples hide.

## Mistakes that waste 80% of beginners' time (explicitly avoided)

1. **Consuming instead of producing.** Watching/reading without designing.
   *Avoided:* a produced design + ADR every single day.
2. **Learning services in isolation.** Memorizing what each tool does, never the
   *problem* it solves or its alternative. *Avoided:* "when NOT this" + tradeoff
   reasoning every day.
3. **Skipping capacity math.** Designing without numbers, so "will it scale?" is
   a vibe. *Avoided:* Day 2 estimation, validated with real load tests.
4. **Ignoring failure until it's a diagram of the happy path.** *Avoided:*
   self-red-team + deliberate breakage every day; a whole resilience phase.
5. **Cargo-culting microservices / CQRS / event sourcing.** Adopting complexity
   without the forcing conditions. *Avoided:* modular-monolith-first framing and
   real re-monolith case studies (Segment, Prime Video).
6. **No artifacts.** Designs that live only in one head. *Avoided:* C4 + ADRs
   from Day 1.
7. **Chasing interview tricks over understanding.** *Avoided:* interviews framed
   as compression reps of production design, placed at phase ends.

## Plan architecture

Six phases over 21 core days. Phases are ordered to build on each other; each day
is a standalone unit that can be reordered, deepened, or dropped.

- **Phase 0 — The architect's operating system** (Day 1)
- **Phase 1 — Scale & data foundations** (Days 2–7)
- **Phase 2 — Resilience & failure** (Days 8–11)
- **Phase 3 — Modern distributed patterns** (Days 12–17)
- **Phase 4 — AI/LLM system design** (Days 18–19)
- **Phase 5 — Integration & mastery** (Days 20–21)

## Daily rhythm (~2–3 hrs, four beats)

1. **Teardown warm-up** (~20 min, *C facet*) — read one real published
   architecture; extract *why* they chose what they chose.
2. **Design core** (~60–75 min, *A spine*) — design a real system/subsystem for
   the day's concept → **self-red-team** it → write **one ADR** defending a key
   decision.
3. **Hands-on lab** (~40–60 min) — build / measure / **break** ONE concept
   locally (docker-compose + Go/Kafka/Postgres/Redis + k6); a few days graduate
   to the AWS sandbox where the cloud is the point.
4. **Journal** (~10 min) — narrate-to-consolidate.

**Recurring facets** so B/C/D are integral, not bolted on:
- **B (interviews):** each phase ends with 1–2 timed canonical problems.
- **C (artifacts):** C4 + ADRs produced daily; NFR discipline throughout.
- **D (altitude down):** recurring beat mapping the day's reasoning into Go code
  (DDD boundaries, patterns, module design), concentrated on Day 12.

## Curriculum map

### Phase 0 — The architect's operating system

- **D1 — How architects reason.** NFRs & the "-ilities"; the design method
  (requirements→constraints→options→tradeoffs→decision→how-it-breaks); C4 model;
  ADRs. **Lab:** reverse-engineer a known system into a C4 diagram + first ADR.
  **Real-world:** arc42 / C4 in practice; AWS Well-Architected pillars as an NFR
  checklist.

### Phase 1 — Scale & data foundations

- **D2 — Back-of-envelope estimation & workload characterization** (QPS,
  read/write ratio, storage, bandwidth, latency budgets). **Lab:** estimate a
  workload, validate with k6. **Ref:** Jeff Dean's "numbers every engineer should
  know."
- **D3 — Storage selection:** SQL / NoSQL / NewSQL, access patterns, indexing
  (DDIA core). **Lab:** same workload on Postgres vs. a KV store, measure.
  **Ref:** Uber's storage evolution; DynamoDB single-table design.
- **D4 — Replication & consistency models; CAP/PACELC in practice.** **Lab:**
  Postgres primary/replica, induce replication lag, observe stale reads. **Ref:**
  Google Spanner (PACELC); eventual-consistency reality at Amazon.
- **D5 — Partitioning / sharding & consistent hashing.** **Lab:** shard a dataset,
  feel the rebalancing pain. **Ref:** Discord message-store sharding; Uber
  Ringpop.
- **D6 — Caching strategies:** cache-aside, write-through, TTL, invalidation,
  stampede. **Lab:** Redis cache-aside, measure hit ratio, trigger a stampede,
  fix it. **Ref:** Facebook memcached scaling; thundering-herd mitigations.
- **D7 — Load balancing, queuing & load-leveling, backpressure.** **Lab:** k6
  spike → add a queue → watch it absorb. **Ref:** AWS queue-based load-leveling
  pattern. **▶ B rep:** *Design a URL shortener + rate limiter (45 min).*

### Phase 2 — Resilience & failure

- **D8 — Timeouts, retries, idempotency, backoff + jitter.** **Lab:** Go service
  with idempotency keys; induce duplicate delivery. **Ref:** Stripe idempotency
  keys; AWS Builders' Library "Timeouts, retries, and backoff with jitter."
- **D9 — Circuit breakers, bulkheads, graceful degradation.** **Lab:** break a
  dependency → watch the cascade → add a breaker. **Ref:** Netflix Hystrix;
  bulkhead pattern.
- **D10 — Cell-based architecture, blast radius, multi-region basics.** **Lab
  (AWS):** design + partial build of a 2-cell setup. **Ref:** AWS cell-based
  architecture; Shopify pods; Slack's cellular migration.
- **D11 — Observability-as-design:** SLI/SLO/error budgets, three pillars,
  correlation IDs. **Lab:** add tracing + metrics to the stack, define SLOs.
  **Ref:** Google SRE book; OpenTelemetry. **▶ B rep:** *Design a resilient
  notification/payment system.*

### Phase 3 — Modern distributed patterns

- **D12 — Microservices boundaries vs. modular monolith; DDD strategic design**
  (bounded contexts). **Lab (D facet):** decompose a monolith design into
  contexts. **Ref:** Segment's monolith→micro→monolith; Amazon Prime Video's
  re-monolith.
- **D13 — Service communication:** sync (gRPC/REST) vs. async; API design &
  versioning. **Lab:** gRPC between two Go services + contract evolution. **Ref:**
  gRPC at scale; API versioning strategies.
- **D14 — Event-driven architecture & the log as source of truth** (leverages
  Kafka strength). **Lab:** Kafka event flow + replay. **Ref:** Kleppmann
  "turning the database inside out"; LinkedIn's log.
- **D15 — CQRS / event sourcing.** **Lab:** tiny event-sourced aggregate + read
  projection. **Ref:** event-sourcing tradeoffs; when NOT to use it.
- **D16 — Sagas, distributed transactions, the outbox pattern.** **Lab:**
  transactional outbox (Postgres+Kafka), prove no lost events. **Ref:** saga
  pattern; the dual-write problem.
- **D17 — Service mesh + deployment/rollout architecture** (blue-green, canary,
  feature flags). **Lab:** weighted/canary routing (local or AWS). **Ref:** Istio;
  progressive delivery. **▶ B rep:** *Design a ride-sharing or news-feed system.*

### Phase 4 — AI/LLM system design

- **D18 — LLM app architecture:** RAG pipelines, embeddings & vector DBs,
  retrieval quality, cost/latency tradeoffs, LLM caching. **Lab:** minimal RAG +
  vector store, measure retrieval quality. **Ref:** production RAG patterns;
  semantic caching.
- **D19 — Agent orchestration, tool use, guardrails, evaluation, multi-agent
  patterns** (ties to Bedrock AgentCore work). **Lab:** small agent loop +
  guardrail + eval harness. **Ref:** agent architectures; LLM-as-judge eval.

### Phase 5 — Integration & mastery

- **D20 — Cross-cutting dimensions:** security architecture (authn/z, secrets,
  zero-trust), cost/FinOps as a design axis, platform/API thinking. **Lab:**
  threat-model + cost-model an earlier design. **Ref:** STRIDE threat modeling;
  Well-Architected security & cost pillars.
- **D21 — Capstone:** full end-to-end architecture of a substantial system
  integrating everything — complete design doc + C4 + ADRs + self-red-team +
  defended tradeoff table, then a **mock architecture review**. **▶ B rep:** one
  hard open-ended problem under time.

## Tooling

- **Local (default):** docker-compose stacks reused across days; Go services;
  Postgres, Redis, Kafka containers; k6 for load generation; OpenTelemetry +
  a local collector for the observability day.
- **AWS sandbox (2–3 days):** cell-based/multi-region (D10) and optionally
  canary routing (D17). Torn down at day's end.
- **Diagrams:** C4 (text-based, e.g. Mermaid/PlantUML kept in-repo).

## Extensibility model

Extensibility is a first-class requirement — nothing is hardcoded to "21 days."

```
system_architect_design/
├── README.md              ← the map + "how to add a day" instructions
├── BACKLOG.md             ← prioritized future topics (grows over time)
├── reference/             ← reusable cheatsheets + living case-study library:
│                            design-method, nfr-checklist, estimation-cheatsheet,
│                            c4-guide, adr-template, real-world-case-studies.md
├── templates/
│   └── day-template.md    ← the 4-beat template every day follows
├── labs/                  ← shared docker-compose stacks, reused across days
└── days/
    ├── day01-.../ (README.md, lab/, adr/, diagrams/, journal.md)
    └── ...
```

Adding a topic later = copy `templates/day-template.md`, drop a folder in `days/`
(or an `ext/` folder for out-of-sequence topics), tick it off `BACKLOG.md`.

**`BACKLOG.md` seeds (deliberately deferred):** analytics/lakehouse & stream
processing deep-dive; real-time/WebSockets & CDN/geo; chaos engineering; GraphQL
federation; deeper LLM eval & fine-tuning-vs-RAG; platform engineering/IDP; extra
interview problem sets.

## Deliverables

- Per day: a `README.md` (4-beat plan + "when NOT this" note), a C4 diagram, at
  least one ADR, lab code/config, and a `journal.md` entry.
- Per phase: 1–2 completed timed interview problems.
- Capstone: a full architecture package (design doc + C4 + ADRs + red-team +
  tradeoff table) plus a mock-review write-up.
- Cross-cutting: `reference/real-world-case-studies.md` accumulated across all
  days as a living best-practices/use-case library.

## Anchor references (syllabus anchors, not dependencies)

- *Designing Data-Intensive Applications* — Kleppmann (data/distributed core).
- *System Design Interview* vol 1 & 2 — Alex Xu (B reps).
- *Building Microservices* — Newman (modern patterns / boundaries).
- **AWS Builders' Library** (resilience, cell-based, retries/backoff).
- *Google SRE* book (observability, SLOs, error budgets).
- Real engineering blogs: Uber, Netflix, Discord, Shopify, Stripe, Segment,
  Amazon (teardowns and battle-tested practices).

## Success criteria

By the end, the learner can:
1. Run the design method on a novel problem without prompting.
2. Produce back-of-envelope capacity estimates and validate them.
3. Reason about consistency, partitioning, and failure modes with specifics, not
   vibes — including "when NOT this" for each major pattern.
4. Self-red-team a design and defend decisions in a mock architecture review.
5. Produce communicable artifacts (C4, ADRs) as a matter of habit.
6. Design an LLM/agent system with retrieval, cost/latency, and guardrail
   reasoning.
7. Pass a 45-minute system-design interview problem as a byproduct.
