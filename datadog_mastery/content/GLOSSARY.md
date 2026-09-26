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
