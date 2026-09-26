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
   — **Hint:** Filter `status:error service:<your-spring-boot-service>` in the search bar,
   set time range to "Past 24 Hours". Switch to **Analytics** view using the view toggle
   above the log stream (three icons: List | Patterns | Analytics — click the bar chart
   icon). In the chart controls: set Group into: **Fields** · Visualize as: **Top List** ·
   Measure: **Count** · Group by: `@error.message`. If `@error.message` returns no data,
   try `@error.type` or `source`
   — depends on how your team's log pipeline parses Java exceptions.
   — **Solution sketch:** Top List shows error messages ranked by count, highest first.
   Common ones: `Connection pool exhausted`, `Timeout`, `NullPointerException`. Note the
   counts — if one error is 10× higher than the others, that is the spike driver. Click
   any row to filter the log list to only that error message.

3. **Find a log entry that has a `trace_id` and note the trace_id value.**
   — **Hint:** In the facets panel, look for a `Traces` section or search for logs with
   `@dd.trace_id:*` (asterisk matches any value). Alternatively, filter `status:error` and
   click log entries until you find one with a trace_id field.
   — **Solution sketch:** The `trace_id` appears as a 64-bit decimal integer (e.g. `7834521098345678234`) or, for W3C 128-bit traces, a 32-character hex string. It is **not** a 64-character hex string — if you see one that length, it is a span ID. Note it — you'll use this field's pivot in H5.

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

Log Analytics turns your current query into a chart. Use it to answer:
- "When exactly did the error spike start?"
- "Which service is producing the most errors?"
- "Is the error rate still climbing or has it stabilised?"

> **UI note (as of late Sep 2026):** DataDog recently replaced the old three-tab switcher
> (`List` | `Patterns` | `Analytics` icons at the top of the log stream) with the inline
> `Group into` + `Visualize as` controls described below. If you see a tutorial or
> screenshot showing an "Analytics" tab or bar-chart icon to click, it is using the old
> layout — the controls and concepts are identical, just reorganised. Old → new mapping:
> old **Patterns tab** = `Group into: Patterns`; old **Analytics tab** = `Group into: Fields`
> + any `Visualize as` except List.

**The control layout — always visible below the search bar:**

There is no separate "Analytics mode" to switch into. Two rows of controls sit directly below the search bar at all times:

```
[ Search bar: env:prd  service:wso2-gw-ecs-svc                      ]

Group into:    [ Fields ]  [ Patterns ]  [ Transactions ]

Visualize as:  [ List ] [ Timeseries ] [ Top List ] [ Bar Chart ]
               [ Table ] [ Tree Map ] [ Pie Chart ] [ Scatter Plot ] [ Distribution ]

[ Chart panel ]
[ Log stream  ]
```

Changing either control updates the chart and log stream immediately.

---

**"Group into" — sets the unit of analysis:**

| Option | What it groups | When to use |
|---|---|---|
| **Fields** | Counts logs split by field values you choose (`service`, `@http.status_code`, etc.) | 80% of incident investigation — "how many errors per service per minute?" |
| **Patterns** | Counts logs split by auto-detected message templates — no field to specify | "Which recurring error pattern is spiking?" when you don't know the exact field to group by |
| **Transactions** | Links sequences of logs sharing a common key (e.g. `@dd.trace_id`) into single events with total duration + step count | "How long does the full request flow take?" "At which step do requests fail?" |

**"Visualize as" — sets the display format:**

| Visualization | Best for | Notes |
|---|---|---|
| **List** | Normal investigation — scrollable log stream + mini-histogram above | Default. Changing other controls updates what logs show below |
| **Timeseries** | "When did this spike?" — trend over time, x-axis = time | Most useful for finding *when* an event happened |
| **Top List** | "What are the top N X?" — horizontal bars ranked by count | Most useful for finding *what* is causing a spike |
| **Bar Chart** | Side-by-side grouped bars — compare a dimension across time buckets | Good for comparing two services across a time window |
| **Table** | Multi-column grid — count broken down by two fields simultaneously | Good for "errors by service AND status code" in one view |
| **Tree Map** | Proportional nested squares — share of volume by category | Good for quick proportional overview |
| **Pie Chart** | Proportional slices — "what % does each service contribute?" | Use when proportions matter more than absolute counts |
| **Scatter Plot** | Two numeric attributes as X/Y dots — correlation analysis | Advanced: e.g. duration vs. error rate per service |
| **Distribution** | Histogram of a numeric attribute — shape of the data | Good for latency analysis — "is the p99 an outlier or the whole distribution?" |

For incident investigation you will mainly use: **List** (browse), **Timeseries** (when), **Top List** (what), **Distribution** (latency shape).

---

**Sub-controls that appear based on the active mode:**

| Sub-control | Active when | What it does |
|---|---|---|
| **Measure** | Always | What to aggregate. Default: **Count** (log events). Switch to any numeric attribute (e.g. `@duration`). Transactions mode also offers **Duration** (ms from first to last log in the sequence) |
| **Group by** | Fields mode | Field(s) to split the chart by. Click `+` to stack up to 3 dimensions (e.g. `service` then `@http.status_code`) |
| **Transaction key** | Transactions mode | The shared field that links related logs into one transaction, e.g. `@dd.trace_id`, `@request_id` |
| **Rollup interval** | Timeseries only | Time bucket size: auto / 10s / 1m / 5m / 15m / 1h |

---

**Recipe 1 — "When did the spike start?" (Fields + Timeseries):**
1. Group into: **Fields** · Visualize as: **Timeseries**
2. Measure: **Count** · Group by: `service`
3. Rollup: **1 minute**
4. Hover over the spike → tooltip shows exact timestamp + count per service
5. Click-drag the spike region → zooms the time range into that window

**Recipe 2 — "What are the top N X?" (Fields + Top List):**
1. Group into: **Fields** · Visualize as: **Top List**
2. Measure: **Count** · Group by: the field to rank (`@error.message`, `@http.url`, `@network.client.ip`, etc.)
3. Result: ranked list, highest count first
4. Click any row → filters the log list to only logs matching that value

**Recipe 3 — "Which recurring pattern is spiking?" (Patterns + Timeseries):**
1. Group into: **Patterns** · Visualize as: **Timeseries**
2. Each line on the chart = one auto-detected message template
3. A line that rises while others stay flat → that pattern is the new event
4. Click a line → pattern detail shows the message template, count, and sample logs

**Recipe 4 — "Trace the full lifecycle of a request" (Transactions + Table):**
1. Group into: **Transactions** · Visualize as: **Table** (or **List**)
2. Transaction key: `@dd.trace_id` (links all logs from the same distributed request)
3. Measure: **Duration** (ms from the first to last log in the transaction)
4. Each row = one complete request flow: trace_id, duration, step count, final status
5. Sort by Duration descending → slowest requests at the top
6. Click a row → expands to show each individual log step within that transaction

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
4. Switch to **Analytics** view (bar chart icon above the log stream). Set Group into:
   **Fields** · Visualize as: **Top List** · Measure: **Count** · Group by:
   `@network.client.ip`. The ranked list shows which IP generated the most 401/403s.
   One IP far ahead of the rest → misconfigured client.
5. Change Group by to `@http.url` or `resource` — Top List now ranks the hit endpoints.
6. Conclusion: if one IP dominates → misconfigured client. If many IPs → auth provider issue.

## Exercises

1. **Use Log Patterns to identify the most frequent error pattern from your Spring Boot services.**
   — **Hint:** Filter `status:error service:<spring-boot-service>`, switch to Patterns view,
   look at the top row by count.
   — **Solution sketch:** The top pattern is usually a connection error, timeout, or
   NullPointerException. The template shows `*` where the variable parts (timestamps,
   IDs) were removed. Click the pattern to see sample logs.

2. **Use Log Analytics to graph 5xx errors per minute for the last 2 hours. Identify the exact minute the error spike started.**
   — **Hint:** Filter `status:error @http.status_code:[500 TO 599]`, switch to Analytics.
   Set Group into: **Fields** · Visualize as: **Timeseries** · Measure: **Count** ·
   Group by: `service` · Rollup: **1 minute**.
   — **Solution sketch:** Each service appears as a separate coloured line. The line that
   jumps first is the origin service. Hover the spike → tooltip shows exact timestamp +
   count. Note this timestamp — it will anchor your trace and infrastructure investigation.

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
