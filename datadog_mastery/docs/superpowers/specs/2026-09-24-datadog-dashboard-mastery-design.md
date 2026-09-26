# DataDog Dashboard Mastery — Stage 1: Investigation — Design Spec

**Date:** 2026-09-24
**Location:** `datadog_mastery/`
**Duration:** 1 day, 8 hours total
**Stage:** 1 of N — Dashboard Investigation (read-only, no creating/editing)

---

## Purpose & Goals

The learner is a senior software engineer who needs to use DataDog fluently to investigate
production incidents in their company environment. The stack is WSO2 API Gateway 4.7 + Java
Spring Boot microservices on ECS Fargate, backed by RDS MySQL. Prior observability experience
is minimal (light Grafana/Loki/VictoriaMetrics/Tempo exposure — not assumed in content).

Stage 1 focuses exclusively on **reading and navigating DataDog to diagnose issues**. No
dashboard creation, no monitor authoring, no alert rule writing. The practice environment is
the learner's real company DataDog tenant — all drills use live production data.

The goal is investigation fluency: given an alert, an error spike, a latency complaint, or a
DB slowdown, the learner can navigate from the signal to the root cause in DataDog without
help. This is the skill that makes an engineer independently useful on an on-call rotation.

---

## Success Criteria

By the end of 8 hours, without notes, the learner can:

1. Navigate to any DataDog product area (Logs, APM, Metrics, Infrastructure, Monitors) directly
2. Write a DDQL log query to isolate errors for a specific service, endpoint, or time window
3. Use facets and log patterns to cut through noise in a high-volume log stream
4. Correlate a log entry to its distributed trace using `trace_id`
5. Read the APM Service Map and identify services with elevated error rates or latency
6. Open a distributed trace, read the flame graph, and identify the slowest or failing span
7. Reconstruct a WSO2 → Spring Boot API call chain from a single trace
8. Read ECS container metrics (CPU, memory, task count) and identify a container restart or OOM event
9. Read RDS MySQL performance panels (QPS, active connections, slow query count, latency)
10. Open a Monitor definition, read its alert condition and notification config, and read its alert history
11. Execute the full investigation pivot: alert → logs → trace → infrastructure in one unbroken flow

---

## Constraints & Environment

| Constraint | Rule |
|---|---|
| Practice environment | Company's real DataDog — read-only investigation only |
| No creation | Do not create dashboards, monitors, saved views, or notebooks during this stage |
| No credentials | No secrets, tokens, or account IDs in any content file |
| No infrastructure | No Terraform, no Docker, no local services needed |
| No git commands in subagent dispatches | Skip all `git status/diff/log` |
| Exercises | All exercises ship with hints + solution sketches |
| Stage handoff | PROGRESS.md tracks completed hours and defines the stage 2 starting point |

---

## Strategy — The Core Design Decision

### The Top 1% Approach: Investigation-First Drill Pattern

Most DataDog learners spend their first weeks clicking through the UI, watching tutorial videos
on toy examples, and reading the docs in order. They reach "competence" in weeks but never
build instinct — they still need help on real incidents.

The top 1% skip that entirely. They learn by **doing real incident reconstruction drills on
real production data from hour one**. Every concept is introduced only when it unlocks a drill.
This builds investigation muscle memory, not UI menu knowledge.

The key insight: every DataDog investigation — regardless of the incident type — follows the
same **3-pivot pattern**:

```
Signal (alert or anomaly) → Context (logs + correlation) → Root cause (trace or infra metric)
```

Learning this pattern first, then learning each tool in service of it, creates durable skill in
8 hours rather than 80.

### The 5 Mistakes That Waste 80% of Beginners' Time

1. **Learning dashboard creation before learning to read dashboards.** Stage 1 is read-only by design.
2. **Treating logs, traces, and metrics as three separate tools.** DataDog's power is their
   correlation via `trace_id` and service tags. Beginners who learn each in isolation never
   learn to pivot between them.
3. **Using the search bar without understanding facets.** Facets are how DataDog structures its
   index. Without them, queries return too much or nothing. This is the #1 "why can't I find
   anything" frustration.
4. **Ignoring service tags and environments.** Every DataDog entity (log, trace, metric, alert)
   is tagged with `service`, `env`, `version`, `host`. Filtering by these tags is the first
   thing every investigation starts with. Beginners skip this and drown in data.
5. **Reading the full trace before scanning the flame graph.** The flame graph shows the slow
   span in 2 seconds. Beginners open every span manually and spend 10 minutes on what should
   take 30 seconds.

---

## Curriculum

### H1 — DataDog Mental Model + Navigation Orientation (~60 min)

**Goal:** Know what DataDog is made of and navigate confidently without guessing.

Topics:
- DataDog's product taxonomy: Logs, APM (Traces), Metrics, Infrastructure, Monitors, Dashboards
- The tagging system: `service`, `env`, `version`, `host` — the connective tissue of everything
- The global time selector and environment filter (always set these first)
- Navigation: left nav structure, quick-switch (Cmd+K), pinning
- DataDog vs Grafana mental model (brief orientation, not a deep mapping)

---

### H2 — Log Explorer: Querying and Filtering (~60 min)

**Goal:** Find any log fast using DDQL syntax and the Log Explorer UI.

Topics:
- Log Explorer layout: search bar, time range, facet panel, log stream
- DDQL syntax: field search (`service:gateway`), free text, operators (`AND`, `OR`, `NOT`),
  wildcard (`*`), attribute search (`@http.status_code:500`)
- Status levels: ERROR / WARN / INFO / DEBUG — filtering by level
- Time range: absolute vs relative, zoom-in on spike
- Log detail panel: parsing structured vs unstructured logs, JSON expansion
- The `trace_id` field: how to pivot from log to trace

**Investigation Scenario — Error rate spike:**
*"Your alerting system shows a spike in 5xx errors. Start in Log Explorer and find which service
and endpoint is throwing the errors."*

---

### H3 — Log Patterns, Facets, and Saved Views (~60 min)

**Goal:** Cut through high-volume noise to find the signal.

Topics:
- Facets: what they are, how to add/remove, the facets panel vs indexed attributes
- Log patterns: automatic clustering of similar logs, how to use it to identify volume spikes
- Aggregation view vs list view: when to use each
- Log analytics: graph log count over time by service, grouping by facet
- Saved views: reading an existing saved view (not creating one yet — that's stage 2)

**Investigation Scenario — WSO2 auth failure flood:**
*"Logs show a spike in 401/403 responses. Use facets and log patterns to determine if this is
one client hammering the gateway or a widespread auth provider issue."*

---

### H4 — APM Service Map and Trace Explorer (~60 min)

**Goal:** Read the service dependency map and navigate to a specific trace.

Topics:
- APM product areas: Service Map, Trace Explorer, Service Catalog, APM Metrics
- Service Map: reading node colours (error rate / latency), edge labels (requests/s), dependency arrows
- How to read the WSO2 → Spring Boot chain on the Service Map
- Trace Explorer: search syntax (same tag model as logs), `service:`, `resource:`, `status:error`
- Trace list: reading p50/p95/p99 latency columns, error count, hit count
- Opening a trace: the trace timeline view vs the span list

**Investigation Scenario — Latency complaint:**
*"A user reports that the payment API is slow. Open the Service Map, find the payment service,
identify which upstream or downstream dependency is contributing to latency."*

---

### H5 — Flame Graphs and API Flow Investigation (~60 min)

**Goal:** Pinpoint the slow or failing span in a distributed trace.

Topics:
- Flame graph anatomy: x-axis = time, span bars, colour = service, width = duration
- Reading span metadata: resource name, HTTP method/URL, DB query, status code, error message
- Identifying the critical path: the chain of spans that determines total latency
- Database spans: how RDS MySQL queries appear in traces (query text, row count, duration)
- Error spans: reading the error type, message, and stack trace attached to a span
- Cross-service propagation: how `trace_id` links WSO2 → Spring Boot → MySQL in one flame graph
- Log correlation panel inside a trace: jumping from trace to associated logs

**Investigation Scenario — Slow API + DB query:**
*"A trace shows total latency of 4s. Open the flame graph. Identify whether the bottleneck is
in WSO2 gateway processing, Spring Boot business logic, or an RDS MySQL query."*

---

### H6 — Metrics and Infrastructure Investigation (~60 min)

**Goal:** Read ECS container health and RDS MySQL performance panels without guessing what the numbers mean.

Topics:
- Infrastructure map: ECS Fargate tasks, container view, reading CPU/memory/network panels
- Key ECS metrics: `aws.ecs.service.running_count`, `container.cpu.usage`, `container.memory.usage`
- Reading for OOM: memory usage trending to limit → task restart → gap in trace coverage
- RDS MySQL key metrics: QPS (queries per second), active connections, replication lag,
  `mysql.performance.slow_queries`, `mysql.net.connections`, `mysql.innodb.row_lock_waits`
- Reading a metric time series: normal baseline, spike, threshold lines
- Correlating a metric event (CPU spike, connection exhaustion) to a time range in logs

**Investigation Scenario — RDS connection exhaustion:**
*"Services are returning DB connection errors. Navigate to the RDS MySQL dashboard. Identify
when connection count crossed the max_connections limit and which time window to investigate
in logs."*

---

### H7 — Monitors and Alert Investigation (~60 min)

**Goal:** Read any Monitor definition and reconstruct what happened when it fired.

Topics:
- Monitors product area: monitor list, status colours (OK / WARN / ALERT / NO DATA)
- Monitor detail page: query definition, trigger conditions, notification config, tags
- Alert history: timeline of state transitions, who was notified, linked logs/traces
- Monitor types: Metric monitor vs Log monitor vs APM monitor — how to read each
- Composite monitors: how multiple conditions combine into one alert
- Muted monitors: understanding maintenance windows

**Investigation Scenario — 2am alert reconstruction:**
*"An alert fired at 2am and woke someone up. Open the monitor that fired. Read its trigger
condition. Identify the time window of the anomaly. Then pivot to logs to see what was happening
in that window."*

---

### H8 — End-to-End Correlation Drill + Power Features (~60 min)

**Goal:** Execute a complete investigation from first signal to root cause in one unbroken flow.

Topics:
- The full pivot chain: Monitor alert → Log Explorer (find the spike) → Log-to-Trace pivot
  (click `trace_id`) → Flame graph (find the bad span) → Infrastructure (confirm ECS/RDS state)
- Unified timeline: reading multiple signal types on a shared time axis
- The `@` operator deep dive: attribute search vs facet search, indexed vs non-indexed fields
- Searching across services: multi-service log queries, APM cross-service trace search
- DataDog-specific power moves with no Grafana equivalent:
  - Log Patterns (auto-clustering — Loki has nothing equivalent)
  - Watchdog anomaly detection (automatic anomaly surfacing)
  - APM → related logs auto-correlation (no manual trace_id needed)
  - Error Tracking (grouped error fingerprints across services)

**Capstone Drill — Full Incident Reconstruction:**
*"An on-call alert fires. The notification says: 'Error rate on payment-service > 5% for 10
minutes.' Without any prior context, reconstruct the full incident: what failed, when it started,
which component caused it, and what the DB was doing at the time."*

---

## Directory Layout

```
datadog_mastery/
├── README.md                          # quickstart, what this stage covers, how to use PROGRESS.md
├── STRATEGY.md                        # top 1% approach, the 5 mistakes, the 3-pivot pattern
├── PROGRESS.md                        # stage tracker with hour checkboxes, stage 2 handoff notes
├── content/
│   ├── GLOSSARY.md                    # plain-English definitions of all DataDog terms
│   └── day01.md                       # the full 8-hour intensive (H1–H8 blocks)
└── docs/superpowers/
    ├── specs/
    │   └── 2026-09-24-datadog-dashboard-mastery-design.md   ← this file
    └── plans/
        └── (plan to be written)
```

---

## Content Day Skeleton

Each H-block inside `day01.md` follows this structure:

```markdown
## H[N] — [Title] (~60 min)

### Why this matters
<1 short paragraph — concrete incident context, not abstract theory>

### Core concepts
<body of the hour's content — concepts, UI navigation steps, syntax>

### Investigation drill
**Scenario:** <realistic incident prompt using the learner's real stack>
**Steps:**
1. Navigate to ...
2. Filter by ...
3. Look for ...

### Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <what to look for / expected finding>
2. <task> — **Hint:** <hint> — **Solution sketch:** ...

### Anti-patterns
- <what beginners do wrong here and why it wastes time>
```

---

## PROGRESS.md Structure

```markdown
# DataDog Mastery — Progress Tracker

## Stage 1: Dashboard Investigation (8h)

- [ ] H1 — Mental model + navigation
- [ ] H2 — Log Explorer: querying
- [ ] H3 — Log patterns + facets
- [ ] H4 — APM Service Map + Trace Explorer
- [ ] H5 — Flame graphs + API flow
- [ ] H6 — Metrics + Infrastructure (ECS + RDS)
- [ ] H7 — Monitors + alert investigation
- [ ] H8 — End-to-end correlation drill

**Completed:** —
**Stage 1 status:** not started

## Stage 2: Dashboard Creation (planned — not yet built)

Prereqs: all H1–H8 checked above.
Scope: building dashboards, creating monitors, writing alert rules, SLO setup.
Start here: run `/superpowers:brainstorming` with "DataDog Stage 2: Creation".
```
