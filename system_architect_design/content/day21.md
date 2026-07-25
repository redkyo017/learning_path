# Day 21 — Capstone: full architecture package + mock review

After today you can take a novel, substantial system from a blank page to a defended
architecture package — requirements, capacity estimate, C4, ADRs, self-red-team — and
survive a skeptical review, naming the runner-up for every decision.

## The core problem

The previous 20 days each drilled one pattern in isolation. Real architecture is
**integration under a budget**: you must apply the right subset of those patterns to
one system, in the right order, and defend the choices against someone trying to
break them. The capstone is not "use everything you learned" — it's the opposite. It
tests whether you can **choose what to leave out** and **go deep where it matters**.

The trap is breadth: a diagram with twelve boxes, each named but none reasoned about.
The skill is **depth over breadth** — pick the 2–3 subsystems that carry the system's
risk and go all the way down (data model, consistency, failure modes, real numbers),
while the rest gets a sentence. A reviewer can tell in ninety seconds which one you
did.

## Key concepts

### The method is the deliverable

You already have the method (`reference/design-method.md`): requirements → constraints
→ top-3 NFRs → ≥2 options → tradeoffs → decision → red-team. The capstone runs it
**end to end on a system you haven't designed before**, and produces a package a
reviewer can read without you in the room. The artifacts:

1. **Requirements** (functional + scale, with what's explicitly out of scope).
2. **Capacity estimate** (Day 2) — the numbers that *drove* decisions, not decoration.
3. **C4 diagrams** C1–C3 (Day 1 / `reference/c4-guide.md`).
4. **3–5 ADRs** for the highest-stakes decisions, each with a rejected alternative.
5. **A "how it breaks" red-team** across the standard failure dimensions.
6. **A tradeoff table** for your single most contested decision.

### The integration checklist (which day applies where)

Walk the system and ask, for each concern, *does this system live or die by it?* If
yes, go deep; if no, one line.

| Concern | Days | Ask |
|---------|------|-----|
| Capacity / workload shape | 2 | What are the QPS, read:write, data size, spikiness? What number changes the design? |
| Storage + access patterns | 3 | SQL/NoSQL/NewSQL by access pattern; indexing |
| Replication / consistency | 4 | Where do you need linearizable vs. eventual? CAP/PACELC stance |
| Partitioning / sharding | 5 | Shard key; hot-partition risk |
| Caching | 6 | What's the hot 20%? cache-aside/write-through; staleness |
| Load leveling / backpressure | 7 | Queue to smooth peaks? shed load? |
| Timeouts / retries / idempotency | 8 | Correct under retries and ambiguous timeouts? |
| Circuit breakers / bulkheads / degradation | 9 | Does a slow dependency cascade? graceful fallback? |
| Cells / blast radius / multi-region | 10 | Blast radius of a bad node/region; is multi-region justified? |
| Observability (SLI/SLO) | 11 | What are the SLIs, the SLOs, the error budget? |
| Boundaries / DDD | 12 | Service boundaries along business capabilities; monolith vs. services |
| Service comms / gRPC / versioning | 13 | Sync vs. async; contract evolution |
| Event-driven / the log | 14 | Is the log the source of truth? |
| CQRS / event sourcing | 15 | Separate read/write models? audit/replay need? |
| Sagas / outbox | 16 | Cross-service consistency without 2PC; exactly-once effects |
| Mesh / rollout | 11,17 | Canary/blue-green; automated rollback on SLO burn |
| Security + cost | 20 | STRIDE top mitigation; $/1K req and the dominant lever |
| AI component | 18,19 | RAG retrieval + cost/latency; agent guardrails + eval — if relevant |

### Self-red-team — the five dimensions

A design you haven't attacked is a hypothesis, not a decision. Walk **every** one and
answer "what happens?":

1. **10× load** — where's the first bottleneck, and what absorbs it?
2. **A region / cell is lost** — does the blast radius stay bounded? failover path?
3. **A dependency is down or slow** — does it cascade, or degrade gracefully?
4. **A bad deploy** — blast radius and rollback path? (canary + SLO-burn rollback)
5. **A hot partition / hot key** — does one tenant sink everyone?
   (plus: **data loss / duplicate delivery** — correct under retries?)

If you can't answer one, that's your next design task, not a footnote.

### The mock review ritual

Play the skeptical senior reviewer against your own package. For **each ADR**, answer
out loud: *"Why not the alternative?"* in one sentence — for our top NFR of ___, X
gives ___ while Y would have cost ___. Every question you **can't** answer confidently
becomes a `BACKLOG.md` entry. The goal is not a perfect design; it's an *honest* one
where you know exactly where the bodies are buried.

### Self-grading rubric (the same /10 as the interview bank)

From `reference/interview-problems.md`: requirements + scale numbers (2); named top-3
NFRs and designed to them (2); ≥2 options compared (1); a capacity estimate that
drove a decision (1); data model + storage justified (1); failure modes / red-team
(2); one clear "why this over the alternative" per key decision (1). Grade yourself on
whether you **ran the method and defended tradeoffs** — not on matching a model
answer.

## The decision / tradeoffs

The capstone's meta-decision is **scope allocation**: where to spend your finite
attention. Depth is a budget.

| Approach | Result |
|----------|--------|
| Breadth (12 shallow boxes) | Fails review — no defensible decision anywhere |
| Depth on the wrong subsystem | You hardened the easy part; the risky one is hand-wavy |
| **Depth on the 2–3 risk-carrying subsystems** | A defensible package; the rest is honestly sketched |

Pick the subsystems that carry the risk (the money path, the fan-out, the consistency
boundary, the hot partition) and go deep there. Name the rest and move on.

## When NOT this

n/a — this is the integration exercise; there is no "instead." But the *when-NOT*
discipline is the whole point at the component level: for every pattern you're about
to add, state the alternative and why it lost. An architecture that uses a saga, a
cache, and multi-region without ever saying why *not* the simpler thing is a
collection of reflexes, not decisions.

## Real-world

Re-skim the 2–3 case studies in `reference/real-world-case-studies.md` most relevant
to the system you pick, and steal their *reasoning*, not their boxes:

- **Ride-hailing / dispatch** — geo-indexing (geohash/S2/H3), a trip state machine,
  lossy high-rate location writes, surge, multi-region. The lesson is *which*
  subsystem is hard (dispatch + geo), and going deep there.
- **Real-time collaborative editor** — OT/CRDT, presence, conflict resolution, WS
  fan-out. The whole problem is the consistency model; everything else is plumbing.
- **LLM-powered support platform** — RAG over docs, agent actions with guardrails,
  human handoff, eval (Days 18–19). The risk is retrieval quality, cost/latency, and
  the injection/guardrail boundary.

Each maps to **Problem 4** in `reference/interview-problems.md` — that's your system
menu. Pick one and produce the complete package.

## Common mistakes / gotchas

1. **Breadth over depth.** Twelve boxes, no reasoning. Pick 2–3 and go down.
2. **A capacity estimate that decided nothing.** Numbers that don't change a decision
   are decoration. Every estimate should end in "→ therefore X."
3. **ADRs with no rejected alternative.** That's a decision you can't defend; it means
   you evaluated one option.
4. **A red-team that only covers 10× load.** All five dimensions, or the design is
   untested against the failures that actually happen (region loss, bad deploy).
5. **Skipping the mock review.** The value is the questions you *can't* answer — those
   are your real gaps. Don't skip to feel finished.
6. **Adding patterns reflexively.** A saga/cache/mesh with no "why not simpler" is
   cargo-culting. Justify each against a named alternative.

## Practice

The capstone itself is the exercise — see `days/day21-capstone/README.md` for the
end-to-end run and the worksheet templates in `lab/`. Two warm-ups to calibrate:

### 1. Scope allocation
For your chosen system, name the 2–3 subsystems that carry the risk, and one sentence
each on why. What gets a single line instead?

<details><summary>Hint</summary>
Follow the money, the fan-out, the consistency boundary, and the hottest partition.
Those are usually where the risk lives.
</details>
<details><summary>Solution sketch (LLM support platform)</summary>
Deep: (a) **retrieval quality + cost/latency** (the product is only as good as what
it retrieves, and tokens dominate the bill — Days 18/20); (b) the **agent action +
guardrail/eval boundary** (injection and wrong actions are the risk — Day 19);
(c) **human handoff / state** (correctness of the escalation path). One line each:
auth, the web frontend, the metrics pipeline, the CDN. You go deep on three, sketch
the rest — and you can say why.
</details>

### 2. Rehearse the hardest "why not the alternative?"
Pick your single most contested ADR. Write the one-sentence defense, then have the
skeptical reviewer push once more. Can you hold the line, or does it become a
`BACKLOG.md` entry?

<details><summary>Solution sketch</summary>
E.g. "We chose a transactional outbox over dual-writes because for our top NFR of
correctness, the outbox is atomic with the state change while dual-writes can lose the
event on a crash between the two writes." Reviewer: "Why not change-data-capture off
the DB log?" — a legitimate alternative (less app code, but couples you to the DB and
adds CDC infra). If you can defend the choice in a sentence, keep it; if you're
hand-waving, log "evaluate CDC vs. outbox" to `BACKLOG.md`. Honesty about the gap is
the passing move.
</details>

## Go deeper (offline-friendly)

- **DDIA** (Kleppmann) — re-skim the chapters matching your risk subsystems
  (Replication Ch.5, Partitioning Ch.6, Transactions Ch.7, Consistency & Consensus
  Ch.9). The capstone is where these compose.
- **Alex Xu, "System Design Interview" vol. 1 & 2** — the closest analog to the
  capstone format; read the worked example nearest your chosen system for structure,
  not answers.
- **AWS Well-Architected Framework** — run your package through the six pillars as a
  final review lens (Day 20).
- Your own **`reference/`** — design-method, nfr-checklist, estimation-cheatsheet,
  c4-guide, adr-template, and the case studies. The capstone is these, composed.

## Check yourself

- Can you run the 7-step method end to end on a novel problem and produce C4 + ADRs
  unprompted?
- Can you give a back-of-envelope estimate that *drove* a decision, and name the
  assumption that would break the design if wrong by 10×?
- For every major pattern in your design, can you state the dominant NFR it serves
  and the "when NOT this"?
- Can you self-red-team across all five dimensions (10× / region loss / dependency
  down / bad deploy / hot partition)?
- For each ADR, can you name the runner-up and why it lost, in one sentence?
- What are your top-3 remaining gaps — and are they in `BACKLOG.md`?
