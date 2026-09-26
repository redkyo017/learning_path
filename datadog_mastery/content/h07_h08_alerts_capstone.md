# H7–H8 — Monitors, Alerts, and End-to-End Correlation (2 × ~60 min)

## Why This Matters

Every investigation you have practiced so far was reactive: you already knew something was wrong and were refining the picture. Monitors are the layer that tells you *before* you find out from a user complaint. More importantly, a well-constructed monitor gives you a pre-packaged investigation brief: it names the service, the condition that fired, the exact time window, and the team responsible. A monitor is not just an alarm — it is a structured artifact that encodes weeks of on-call learning.

The 2am call is the test. You have no prior context. The alert fired 8 minutes ago. Users are hitting errors. Your job in the next 15 minutes is to move from "something is wrong" to "the payment-service order_processor span is failing because the RDS MySQL instance ran out of connections at 01:52 UTC, and here is the slow SQL query that caused it." This pair of hours builds every skill you need for that 15-minute reconstruction.

---

# H7 — Monitors + Alert Investigation (~60 min)

## Core Concepts

### The Monitors Product Area

Navigate to **Monitors → Manage Monitors** in the left sidebar. This is the authoritative list of every automated check your team has configured. It is the first place to go when you receive an alert notification — the notification message usually includes a direct link, but knowing how to find it manually matters when the link is missing or you are debugging a silently misfiring monitor.

**Monitor list columns:**

| Column | What it shows |
|---|---|
| **Status** | The current state: OK / WARN / ALERT / NO DATA (colour-coded — see below) |
| **Name** | The monitor's display name, usually of the form `[service] — [condition]` |
| **Service** | The `service:` tag on the monitor (not the metric source — the tag the monitor is annotated with) |
| **Tags** | Full tag set on the monitor itself, including `env:`, `team:`, `severity:` |
| **Last triggered** | The most recent time the monitor transitioned into ALERT state |
| **Modified** | When the monitor definition was last edited — important for "did someone change the threshold recently?" |

**Status colour meanings:**

- **Green (OK)** — the monitored condition is within acceptable bounds; all is well
- **Yellow (WARN)** — the monitored value has crossed the warn threshold but not the alert threshold; the system is degrading but not yet broken; a signal to watch, not necessarily to wake someone up
- **Red (ALERT)** — the monitored value has crossed the alert threshold; this is the state that pages people; something requires immediate attention
- **Grey (NO DATA)** — Datadog is not receiving the metric or log data that the monitor depends on; this can mean the service is down (serious) or the instrumentation has broken (also serious); treat NO DATA with the same urgency as ALERT until you know which it is

**Filtering the monitor list:**

Use the search bar and the facets on the left panel. Useful filter combinations:
- `env:production status:alert` — all currently firing production monitors; your starting point during an incident
- `service:payment-service` — every monitor watching the payment service
- `tag:team:platform` — all monitors owned by the platform team
- `type:metric` — only metric-based monitors (hides log and APM monitors)

---

### Monitor Detail Page Anatomy

Click any monitor name to open its detail page. The page has five distinct sections. Understanding each one lets you reconstruct the full context of an alert without asking the person who wrote it.

---

**Query Section**

The query section appears at the top of the monitor configuration panel (click **Edit** to see it fully, or read the summary in the status page header). It answers: *what is being measured?*

For a metric monitor the query looks like this:

```
avg(last_10m):avg:trace.servlet.request.errors{service:payment-service,env:production}.as_count() / avg:trace.servlet.request.hits{service:payment-service,env:production}.as_count() > 0.05
```

Read it left to right:
- `avg(last_10m)` — the evaluation function: average over the last 10 minutes
- `avg:trace.servlet.request.errors{service:payment-service,env:production}.as_count()` — the numerator metric, scoped to the payment-service in production
- divided by the hits metric — computing a ratio
- `> 0.05` — the alert threshold: 5% error rate

For a log monitor the query is a log search string plus an aggregation:

```
logs("service:payment-service status:error env:production").rollup("count").last("5m") > 100
```

This fires when more than 100 error logs appear from payment-service in the last 5 minutes.

For an APM monitor the query references a specific service's APM metric:

```
avg(last_5m):avg:trace.servlet.request.duration.by_http_status{service:payment-service,env:production,http.status_class:5xx} > 2000000000
```

Duration is in nanoseconds; 2,000,000,000 ns = 2 seconds p99 latency.

---

**Condition Section**

The condition section defines the thresholds and the evaluation window. It answers: *what values trigger which states, and over how long?*

Key fields:
- **Alert threshold** — the value that causes a transition to ALERT state (pages people)
- **Warning threshold** — the value that causes a transition to WARN state (optional; creates an early warning before the page fires)
- **Evaluation window** — the time range over which the query is evaluated (e.g., "last 10 minutes"). A shorter window makes the monitor more sensitive (reacts faster but may flap); a longer window makes it more stable (less noise but slower to fire)
- **Require full window** — when checked, the monitor waits until a full evaluation window of data is available before evaluating; avoids false ALERT at startup or after a data gap
- **Recovery threshold** — the value the metric must drop below (or rise above, depending on direction) before the monitor transitions back to OK; prevents flapping if the value hovers near the alert threshold

**Reading a concrete example:**
> Alert threshold: 0.05 | Warning threshold: 0.02 | Evaluation window: last 10 minutes | Recovery threshold: 0.03

This means:
- When error rate reaches 2% for 10 minutes → WARN
- When error rate reaches 5% for 10 minutes → ALERT (page fires)
- Once in ALERT, error rate must drop below 3% (recovery threshold) before returning to OK

---

**Notification Section**

The notification section answers: *who gets paged, through what channel, and what message do they receive?*

Key fields:
- **Notify:** — a list of notification targets; each target is prefixed with its type:
  - `@pagerduty-payment-service-oncall` — creates a PagerDuty incident for the named service's escalation policy
  - `@slack-platform-incidents` — posts a message to the named Slack channel
  - `@ops-team@example.com` — sends an email to that address
- **Message template** — a text block using `{{` template variables `}}` that is included in the notification; good monitor messages include:
  - What fired: `{{#is_alert}}Error rate is {{value}} — threshold is {{threshold}}{{/is_alert}}`
  - The affected service and env (from tags)
  - A link to the relevant dashboard or runbook
- **Include triggering tags in notification title** — when enabled, the alert message title includes the tag values that caused the alert (e.g., `service:payment-service env:production`) which is critical for multi-service monitors that group by tag

Reading the notification section also tells you who was paged. During an incident, if you did not receive the alert yourself, the notification section tells you who did — useful for finding the incident commander.

---

**Tags Section**

The tags section lists the tags applied to the monitor itself (not the metric's tags). These are organisational labels that affect routing, filtering, and dashboards.

Standard tags to look for:

| Tag | Purpose |
|---|---|
| `service:payment-service` | Ties this monitor to a specific service in the Service Catalog |
| `env:production` | Scopes to environment — filtering the monitor list by `env:production` shows only production monitors |
| `team:platform` | Ownership — who maintains and triages this monitor |
| `severity:critical` | Business impact — P1 monitors that always require immediate response |
| `type:latency` | Classification — what kind of condition this monitors |

If a monitor lacks `service:` and `env:` tags it is poorly configured: you will not be able to find it during an incident when filtering by service, and alert notifications may not include enough context to start an investigation.

---

### Alert History — Reading State Transitions

Scroll down on any monitor detail page to find the **Alert History** section. This is a timeline of every state transition the monitor has experienced, stored for up to 15 months (depending on your Datadog plan).

Each row in the alert history shows:
- **Timestamp** — when the transition occurred, in your account's configured timezone (switch to UTC if you are coordinating across time zones)
- **Previous state → New state** — e.g., `OK → ALERT`, `ALERT → WARN`, `WARN → OK`
- **Value at transition** — the metric value at the moment the threshold was crossed (e.g., `0.067` for a 6.7% error rate)
- **Triggering groups** — which tag groups triggered; for a monitor with `group by service` this shows which specific services fired

**Reading a transition sequence:**

```
2026-09-24 01:52:17 UTC   OK → ALERT   value: 0.071   service:payment-service
2026-09-24 01:58:44 UTC   ALERT → WARN value: 0.033   service:payment-service
2026-09-24 02:04:31 UTC   WARN → OK    value: 0.009   service:payment-service
```

This tells the story:
1. The error rate crossed 5% (alert threshold) at 01:52:17 — this is when the page fired
2. At 01:58:44 the error rate dropped below 5% but was still above the warn threshold (2%) — a partial recovery, suggesting the underlying issue was being fixed
3. By 02:04:31 the error rate was back below the recovery threshold (1%) — full recovery

The investigation window is therefore `01:50:00 → 02:05:00 UTC` — two minutes before the first transition to catch the build-up, and a minute after the final recovery.

**Using the alert history to set your Log Explorer time range:**
Take the first ALERT transition timestamp, subtract 3 minutes, and use that as your Log Explorer start time. Take the WARN→OK or ALERT→OK transition time, add 2 minutes, and use that as your end time. This window captures the full incident lifecycle.

---

### Monitor Types — How to Read Each

**Metric Monitor**

Watches a numeric time-series metric against a threshold. The most common type.

What to look for in the query:
- The metric name (e.g., `trace.servlet.request.errors`) — tells you the signal source (APM, AWS, custom)
- The aggregation method (`avg`, `sum`, `max`, `min`) — `max` is conservative (fires if any single data point crosses); `avg` is less sensitive (needs sustained elevation)
- The evaluation window — short windows (1–5 min) catch sudden spikes; long windows (30–60 min) catch slow degradation
- The scope tags — `{service:payment-service,env:production}` tells you exactly which service and environment

---

**Log Monitor**

Watches the count (or absence) of log messages matching a search query.

What to look for:
- The log search string — e.g., `service:payment-service status:error "OrderProcessingException"` — this is the exact query you can paste into Log Explorer to see the logs that caused the alert
- The aggregation — `count` (total log lines), `unique_count` (distinct values of a field), `percentile` (for numeric fields)
- The threshold — e.g., `> 50` means more than 50 matching log lines in the evaluation window
- The group-by — if the monitor groups by `@error.type`, a separate alert fires for each distinct error type exceeding the threshold

A log monitor that fires at 01:52 UTC tells you the log search `service:payment-service status:error "OrderProcessingException"` produced more than 50 results in some 5-minute window around 01:52. Open Log Explorer, paste the exact search string, set the time range to the alert window, and you are looking at the same logs that triggered the alert.

---

**APM Monitor**

Watches APM-derived metrics for a specific service, resource, or operation. These are the monitors most directly tied to user-facing experience.

Common subtypes:
- **Error rate monitor** — fires when the fraction of traced requests returning an error exceeds a threshold (e.g., 5% of all `/api/v1/orders` requests returning 5xx)
- **Latency monitor** — fires when p50, p75, p90, p95, or p99 request duration exceeds a threshold (e.g., p99 > 2 seconds for `checkout-service`)
- **Throughput monitor** — fires when requests per second drops below a threshold (e.g., `payment-service` normally processes 200 req/s; dropping below 50 req/s for 10 minutes indicates a disruption)

Reading an APM monitor detail page gives you the service name directly — you can pivot immediately to APM → Services → that service and set the same time range to see the health timeline.

---

### Composite Monitors

A composite monitor combines two or more individual monitors using boolean logic (AND, OR). It fires only when the compound condition is true. Composite monitors reduce noise by requiring corroboration from multiple signals before paging.

**Where to find them:** Composite monitors appear in the monitor list alongside other monitors. They are identified by the type label "Composite" in the type column.

**Reading the AND/OR tree:**

On the monitor detail page, the query section shows a logical expression referencing other monitor IDs:

```
!a && b
```

This means: fire when monitor `b` is in ALERT and monitor `a` is NOT in ALERT.

More complex example:
```
(a || b) && c
```

Fire when (monitor `a` OR monitor `b` is in ALERT) AND monitor `c` is also in ALERT.

**Finding the component monitors:**
Each identifier (`a`, `b`, `c`) links to a specific monitor. Click on the identifier to open the component monitor. For a composite that fired, the component monitor that is in ALERT is the one that contributed to the firing — the one that is NOT in ALERT is the one whose condition was satisfied by its absence (in a `!a` style rule).

**Common composite patterns:**
- `error_rate_high AND NOT maintenance_window_active` — avoid paging during scheduled maintenance
- `high_latency AND high_error_rate` — fire only when both degradation signals are present simultaneously (reduces false pages from latency-only blips)
- `payment_service_errors OR checkout_service_errors` — page when either revenue-critical service has errors

---

### Muted Monitors

A muted monitor continues to evaluate its condition but suppresses all notifications during the mute window. The monitor will still show ALERT status in the UI — it is only the notifications that are silenced.

**Visual indicator:** In the monitor list, a muted monitor shows a bell-with-slash icon (🔕) to the right of the monitor name. The status column still reflects the real current state (ALERT, WARN, etc.).

**How to check the mute expiry:** Click the monitor name to open the detail page. At the top of the page, a yellow banner reads: `This monitor is muted until [date and time].` The timestamp is in your account's configured timezone. If no expiry is shown, the mute has no automatic expiry (someone muted it indefinitely — this is dangerous for production monitors).

**Why mutes matter during investigations:**
If you are investigating an alert and you find the monitor is already in ALERT state but has been muted, the on-call team may not have been paged about it. Check the mute expiry time — if the mute expired before the current alert started, the notification was sent normally. If the mute is still active and the monitor is in ALERT, the team may be unaware.

---

## Investigation Drill — 2am Alert Reconstruction

**Scenario:** At 02:00 UTC your phone buzzes. PagerDuty: "ALERT: payment-service error rate > 5% — production." It is your first on-call shift. You have no prior context on the payment service.

**Walk-through:**

**Step 1 — Open the monitor (1 minute)**

Click the PagerDuty link → it opens the Datadog monitor detail page directly. If the link is missing, navigate to Monitors → Manage Monitors, filter by `service:payment-service env:production status:alert`, and click the firing monitor.

**Step 2 — Read the condition (1 minute)**

In the query section you read:
```
avg(last_10m):avg:trace.servlet.request.errors{service:payment-service,env:production}.as_count() / avg:trace.servlet.request.hits{service:payment-service,env:production}.as_count() > 0.05
```

Translation: the APM-derived error rate for the payment-service in production has averaged above 5% for the last 10 minutes.

**Step 3 — Read the alert history to find the exact time (30 seconds)**

Scroll to Alert History. You see:
```
2026-09-24 01:52:17 UTC   OK → ALERT   value: 0.071
```

The error rate reached 7.1% at 01:52:17 UTC. The investigation window starts at 01:49 UTC (3 minutes before) to catch the build-up.

**Step 4 — Note the service tag (15 seconds)**

Tags section confirms: `service:payment-service env:production team:payments`. You are looking for payment-service logs and traces.

**Step 5 — Pivot to Log Explorer (2 minutes)**

Open Log Explorer. Set the custom time range to `01:49 UTC → 02:05 UTC`. Add filter: `service:payment-service status:error env:production`.

**Step 6 — Read the first error (1 minute)**

The first error log appears at 01:51:44 UTC — slightly before the alert fired (the alert needs 10 minutes of averaging; the errors started building about 2 minutes before the threshold was crossed). The log message:

```
ERROR [OrderProcessingService] Failed to acquire DB connection after 30000ms: HikariPool-1 — Connection is not available
```

**Step 7 — Identify the category of problem**

This is a database connection exhaustion error — the HikariCP pool in the Spring Boot payment-service could not get a connection to RDS MySQL. The root cause is not in the application logic; it is in the database tier.

**Step 8 — Pivot to infrastructure to confirm (1 minute)**

Open the RDS metrics dashboard (or Metrics Explorer). Plot `aws.rds.database_connections` for `dbinstanceidentifier:prod-mysql-primary`. Set time range to `01:47 UTC → 02:05 UTC`. The connection count shows a flat ceiling at exactly `max_connections` from 01:51 UTC onward — classic connection exhaustion.

**Step 9 — State the finding**

> "payment-service error rate crossed 5% at 01:52 UTC. Root cause: RDS MySQL connection exhaustion — `database_connections` hit `max_connections` limit at 01:51 UTC. First error logged at 01:51:44 UTC: HikariPool connection timeout. Service is alive; database is alive; pool size or a connection leak is the cause. No application code change needed — reduce pool size or find the leak."

Total navigation time: under 10 minutes. Total noise avoided: all log lines not in that 15-minute window; all services except payment-service and RDS.

---

## Exercises

### Exercise 1 — Read a Monitor Condition and Predict the Alert Window

**Scenario:** You are reviewing monitors before going on call. You find this monitor definition:

> **Name:** `[order-service] — p99 latency > 3s`
> **Query:** `avg(last_5m):p99:trace.servlet.request.duration{service:order-service,env:production} > 3000000000`
> **Alert threshold:** `3000000000`
> **Warning threshold:** `1500000000`
> **Evaluation window:** last 5 minutes

**Task:** Translate the full monitor condition into plain English. State what value is being measured, in what units, over what window, and what thresholds produce WARN vs ALERT states. Predict how many minutes of elevated latency are required before the monitor fires its first ALERT notification.

**Hint:** The metric is APM p99 latency. Datadog stores durations in nanoseconds. Divide by 1,000,000 to get milliseconds, or by 1,000,000,000 to get seconds. The evaluation window is "last 5 minutes" with `avg` aggregation — this means the p99 latency averaged across all order-service spans in the last 5 minutes must exceed the threshold. Because the evaluation is continuous (not requiring a full window by default), the monitor can fire as soon as a 5-minute window of data shows an average above the threshold.

**Solution sketch:**
1. Convert the thresholds: `3,000,000,000 ns ÷ 1,000,000,000 = 3 seconds` (alert threshold); `1,500,000,000 ns = 1.5 seconds` (warning threshold).
2. Plain-English translation: "When the average p99 latency of the order-service in production exceeds 1.5 seconds for any 5-minute window → WARN. When it exceeds 3 seconds for any 5-minute window → ALERT."
3. Time to first ALERT: the monitor evaluates on a rolling 5-minute window. If p99 spikes instantly to 4 seconds and stays there, the alert fires approximately 5 minutes after the spike starts (one full evaluation window of data above threshold). If latency rises gradually, it could take longer before the 5-minute average crosses 3 seconds.
4. Operational implication: this monitor has a ~5-minute lag between the start of latency degradation and the page firing. When you see the alert, the problem started at least 5 minutes ago — set your Log Explorer time range to at least 8 minutes before the alert timestamp.

---

### Exercise 2 — Diagnose a Muted Monitor Incident

**Scenario:** You look at the monitors list during a reported outage and notice `[checkout-service] — error rate > 5%` is in ALERT state but shows the mute icon. The outage started 45 minutes ago. The mute banner reads: "This monitor is muted until 2026-09-24 03:00 UTC." It is currently 02:30 UTC.

**Task:** Determine whether the on-call team was paged for this alert, when the mute was set and whether the mute was intended to cover this alert, and what action to take now.

**Hint:** A muted monitor fires no notifications during the mute window regardless of when it entered ALERT state. Compare the mute expiry time with when the alert transitioned to ALERT. Look at the alert history to find the ALERT transition timestamp. If the monitor entered ALERT state while the mute was active, no page was sent. Check the monitor's Tags section for a `team:` tag — that team may have a secondary communication channel (Slack) where you can notify them manually.

**Solution sketch:**
1. Open the alert history. Find the OK → ALERT transition timestamp. If it shows e.g. `02:15 UTC OK → ALERT`, the monitor entered ALERT state at 02:15 UTC.
2. The mute is active until 03:00 UTC. Since the alert started at 02:15 UTC (during the mute window), no PagerDuty notification was sent to the on-call team.
3. The mute was set to 03:00 UTC — likely for a scheduled maintenance window. But the checkout-service outage at 02:15 is unrelated to any planned maintenance — this is an unintended suppression.
4. Immediate action: the on-call team was NOT paged. Find the `team:checkout` tag on the monitor, identify the team lead or on-call rotation owner, and notify them manually (Slack, phone). Do not wait for the mute to expire.
5. Second action: note that the monitor is muted and check the mute expiry time. Escalate to the monitor's `team:` owner (visible in the tags section) to unmute it — do not click anything that changes production monitor state.
6. Long-term recommendation: mutes should be scoped to the specific maintenance being performed. A global mute on a revenue-critical monitor until 03:00 UTC without an incident or maintenance tag is a dangerous configuration.

---

### Exercise 3 — Read a Composite Monitor

**Scenario:** A composite monitor `(error_rate > 5%) AND (p99_latency > 2s)` just fired. You open it and see `error_rate` component is `ALERT`. The `p99_latency` component shows `WARN` (threshold was crossed, recovery hasn't triggered yet). The composite is `ALERT`. What does this tell you about the incident, and what's your first investigation step?

**Hint:** A composite fires when ALL its conditions are met — read each component's current value and threshold. WARN means the threshold was crossed but hasn't recovered. What does both conditions being true simultaneously suggest about the system state?

**Solution sketch:**
1. Both error rate AND p99 latency are elevated — this isn't just an error spike, it's a latency-causing failure, not just a noisy alerting issue.
2. Your first step: open Trace Explorer filtered to that service in the alert time window and look for slow spans with errors. The dual signal rules out false-positive / alert misconfiguration.
3. When only one condition is true, the cause is narrower: a fast-failing error wouldn't raise p99 this high; a latency issue without errors suggests timeouts being masked. Both conditions true simultaneously indicates a genuine latency-causing failure in the request path.
4. In Trace Explorer, filter `service:payment-service status:error` for the alert time window. Look for spans with both high duration AND an error flag — these are the requests driving both signals simultaneously.
5. The composite's design intent: it fires only when the service is both erroring AND slow, which filters out noise from brief error bursts (which recover quickly and don't raise p99) and latency blips that don't produce errors (e.g., a slow but successful batch endpoint).

---

## Anti-Patterns

- **Treating NO DATA as "everything is fine."** NO DATA means Datadog stopped receiving data from the monitored source. This is often more serious than an ALERT — it can mean the service crashed and stopped emitting metrics entirely, or the Datadog Agent sidecar failed. Always investigate NO DATA with the same urgency as ALERT until you confirm the source is intentionally offline (e.g., a known deployment gap).

- **Opening Log Explorer before reading the monitor condition.** The monitor condition gives you the service tag, the time window, and the error category — all three are required inputs for an efficient Log Explorer search. Without them you are searching blind. Spend 90 seconds reading the monitor before touching Log Explorer.

- **Setting an alert threshold to the same value as the recovery threshold.** If the alert threshold is 5% and the recovery threshold is also 5%, the monitor will flap between ALERT and OK every time the value oscillates near 5%. Set the recovery threshold 20–40% below the alert threshold (e.g., alert at 5%, recover at 3%) to create a stable hysteresis band.

- **Muting monitors indefinitely.** A monitor muted with no expiry will never page, regardless of how severe the condition becomes. Every mute must have an expiry tied to a specific maintenance window. Audit your monitor list regularly for permanent mutes — they are silent blind spots.

- **Ignoring the `group by` dimension on a monitor.** A monitor that alerts on `service:payment-service env:production` with `group by @http.url` may fire for one URL pattern while others are fine. The notification message includes the specific group that triggered — read it carefully before assuming the whole service is down.

---

# H8 — End-to-End Correlation Drill + Power Features (~60 min)

## Why This Matters

The full power of Datadog is not in any single view — it is in the data model that connects every signal. When a monitor fires, the alert carries a `service:` tag. That tag links to logs in Log Explorer. Those logs carry `trace_id` fields. That trace_id links to a distributed trace. That trace has database spans carrying the exact SQL query. That SQL query runs on an RDS instance whose CPU and connection metrics are in the Infrastructure view. And Watchdog — Datadog's automated anomaly detector — may have flagged an unusual pattern in the payment-service 20 minutes before the monitor fired.

No other observability platform closes this loop end to end without manual glue. This hour teaches you to traverse the entire loop under incident pressure, and introduces four Datadog-native capabilities that have no equivalent in Grafana or standalone log tooling.

---

## The 3-Pivot Investigation Chain

The 3-pivot chain is the core navigation pattern for production incident investigation in Datadog. Every investigation follows the same structure: Signal → Context → Root Cause.

- **Signal** — the monitor alert: what fired, when, which service
- **Context** — the error logs: what errors occurred in that window, which request triggered them
- **Root Cause** — the distributed trace + infrastructure: which span failed, which DB query ran, which container was stressed

**The exact navigation steps:**

1. Open **Monitors → Manage Monitors** in the left nav. In the search bar, type `env:production status:alert`. The list shows only currently firing production alerts.

2. Find the fired alert. Click its name to open the detail page. Read the alert history to find the exact ALERT transition timestamp (e.g., `01:52:17 UTC`). Note the `service:` tag from the tags section (e.g., `service:payment-service`).

3. Open **Log Explorer** (left nav: Logs → Explorer). Click the time picker in the top right. Choose **Custom range**. Set start time to `[alert_timestamp] - 3 minutes` (e.g., `01:49:00 UTC`) and end time to `[alert_timestamp] + 15 minutes` (e.g., `02:07:00 UTC`). This window covers the build-up before the alert and the immediate aftermath.

4. In the Log Explorer search bar, type: `service:payment-service status:error env:production`. Hit Enter. The list updates to show only error logs from payment-service in production during your time window.

5. Scan the log list. Look for a log line that has a `trace_id` field visible in the log attributes panel (click any log line to expand it). A `trace_id` field means the Datadog Java APM agent injected a correlation ID into this log — you can jump directly to the trace.

6. Click the `trace_id` value in the log attributes panel. A pop-up appears with two options: "Copy value" and "View in APM." Click **View in APM**. This opens the distributed trace for the specific request that generated this error log.

7. On the trace detail page, read the flame graph. The X axis is time (nanoseconds). The Y axis is the call stack depth. Each coloured bar is a span — one unit of work in one service. Identify the **widest span** (longest horizontal bar) — that is the span that consumed the most time. Identify any **red spans** (spans with an error flag) — those represent failures.

8. Click the widest or errored span. The right-hand panel updates to show its metadata: **Service** (e.g., `mysql-payments-db`), **Resource** (e.g., `SELECT * FROM payments WHERE id = ?`), **Duration** (e.g., 3,420 ms), **Error message** (if applicable), and all span tags.

9. If the span is a database span (service contains `mysql` or resource is a SQL statement), look for the `db.statement` tag in the span metadata. This is the exact SQL query that was executing. Note it down — it is the most actionable piece of information in the entire investigation chain.

10. Note the service name from the slow or failing span (e.g., the Spring Boot service `payment-processor` made the slow DB call). Navigate to **Infrastructure → Containers** in the left nav.

11. In the Containers search bar, filter by `task_family:payment-processor env:production` (or the appropriate ECS task family name for the service). The container list updates to show only the ECS Fargate tasks for that service.

12. Set the Containers view time range to match the alert window (use the time picker in the top right). Examine the CPU% and Memory% columns. A CPU% near 100% sustained during the alert window indicates CPU throttling. A Memory% trending to 100% followed by a drop indicates an OOM kill. A CPU and Memory both in normal range (under 70%) means the container was not resource-constrained — the slow query was caused by the database tier, not container resource limits.

13. **You now have the full picture:**
    - **Signal:** the monitor alert named `payment-service error rate > 5%` at `01:52:17 UTC`
    - **Context:** error logs from payment-service showing `HikariPool connection timeout` starting at `01:49:45 UTC`
    - **Root cause:** a specific database span in the trace shows a `SELECT` query on the `payments` table taking 3,420 ms — the slow query is exhausting the connection pool, which caused the error rate spike; the ECS containers are healthy (CPU 45%, Memory 62%)

This 13-step chain can be completed in under 15 minutes with practice.

---

## DataDog Power Features

These four capabilities exist in Datadog and have no equivalent in standard Grafana or standalone log/metrics tools. Learning them gives you investigation abilities that go beyond the standard 3-pivot chain.

---

### Watchdog — Automatic Anomaly Detection

**What it is:** Watchdog is Datadog's ML-powered anomaly detection engine. It continuously scans your APM, infrastructure, and log data for unusual patterns — spikes, drops, seasonal deviations — and generates automatic findings without requiring you to configure thresholds. It catches slow-building problems that your explicitly-configured monitors might miss.

**Visual indicator:** In APM and on dashboards, Watchdog findings appear as a paw-print icon (🐾) on affected metrics graphs. Hovering over the icon shows a brief description of the anomaly.

**Where to find the Watchdog feed:**
- Navigate to **APM → Watchdog** in the left nav — this shows all currently active APM anomalies sorted by impact
- Navigate to **Monitors → Watchdog Alerts** — this shows all Watchdog findings across APM, infrastructure, and logs in a unified feed
- On any APM service page, look for the Watchdog panel in the top section — it shows anomalies detected for that specific service

**What Watchdog finds that monitors miss:**
Monitors require you to know in advance what threshold to set. Watchdog detects relative anomalies — for example, "this service normally has 0.1% error rate and today it has 0.3% — that is unusual even though it is below your 5% alert threshold." It also detects seasonal anomalies: "this service always has lower throughput on Sunday mornings; today's Sunday morning throughput is lower than usual even after accounting for the seasonal pattern."

**During an investigation:** After completing the 3-pivot chain, check the Watchdog feed for the affected service. Watchdog may show a finding 10–30 minutes before your monitor fired — that earlier timestamp can extend your investigation window and show you the build-up phase.

---

### APM → Logs Auto-Correlation

**What it is:** When the Datadog Java APM agent is attached to your Spring Boot service, it automatically injects `trace_id` and `span_id` values into every log line emitted during a traced request. This means every error log from a request that is traced carries the exact trace ID for that request — the two signals are linked at write time, not at query time.

**Where to find it:** On any trace detail page (APM → Traces → click a trace), scroll down to the **Logs** tab in the trace detail panel (below the flame graph). This tab shows every log line emitted during the lifespan of that specific trace — across all services in the trace. You are seeing the complete application log stream for one specific user request.

**Why this is powerful:** In Grafana + Elasticsearch, connecting a metric spike to specific log lines requires manual timestamp correlation and service name matching. In Datadog, the connection is automatic and bidirectional: from a log line you can click View in APM; from a trace you can click the Logs tab. Both directions require no manual work.

**For WSO2 + Spring Boot:** The Datadog Java APM agent injects trace context into SLF4J MDC (Mapped Diagnostic Context) automatically. Your Spring Boot log output includes fields like `dd.trace_id=5234878965765850...` and `dd.span_id=8234567890123...` in every log line from within a traced request. The WSO2 API Gateway, if instrumented with the Datadog agent or the WSO2 Datadog extension, similarly injects trace context into its access logs.

---

### Error Tracking

**What it is:** Error Tracking groups individual error log lines and APM error events into fingerprinted issues. Instead of seeing 50,000 individual `NullPointerException` log lines, you see one issue: "`NullPointerException` in `OrderProcessingService.processPayment` — 50,000 occurrences, first seen 3 days ago, 2,400 occurrences in the last hour."

**Where to find it:** Navigate to **APM → Error Tracking** in the left nav (also accessible from **Logs → Error Tracking** for log-based errors). The main page shows a list of issues sorted by occurrence count or first-seen date.

**Reading an Error Tracking issue:**
- **Fingerprint** — the issue title, constructed from the error class name and the top stack frame; e.g., `NullPointerException at OrderProcessingService:142`
- **Occurrences graph** — a bar chart of occurrences over time (last 24h, 7d, 14d selectable); a rising trend indicates a worsening problem; a step function (sudden jump) indicates a deployment introduced the regression
- **Affected services and versions** — which Spring Boot service versions are generating this error; useful for identifying when a regression was introduced
- **Sample traces** — a list of individual traces associated with this error fingerprint; click one to see the full flame graph for a request that hit this error

**During an investigation:** After finding an error log in the 3-pivot chain, pivot to Error Tracking and search for the same error class. The issue's occurrence graph may show this error has been occurring at a low rate for days (pre-existing known issue) or spiked suddenly today (new regression). This context changes the priority and response.

---

### Unified Timeline

**What it is:** The Unified Timeline overlays multiple event streams on a single shared time axis: log volume, monitor state changes, deployment events, and custom event annotations. Instead of switching between views to correlate "when did the deploy happen relative to when the error rate spiked," the Unified Timeline shows all of them together.

**Where to find it:** The Unified Timeline is available inside a **Dashboard** as a widget type called **Event Timeline** or **Change Tracking**. On service-specific dashboards built with the Datadog APM integration, the Events panel at the bottom of the dashboard shows an event overlay that includes Datadog monitors and deployment events.

Navigate to **APM → Services → [service name] → Full-page view** and scroll to the bottom of the page — Datadog's built-in service page includes an event overlay. Or open a dashboard that includes the service and look for the Events row, which shows monitor state transitions (OK→ALERT as red bars), deployments (blue markers), and feature flag changes (purple markers) on the same time axis as the service's error rate graph.

**Using the Unified Timeline during an investigation:** Set the time range to the 30 minutes before and after the alert. Look for a deployment event (blue marker) within 5–10 minutes before the first ALERT transition — this is the most common root cause of sudden error rate spikes. A deployment that coincides with the start of the error rate increase is the first hypothesis to test.

---

## Capstone Drill — Full Incident Reconstruction

**Scenario:** 10:47 PM. Your phone rings. PagerDuty: "ALERT: payment-service error rate > 5% for 10 minutes — env:production." You have no prior context. No runbook link in the alert. No one else is online. The payment service processes all purchase transactions. Reconstruct the full incident: what failed, when it started, which component caused it, and what the database was doing at the time.

**Walk-through (13 steps):**

**Step 1 — Open the monitor**

Click the PagerDuty link. You are on the Datadog monitor detail page for `[payment-service] — error rate > 5%`. The status banner shows **ALERT** in red.

**Step 2 — Read the alert history to establish the exact timeline**

Scroll to Alert History. You see:
```
2026-09-24 22:37:44 UTC   OK → ALERT   value: 0.082   service:payment-service
```
The error rate reached 8.2% at 22:37:44 UTC. Add 3 minutes backward for the build-up window: investigation start = 22:34:00 UTC.

**Step 3 — Read the monitor condition**

Query section shows: `avg(last_10m):trace.servlet.request.errors{service:payment-service,env:production}`. It is an APM error rate monitor on the payment-service. Tags confirm: `service:payment-service env:production team:payments severity:critical`.

**Step 4 — Check for a Watchdog finding before opening logs**

Navigate to **APM → Watchdog**. Filter by `service:payment-service`. A Watchdog anomaly shows: "Error rate anomaly detected — payment-service, starting 22:29 UTC." Watchdog caught the build-up 8 minutes before your monitor fired. The true start of the incident is 22:29 UTC, not 22:37. Revise your investigation window: 22:27 UTC → 22:55 UTC.

**Step 5 — Open Log Explorer with the refined time window**

Navigate to **Logs → Explorer**. Set custom time range: `22:27 UTC → 22:55 UTC`. Search: `service:payment-service status:error env:production`.

**Step 6 — Find the first error log**

The earliest error appears at 22:29:11 UTC:
```
ERROR [PaymentProcessor] javax.persistence.PessimisticLockException: could not obtain pessimistic lock
    at com.example.payments.OrderRepository.lockOrderForUpdate(OrderRepository.java:87)
    trace_id: 7834521098345678234
```

This is a database-level locking error — the Spring Boot application could not acquire a pessimistic row lock on the `orders` table. Note the `trace_id`.

**Step 7 — Pivot from the log to the trace**

Click the `trace_id` value `7834521098345678234`. Select **View in APM**. The trace detail page opens.

**Step 8 — Read the flame graph**

The flame graph shows:
- `wso2-api-gateway` span: 1,240 ms (the full request duration)
- `payment-service` span (Spring Boot): 1,235 ms
- Nested under it: `mysql-payments-db` span: 1,229 ms — this is the widest span, a red error span

The WSO2 gateway and Spring Boot spans are short by themselves — nearly all the time is consumed inside the DB span. The root cause is in the database interaction.

**Step 9 — Read the DB span metadata**

Click the `mysql-payments-db` span. Right panel shows:
- **Service:** `mysql-payments-db`
- **Resource:** `SELECT * FROM orders WHERE id = ? FOR UPDATE`
- **Duration:** 1,229 ms
- **Error:** `Lock wait timeout exceeded; try restarting transaction`
- **db.statement:** `SELECT id, user_id, total_amount, status FROM orders WHERE id = 98732 FOR UPDATE`
- **db.instance:** `prod-payments-db`

The SQL query is a pessimistic lock (`FOR UPDATE`). It waited 1,229 ms and timed out because another transaction was holding the lock. This is a deadlock or lock contention pattern in the `orders` table.

**Step 10 — Check RDS MySQL metrics for deadlock confirmation**

Navigate to **Metrics Explorer** (or the RDS dashboard if your team has one). Plot `aws.rds.deadlocks` for `dbinstanceidentifier:prod-payments-db`. Time range: `22:25 UTC → 22:55 UTC`.

The deadlock count shows a spike from 0 to 8–12 deadlocks per minute starting at 22:28 UTC — exactly aligning with the first error log. The DB is experiencing sustained deadlock activity.

**Step 11 — Check the containers for resource stress**

Navigate to **Infrastructure → Containers**. Filter: `task_family:payment-service env:production`. Time range: `22:27 UTC → 22:55 UTC`.

CPU% for all payment-service containers: 35–48% (well within normal range). Memory%: 61–68% (healthy). No containers are CPU-throttled or near OOM. The ECS Fargate tasks are healthy — the problem is entirely in the database tier.

**Step 12 — Check for a deployment event using the Unified Timeline**

Navigate to the payment-service APM service page (**APM → Services → payment-service**). Scroll to the Events panel at the bottom. The unified timeline shows:
- At `22:25 UTC` — a deployment marker: `payment-service deployed version v2.14.1`
- At `22:29 UTC` — error rate begins rising
- At `22:37 UTC` — monitor transitions to ALERT

The deployment preceded the incident by 4 minutes. Version `v2.14.1` is the most probable cause — it likely introduced code that performs a `SELECT ... FOR UPDATE` in a broader transaction scope, causing lock contention across concurrent requests.

**Step 13 — State the complete incident reconstruction**

> "Root cause: deployment of payment-service v2.14.1 at 22:25 UTC introduced a change to `OrderRepository.lockOrderForUpdate()` that holds a pessimistic row lock on the `orders` table for the duration of the payment processing transaction. Under concurrent load, multiple threads hold and wait for the same row lock, causing deadlocks. RDS MySQL deadlock count spiked from 0 to 12/min at 22:28 UTC. The Spring Boot application surfaces this as `PessimisticLockException` and marks requests as errors. ECS Fargate containers are healthy (CPU 45%, Memory 64%). Immediate mitigation: roll back to payment-service v2.13.8. Long-term fix: replace the pessimistic lock with optimistic locking (`@Version` field) in the `Order` entity."

Full reconstruction time from alert to root cause statement: under 15 minutes.

---

## Exercises

### Exercise 1 — Watchdog-First Investigation

**Scenario:** You open the Watchdog feed on a Monday morning and find: "Anomaly detected — order-service p99 latency elevated, starting Sunday 23:15 UTC. Current value: 1,800 ms, expected: 280 ms." No monitor has fired — the team's latency monitor has a threshold of 3 seconds, which was not reached. You investigate proactively.

**Task:** Use the Watchdog finding as your starting point, follow the 3-pivot chain, and identify what caused the Sunday night p99 latency increase. The Watchdog anomaly ended at Monday 00:45 UTC without ever triggering a monitor.

**Hint:** The Watchdog anomaly gives you a precise time window: 23:15 → 00:45 UTC. Set your Log Explorer time range to `23:12 → 00:48 UTC`. Filter `service:order-service`. Look for slow query indicators or high-volume patterns. The Watchdog finding may also link directly to the APM service page — click the "View in APM" link in the Watchdog finding panel to land on the order-service APM page with the time range pre-set.

**Solution sketch:**
1. Open APM → Watchdog. Click the anomaly for `order-service`. The finding page shows the latency graph with the anomaly band highlighted in pink. Click "View in APM" to open the order-service page with the time range pre-set to `23:10 → 01:00 UTC`.
2. On the APM service page, check the latency distribution breakdown by resource (endpoint). Look for a specific resource whose p99 spiked — e.g., `GET /orders/history` shows p99 rising from 280 ms to 1,800 ms while all other endpoints are normal.
3. Open a trace for `GET /orders/history` during the anomaly window. Find the slow span — likely a DB query.
4. The DB span metadata shows: `SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 500` taking 1,600 ms. A batch export job runs every Sunday at 23:00 and inserts 80,000 rows into the `orders` table, causing the query to scan significantly more rows than usual.
5. Check `aws.rds.queries` for `dbinstanceidentifier:prod-mysql-primary` from 23:00 → 01:00 UTC — QPS is elevated 3× above normal from 23:00 to 00:45. The batch job and the user-facing `GET /orders/history` endpoint are competing for the same table.
6. Conclusion: "Sunday 23:00 UTC batch export job saturated the `orders` table I/O, causing the `GET /orders/history` query to slow from 280 ms to 1,800 ms p99. No monitor fired because the threshold (3 s) was not reached. Watchdog detected the anomaly relative to the seasonal baseline. Recommendation: schedule the batch job during lower-traffic hours (03:00–05:00 UTC) or add a read replica for reporting queries."

---

### Exercise 2 — Error Tracking Issue Classification

**Scenario:** Error Tracking shows two issues for the `checkout-service`:

> **Issue A:** `NullPointerException at CheckoutController:234` — 42 occurrences in the last 24h, first seen 14 days ago, trend: stable
> **Issue B:** `IllegalStateException at PaymentGatewayClient:89` — 3,800 occurrences in the last 24h, first seen 2 hours ago, trend: sharply rising

A monitor just fired on checkout-service error rate > 5%.

**Task:** Determine which Error Tracking issue is causing the monitor alert and which is a pre-existing known issue. Explain your reasoning, describe how to link the Error Tracking issue to a specific trace, and state what information you need from the trace to confirm the root cause.

**Hint:** The occurrence count and the trend graph are the key discriminators. A stable issue with 42 occurrences per day is almost certainly not causing a sudden 5% error rate spike — at typical checkout-service throughput of 1,000 requests per hour, 42 errors per day is a 0.17% error rate baseline. A sharply rising issue with 3,800 occurrences in 24 hours (all in the last 2 hours) at 1,900 occurrences per hour is 190% of the hourly throughput — but more practically, look at when the trend started relative to when the monitor fired.

**Solution sketch:**
1. Issue B is causing the monitor alert. Evidence: Issue B first appeared 2 hours ago (correlating with the alert window), is sharply rising, and has 3,800 occurrences vs. 42 for Issue A. Issue A (NullPointerException, stable for 14 days) is a pre-existing known issue that the team has accepted below their alert threshold.
2. To link Issue B to a trace: in the Error Tracking issue detail page, scroll to the "Sample Traces" section. Click any listed trace to open the flame graph for a request that triggered this `IllegalStateException`.
3. In the trace, look for: (a) which span is marked as errored (red), (b) the error message and stack trace in the span metadata, (c) whether there is a DB span immediately before the errored span (database state causing the exception), (d) the `db.statement` if applicable.
4. The `IllegalStateException at PaymentGatewayClient:89` suggests the payment gateway client is in an unexpected state. In the trace, look for a preceding HTTP client span to the external payment gateway — the gateway may be returning an unexpected response code (e.g., 503 or a response body that fails deserialization).
5. Confirm root cause: if the gateway HTTP span shows a 503 response, the external payment gateway is having issues. If it shows a 200 response but the subsequent parsing span fails, there is likely a contract change in the gateway's API response format introduced by a recent deployment.

---

### Exercise 3 — Unified Timeline Deployment Correlation

**Scenario:** Your team's checkout-service dashboard shows the error rate rising from 0.1% to 3.8% over the past 20 minutes. No monitor has fired yet (threshold is 5%). You open the Unified Timeline on the dashboard and see two recent events:

- `22:15 UTC` — Feature flag `new_discount_calculation_v2` enabled for 100% of users (shown as a purple marker)
- `22:10 UTC` — `checkout-service v3.2.1` deployed (shown as a blue marker)

The error rate began rising at `22:12 UTC`.

**Task:** Using the Unified Timeline evidence, state which event is the most likely cause of the error rate increase and explain your reasoning. Describe the exact next investigation step in Datadog, specifying which view to open, what filter to apply, and what you expect to find.

**Hint:** The 2-minute gap between deployment (22:10) and the start of errors (22:12) is consistent with ECS Fargate rolling deployment completing and new tasks starting to receive traffic. The feature flag change at 22:15 came 3 minutes after the error rate began rising — timing suggests the feature flag is not the primary cause (it was enabled after the errors started), but it may be amplifying the problem. Check the deployment first.

**Solution sketch:**
1. Most likely cause: `checkout-service v3.2.1` deployed at 22:10 UTC. The 2-minute lag is the rolling deployment window — ECS replaces tasks sequentially, and errors begin as new task versions receive traffic. The feature flag at 22:15 is secondary (post-error-onset).
2. Next investigation step: Open **APM → Traces**. Set time range `22:09 → 22:30 UTC`. Filter: `service:checkout-service status:error env:production`. Add a breakdown by `version` — in the Trace Explorer, click "Group by" and select `@version`. This splits the error trace count by checkout-service version.
3. Expected finding: traces from `v3.2.1` show significantly higher error rates than traces from `v3.2.0` in the same window (during the rolling deployment, both versions are running simultaneously). The version comparison directly confirms the regression is in the new deployment.
4. Open one error trace from `v3.2.1`. Read the flame graph and the errored span. The error message in the span tells you what code path in v3.2.1 is failing.
5. Mitigation path: if the trace confirms a code regression in v3.2.1, trigger an ECS service update rolling back to `v3.2.0`. Monitor error rate recovery — it should begin dropping within 2–3 minutes as the old tasks start receiving traffic again.

---

## Anti-Patterns

- **Skipping Watchdog before opening logs.** Watchdog often detects anomaly onset 5–15 minutes before a monitor fires. By skipping the Watchdog feed, you miss the early phase of the incident — the logs and traces that show the problem building rather than already in full effect. Check Watchdog first during any investigation; it widens your window.

- **Following the 3-pivot chain in the wrong order.** Jumping to traces before finding the relevant error log means you are searching the APM trace list without knowing which specific request to look for. The log gives you a `trace_id` — use it as the exact pointer into APM. Without it you are scanning hundreds of traces.

- **Treating all Error Tracking issues as active incidents.** Error Tracking aggregates issues over time. A stable issue with 10 occurrences per day that is 30 days old is almost certainly not causing today's alert. Always check the trend graph and the first-seen timestamp before treating an Error Tracking issue as the cause of an acute incident.

- **Using the Logs tab in a trace as a substitute for the full Log Explorer search.** The Logs tab in a trace detail shows only logs from that specific trace's `trace_id`. If the root cause is a systemic failure affecting hundreds of requests, the single trace's logs are a sample — they confirm the error pattern but do not show frequency or breadth. Always also run the full Log Explorer search for the service and time window to understand the scale.

- **Ignoring the deployment marker on the Unified Timeline.** The single most common cause of a sudden error rate spike is a code deployment. If you see a deployment event within 10 minutes before the start of an error spike, test the deployment-as-cause hypothesis first before investigating database, network, or infrastructure issues. Verifying a deployment root cause takes 5 minutes (compare error rates by version in Trace Explorer); ruling it out takes the same time; doing it last wastes 20 minutes of investigation on the wrong layer.

- **Closing an incident investigation without checking the WARN→OK or ALERT→OK transition on the monitor.** The recovery transition tells you when the condition actually resolved — not when you stopped looking. If the monitor is still in ALERT when you hand off or close the incident, the issue has not resolved. Always confirm the OK transition before declaring the incident over.

---

## You've Completed Stage 1

You have now built and exercised the full Datadog investigation vocabulary for the WSO2 API Gateway + Spring Boot + ECS Fargate + RDS MySQL stack:

- **H1** — Orientation: the data model, the left nav, how tags connect signals
- **H2–H3** — Logs: Log Explorer search syntax, facet analysis, error pattern triage
- **H4–H5** — APM: Service Map, Trace Explorer, flame graph reading, DB span analysis
- **H6** — Infrastructure: ECS container metrics, RDS MySQL metrics, OOM patterns, metric-to-log correlation
- **H7** — Monitors: alert history, condition reading, composite monitors, muted monitors, 2am reconstruction
- **H8** — End-to-end: the 3-pivot chain, Watchdog, Error Tracking, APM→Logs correlation, Unified Timeline, full capstone reconstruction

**Updating PROGRESS.md:**

Open `datadog_mastery/PROGRESS.md`. Mark all eight hours as complete: H1 through H8. Update the overall status from "In Progress" to "Stage 1 Complete."

**Planning Stage 2:**

Stage 2 of the Datadog mastery path covers authoring — writing your own monitors, dashboards, and SLOs rather than reading ones others have written:

- **S2-H1** — Building monitors from scratch: threshold selection, evaluation window design, notification templates
- **S2-H2** — Dashboard design: widget types, template variables, time-shift comparisons
- **S2-H3** — SLOs: error budgets, burn rate alerts, integrating SLOs with monitor routing
- **S2-H4** — Synthetic monitoring: writing API tests, browser tests, uptime checks for the WSO2 API Gateway endpoints
- **S2-H5** — Advanced APM: custom instrumentation, adding business-level spans, adding custom tags to traces from Spring Boot

Before beginning Stage 2, complete the Stage 1 verification exercise: set a 30-minute timer and execute the full capstone drill without looking at these notes. Start from a real or simulated Datadog alert and reconstruct the incident independently. If you reach a full root-cause statement within the 30 minutes, Stage 1 is mastered. If you get stuck, note which step you stalled on and re-read that section before moving forward.
