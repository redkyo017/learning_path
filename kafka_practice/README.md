# Kafka Mastery — 15 Days

A self-directed, aggressive Kafka learning plan for an integration/infra role:
secure, operate, and integrate against real Kafka clusters — not just write
client code — anchored against the Confluent Certified Administrator (CCAAK)
exam objectives, ending in a self-administered practice exam on Day 15.

This file is the entry point. It doesn't repeat what's already written
elsewhere in more detail — it tells you where to look and summarizes the
guidelines that apply across all 15 days, so you don't have to re-derive them
each morning.

## Where everything lives

| Path | What it is |
|---|---|
| `docs/superpowers/specs/2026-07-09-kafka-15-day-plan-design.md` | The design spec — purpose, structure, full strategy/mistakes tables, success criteria. Read this once, up front. |
| `docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` | The day-by-day execution plan — exact commands, time boxes, checkboxes. This is what you follow each day. |
| `content/dayNN.md` (+ `content/README.md`) | The theory layer — concepts, best practices, pitfalls, use cases, worked examples, exercises+answers for each day. Read the day's content doc before that day's hands-on work. |
| `labs/` | Java (Maven) lab code — the primary track, since it matches your employer's stack and is required for Kafka Streams/Connect. |
| `labs-go/` (+ `labs-go/README.md`) | Parallel Go implementation for days that have one — use this instead of Java while you're still ramping up, per your own call. See caveats below before trusting it blindly. |
| `docker/`, `aws/`, `mm2/` | Docker Compose cluster, AWS CLI/JSON templates, MirrorMaker2 config — referenced by specific days in the plan. |
| `journal.md` (you create this) | Your own daily reflection log — the plan's retrieval-practice mechanism. Nothing in this repo writes to it for you. |

**Start here:** `docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`, Day 1,
alongside `content/day01.md`.

## Daily rhythm (every content day, ~5 hours)

1. **Primer from primary sources** (20 min) — official docs/KIPs, not blog summaries.
2. **Hands-on build/config** (60-70 min).
3. **Deliberate-failure ("chaos") lab** (45 min) — break it on purpose, then diagnose. This is the plan's highest-leverage technique; it is mandatory, not optional, on the days that have one.
4. Break (15 min).
5. **Integration coding** (60 min).
6. **Teach-it-back** (30 min) — write the day's concept as if explaining it to a teammate who just got paged about it. This is more diagnostic than re-reading notes.
7. **Journal entry + save point** (20-30 min) — your own responsibility; nothing here runs git for you.

Review days (5, 10, 13) drop steps 1-2 and run entirely closed-book on the prior days' material instead, plus that phase's cloud teardown.

## Unconventional strategies this plan deliberately uses

| Strategy | Why |
|---|---|
| Primary sources over blog summaries | Blog posts frequently misstate subtle semantics (exactly-once being the canonical example). |
| Break things on purpose | Reading about a failure mode builds recognition; causing and debugging it builds instinct. |
| CLI-first, GUI-never during learning | GUI tools hide the actual commands/config being sent — typing them builds a transferable mental model. |
| Teach-it-back instead of re-reading | Forces retrieval, exposes gaps immediately. |
| CCAAK objectives as a scope boundary | Replaces "have I gone deep enough" guesswork with an external checklist. |
| Security and cost-control from Day 1 | Practicing both locally first makes them habits before the cloud phases enforce them by default. |

## Mistakes this plan is designed to block

| Mistake | Blocked by |
|---|---|
| "It's just a queue" mental model | Day 1 explicitly contrasts Kafka's log/partition model against generic pub/sub first. |
| Ignoring partition/key strategy until it causes hot partitions | Day 2 makes key choice a hands-on lab, not a paragraph. |
| Shaky offsets/rebalancing understanding | Day 3's dedicated rebalance-storm chaos lab. |
| Security as an afterthought | Day 5 secures the local cluster before any cloud platform is touched. |
| App-code fluency with zero cluster-admin fluency | CLI-first admin commands used every day from Day 1. |
| No cost/teardown discipline | Explicit, scheduled teardown at the end of Day 10 and Day 13. |
| Learning Streams before core semantics are solid | Streams/ksqlDB deliberately placed last (Day 13). |

Full "why it wastes time" detail for each is in the spec, not repeated here.

## Language tracks: Java vs. Go — read before you start coding

- **Java (`labs/`) is the primary track** — it's what the plan was designed
  around, matches your employer's Spring Boot stack, and is required for
  Kafka Streams and Kafka Connect plugin development (both JVM-native, no
  way around this).
- **Go (`labs-go/`) is a secondary track** for days that have one, added so
  you can keep making hands-on progress while you're still ramping up on
  Java. Config files differ in shape between the two (Go uses flat
  `sasl.username`/`sasl.password` keys; Java uses a JAAS config string) —
  see `labs-go/README.md` for the concrete before/after.
- **Two Go-specific caveats to know before you lean on it:**
  1. Every Go file has `TODO(human)` comments at API calls that couldn't be
     verified without compiling. Run `go mod tidy && go build ./...` in
     `labs-go/` early — before you're mid-lab — to shake these out.
  2. Day 12's Avro port has a real API gap, documented in the file itself:
     confluent-kafka-go's serializer derives the Avro schema from the Go
     struct via reflection, not from the `.avsc` file the way Java does.
  3. Kafka Streams (Day 13, and the Streams half of Day 14) has no official
     Go client and stays Java-only — a deliberate scope decision, not a gap
     to fill in later without first deciding on a real approach (hand-rolled
     windowing vs. a third-party library — see the Day 13 content doc for
     the trade-off if you revisit this).

## Cost control (cloud phases: Days 6-13)

- MSK (Days 6-10) and Confluent Cloud (Days 11-13) both run for their full
  multi-day window, not torn down nightly — that's an accepted trade-off, not
  an oversight. What's *not* optional: the full teardown checklist at the end
  of Day 10 (AWS) and Day 13 (Confluent), before moving on.
- If spend during a window becomes a real concern, scale broker count/size
  down further rather than shortening the window ad hoc.

## Success criteria (from the spec — how you'll know you're done)

- [ ] Can stand up a secured Kafka cluster from scratch on both Docker and MSK, without notes.
- [ ] Can diagnose and recover from all four chaos labs (broker kill, rebalance storm, under-replication, ACL misconfiguration) by reasoning from first principles.
- [ ] Can configure a working source + sink connector end-to-end, including schema registry.
- [ ] Passes the Day 15 self-administered CCAAK-style practice exam closed-book.
- [ ] Can teach back every major concept, postmortem-style, without notes.

## A note on scope decisions

A few things were deliberately left out or scoped down, and it's worth
knowing they're deliberate rather than re-discovering the gap mid-lab:
non-Java/Go client ecosystems, KRaft internals beyond a conceptual level,
Confluent enterprise-only features, and (within Day 5) a full mTLS
broker-listener wiring beyond cert generation. Full list and rationale in the
spec's "Out of scope" section.
