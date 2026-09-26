# DataDog Dashboard Mastery — Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete 8-hour DataDog investigation mastery course for Stage 1 (read-only, dashboard investigation), covering Logs, APM, Metrics/Infrastructure, Alerts, and end-to-end correlation drills.

**Architecture:** Six parallel content files (one per learning block group) plus three scaffold files. All content is markdown. No code, no Terraform, no infrastructure. Practice drills use the learner's real company DataDog (WSO2 API Gateway + Java Spring Boot on ECS Fargate + RDS MySQL).

**Tech Stack:** Markdown only. No dependencies. No build step.

**Spec:** `datadog_mastery/docs/superpowers/specs/2026-09-24-datadog-dashboard-mastery-design.md`

## Global Constraints

- No credentials, tokens, account IDs, or real secrets in any file — use placeholders
- No git commands in any subagent dispatch (no `git status`, `git log`, `git diff`)
- Every exercise must ship with a **Hint:** and a **Solution sketch:** — never a bare problem
- Stack context for all drills: WSO2 API Gateway 4.7 + Java Spring Boot microservices on ECS Fargate + RDS MySQL
- Read-only investigation only — no steps that create dashboards, monitors, or saved views
- No running real infrastructure — all lab steps are navigation and observation only
- DataDog UI references should match the current DataDog UI (2024–2025): left nav, global time selector, Cmd+K quick-switch

---

## File Map

```
datadog_mastery/
├── README.md                              ← Task 1
├── STRATEGY.md                            ← Task 1
├── PROGRESS.md                            ← Task 1
├── content/
│   ├── GLOSSARY.md                        ← Task 2
│   ├── h01_orientation.md                 ← Task 3  (parallel with 2,4,5,6,7)
│   ├── h02_h03_logs.md                    ← Task 4  (parallel with 2,3,5,6,7)
│   ├── h04_h05_apm_traces.md              ← Task 5  (parallel with 2,3,4,6,7)
│   ├── h06_infrastructure.md              ← Task 6  (parallel with 2,3,4,5,7)
│   └── h07_h08_alerts_capstone.md         ← Task 7  (parallel with 2,3,4,5,6)
└── docs/superpowers/
    ├── specs/2026-09-24-datadog-dashboard-mastery-design.md
    └── plans/2026-09-24-datadog-dashboard-mastery-plan.md
```

Tasks 2–7 are all independent and can be dispatched in parallel after Task 1 completes.

---

### Task 1: Scaffold — README + STRATEGY + PROGRESS

**Files:**
- Create: `datadog_mastery/README.md`
- Create: `datadog_mastery/STRATEGY.md`
- Create: `datadog_mastery/PROGRESS.md`

**Interfaces:**
- Produces: foundation files that all content files reference; README links all h*.md files

- [ ] **Step 1: Write `datadog_mastery/README.md`**

Write a README with these exact sections:

```markdown
# DataDog Dashboard Mastery

## What This Is
A single-day 8-hour investigation mastery course for DataDog. Stage 1 covers read-only
investigation: navigating Logs, APM, Metrics, Infrastructure, and Alerts to diagnose
production incidents. No dashboard creation. No alert authoring. Pure investigation skill.

## Who This Is For
Engineers who need to investigate incidents in their company's DataDog and don't want to
spend weeks clicking through the UI to build intuition.

## Prerequisites
- Access to your company's DataDog account (read-only is enough)
- Basic understanding of what logs, metrics, and traces are (you don't need prior DataDog experience)
- Stack context used in drills: WSO2 API Gateway + Java Spring Boot on ECS Fargate + RDS MySQL
  (adapt drill steps to your own service names)

## How to Use This Course
1. Open this README and `PROGRESS.md` side-by-side
2. Work through each hour file in order — each builds on the previous
3. Do the investigation drills in your real DataDog, not a sandbox
4. Check off each hour in `PROGRESS.md` as you complete it

## Course Map

| Hour(s) | File | Focus |
|---------|------|-------|
| H1 | [h01_orientation.md](content/h01_orientation.md) | Mental model + navigation |
| H2–H3 | [h02_h03_logs.md](content/h02_h03_logs.md) | Log Explorer + facets |
| H4–H5 | [h04_h05_apm_traces.md](content/h04_h05_apm_traces.md) | APM + trace investigation |
| H6 | [h06_infrastructure.md](content/h06_infrastructure.md) | ECS + RDS metrics |
| H7–H8 | [h07_h08_alerts_capstone.md](content/h07_h08_alerts_capstone.md) | Alerts + capstone drill |

## Reference
- [GLOSSARY.md](content/GLOSSARY.md) — plain-English DataDog terms
- [STRATEGY.md](STRATEGY.md) — the unconventional approach
- [PROGRESS.md](PROGRESS.md) — your stage tracker

## Stages
- **Stage 1 (this):** Investigation mastery — read and navigate confidently
- **Stage 2 (not yet built):** Creation mastery — dashboards, monitors, SLOs
```

- [ ] **Step 2: Write `datadog_mastery/STRATEGY.md`**

```markdown
# DataDog Investigation Strategy — Top 1% Approach

## The Core Pattern Every Expert Uses

Every DataDog investigation, regardless of incident type, follows the same 3-pivot pattern:

```
Signal → Context → Root Cause
(Alert/Anomaly) → (Logs + correlation) → (Trace or Infra metric)
```

Most engineers treat DataDog's products (Logs, APM, Metrics, Infrastructure) as separate
tools. Experts treat them as one system connected by tags. The `trace_id` field links a log
entry to its distributed trace. The `service` tag links a trace to its infrastructure metrics.
Learning the pivots first — not the individual tools — is what compresses weeks into hours.

## The 5 Mistakes That Waste 80% of Beginners' Time

1. **Learning dashboard creation before reading dashboards.**
   You must read before you write. Stage 1 is read-only by design.

2. **Treating logs, traces, and metrics as three separate tools.**
   DataDog is one investigation surface. Every log has a `trace_id`. Every trace links to
   infrastructure. The moment you learn to pivot between them, investigations take minutes
   instead of hours.

3. **Using the search bar without understanding facets.**
   Facets are the index. Without them, you're doing full-text search on petabytes of logs
   and wondering why results are wrong or missing. Learn facets in H3 before you do anything
   else with logs.

4. **Ignoring service tags and environments.**
   Every DataDog entity is tagged with `service`, `env`, `version`, `host`. Filter by these
   first — always. Beginners skip this and drown in cross-environment noise.

5. **Reading spans manually before scanning the flame graph.**
   The flame graph shows the slow span in 2 seconds by width. Opening each span manually
   takes 10 minutes. Look at the flame graph first.

## How to Use Your Company DataDog for Fast Learning

The fastest path to DataDog fluency is real production data from day 1. For every drill:

1. Find a real service in your company's DataDog (your payment API, your auth service, etc.)
2. Replace the drill's example service names with your real ones
3. Find a recent time window where something was slightly off (elevated latency, some errors)
4. Do the drill against that real event

You don't need a synthetic dataset. You don't need a sandbox. Your company's production logs
from last week are better training data than any tutorial.
```

- [ ] **Step 3: Write `datadog_mastery/PROGRESS.md`**

```markdown
# DataDog Mastery — Progress Tracker

## Stage 1: Dashboard Investigation (8 total hours)

Work through each block in order. Check off each hour when done.

- [ ] H1 — Mental model + navigation (~60 min) → [h01_orientation.md](content/h01_orientation.md)
- [ ] H2 — Log Explorer: querying + DDQL syntax (~60 min) → [h02_h03_logs.md](content/h02_h03_logs.md)
- [ ] H3 — Log patterns + facets + saved views (~60 min) → [h02_h03_logs.md](content/h02_h03_logs.md)
- [ ] H4 — APM: Service Map + Trace Explorer (~60 min) → [h04_h05_apm_traces.md](content/h04_h05_apm_traces.md)
- [ ] H5 — Flame graphs + API flow investigation (~60 min) → [h04_h05_apm_traces.md](content/h04_h05_apm_traces.md)
- [ ] H6 — Metrics + Infrastructure: ECS + RDS MySQL (~60 min) → [h06_infrastructure.md](content/h06_infrastructure.md)
- [ ] H7 — Monitors + alert investigation (~60 min) → [h07_h08_alerts_capstone.md](content/h07_h08_alerts_capstone.md)
- [ ] H8 — End-to-end correlation capstone drill (~60 min) → [h07_h08_alerts_capstone.md](content/h07_h08_alerts_capstone.md)

**Stage 1 completed:** ___________
**Stage 1 status:** not started

---

## Stage 2: Dashboard Creation (not yet built)

**Prerequisites:** All 8 hours above checked off.

**Scope:** Building dashboards, creating monitors, writing alert rules, SLO setup, notebook
authoring, saved views creation, alert routing and notification configuration.

**To start Stage 2:** Run `/superpowers:brainstorming` with the prompt:
> "DataDog Stage 2: Dashboard Creation — I've completed Stage 1 (investigation mastery).
> Now I want to learn to create dashboards, monitors, and alert rules."

---

## Notes

Add any notes from your investigation sessions here:

```

- [ ] **Step 4: Verify all three files exist and have required sections**

```bash
grep -q "Course Map" datadog_mastery/README.md && echo "README OK"
grep -q "3-pivot" datadog_mastery/STRATEGY.md && echo "STRATEGY OK"
grep -q "Stage 2" datadog_mastery/PROGRESS.md && echo "PROGRESS OK"
```

Expected: all three lines print `OK`.

---

### Task 2: GLOSSARY

**Files:**
- Create: `datadog_mastery/content/GLOSSARY.md`

**Interfaces:**
- Consumes: nothing (standalone reference)
- Produces: plain-English definitions linked from h*.md files

- [ ] **Step 1: Write `datadog_mastery/content/GLOSSARY.md`**

Write a GLOSSARY with these exact sections and at minimum all terms listed below. Each entry: term in bold, 1–3 sentence plain-English definition, no jargon in the definition unless the jargon term is also defined in the same glossary. Group terms under headers.

```markdown
# DataDog Glossary — Plain English

## Core Concepts

**APM (Application Performance Monitoring)**
DataDog's system for tracing requests as they travel through your services. APM shows you
exactly which function calls, database queries, and external HTTP calls happened during a
request, and how long each one took.

**Distributed Trace**
The complete record of a single request as it moves through multiple services. A trace for
a payment API call might show: WSO2 gateway (50ms) → Spring Boot payment service (200ms)
→ RDS MySQL query (180ms). The full chain in one view.

**Span**
One unit of work inside a distributed trace. A trace is made of many spans. Each span
represents one function call, one database query, or one HTTP call to another service. Spans
have a start time, duration, service name, and resource name.

**Flame Graph**
The visual display of a trace's spans as horizontal bars on a time axis. Wider bar = longer
duration. Nested bars = one service calling another. Reading the flame graph lets you see the
bottleneck in 2 seconds without opening individual spans.

**Service Map**
The visual graph of all your services and how they call each other. Each node is a service;
edges are calls between services. Node colour shows health: green = healthy, yellow = degraded,
red = elevated errors. The Service Map is your first stop for "which service is the problem."

**Tag**
A key:value label attached to every DataDog entity — logs, traces, metrics, monitors,
infrastructure. The four most important tags: `service`, `env` (environment), `version`,
`host`. All investigation filtering starts with tags.

**Environment (`env` tag)**
The deployment stage a service is running in: `env:production`, `env:staging`, `env:dev`.
Always filter by environment before investigating — mixing production and staging data gives
meaningless results.

**`trace_id`**
The unique identifier that links a log entry to its distributed trace. When you see a 500
error in a log, click the `trace_id` field to jump directly to the full trace for that
request. This is the most important pivot in DataDog.

---

## Logs

**Log Explorer**
The main DataDog UI for searching and browsing logs. Has a search bar (DDQL), a time
range selector, a facets panel, and the log stream. Where you spend most of your
investigation time for errors and anomalies.

**DDQL (Datadog Query Language)**
The query syntax used in Log Explorer's search bar. Examples:
`service:payment-service status:error` — logs from the payment service with ERROR status.
`@http.status_code:500` — logs with HTTP 500 status (the `@` prefix means a log attribute).
`-service:health-check` — exclude health-check service logs.

**Facet**
A structured, indexed field in your logs that DataDog knows how to aggregate and filter.
Facets appear in the left panel of Log Explorer. `service`, `status`, `host`,
`@http.status_code` are common facets. Filtering by facets is faster and more reliable than
free-text search.

**Log Pattern**
DataDog's automatic clustering of similar log messages into groups. Log patterns collapse
1000 nearly-identical error messages into one row showing "N occurrences." Useful for
spotting new error types in a noisy stream.

**Log Analytics**
The aggregation view in Log Explorer that shows log counts graphed over time. Switch between
"List" (individual logs) and "Analytics" (counts and groupings) with the view toggle.

**Saved View**
A stored set of Log Explorer filters, columns, and time range. Teams create saved views for
common investigations: "production 5xx errors" or "payment service errors." Saved views are
read-only shortcuts to a pre-configured investigation state.

---

## APM

**Trace Explorer**
The search interface for distributed traces. Works like Log Explorer but for traces: filter
by `service`, `resource`, `http.status_code`, `duration`, `error`. Returns a list of
matching traces with p50/p95/p99 latency statistics.

**Service Catalog**
The registry of all instrumented services in your DataDog account. Each service has an
overview page showing error rate, latency trends, deployment history, and the service's
owner team. Use it to get baseline health before diving into traces.

**Resource**
The name of a specific operation inside a service — usually an endpoint name or database
query template. `resource:POST /api/v1/payment` identifies all traces for that specific
endpoint.

**Span Metadata**
The key-value attributes attached to a span. For an HTTP span: method, URL, status code.
For a database span: the SQL query, row count, table name. Span metadata is where you find
the actual error message or the slow SQL query.

**Error Tracking**
DataDog's automatic grouping of similar errors across services into "issues." Instead of
seeing 10,000 individual NullPointerException log entries, Error Tracking shows one issue
with a count, a stack trace, and a trend graph.

---

## Infrastructure and Metrics

**Infrastructure Map**
The visual view of your hosts, containers, and ECS tasks. Shows CPU, memory, and network
usage per container as coloured hexagons. Red/orange = high utilisation. Use it to spot
which ECS task is consuming resources.

**Metrics Explorer**
The interface for browsing and graphing individual metrics. Use it to look up what a metric
is named, understand its dimensions (tags), and see its current values. Not for building
dashboards — for ad-hoc investigation.

**Dashboard**
A collection of widgets showing metrics, logs, and APM data on a shared canvas. Dashboards
are read-only during Stage 1. Your company's existing dashboards (ECS performance, RDS
health, API gateway metrics) are your primary investigation surface.

**Monitor**
DataDog's term for an alert rule. A monitor watches a metric, log query, APM error rate,
or other signal and fires when a condition is met (e.g., "error rate > 5% for 10 minutes").
Monitors send notifications to PagerDuty, Slack, or email.

---

## Alerting

**Monitor Status**
The current health state of a monitor: `OK` (condition not met), `WARN` (approaching
threshold), `ALERT` (threshold crossed, notification sent), `NO DATA` (no signal received —
often means the service is down).

**Alert History**
The timeline of state transitions for a monitor: when it went from OK → ALERT, when it
recovered, what the metric value was at each transition. Use alert history to reconstruct
when an incident started and ended.

**Composite Monitor**
A monitor that combines multiple other monitors with AND/OR logic. Example: "alert if
error rate > 5% AND latency p95 > 2s." Reading a composite monitor means reading all its
component monitors.

**Muted Monitor**
A monitor temporarily silenced during a maintenance window. A muted monitor still evaluates
its condition but suppresses notifications. Appears with a mute icon in the monitor list.

---

## DataDog-Specific Power Features

**Watchdog**
DataDog's automatic anomaly detection. Watchdog scans your APM metrics and infrastructure
metrics for deviations from baseline without any configuration. Watchdog alerts appear as
dog-paw icons in dashboards and APM views. No equivalent in Grafana.

**Unified Timeline**
A shared time axis that shows logs, traces, deploys, and monitor state changes together.
Available inside a Dashboard or trace detail view. Use it to correlate "the alert fired at
14:32" with "a deploy happened at 14:30."

**Notebook**
DataDog's collaborative investigation document. A notebook combines text, graphs, and log
queries in a single shareable page. Teams use notebooks to document incident postmortems.
```

- [ ] **Step 2: Verify term count and required sections**

```bash
grep -c "^\*\*" datadog_mastery/content/GLOSSARY.md
```

Expected: 25 or more.

```bash
grep -q "trace_id" datadog_mastery/content/GLOSSARY.md && \
grep -q "Flame Graph" datadog_mastery/content/GLOSSARY.md && \
grep -q "DDQL" datadog_mastery/content/GLOSSARY.md && \
echo "GLOSSARY key terms OK"
```

Expected: prints `GLOSSARY key terms OK`.

---

### Task 3: H1 — Orientation Hour

**Files:**
- Create: `datadog_mastery/content/h01_orientation.md`

**Interfaces:**
- Consumes: nothing (first hour, no prerequisites)
- Produces: mental model + navigation orientation; learner can find any product area

- [ ] **Step 1: Write `datadog_mastery/content/h01_orientation.md`**

Write the file with this exact structure. Fill every section with real, detailed content — no placeholders.

```markdown
# H1 — DataDog Mental Model + Navigation (~60 min)

## Why This Matters

The single biggest time-waster for new DataDog users is not knowing where to look. DataDog
has dozens of product areas, and the left navigation changes based on what you've recently
visited. Spending 5 minutes on orientation here saves 30 minutes of clicking in circles on
every subsequent investigation.

## Core Concepts

### DataDog's Product Taxonomy

DataDog is not one tool — it is a platform with distinct products that share a common data
model. Understanding what each product does and when to use it is the foundation of fast
investigations.

| Product | Where | What it answers |
|---------|-------|----------------|
| **Logs** | Logs → Explorer | "What happened? What error message?" |
| **APM** | APM → Traces | "Which service was slow? Which span failed?" |
| **Infrastructure** | Infrastructure → Containers | "Is the container healthy? CPU/memory OK?" |
| **Metrics** | Metrics → Explorer | "What does this metric look like over time?" |
| **Dashboards** | Dashboards | "What is the overall system health right now?" |
| **Monitors** | Monitors → Manage Monitors | "What alerts have fired? What conditions trigger them?" |

### The Tagging System — The Most Important Concept in DataDog

Every entity in DataDog — every log line, every trace, every metric data point, every alert —
carries tags. Tags are `key:value` pairs. The four you will use in every investigation:

- `service:<name>` — which service produced this data (e.g., `service:payment-api`)
- `env:<environment>` — which deployment environment (e.g., `env:production`)
- `version:<tag>` — which deployed version (e.g., `version:1.4.2`)
- `host:<hostname>` — which host or ECS task produced this data

**Rule #1:** Always set `env:production` in the global environment filter before investigating.
Mixing environments produces meaningless results.

### The Global Controls — Set These First on Every Session

Before doing anything else, check these two controls at the top of every DataDog page:

1. **Time selector** (top right): defaults to "Past 1 Hour." For incident investigation,
   change this to the time window around the incident. For exploration, "Past 15 Minutes" or
   "Past 1 Hour" is fine.

2. **Environment filter** (top bar, appears after setup): set to `production`. If your
   company uses a different env tag value, use that.

### Navigation

**Left navigation structure:**
- The left nav is the primary way to switch between product areas
- It collapses to icons at narrow widths — hover to see labels
- Frequently visited sections pin themselves to the top

**Keyboard shortcut:** `Cmd+K` (Mac) / `Ctrl+K` (Windows/Linux) opens the universal search
and quick-nav. Type any service name, dashboard name, or product area to jump directly.
This is the fastest way to navigate once you know what you're looking for.

**Breadcrumbs:** DataDog shows your navigation path at the top of most pages. Use it to
understand where you are and navigate back.

### DataDog vs Grafana — A Quick Orientation

If you've touched Grafana before, here's a one-line mapping to reduce confusion:

| Grafana concept | DataDog equivalent |
|---|---|
| Loki (log store) | DataDog Logs |
| Log query (LogQL) | DDQL in Log Explorer |
| Tempo (traces) | DataDog APM |
| VictoriaMetrics / Prometheus | DataDog Metrics |
| Grafana Alert | DataDog Monitor |
| Grafana Dashboard | DataDog Dashboard |

The key difference: DataDog integrates all of these in one platform with native correlation
(one click from a log to its trace, one click from a trace to its infra metrics). In Grafana,
that cross-product correlation is manual configuration work.

## Investigation Drill

**Scenario:** You've just been added to the DataDog on-call rotation. Your first task: verify
you can navigate to your team's key services without help.

**Steps:**
1. Open your company's DataDog. Set the time range to "Past 1 Hour."
2. Set the environment filter to `env:production` (or your company's production env tag).
3. Navigate to **APM → Service Catalog**. Find the WSO2 gateway service (look for a name
   containing "gateway", "wso2", or "apim"). Note its current error rate and p99 latency.
4. Navigate to **Logs → Explorer**. In the search bar, type `service:<your-gateway-service-name>`.
   Confirm logs appear. Note the volume (number of logs per minute).
5. Navigate to **Infrastructure → Containers**. Find the ECS tasks running your gateway service.
   Note their CPU and memory usage.
6. Use `Cmd+K` to jump directly to your company's main service dashboard (search for
   "dashboard" + a service keyword). Confirm you can find it in under 10 seconds.
7. Navigate to **Monitors → Manage Monitors**. Filter by `service:<your-gateway-name>`.
   Note how many monitors exist and their current status.

You've now touched every major product area. The rest of the course is learning each one deeply.

## Exercises

1. **Navigate to the Service Map** (APM → Service Map). Find the WSO2 gateway node.
   How many downstream services does it call?
   — **Hint:** APM is in the left nav; Service Map is a sub-menu item. Zoom out if the map
   is crowded. Click on the gateway node to see its edges.
   — **Solution sketch:** The gateway node should show arrows to each downstream Spring Boot
   service. The number of edges equals the number of services the gateway routes to. A typical
   company setup shows 3–15 downstream services.

2. **Find the p99 latency for your payment or main API service** using the Service Catalog.
   — **Hint:** APM → Service Catalog → search for the service name → click the service →
   look for the latency panel.
   — **Solution sketch:** The Service Catalog page for a service shows a latency trend graph
   with p50/p75/p95/p99 lines. P99 is the slowest 1% of requests. A healthy REST API
   typically shows p99 < 500ms; anything over 2s warrants investigation.

3. **Set a bookmark or note the exact URL path** for the Log Explorer pre-filtered to your
   production gateway service. You will use this URL many times during investigations.
   — **Hint:** Apply the filter `service:<name> env:production` in Log Explorer, then copy
   the browser URL — DataDog encodes the filter state in the URL.
   — **Solution sketch:** The URL will look like
   `https://app.datadoghq.com/logs?query=service%3Agateway%20env%3Aproduction&...`.
   Save this in your bookmarks bar.

## Anti-Patterns

- **Skipping the global environment filter.** Without `env:production`, you're looking at
  all environments mixed together. Staging errors will look like production incidents.
- **Clicking through the left nav randomly instead of using Cmd+K.** The nav has 20+ items.
  Cmd+K is 3 keystrokes to anywhere. Use it from the first day.
- **Not noting service names.** Your company's DataDog services are named by the dev team
  (e.g., `payment-service`, `pmt-svc`, `paymentapi` — anything goes). Look them up in the
  Service Catalog once and note them down. Every subsequent filter depends on knowing the
  exact `service:` tag value.
```

- [ ] **Step 2: Verify file structure**

```bash
grep -q "3-pivot\|3 Pivot\|pivot" datadog_mastery/content/h01_orientation.md || \
grep -q "Investigation Drill" datadog_mastery/content/h01_orientation.md && echo "H1 OK"
grep -q "Solution sketch" datadog_mastery/content/h01_orientation.md && echo "H1 exercises have solutions OK"
grep -q "Anti-Patterns\|Anti-patterns" datadog_mastery/content/h01_orientation.md && echo "H1 anti-patterns OK"
```

Expected: all three print `OK`.

---

### Task 4: H2–H3 — Log Investigation

**Files:**
- Create: `datadog_mastery/content/h02_h03_logs.md`

**Interfaces:**
- Consumes: H1 navigation orientation (learner can reach Log Explorer)
- Produces: DDQL query skill + facet understanding + log pattern reading

- [ ] **Step 1: Write `datadog_mastery/content/h02_h03_logs.md`**

Write the file with this exact structure covering both H2 and H3. Every section must have real, detailed content.

```markdown
# H2–H3 — Log Investigation (2 × ~60 min)

## Why This Matters

Logs are the first place every engineer goes when something breaks. But without knowing
DataDog's query syntax and facet system, you'll either see too much (noise from all services)
or too little (your query matches nothing). These two hours turn Log Explorer from a
frustrating search box into a precision investigation tool.

---

# H2 — Log Explorer: Querying and Filtering (~60 min)

## Core Concepts

### Log Explorer Layout

The Log Explorer has four zones:
1. **Search bar** (top): where you write DDQL queries
2. **Time range selector** (top right): always set this to the incident window
3. **Facets panel** (left): indexed fields you can click to filter
4. **Log stream** (center): the matching log entries, newest first by default

### DDQL Syntax — The Complete Reference for Investigation

DDQL (DataDog Query Language) uses a tag:value model. Memorise these patterns:

**Filter by service:**
```
service:payment-api
```

**Filter by status level:**
```
status:error
status:warn
```

**Filter by HTTP status code (attribute search — note the `@`):**
```
@http.status_code:500
@http.status_code:[400 TO 599]
```

**Combine conditions (AND is implicit with spaces):**
```
service:payment-api status:error @http.status_code:500
```

**OR condition:**
```
service:payment-api OR service:auth-service
```

**Exclude a service:**
```
-service:health-check
```

**Wildcard in a value:**
```
service:payment*
```

**Free text search (searches the log message body):**
```
"NullPointerException"
"Connection refused"
```

**Time-bounded search:** Use the time picker, not a query clause. Set "Past 15 Minutes"
for recent incidents, custom range for historical reconstruction.

### Log Status Levels

DataDog normalises log severity into: `EMERGENCY`, `ALERT`, `CRITICAL`, `ERROR`, `WARNING`,
`NOTICE`, `INFO`, `DEBUG`. In your WSO2 + Spring Boot logs, you'll most often see:
- `ERROR` — something failed; investigation required
- `WARN` — something unexpected but handled; worth watching
- `INFO` — normal operation; useful for tracing request flow

### Reading a Log Entry

Click any log in the stream to open the detail panel. Key fields to look for:
- **Message:** the raw log text
- **service:** which service produced it
- **trace_id:** if present, click it to jump to the distributed trace for this request
- **@http.status_code:** HTTP response status (for access logs)
- **@error.message** and **@error.stack:** for error logs, the exception message and stack trace
- **host:** the ECS task / container that produced this log

### The `trace_id` Pivot — The Most Powerful Click in DataDog

When you find an error log, look for the `trace_id` field in the detail panel. Click it.
DataDog opens the distributed trace for that exact request — showing you every service call,
every DB query, and every span that was part of the request that produced that error. This
is the fastest path from "I found an error" to "I know which service and which line caused it."

## Investigation Drill — Error Rate Spike

**Scenario:** Your alerting system shows a spike in 5xx errors at 14:30 today. Find which
service and endpoint is throwing them.

**Steps:**
1. Open Log Explorer. Set time range to the 15-minute window around 14:30.
2. Set the environment filter to `env:production`.
3. Type this query in the search bar: `status:error @http.status_code:[500 TO 599]`
4. Look at the log stream. Which `service:` appears most frequently in the results?
5. Narrow down: `service:<the-culprit-service> status:error @http.status_code:500`
6. Click one of the error logs. Open the detail panel.
7. Look at the `@error.message` or `message` field. What is the error?
8. Look for a `trace_id` field. If present, note it — you will use it in H5.

**Expected finding:** You should see error logs clustered around one service. The error
message will suggest the failure type (DB connection refused, upstream timeout, NPE, etc.).

## Exercises

1. **Find all 401 Unauthorized responses from the WSO2 gateway in the last hour.**
   — **Hint:** The gateway service name in your DataDog might be `wso2-gateway`, `apim`,
   or similar. Use `service:<name> @http.status_code:401`. If `@http.status_code` returns
   nothing, try `status:error` and scan the messages for "401" text.
   — **Solution sketch:** You should see log entries with HTTP 401 responses. Look at whether
   they come from one client IP (`@network.client.ip`) or many — one IP suggests a
   misconfigured client; many IPs suggest an auth provider issue.

2. **Find the top 5 error messages from your Spring Boot services in the last 24 hours.**
   — **Hint:** Filter `status:error` then switch to Analytics view (the chart icon near the
   search bar). Group by `@error.message` or `message`. Sort by count descending.
   — **Solution sketch:** The Analytics view shows a bar chart grouped by your chosen field.
   The tallest bars are the most frequent errors. Common ones: `Connection pool exhausted`,
   `Timeout`, `NullPointerException`, `HTTP 500`.

3. **Find a log entry that has a `trace_id` and note the trace_id value.**
   — **Hint:** In the facets panel, look for a `Traces` section or search for logs with
   `@dd.trace_id:*` (asterisk matches any value). Alternatively, filter `status:error` and
   click log entries until you find one with a trace_id field.
   — **Solution sketch:** The `trace_id` appears as a 64-character hex string in the detail
   panel under `@dd.trace_id` or similar. Note it — you'll use this field's pivot in H5.

---

# H3 — Log Patterns, Facets, and Analytics (~60 min)

## Core Concepts

### Facets — The Log Index

Facets are the indexed, structured fields DataDog knows how to aggregate. They appear in the
left panel of Log Explorer. Click any facet value to add it as a filter.

**Default facets (always available):**
- `Status` — ERROR / WARN / INFO / DEBUG
- `Service` — your service names
- `Host` — the container/task hostname
- `Source` — the log source (e.g., java, nginx, aws)

**Custom facets (set up by your team):**
- `@http.status_code`, `@http.method`, `@http.url` — HTTP request attributes
- `@error.type`, `@error.message` — exception details
- `@db.statement` — SQL query text (if DB query logging is enabled)

**Key rule:** If a field appears in the facets panel, filter by clicking it. If it doesn't
appear, you can still search with `@field_name:value` in the search bar — but it will be
slower (full-scan, not indexed).

### Log Patterns — Cutting Through Noise

Log Patterns automatically clusters similar log messages. When your service produces 50,000
very similar error lines like:
```
Connection to mysql-host:3306 failed after 500ms (attempt 1/3)
Connection to mysql-host:3306 failed after 500ms (attempt 2/3)
```
Log Patterns collapses them into one row showing `N occurrences` of a template. This lets
you see the shape of problems without scrolling through thousands of near-identical lines.

**To use Log Patterns:** In Log Explorer, switch from "List" to "Patterns" using the view
selector near the search bar. The patterns view shows:
- Pattern template (with wildcards for variable parts)
- Count of matching logs
- Sample log entry
- Time distribution graph

### Log Analytics — Graphing Log Volume

Log Analytics graphs log counts over time grouped by any facet. Use it to answer:
- "When exactly did the error spike start?"
- "Which service is producing the most errors?"
- "Is the error rate still going up or has it stabilized?"

**To use:** Switch to "Analytics" view. The x-axis is time. Choose a group-by field from
the "Group by" dropdown (e.g., `service`, `@http.status_code`, `@error.type`).

### Saved Views — Read-Only Navigation Shortcuts

Your team has likely created saved views for common investigations. To access them:
- Click the "Views" dropdown in the top-left of Log Explorer
- Select a saved view to apply its pre-set filters and columns

**Stage 1 rule:** Browse saved views, don't create them. Creating saved views is Stage 2.

## Investigation Drill — WSO2 Auth Failure Analysis

**Scenario:** You see a spike in 401/403 responses. Determine whether this is one
misconfigured client hammering the gateway or a widespread auth provider issue.

**Steps:**
1. Open Log Explorer. Filter: `service:<wso2-gateway-name> @http.status_code:[401 TO 403]`
2. Switch to **Patterns** view. Look at the top patterns — is it one repeating message?
3. Switch back to **List** view. Open one 401 log. Look at the `@network.client.ip` or
   `@http.request.headers.x-forwarded-for` field. Note the client IP.
4. Now switch to **Analytics** view. Group by the client IP facet (if available) or
   `@network.client.ip`. Which client IP has the highest count?
5. Switch to group by `@http.url` or `resource` — which endpoint is being hit most?
6. Conclusion: if one IP dominates → misconfigured client. If many IPs → auth provider issue.

## Exercises

1. **Use Log Patterns to identify the most frequent error pattern from your Spring Boot services.**
   — **Hint:** Filter `status:error service:<spring-boot-service>`, switch to Patterns view,
   look at the top row by count.
   — **Solution sketch:** The top pattern is usually a connection error, timeout, or
   NullPointerException. The template shows `*` where the variable parts (timestamps,
   IDs) were removed. Click the pattern to see sample logs.

2. **Use Log Analytics to graph 5xx errors per minute for the last 2 hours. Identify the exact minute the error spike started.**
   — **Hint:** Filter `status:error @http.status_code:[500 TO 599]`, switch to Analytics,
   set interval to "1 minute," hover over the spike in the graph.
   — **Solution sketch:** The graph shows bars per minute. The spike appears as a sudden
   height increase. Hover the mouse over the spike to see the exact timestamp and count.
   Note this timestamp — it will anchor your trace and infrastructure investigation.

3. **Find a log entry from a Spring Boot service that contains a full Java stack trace.**
   — **Hint:** Filter `service:<spring-boot-service> status:error`. In the log stream, look
   for entries with long messages. The detail panel for Java error logs usually has
   `@error.stack` containing the stack trace.
   — **Solution sketch:** A Java stack trace in DataDog looks like:
   `java.lang.NullPointerException: null\n\tat com.example.PaymentService.process(PaymentService.java:45)\n\tat ...`
   The first line is the exception type. The second line is where it was thrown. That's your
   starting point for the fix.

## Anti-Patterns

- **Using free-text search for everything.** Free text searches the raw log body — it's slow
  and imprecise. `"500"` matches log lines that contain "500" anywhere, including timestamps.
  Use `@http.status_code:500` instead — it searches the indexed attribute.
- **Forgetting the `@` prefix for log attributes.** `http.status_code:500` (no `@`) searches
  for a tag. `@http.status_code:500` searches a log attribute. They are different things.
  Missing the `@` returns zero results and looks like a DataDog bug.
- **Switching to Patterns view and ignoring the count column.** The count tells you which
  patterns matter. A pattern with 1 occurrence is noise. A pattern with 50,000 occurrences
  is the incident.
- **Not using Log Analytics before the log list.** Analytics tells you *when* the problem
  happened and *how much* in 5 seconds. The log list tells you *what* happened. Always
  orient with Analytics first when the time window is unclear.
```

- [ ] **Step 2: Verify file structure**

```bash
grep -q "DDQL" datadog_mastery/content/h02_h03_logs.md && echo "H2H3 DDQL OK"
grep -q "trace_id" datadog_mastery/content/h02_h03_logs.md && echo "H2H3 trace_id OK"
grep -q "Solution sketch" datadog_mastery/content/h02_h03_logs.md && echo "H2H3 exercises OK"
grep -q "Anti-Patterns\|Anti-patterns" datadog_mastery/content/h02_h03_logs.md && echo "H2H3 anti-patterns OK"
```

Expected: all four print `OK`.

---

### Task 5: H4–H5 — APM and Trace Investigation

**Files:**
- Create: `datadog_mastery/content/h04_h05_apm_traces.md`

**Interfaces:**
- Consumes: H2–H3 (learner can find a `trace_id` in logs and knows what a service tag is)
- Produces: ability to navigate Service Map, read a flame graph, identify a slow or failing span

- [ ] **Step 1: Write `datadog_mastery/content/h04_h05_apm_traces.md`**

Write the file covering both H4 and H5. Key requirement: both investigation scenarios must reference the WSO2 API Gateway → Spring Boot → RDS MySQL chain explicitly. Every exercise must have a Hint and Solution sketch.

The file must cover these topics with real detail:

**H4 topics (must include):**
- APM product areas overview (Service Map, Trace Explorer, Service Catalog, APM Metrics)
- Service Map reading: node colours, edge labels, how to read WSO2 → Spring Boot → MySQL
- Trace Explorer search syntax: `service:`, `resource:`, `status:error`, `@duration:>2s`
- Reading the trace list: p50/p95/p99 columns, error count, hit count
- Opening a trace: timeline view vs span list
- Investigation Scenario: latency complaint → find the slow service on Service Map

**H5 topics (must include):**
- Flame graph anatomy: x-axis = time, bar width = duration, nesting = call chain
- Reading span metadata: resource name, HTTP method/URL, DB query, status code, error message
- Identifying the critical path (the widest/deepest chain)
- How database spans appear: RDS MySQL query text, row count, duration
- Error spans: reading the error type + message + Java stack trace in a span
- Cross-service propagation: how trace_id links WSO2 → Spring Boot → MySQL spans in one flame graph
- The log correlation panel inside a trace (clicking "Logs" tab in trace detail)
- Investigation Scenario: 4s trace → flame graph → identify whether bottleneck is WSO2, Spring Boot, or MySQL

**Both hours must include:** Investigation drills with step-by-step navigation, 3 exercises each with Hint + Solution sketch, Anti-patterns section.

- [ ] **Step 2: Verify**

```bash
grep -q "Flame" datadog_mastery/content/h04_h05_apm_traces.md && echo "H4H5 flame graph OK"
grep -q "WSO2\|wso2" datadog_mastery/content/h04_h05_apm_traces.md && echo "H4H5 stack ref OK"
grep -q "Solution sketch" datadog_mastery/content/h04_h05_apm_traces.md && echo "H4H5 exercises OK"
grep -q "Anti-Patterns\|Anti-patterns" datadog_mastery/content/h04_h05_apm_traces.md && echo "H4H5 anti-patterns OK"
```

Expected: all four print `OK`.

---

### Task 6: H6 — Infrastructure Investigation

**Files:**
- Create: `datadog_mastery/content/h06_infrastructure.md`

**Interfaces:**
- Consumes: H4–H5 (learner knows what a service tag is and can find a time window from a trace)
- Produces: ability to read ECS container metrics and RDS MySQL dashboard panels

- [ ] **Step 1: Write `datadog_mastery/content/h06_infrastructure.md`**

Write the file covering H6. Every section must have real, detailed content.

**Required topics (must include):**

- Infrastructure product area overview: Host Map, Containers, Processes
- ECS Fargate container view: how to find your ECS tasks, what columns mean
- Key ECS metrics to know by name:
  - `aws.ecs.service.running_count` — number of running tasks
  - `container.cpu.usage` — CPU used vs CPU limit
  - `container.memory.usage` — memory used vs memory limit
  - `container.net.rcvd.bytes` and `container.net.sent.bytes` — network I/O
- Reading for OOM (Out of Memory Kill): memory usage trending to limit → task count drops → gap in traces
- RDS MySQL key metrics panel (what a well-configured RDS dashboard shows):
  - `aws.rds.database_connections` — current active connections
  - `aws.rds.free_storage_space` — disk remaining
  - `aws.rds.read_latency` and `aws.rds.write_latency` — read/write speed
  - `aws.rds.queries` — queries per second
  - `aws.rds.deadlocks` — deadlock count
  - `mysql.performance.slow_queries` — slow query count (from the MySQL integration)
- How to correlate a metric event (CPU spike, connection exhaustion) to a time range in Log Explorer
- Investigation Scenario: RDS connection exhaustion → find when `aws.rds.database_connections` crossed the limit → pivot to logs for that time window
- 3 exercises with Hint + Solution sketch covering ECS OOM reading, RDS slow queries, and metric-to-log correlation
- Anti-patterns section

- [ ] **Step 2: Verify**

```bash
grep -q "aws.rds" datadog_mastery/content/h06_infrastructure.md && echo "H6 RDS metrics OK"
grep -q "ECS\|ecs" datadog_mastery/content/h06_infrastructure.md && echo "H6 ECS OK"
grep -q "Solution sketch" datadog_mastery/content/h06_infrastructure.md && echo "H6 exercises OK"
grep -q "Anti-Patterns\|Anti-patterns" datadog_mastery/content/h06_infrastructure.md && echo "H6 anti-patterns OK"
```

Expected: all four print `OK`.

---

### Task 7: H7–H8 — Alerts and Capstone Drill

**Files:**
- Create: `datadog_mastery/content/h07_h08_alerts_capstone.md`

**Interfaces:**
- Consumes: H1–H6 (all prior skills — this hour uses every pivot learned so far)
- Produces: ability to read any monitor definition + execute a full alert → log → trace → infra investigation

- [ ] **Step 1: Write `datadog_mastery/content/h07_h08_alerts_capstone.md`**

Write the file covering both H7 and H8. The H8 capstone drill is the most important section — it must be fully detailed, step-by-step, and must reference the full pivot chain explicitly.

**H7 required topics:**
- Monitors product area: monitor list, status colours (OK / WARN / ALERT / NO DATA)
- Monitor detail page anatomy:
  - The query section: what metric/log/trace is being evaluated
  - The condition section: the threshold and evaluation window
  - The notification section: who gets paged and how
  - The tags section: `service:`, `env:`, `team:` tags on the monitor itself
- Alert history: timeline of state transitions, how to read when it went OK → ALERT → OK
- Monitor types and how to read each:
  - Metric monitor: watching a numeric threshold (e.g., error rate > 5%)
  - Log monitor: watching log query result count (e.g., ERROR logs > 100/min)
  - APM monitor: watching error rate or p99 latency from a specific service
- Composite monitors: how to read the AND/OR tree
- Muted monitors: what the mute icon means, how to check the mute expiry
- Investigation Scenario: a monitor fired at 2am → open it → read its condition → read its alert history → identify the time window → pivot to logs

**H8 required topics (capstone — must be the most detailed section):**
- The full 3-pivot pattern written out as exact navigation steps:
  1. Monitors → find the fired alert → read its time window and affected service tag
  2. Log Explorer → filter `service:<from-alert> status:error env:production` + set time range from alert
  3. Find an error log with a `trace_id` → click trace_id → open the trace
  4. Read the flame graph → identify the slow or failing span
  5. Check the span's service → go to Infrastructure → find that service's ECS tasks → check CPU/memory at the alert time
- DataDog power features with no Grafana equivalent:
  - Watchdog anomaly alerts (what they look like, where to find them)
  - APM → Logs auto-correlation (the "Logs" tab in a trace detail page)
  - Error Tracking (grouped error fingerprints — where to find it)
  - Unified timeline (logs + deploys + alerts on one axis — where to find it)
- Capstone Drill: full incident reconstruction
  - Scenario: "An on-call alert fires: Error rate on payment-service > 5% for 10 minutes. No prior context. Reconstruct the full incident."
  - Full step-by-step navigation (12+ steps), from opening the monitor to identifying the root cause service and DB query
- 3 exercises with Hint + Solution sketch
- Anti-patterns section
- Closing section: "You've completed Stage 1. Update your PROGRESS.md and plan Stage 2."

- [ ] **Step 2: Verify**

```bash
grep -q "3-pivot\|pivot chain\|pivot pattern\|Signal.*Context.*Root\|alert.*log.*trace" \
  datadog_mastery/content/h07_h08_alerts_capstone.md && echo "H7H8 capstone pivot OK"
grep -q "Watchdog" datadog_mastery/content/h07_h08_alerts_capstone.md && echo "H7H8 power features OK"
grep -q "Solution sketch" datadog_mastery/content/h07_h08_alerts_capstone.md && echo "H7H8 exercises OK"
grep -q "PROGRESS\|Stage 2" datadog_mastery/content/h07_h08_alerts_capstone.md && echo "H7H8 closing OK"
```

Expected: all four print `OK`.
