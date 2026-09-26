# H4–H5 — APM and Trace Investigation (2 × ~60 min)

## Why This Matters

A user files a support ticket: "The `/orders` API is slow — sometimes takes 5 seconds." Your logs (H2–H3) showed a `trace_id` but gave you only a single service's perspective. APM lets you answer the harder questions: *which service in the chain caused the slowdown?* Was it WSO2 API Gateway parsing the JWT? The Spring Boot order service running a loop? Or an RDS MySQL query doing a full table scan?

In the next two hours you will go from "something is slow" to "it is this specific MySQL query on the `order_items` table, called 47 times in a single request." That precision is the difference between a 20-minute fix and a 3-hour guessing game.

---

# H4 — APM: Service Map + Trace Explorer (~60 min)

## Core Concepts

### APM Product Areas

Datadog APM has four main surfaces, each serving a different investigation stage:

| Area | What it shows | When to use it |
|---|---|---|
| **Service Map** | Live topology of every instrumented service and their call relationships | First stop — answers "which service is sick?" |
| **Trace Explorer** | Searchable list of individual request traces, with latency distributions | Second stop — narrows to the specific requests showing the problem |
| **Service Catalog** | Ownership metadata, SLOs, runbook links per service | Context — who owns this service, what is its error budget? |
| **APM Metrics** | Aggregated throughput/latency/error rate time-series | Trend analysis — was 5s latency sudden or gradual? |

In a latency investigation you almost always start at the Service Map, pivot into Trace Explorer, and finally open individual traces (H5).

---

### Reading the Service Map

Navigate to **APM → Service Map** in the left sidebar.

**Node colours** indicate the current health of each service based on its error rate and latency SLO:

- **Green** — error rate and p99 latency are within normal bounds
- **Yellow (degraded)** — latency is elevated or error rate is slightly above baseline; worth watching
- **Red (errors)** — error rate exceeds the configured threshold; investigate immediately

**Edge labels** show the request rate between two services in requests per second (req/s). A thick edge with a high req/s means this is a hot path. An edge that turns red indicates errors on that call direction specifically.

**Reading the WSO2 → Spring Boot → MySQL chain:**

In your environment the typical call flow looks like this in the Service Map:

```
[wso2-api-gateway]  ──(req/s)──▶  [order-service]  ──(req/s)──▶  [mysql-orders-db]
```

- The `wso2-api-gateway` node is your entry point. Traffic arrives here from external clients.
- It calls `order-service` (Spring Boot on ECS Fargate) for business logic.
- `order-service` calls `mysql-orders-db` (RDS MySQL) for persistence.

If `order-service` turns yellow but `wso2-api-gateway` is green, the bottleneck is in the Spring Boot layer or below. If the MySQL node turns yellow and the edge from `order-service` → `mysql-orders-db` shows low req/s but high latency, suspect a slow query rather than a traffic surge.

**Useful Service Map controls:**
- **Time range picker** (top-right) — set to "Past 15 minutes" to see the current state; widen to "Past 1 hour" to see a pattern.
- **Env filter** — always filter to `env:production` first to avoid staging noise.
- **Cluster into groups** — toggle "Group by: cluster" to collapse ECS task replicas into one node.

---

### Trace Explorer Search Syntax

Navigate to **APM → Traces** (or use the "View Traces" link from any Service Map node).

The search bar at the top accepts a structured query language. Think of it as a combination of tag filters.

**Core filter atoms:**

| Filter | Example | Meaning |
|---|---|---|
| `service:` | `service:order-service` | Traces that include a span from this service |
| `resource:` | `resource:"/api/v1/orders"` | Traces where a span's resource name matches |
| `status:error` | `status:error` | Traces that contain at least one errored span |
| `@duration:` | `@duration:>2s` | Traces whose total duration exceeds 2 seconds |
| `env:` | `env:production` | Only production traces |
| `operation_name:` | `operation_name:servlet.request` | Filter by the span operation type |

**Combining filters** uses space-separated AND logic:

```
service:order-service status:error env:production
```

This returns only traces that are from `order-service`, contain an error, and are in production. All filters are ANDed by default.

**Useful compound queries for common investigations:**

```
# Find slow POST /orders traces in production
service:order-service resource:"POST /api/v1/orders" @duration:>2s env:production

# Find any trace chain touching WSO2 with errors
service:wso2-api-gateway status:error env:production

# Slow database calls specifically
service:order-service operation_name:mysql.query @duration:>500ms
```

**Date range:** Use the time picker alongside the search bar. "Last 15 minutes" is good for an active incident. Use a custom range when you have a specific timestamp from a customer complaint.

---

### Trace List Columns

After running a search the list view shows one row per trace. Key columns:

- **Duration** — total wall-clock time of the entire request chain from first span to last span closing. This is the latency the user experienced.
- **p50 / p95 / p99** — these appear in the *aggregated* view (grouped by resource). They show the 50th, 95th, and 99th percentile durations across all matching traces. A p50 of 200ms with a p99 of 4s means most requests are fast but the tail is painful.
- **Hits** — how many traces matched the query in the selected time window. Useful to see if a slow pattern is rare (5 hits) or widespread (500 hits).
- **Errors** — count of traces that contained at least one error span. A non-zero number here means some requests failed entirely, not just slowed down.
- **Service** — which service the root span belongs to (usually `wso2-api-gateway` for inbound API calls).

**Switching between list and analytics views:**

Click the **bar chart icon** in the top-left of the trace list to switch to an analytics view that shows a time-series of trace count and latency. Use this to answer "did latency spike at 14:32?" before drilling into individual traces.

---

### Opening a Trace: Timeline View vs Span List

Click any row in the trace list to open the **trace detail panel** on the right (or full screen).

**Timeline view (default):**
The flame graph / waterfall view. Each horizontal bar is a span. Spans are nested to show parent-child call relationships. The x-axis is time from trace start. This is the best view for understanding *where time was spent* visually.

**Span list view:**
A flat table of all spans sorted by duration or start time. Use it when you want to sort by slowest span or scan all spans for a specific resource name.

Toggle between them using the "Waterfall" / "List" buttons above the span area.

---

## Investigation Drill — Latency Complaint to Slow Service

**Scenario:** A customer reports that `POST /api/v1/orders` is taking over 3 seconds. It was fast yesterday.

**Step 1: Open Service Map**
- Go to **APM → Service Map**, time range: last 30 minutes, env: production.
- Scan node colours. Suppose `order-service` is yellow and `mysql-orders-db` is also yellow.
- This immediately suggests the database layer is under stress.

**Step 2: Check the edge label**
- Click the edge between `order-service` and `mysql-orders-db`.
- The edge popup shows: 120 req/s, p99 latency 3.1s, error rate 0%.
- No errors, but latency is very high. Likely a slow query, not a failure.

**Step 3: Open Trace Explorer from the Service Map**
- Click the `order-service` node → "View Traces" button in the popup.
- This pre-populates the filter: `service:order-service env:production`.
- Add `@duration:>2s` to the search bar and press Enter.

**Step 4: Sort and inspect the trace list**
- Sort by Duration descending.
- You see traces in the 3–5s range. Hit count: 47 in the last 30 minutes.
- The p95 column shows 3.8s vs a baseline of ~400ms from yesterday.

**Step 5: Pivot to an individual trace**
- Click the slowest trace row.
- The timeline view opens — you can see where the time is being spent.
- This is where H5 picks up: reading the flame graph.

---

## Exercises

**Exercise 1 — Filter construction**

You receive an alert: `wso2-api-gateway` is reporting elevated error rates for the past 10 minutes in production. Write the Trace Explorer query to find all errored traces originating from WSO2.

> **Hint:** You need three filters: service name, error status, and environment.

> **Solution sketch:**
> ```
> service:wso2-api-gateway status:error env:production
> ```
> Sort by recency. Click into a few traces to check the error span — is the error originating in WSO2 itself (e.g. a JWT validation failure) or is WSO2 just propagating a 500 from `order-service` downstream?

---

**Exercise 2 — Reading aggregated latency**

In the Trace Explorer you see these values for `resource:"POST /api/v1/orders"`:

| Hits | p50 | p95 | p99 | Errors |
|---|---|---|---|---|
| 1,240 | 310ms | 2.8s | 5.1s | 12 |

Answer: Is this a widespread problem or an outlier problem? What would you investigate first — errors or latency?

> **Hint:** Compare p50 to p99. A large gap means the problem affects only a subset of requests.

> **Solution sketch:**
> The p50 is 310ms — most requests (50%+) are perfectly fine. Only the tail (top 5% and especially top 1%) is slow. This is a tail-latency problem, not a global slowdown. Combined with only 12 errors out of 1,240 hits (under 1%), the latency issue is more impactful than the error rate. Investigate latency first: filter `@duration:>2s` and look for a pattern — do slow traces share a specific user, payload size, or time window?

---

**Exercise 3 — Service Map interpretation**

On the Service Map you see:

```
[wso2-api-gateway] GREEN ──40 req/s──▶ [order-service] GREEN ──40 req/s──▶ [mysql-orders-db] RED
```

The `mysql-orders-db` node is red. WSO2 and `order-service` are green. What does this pattern most likely mean, and how would you investigate?

> **Hint:** Think about what "red" on a downstream dependency means for the upstream caller. Does the upstream being green mean there's no user impact?

> **Solution sketch:**
> `mysql-orders-db` being red while upstream services are green is a warning sign, not a clean bill of health. It means either: (a) `order-service` is swallowing MySQL errors internally (returning a cached result or a fallback), or (b) the green status on `order-service` is lagging behind the actual error condition. To investigate: click `mysql-orders-db` → View Traces → filter `status:error`. Look at the error messages on MySQL spans. Then check `order-service` logs for any "DB connection error" lines that might be getting caught and silenced by a try/catch.

---

## Anti-Patterns

**Using Trace Explorer as a search engine for all problems.** Trace Explorer shows only sampled traces (Datadog applies head-based or tail-based sampling). A query returning 0 results does not mean the problem never happened — it may mean the slow requests were not sampled. Confirm with APM Metrics time-series to see if the pattern is real at the aggregate level.

**Filtering only on `service:` when the problem is cross-service.** If you filter `service:order-service` you will see traces where `order-service` was involved but the root of the latency may be in a downstream MySQL span. Always open the full trace to see the complete chain.

**Ignoring the time range.** Setting the time range to "Last 1 hour" during an active incident means you are mixing healthy and unhealthy traffic. Narrow to the incident window for accurate p99 numbers.

**Treating p50 as "the" latency.** In a microservices system, p50 can look healthy while p99 is catastrophic for users on the tail. Always check p95 and p99 before concluding that latency is normal.

**Not filtering by `env:`.** Running queries without an `env:` filter merges production and staging traces. A noisy load test in staging can make production latency look artificially better or worse.

---

# H5 — Flame Graphs + API Flow Investigation (~60 min)

## Why This Matters

You found a 4-second trace from the last drill. Now you need to answer: *where inside that trace did the 4 seconds go?* A flame graph turns an opaque number into a visual breakdown. You can see at a glance that WSO2 spent 200ms on JWT validation, Spring Boot spent 300ms on business logic, and MySQL spent 3.5s on a single query — and that query is the fix.

Without flame graph reading skills you are left asking "is this a Java problem or a DB problem?" With them, you have an exact file, method, or SQL statement to hand to the right person.

## Core Concepts

### Flame Graph Anatomy

When you open a trace in Datadog's APM, the default view is a waterfall / flame graph hybrid. Understanding the axes is essential:

**X-axis — time.** The left edge of any bar represents when that span started, relative to the start of the entire trace. The right edge is when it finished. A bar that starts at 0ms and ends at 4000ms was active for the entire request duration.

**Bar width — duration.** A wider bar took longer. This is the most immediate visual cue. In a 4-second trace, a bar spanning 3.5 seconds is the bottleneck.

**Nesting / vertical position — call chain.** A child span is drawn *below* its parent span. Reading top to bottom traces the call stack: the topmost bar is the root span (e.g. the HTTP request entering WSO2), and each level down is a nested call. The deepest bar in a branch is a leaf operation (often a DB query or external HTTP call with no further children).

**Colour — service.** Each service gets its own colour. In your environment:
- WSO2 API Gateway spans → one colour (e.g. blue)
- Spring Boot `order-service` spans → a different colour (e.g. green)
- MySQL spans → a third colour (e.g. orange)

When you see a long orange bar deep in the call chain, that is a slow database operation.

**Gaps between bars** represent time that is unaccounted for — either async processing between parent and child, or spans that were not instrumented.

---

### Reading Span Metadata

Click any bar in the flame graph to open its **span detail panel** on the right side. This panel shows everything the instrumentation captured about that operation.

**Key fields you will read in every investigation:**

| Field | What it tells you |
|---|---|
| **Resource name** | The logical name of the operation: `GET /api/v1/orders/{id}`, `SELECT orders WHERE ...`, `POST https://payment-service/charge` |
| **Service** | Which service owns this span |
| **Operation name** | The kind of operation: `servlet.request`, `spring.handler`, `mysql.query`, `http.request` |
| **Duration** | How long this span took in ms or seconds |
| **HTTP method + URL** | For HTTP spans: the method (GET/POST/PUT) and the full URL called |
| **DB statement** | For database spans: the full SQL query text, often with bind parameter placeholders |
| **HTTP status code** | For HTTP spans: 200, 404, 500, etc. |
| **Error message** | If `status:error`, the error type and message are shown here |
| **span_id / trace_id** | The W3C trace context IDs — useful for searching logs |

For a Spring Boot controller span you will typically see:
```
Resource:  GET /api/v1/orders/{id}
Operation: spring.handler
Duration:  3,842ms
http.method: GET
http.url: /api/v1/orders/10042
http.status_code: 200
```

---

### Reading RDS MySQL Database Spans

MySQL spans in Datadog come from the JDBC instrumentation and show the most diagnostic detail of any span type.

**What you will see in the span detail panel:**

- **`db.statement`** — the actual SQL query. Datadog auto-obfuscates bind parameter values (replacing `WHERE id = 10042` with `WHERE id = ?`) but preserves the query structure. You can see `SELECT * FROM order_items WHERE order_id = ?` and immediately identify a missing index problem or a cartesian join.
- **`db.row_count`** — how many rows the query returned or affected. A value of 50,000 on a query that should return 10 rows is a red flag.
- **`db.type`** — `mysql`
- **`db.instance`** — the database name (e.g. `orders_db`)
- **`out.host`** — the RDS endpoint hostname
- **Duration** — how long MySQL took to execute and return results

**Recognising a slow query problem:**

```
db.statement: SELECT oi.*, p.name, p.price FROM order_items oi 
              JOIN products p ON oi.product_id = p.id 
              WHERE oi.order_id = ?
db.row_count: 1
Duration: 3,512ms
```

A 3.5-second query returning 1 row usually means a missing index or a lock wait. This is the span you hand to your DBA or the team that owns the `order_items` schema.

**N+1 query pattern:**

In the span list view, if you see 40+ MySQL spans with identical `db.statement` and each taking 80ms, the total accumulation is the 3-second latency. This is an N+1 problem in the Spring Boot service — it is querying the database once per item in a loop instead of fetching all items in a single query.

---

### Identifying the Critical Path

The **critical path** is the sequence of spans that, if each were made faster, would reduce the total trace duration. It is the chain of spans from root to leaf where every span occupies the maximum time budget.

**How to find it visually:**

1. Look for the widest bar at the top level (root span duration).
2. Find the child span that starts earliest and ends latest — this is the critical child.
3. Within that child, find its critical grandchild.
4. Repeat until you reach a leaf span.

In a 4-second trace where WSO2 has a 3.95-second root span, and `order-service` has a 3.8-second child span, and MySQL has a 3.5-second grandchild span — the critical path is `wso2 → order-service → mysql.query`. Fixing the MySQL query will reduce the trace to approximately 0.5 seconds.

**What is NOT on the critical path:**

A 50ms call to an internal cache service that runs in parallel with the MySQL query is not on the critical path. Even if you eliminate it entirely, the trace stays at 3.95 seconds. Do not optimize off-critical-path spans during a latency incident.

---

### Error Spans: Reading the Full Error Detail

When a span has `status:error`, the flame graph bar gets a red tint and the span detail panel shows additional fields:

- **`error.type`** — the Java exception class: `com.mysql.cj.jdbc.exceptions.CommunicationsException`, `java.lang.NullPointerException`, `org.springframework.web.server.ResponseStatusException`
- **`error.message`** — the exception message string: `"Communications link failure"`, `"Order not found: 10042"`
- **`error.stack`** — the full Java stack trace, truncated to the first 10 frames in the UI but copyable in full

**Reading the stack trace in context:**

```
error.type:    com.example.orders.exceptions.InsufficientStockException
error.message: Insufficient stock for productId=9921, requested=5, available=2
error.stack:
  com.example.orders.service.OrderService.validateStock(OrderService.java:142)
  com.example.orders.service.OrderService.createOrder(OrderService.java:89)
  com.example.orders.controller.OrderController.createOrder(OrderController.java:55)
  ...
```

This tells you the exact class, method, and line number. You do not need to reproduce the bug — the trace has already captured the state.

**Error propagation:** If `order-service` throws an exception, its span turns red. WSO2's root span will also turn red because WSO2 received a 500 response from `order-service`. Both are red, but the *origin* of the error is in `order-service`. Always find the deepest red span to locate the root cause.

---

### Cross-Service Trace Propagation

In a distributed system, how does Datadog link spans from WSO2, Spring Boot, and MySQL into a single flame graph?

**The mechanism: trace context headers**

When WSO2 receives an inbound request, the Datadog agent injects a `dd-trace-id` header (or the W3C `traceparent` header) into the request. When WSO2 calls `order-service`, it forwards this header. When `order-service` calls MySQL via JDBC, the Datadog Java agent captures the same `trace_id` in the database span.

All three spans — WSO2, Spring Boot, MySQL — share the same `trace_id`. Datadog assembles them into one flame graph by joining on this ID.

**What this means in practice:**

- The `trace_id` you found in your H2–H3 log investigation is the same ID you will see in the APM flame graph.
- You can jump from a log line (with `trace_id:abc123`) directly to the flame graph by clicking the trace ID in the Log Explorer.
- If you see a span with no parent (an orphaned span), it means context propagation was broken — a service forwarded the call without passing the `dd-trace-id` header.

**Verifying propagation in your stack:**

For WSO2 → Spring Boot: WSO2 must be configured to forward the `dd-trace-id` and `dd-parent-id` headers when it proxies requests. In WSO2 API Manager 4.7 this is done via a sequence or handler configuration — if the trace shows WSO2 and `order-service` as separate, unlinked traces, check that WSO2 is not stripping custom headers.

---

### Log Correlation Panel Inside a Trace

One of the most powerful features in APM trace detail is the **Logs tab**. It automatically shows log lines that share the current trace's `trace_id`.

**How to use it:**

1. Open a trace in full-screen mode.
2. Click the **"Logs"** tab at the bottom of the trace detail panel (next to "Infrastructure", "Processes").
3. The panel shows all log lines emitted during this exact request, from all services that injected `trace_id` into their log output.

**What you see:**

- WSO2 access log: `GET /api/v1/orders/10042 200 3842ms`
- Spring Boot application log: `OrderService: Starting order lookup for orderId=10042`
- Spring Boot application log: `OrderService: DB query took 3512ms — slow query threshold exceeded`
- Spring Boot application log: `OrderService: Returning order with 1 item`

You get the complete narrative of the request across all services without manually correlating `trace_id` in the Log Explorer.

**Prerequisite:** Each service must inject `dd.trace_id` and `dd.span_id` into its log output. For Spring Boot with Logback this is done by adding the Datadog MDC fields to the log pattern. If logs do not appear in the tab, the service is not injecting the trace context into logs.

---

## Investigation Drill — 4-Second Trace to Bottleneck

**Scenario:** A Trace Explorer query (`service:wso2-api-gateway @duration:>3s env:production`) returns a 4,020ms trace. Identify whether the bottleneck is in WSO2, Spring Boot, or MySQL.

**Step 1: Open the trace, orient on the root span**
- Click the trace row. The flame graph opens.
- The topmost (widest) bar is the WSO2 root span: `wso2-api-gateway: servlet.request — 4,020ms`.
- WSO2's total duration = 4,020ms. WSO2 itself is not the bottleneck — it is just holding the connection open while waiting for downstream.

**Step 2: Find the critical child**
- WSO2 has one child span: `order-service: servlet.request — 3,960ms`.
- That child starts at ~10ms and ends at ~3,970ms.
- WSO2 spent only ~60ms on its own work (JWT validation + routing). Everything else is `order-service`.

**Step 3: Drill into order-service**
- `order-service` has several children:
  - `spring.handler: OrderController.createOrder — 3,950ms` (critical child)
  - `http.request: payment-service — 80ms` (short, parallel, not on critical path)
- Click the `OrderController.createOrder` span: resource = `POST /api/v1/orders`, duration = 3,950ms.

**Step 4: Find the MySQL children**
- `OrderController.createOrder` has several MySQL children:
  - `mysql.query: SELECT order_items WHERE order_id=? — 3,510ms` ← widest bar
  - `mysql.query: SELECT products WHERE id=? — 12ms` × 40 spans (N+1, but not the longest)
- Click the 3,510ms MySQL span.

**Step 5: Read the span metadata**
- `db.statement`: `SELECT oi.*, p.name, p.description, p.image_url FROM order_items oi JOIN products p ON oi.product_id = p.id LEFT JOIN inventory i ON p.id = i.product_id WHERE oi.order_id = ?`
- `db.row_count`: `1`
- `out.host`: `orders-db.cluster-xyz.us-east-1.rds.amazonaws.com`

**Conclusion:** The bottleneck is a single MySQL query — a multi-table JOIN returning 1 row but taking 3.5 seconds. Likely missing index on `order_items.order_id` or on `inventory.product_id`. WSO2 and Spring Boot are healthy; the fix is a database schema change.

**Step 6: Confirm with the Logs tab**
- Click the "Logs" tab. You see the Spring Boot log line: `"Slow query detected: 3510ms for order_id=10042"`.
- This confirms the DB timing matches the slow query log your DBA enabled.

---

## Exercises

**Exercise 1 — Critical path identification**

You open a 2,800ms trace. The flame graph shows:

```
[wso2-api-gateway: 2,800ms]
  └─[order-service: 2,750ms]
       ├─[redis.command: GET order:cache — 15ms]
       ├─[mysql.query: SELECT orders WHERE id=? — 2,700ms]
       └─[http.request: notification-service — 20ms]
```

Which span is on the critical path? What is the WSO2 self-time (time spent in WSO2's own code, excluding downstream)?

> **Hint:** Self-time = parent duration minus the duration of the longest sequential child. Is WSO2 waiting for `order-service` the entire time, or doing parallel work?

> **Solution sketch:**
> Critical path: `wso2-api-gateway → order-service → mysql.query`. The 2,700ms MySQL span drives almost all of the latency.
>
> WSO2 self-time ≈ 2,800ms − 2,750ms = 50ms. WSO2 spent only 50ms on its own processing (auth, routing, etc.) and 2,750ms waiting for `order-service` to respond.
>
> The Redis and notification-service spans are children of `order-service` but run sequentially with MySQL. If they overlap with MySQL they are not on the critical path. If they run after MySQL they add ~35ms. Either way, they are not the bottleneck.

---

**Exercise 2 — Error origin in a multi-service trace**

A trace shows three red spans:

```
[wso2-api-gateway: 210ms] ← RED
  └─[order-service: 180ms] ← RED
       └─[mysql.query: 170ms] ← RED
```

All three are red. Where would you look first to find the root cause? What fields would you read in the MySQL span?

> **Hint:** In error propagation, the root cause is at the *deepest* span in the error chain. Upstream services become red because they receive an error response from downstream.

> **Solution sketch:**
> Start at the MySQL span — it is the deepest red span and the likely origin of the error.
>
> Fields to read on the MySQL span:
> - `error.type` — is it `com.mysql.cj.jdbc.exceptions.CommunicationsException` (connectivity), `java.sql.SQLSyntaxErrorException` (bad query), or `java.sql.SQLException: Deadlock found`?
> - `error.message` — the human-readable description.
> - `db.statement` — the SQL query that failed. A syntax error in the query string is immediately visible here.
>
> If the MySQL span error is `Deadlock found when trying to get lock`, the fix is in transaction isolation or query ordering in Spring Boot, not in WSO2.

---

**Exercise 3 — Log correlation**

You open a trace and click the "Logs" tab but the tab shows 0 log lines, even though you can see Spring Boot processing the request in the flame graph.

What are the two most likely root causes, and how would you verify each?

> **Hint:** Think about the two requirements for log correlation to work: the log must exist in Datadog, and the log must have the `trace_id` injected into it.

> **Solution sketch:**
> **Root cause 1: Spring Boot is not injecting `dd.trace_id` into log output.**
> Verify: Go to Log Explorer, search for `service:order-service` and look at a raw log line. If you do not see `dd.trace_id` or `trace_id` fields in the log attributes panel, the Logback/Log4j configuration is missing the Datadog MDC fields. Fix: add `%X{dd.trace_id}` to the log pattern and ensure the Datadog Java agent's log injection is enabled.
>
> **Root cause 2: Logs are arriving but with a different `trace_id` format.**
> Datadog uses a decimal `trace_id` in APM but some integrations log a hex `trace_id`. Verify: copy the `trace_id` from the APM trace panel and search for it manually in the Log Explorer. If it appears in hex format and not decimal, the log injection configuration needs the `datadog.logs.injection` system property set correctly.

---

## Anti-Patterns

**Assuming the widest bar is always the root cause.** The widest bar at the top is often just the HTTP server span holding the connection open. Look for the widest bar at the *leaf* level — that is where the actual work is being done.

**Fixing off-critical-path spans.** If the MySQL query is 3.5s but you instead optimise a 20ms Redis call that is not on the critical path, you reduce the trace from 4s to 3.98s. Always identify the critical path before deciding what to fix.

**Reading only the first error span.** In a chain where `order-service` catches a MySQL exception and re-throws a wrapped `ServiceException`, the `order-service` span shows the wrapped error but not the original. Always scroll to the deepest red span to find the original exception.

**Ignoring `db.row_count`.** A query taking 3 seconds returning 1 row and a query taking 3 seconds returning 50,000 rows are very different problems. The first is likely a missing index (optimizer is doing a full scan to find the row). The second might be expected for a batch operation. Always check row count before assuming a query is badly written.

**Not using the Logs tab.** Many engineers open a trace, read the flame graph, and close it. The Logs tab often has the single most informative line — the application's own log message describing what it was doing, with timestamps that confirm the DB timing. It is one click and saves 10 minutes of manual `trace_id` searching in Log Explorer.

**Blaming the first long span you see.** A 500ms WSO2 span that processes JWT + rate-limits + routes is not necessarily slow — check the baseline. The same 500ms span on a normally-50ms route is a problem. Always compare against a healthy trace before declaring something abnormal.
