# H6 — Metrics + Infrastructure Investigation (~60 min)

## Why This Matters

At 14:22 on a Tuesday, your WSO2 API Gateway starts returning HTTP 503s to all clients. APM shows every Spring Boot service has elevated error rates, but the traces all terminate normally — the services themselves are responding. The real culprit is one level down: RDS MySQL has hit its `max_connections` limit and is refusing new connections. Your ECS Fargate tasks are fine; your application code is fine; but the database can no longer accept the flood of connection attempts spawned by a connection pool misconfiguration pushed to production 20 minutes earlier.

Without infrastructure metrics you would spend 30 minutes chasing phantom application bugs. With them, you navigate to the RDS dashboard, see `aws.rds.database_connections` flatlined at its ceiling, and have a root cause in under two minutes. This hour builds the vocabulary and navigation skills to get there fast.

The stack you are investigating: WSO2 API Gateway 4.7 → Spring Boot microservices on ECS Fargate → RDS MySQL (db.r6g.large, Multi-AZ). All components emit metrics to Datadog via the AWS integration and the Datadog Agent sidecar.

---

## Core Concepts

### Infrastructure Product Areas

Datadog's **Infrastructure** section in the left nav contains three main views. Each answers a different question.

**Host Map**
Shows every host (EC2 instance, on-prem server) registered with the Datadog Agent as a coloured hexagon. Colour encodes a chosen metric — typically CPU utilisation or a custom metric. Size encodes another metric (often memory). Useful when you want an instant visual scan: "are any hosts unusually hot?" For ECS Fargate workloads this view is mostly empty because Fargate tasks are not hosts in the traditional sense — no underlying EC2 is exposed. You will rarely use Host Map during ECS investigations.

**Containers**
Lists every running container the Agent is aware of, including ECS Fargate tasks. This is your primary view for container-level investigation. Columns show CPU%, Memory%, Network I/O, and the container's owning ECS service. You can filter, sort, and click into individual containers.

**Processes**
Shows OS-level processes inside containers that have process collection enabled. Useful when you need to see what is actually running inside a container — for example, whether a Java JVM process has ballooned in memory relative to container limits. Requires `process_config.process_collection.enabled: true` in the Agent configuration.

For ECS Fargate + Spring Boot investigations the workflow is:

1. Start in **Containers** to identify which tasks are resource-constrained.
2. Pivot to a **Metrics Explorer** or a pinned dashboard for specific metric graphs.
3. Use **Processes** if you need process-level granularity inside a suspect container.

---

### ECS Fargate — Container View

**Navigating to ECS containers:**

1. In Datadog, click **Infrastructure → Containers** in the left nav.
2. In the search bar, filter by `ecs_cluster_name:<your-cluster>` and/or `task_family:<your-service-name>`. For example: `ecs_cluster_name:prod-backend task_family:payment-service`.
3. The table updates to show only containers matching those tags.

**What the columns mean:**

| Column | What it shows | How to read it |
|---|---|---|
| **Name** | Container name as defined in the ECS task definition, e.g. `payment-service` or `datadog-agent` | Identifies which container within the task you are looking at |
| **CPU%** | CPU utilisation as a percentage of the container's CPU limit (not the host CPU). A 512-unit vCPU limit = 0.5 vCPU = 100% at full use | Values consistently above 80% indicate CPU throttling. A spike to 100% followed by a crash is a CPU-constrained restart |
| **Memory%** | Memory used as a percentage of the container's memory hard limit (the `memoryReservation` or `memory` field in the task definition) | Values trending toward 100% warn of impending OOM kill. Once the process exceeds the hard limit, the Linux kernel OOM killer terminates it |
| **Network I/O** | Bytes received and sent per second for the container's network interface | Sustained high send rates can indicate a runaway logging loop or data exfiltration; near-zero receive after normal activity can mean the container lost its network path |
| **Task count** | Not a Containers view column — visible on the ECS service dashboard or via `aws.ecs.service.running_count` metric | Shows how many tasks are currently running vs desired |

**Sorting and filtering tips:**
- Click the **Memory%** column header to sort descending — the hungriest containers float to the top.
- Add the column `ecs_task_arn` to copy the full ARN for cross-referencing CloudWatch logs.
- The search field supports tag facets from your Datadog tagging strategy: `env:production`, `service:payment-service`, `version:1.4.2`.

---

### Key ECS Metrics

Each metric below has an exact name as it appears in the Datadog metrics catalogue. These names are what you type into the Metrics Explorer, dashboards, and monitors.

---

**`aws.ecs.service.running_count`**

- **Source:** AWS CloudWatch via the Datadog AWS integration (no Agent needed on the task).
- **What it measures:** The number of ECS tasks in the RUNNING state for a given service at each collection interval (typically 1-minute resolution from CloudWatch).
- **Tags:** `clustername`, `servicename`, `region`.
- **How to read it:** Plot this alongside your error rate. A healthy service holds a flat line at your desired task count. A sudden drop — from 5 to 2 for example — means tasks crashed and ECS is restarting them. The gap between desired count (set in the ECS service definition) and running count is your "missing capacity" window.

---

**`container.cpu.usage`**

- **Source:** Datadog Agent sidecar (requires `DD_ECS_TASK_COLLECTION_ENABLED=true` on the Agent container).
- **What it measures:** Raw nanocores (nanoseconds of CPU time per second) consumed by the container. This is a raw count, not a percentage. For ECS Fargate, use `ecs.fargate.cpu.percent` to get CPU usage as a percentage of the container's CPU limit.
- **Tags:** `container_name`, `task_arn`, `ecs_cluster_name`.
- **How to read it:** High nanocores values relative to the container's CPU allocation indicate CPU pressure. For ECS Fargate percentage-based alerting, use `ecs.fargate.cpu.percent` instead — a value near 100 sustained for more than a minute indicates the container cannot get CPU time beyond its limit. Use `avg by container_name` to compare services side by side.

---

**`container.memory.usage`**

- **Source:** Datadog Agent sidecar.
- **What it measures:** Raw bytes of memory currently used by the container's cgroup. This is a raw byte count, not a percentage. For ECS Fargate, use `ecs.fargate.mem.usage` (bytes used) and `ecs.fargate.mem.limit` (bytes limit) to track memory. The ratio `ecs.fargate.mem.usage / ecs.fargate.mem.limit` gives the memory utilisation percentage.
- **Tags:** `container_name`, `task_arn`, `ecs_cluster_name`.
- **How to read it:** Monitor the ratio `ecs.fargate.mem.usage / ecs.fargate.mem.limit`. When this ratio approaches 1.0 (or ~95%), the container is near its memory limit. Once the process exceeds the hard limit, the Linux kernel OOM killer terminates the container — ECS will mark the task as STOPPED with exit code 137, and `aws.ecs.service.running_count` will drop. The key pattern to watch: a slow upward creep (memory leak) that eventually reaches the limit, versus a sudden spike (a burst allocation, typically in batch processing).

---

**`container.net.rcvd.bytes`** and **`container.net.sent.bytes`**

- **Source:** Datadog Agent sidecar.
- **What they measure:** Bytes received (inbound) and sent (outbound) per second across the container's network interface.
- **Tags:** `container_name`, `task_arn`, `ecs_cluster_name`.
- **How to read them:** Normal values depend heavily on your traffic profile — establish a baseline during normal operations. Anomalies to watch for:
  - `rcvd.bytes` drops to near zero while the service is still expected to receive traffic: the task may have been deregistered from its load balancer target group.
  - `sent.bytes` spikes to an unusual high: a runaway logging loop sending large payloads, or a batch job exporting data unexpectedly.
  - Both metrics near zero simultaneously: the container is alive but not connected to the network — possible security group or VPC routing issue.

---

### Reading for OOM (Out of Memory Kill)

An OOM kill is a silent crash. The container does not log a friendly error; it simply vanishes. The visual pattern across three Datadog panels tells the story:

**Step 1 — Memory trending to the limit**
On a graph of `ecs.fargate.mem.usage` filtered to `task_family:payment-service`, you see a rising staircase pattern over 20–45 minutes. Each step is the JVM heap expanding. The line approaches the container's memory limit (tracked via `ecs.fargate.mem.limit`).

**Step 2 — Task count drops**
When the ratio `ecs.fargate.mem.usage / ecs.fargate.mem.limit` approaches 1.0 (~95%), memory usage (`ecs.fargate.mem.usage`) approaches the memory limit (`ecs.fargate.mem.limit`). Switch to `aws.ecs.service.running_count`. You will see a dip — one task disappears. ECS immediately launches a replacement (because DesiredCount is still 25), so the count recovers within 30–60 seconds. This shows up as a brief V-shape or notch in the running count graph.

**Step 3 — Gap in traces**
In APM → Services, look at the throughput graph for the same time window. The OOM-killed task was handling live requests at the moment it died. Those requests are orphaned — they never completed and never reached a downstream span. You will see a brief flat spot or drop in throughput, and the error rate may spike with connection-reset errors from clients that were mid-request.

**Confirming the OOM kill:**
- Filter Log Explorer for `ecs.cluster:prod-backend service:payment-service` and search for `OOMKilled` or `exit code 137`. ECS task state-change events forwarded to Datadog logs contain this detail.
- In Containers view, look at the `Status` column for recently stopped containers — `OOMKilled` appears as the stop reason.

**Why it matters for Spring Boot on ECS Fargate:**
The JVM does not respect cgroup memory limits by default in older JDK versions. JDK 8u131+ and JDK 10+ include `UseContainerSupport` (enabled by default from JDK 10). Without it, the JVM reads the host's total memory and allocates a heap far larger than the container allows, causing reliable OOM kills shortly after startup under load.

---

### RDS MySQL — Key Metrics Panel

A well-configured RDS MySQL dashboard in Datadog shows a set of panels that together tell you whether the database is healthy, saturated, or degrading. Below are the six most important metrics, what they mean, and what threshold to worry about.

---

**`aws.rds.database_connections`**

- **Source:** AWS CloudWatch via Datadog AWS integration, published every 1 minute.
- **What it measures:** The number of active database connections at the time of the CloudWatch data point.
- **Tags:** `dbinstanceidentifier`, `region`, `engine`.
- **Threshold to watch:** Your MySQL instance's `max_connections` parameter (viewable in Parameter Groups in the RDS console). For a `db.r6g.large` with 16 GB RAM the default is approximately 1,300 connections, but this varies by `innodb_buffer_pool_size`. A common Spring Boot HikariCP pool with 10 connections per service instance × 50 instances = 500 connections. When you see `database_connections` flatlined at exactly `max_connections`, the database is refusing new connections and your application logs will show "too many connections" errors.

---

**`aws.rds.free_storage_space`**

- **Source:** AWS CloudWatch.
- **What it measures:** Bytes of free storage remaining on the RDS instance's allocated storage volume.
- **Why it matters:** When free storage reaches zero, MySQL stops accepting writes. InnoDB cannot write to its redo log and the instance becomes read-only, which looks like an application hang (writes block indefinitely waiting for disk).
- **Alert threshold:** Below 10% of allocated storage. For a 500 GB instance, alert when `free_storage_space < 50,000,000,000` bytes (50 GB). A sudden drop in free storage is often caused by binlog accumulation (replication lag) or a slow query that created a large temporary table.

---

**`aws.rds.read_latency`** and **`aws.rds.write_latency`**

- **Source:** AWS CloudWatch.
- **What they measure:** Average time in seconds for each read or write I/O operation to complete. These are disk-level latencies, not query latencies.
- **Normal range:** For gp3 EBS storage (the RDS default), read and write latency should be below 0.001 seconds (1 ms) for typical OLTP workloads. Values above 0.01 seconds (10 ms) indicate storage saturation. Values above 0.1 seconds (100 ms) will cause visible application slowness.
- **How to read them together:** `read_latency` high + `write_latency` normal → you are doing too many random reads (missing indexes, full table scans). Both high simultaneously → I/O throughput is saturated, consider upgrading storage type or instance class.

---

**`aws.rds.queries`**

- **Source:** AWS CloudWatch.
- **What it measures:** The average number of queries executed per second during each 1-minute period.
- **How to use it:** First, establish your normal baseline (e.g., 800 QPS during peak hours). A spike to 5× baseline without a corresponding traffic increase indicates a runaway query loop, a missing cache layer that should be absorbing reads, or a badly optimised batch job. A drop to near zero despite application traffic means connections are failing before queries can be submitted.

---

**`aws.rds.deadlocks`**

- **Source:** AWS CloudWatch.
- **What it measures:** The average number of deadlocks per second.
- **When to worry:** Any non-zero value warrants investigation. Deadlocks mean two transactions are waiting on each other's locks; MySQL resolves them by killing one transaction (the "victim" transaction), which causes an error in your application. In Spring Boot with `@Transactional` methods, the application will surface this as a `CannotAcquireLockException` or `DeadlockLoserDataAccessException`. Occasional deadlocks (1–2 per hour) may be tolerable; a sustained rate of >1 per second indicates a schema design or transaction ordering problem.

---

**`mysql.performance.slow_queries`**

- **Source:** Datadog MySQL integration (requires the `datadog` MySQL user and the `performance_schema` enabled). This is different from the AWS CloudWatch metrics — it comes from the Datadog Agent running a check against the MySQL `performance_schema` tables.
- **What it measures:** Count of slow queries (queries exceeding `long_query_time`, typically 1 second) in the last collection interval.
- **Tags:** `host`, `port` — note this metric does not automatically carry the ECS service tags, so you need to use the `dbinstanceidentifier` tag to link it to the RDS instance.
- **How to read it:** A rising slow query count alongside rising `read_latency` confirms that slow reads are causing the latency increase. Pivot from here to APM Database Monitoring (if enabled) or to RDS Enhanced Monitoring to identify which query patterns are slow.

---

### Correlating a Metric Event to Logs

The most common workflow in infrastructure investigation is: you see a spike or anomaly on a metric graph, and you want to find the log lines that explain it. The technique is timestamp pivot.

**Step-by-step:**

1. **Identify the event time on the metric graph.** Hover over the spike in the Datadog metric graph. The tooltip shows the exact timestamp — note it, for example `2026-09-24 14:22:31 UTC`.

2. **Widen the window by 2–3 minutes.** A metric data point is a 1-minute average; the event that caused it started before the peak data point. Subtract 2 minutes to get your search window start time, add 1 minute to get your end time. For the example above: start `14:20:31`, end `14:23:31`.

3. **Open Log Explorer and set the time range.** In Log Explorer, click the time picker in the top right. Choose **Custom range** and enter the start and end timestamps. Use UTC to avoid timezone confusion.

4. **Apply the correct service filter.** Add `service:<your-service-name>` and `env:production` to the search bar. If the metric was an RDS metric (`aws.rds.*`), filter for the application services that connect to that RDS instance — the application logs will show the database errors.

5. **Search for error keywords.** For a connection exhaustion event: search `"too many connections"` or `"HikariPool"` or `"Communications link failure"`. For an OOM: search `"OutOfMemoryError"` or `"exit code 137"`. For a deadlock: search `"Deadlock"` or `"CannotAcquireLock"`.

6. **Pivot back to traces from a log line.** If a log line has a `trace_id` field (added by the Datadog Java APM agent), click **View in APM** from the log line detail panel to jump to the specific trace.

**Using the metric graph's built-in annotation:**
Datadog metric graphs support event overlays. Note the time range of the metric spike, then open Log Explorer with that same time window. Spikes in log volume that coincide with a metric spike are a strong signal.

---

## Investigation Drill — RDS Connection Exhaustion

**Scenario:** At 09:15 UTC, the WSO2 API Gateway begins returning 503s. APM error rate for `payment-service` spikes to 40%. ECS task count is healthy (25/25 running). You need to find the root cause.

**Walk-through:**

**1. Rule out ECS first (2 minutes)**

Navigate to Infrastructure → Containers. Filter `task_family:payment-service env:production`. Sort by Memory% and CPU%. All values are in normal range — no tasks are CPU-throttled or near OOM. The tasks are alive and not stressed.

**2. Open the RDS MySQL dashboard (1 minute)**

In Datadog, open your team's RDS overview dashboard (or navigate to Metrics Explorer and search `aws.rds.database_connections`). Scope to `dbinstanceidentifier:prod-mysql-primary`.

**3. Find the breach time (2 minutes)**

The `aws.rds.database_connections` graph shows a flat line at 1,300 connections from approximately 09:10 UTC onward. Your `max_connections` for this instance is 1,300. This is connection exhaustion — the flat-top pattern (connections pinned at the ceiling) is diagnostic. Before 09:10 the value was varying between 400 and 600, normal for your workload.

**4. Note the event time: 09:10 UTC.**

**5. Correlate to application logs (3 minutes)**

Open Log Explorer. Set the time range to `09:08 UTC → 09:15 UTC`. Filter `service:payment-service env:production`. Search `"too many connections"`. You will find a burst of log lines: `HikariPool-1 - Connection is not available, request timed out after 30000ms` appearing from 09:10:03 UTC onward.

**6. Find the trigger (2 minutes)**

Scroll back slightly further in the logs to `09:07–09:10`. Look for deployment events or configuration changes. You find: `ECS task definition update: payment-service:47 → 48` at 09:09:42 UTC. Task definition 48 changed the HikariCP `maximumPoolSize` from 10 to 50. With 25 tasks × 50 connections = 1,250 potential connections, plus 5 WSO2 processes × 10 connections each = 1,300 total — exactly the limit, hit immediately when all tasks restarted with the new configuration.

**7. State the root cause clearly:**

> "RDS connection exhaustion caused by a HikariCP pool size increase in task definition payment-service:48 deployed at 09:09:42 UTC. With 25 tasks × 50 connections = 1,250 application connections plus 50 WSO2 connections, the instance's `max_connections` limit of 1,300 was reached at 09:10 UTC. ECS tasks are healthy; the database is healthy; the configuration change is the cause."

---

## Exercises

### Exercise 1 — ECS OOM Detection

**Scenario:** You receive an alert that `aws.ecs.service.running_count` for `order-service` dropped from 4 to 3 at 11:45 UTC and recovered to 4 by 11:46 UTC. You need to confirm whether this was an OOM kill.

**Task:** Using the panels available in the Containers view and Metrics Explorer, determine whether the task drop was caused by OOM and identify which container instance was killed.

**Hint:** The key evidence is the timing relationship between memory usage (`ecs.fargate.mem.usage`) approaching the memory limit (`ecs.fargate.mem.limit`) — the ratio approaching 1.0 or ~95% — and the dip in `aws.ecs.service.running_count`. Look for the V-shape in running count and the cliff-drop in memory usage (the line ends abruptly when the container disappears). Also check Log Explorer for `exit code 137` or `OOMKilled` in ECS task state-change events.

**Solution sketch:**
1. Open Metrics Explorer. Plot `ecs.fargate.mem.usage` and `ecs.fargate.mem.limit` filtered to `task_family:order-service env:production`. Set the time range to 11:40–11:50 UTC. Look for a container instance where `ecs.fargate.mem.usage` approaches `ecs.fargate.mem.limit` (the ratio approaches 1.0, or ~95%) and then both lines drop to zero (the container disappears) at 11:45.
2. On the same graph or a second panel, overlay `aws.ecs.service.running_count` for `servicename:order-service`. You should see the notch at 11:45–11:46 aligning with the memory cliff.
3. Open Log Explorer, time range 11:44–11:46 UTC, filter `service:order-service`, search `OOMKilled OR "exit code 137"`. The ECS task state-change event logged by the Datadog AWS integration will name the specific `task_arn`.
4. Cross-reference the `task_arn` from the log with the container instance that disappeared from the `ecs.fargate.mem.usage` graph to confirm they are the same task.
5. State the conclusion: "Task `arn:aws:ecs:ap-southeast-1:...` was OOM-killed at 11:45:03 UTC after the ratio `ecs.fargate.mem.usage / ecs.fargate.mem.limit` approached 1.0 (~95%). The JVM heap grew to the container limit, triggering a kernel OOM kill (exit code 137)."

---

### Exercise 2 — RDS Slow Queries

**Scenario:** Users report that the `GET /orders` endpoint has become slow — P99 latency jumped from 200 ms to 4 seconds at 15:00 UTC. APM shows the slowness is in the `db.type:mysql` span. You want to confirm slow queries are the cause and estimate how many are occurring per minute.

**Task:** Use the RDS metrics to confirm slow query activity, identify whether the latency is read or write latency, and determine whether deadlocks are also present.

**Hint:** The metric `mysql.performance.slow_queries` tells you the count of slow queries. Pair it with `aws.rds.read_latency` and `aws.rds.write_latency` to understand whether reads or writes are slow. The scope should be `host:prod-mysql-primary` for the MySQL integration metric and `dbinstanceidentifier:prod-mysql-primary` for the CloudWatch metrics. Check both in the same time window (14:58–15:05 UTC) to see which rose first.

**Solution sketch:**
1. Open the RDS dashboard (or Metrics Explorer). Plot `mysql.performance.slow_queries` scoped to `host:prod-mysql-primary`, time range 14:55–15:10 UTC. A rising count starting at 15:00 (e.g., from 0 to 15 slow queries per minute) confirms slow query activity.
2. Plot `aws.rds.read_latency` and `aws.rds.write_latency` (both on `dbinstanceidentifier:prod-mysql-primary`) on the same or adjacent graph. If `read_latency` rose from 0.001 s to 0.08 s while `write_latency` stayed flat, this is a read-heavy slow query pattern — likely a missing index or a large full table scan.
3. Plot `aws.rds.deadlocks`. If it is zero, deadlocks are not contributing. If it is non-zero, note the rate.
4. Plot `aws.rds.queries` (QPS). A rising QPS combined with rising latency indicates genuine query saturation. A flat or falling QPS with rising latency indicates a few individual queries became much slower.
5. State the finding: "RDS read latency increased from 1 ms to 80 ms at 15:00 UTC. Slow query count rose to 15/minute. QPS remained flat at 800. No deadlocks. Pattern is consistent with a slow read query (full table scan or missing index). Next step: enable RDS Enhanced Monitoring or use APM Database Monitoring to identify the specific query text."

---

### Exercise 3 — Metric-to-Log Correlation

**Scenario:** You are reviewing yesterday's metrics and notice a spike in `container.net.sent.bytes` for `report-service` at 22:30 UTC — it jumped from a normal 50 KB/s to 8 MB/s for approximately 5 minutes. This happened outside business hours. You need to find the log lines that explain what the service was sending.

**Task:** Use the timestamp pivot technique to find the relevant log window, identify what triggered the large outbound transfer, and determine whether it was expected or anomalous.

**Hint:** The metric spike is from 22:30 to 22:35 UTC. Add 2 minutes of buffer on each side to catch the trigger event in logs. Filter logs for `service:report-service env:production`. Search for keywords related to file generation, S3 uploads, or export jobs — these are the common causes of large outbound network bursts from a reporting service. Check whether there is a scheduled task (`@Scheduled` in Spring Boot) configured to run at 22:30.

**Solution sketch:**
1. Open Log Explorer. Set the time range to `22:28 UTC → 22:37 UTC` (covering the spike plus buffer). Filter `service:report-service env:production`.
2. First scan the log volume bar chart — does log volume spike at 22:30, or is it flat? A high-volume log burst at the same time as the network spike is diagnostic.
3. Search for keywords: `"export"`, `"upload"`, `"S3"`, `"generate report"`, `"scheduled"`. Find the triggering log line, for example: `INFO  Scheduled monthly summary report generation started — 2026-09-23 22:30:00 UTC` followed by `INFO  Uploading report-2026-09 to s3://prod-reports-bucket — 7.8 MB`.
4. If you find a scheduled job explanation, the behaviour is expected. Note the timestamp and the log entry in your incident notes for future reference — this is a known scheduled job.
5. If no log explanation is found, escalate: "Unexplained 8 MB/s outbound burst from report-service at 22:30 UTC lasting 5 minutes. No log evidence of a scheduled job or user-initiated export. Recommend enabling verbose logging for outbound HTTP clients in report-service to trace the destination."

---

## Anti-Patterns

- **Jumping to logs before looking at metrics.** Logs are verbose and require keyword guessing. Metrics give you the timestamp and the affected component. Always establish the event time from a metric graph before opening Log Explorer — you will have a precise time window and know which service to filter for.

- **Scoping metrics to `*` (all services) during an incident.** Plotting `avg:container.memory.usage{*}` across all containers produces a meaningless average. Always scope to the specific service under investigation (`task_family:payment-service`) and break down by container name. An aggregate average hides individual containers that are critically stressed.

- **Assuming a task restart means an application bug.** Task restarts on ECS Fargate have multiple causes: OOM kill (exit 137), health-check failure (exit 1), application crash (exit non-zero), or ECS spot interruption. Look at the exit code in the ECS task state-change log before concluding there is an application bug.

- **Treating `aws.rds.database_connections` as a count of queries.** Database connections are persistent TCP connections held open by connection pools. One connection can execute thousands of queries. A high connection count does not mean high query volume; it may mean connection pools are too large, idle connections are not being released, or a connection leak is accumulating connections that are never closed.

- **Ignoring `aws.rds.free_storage_space` until it is critical.** Storage fills slowly and then suddenly reaches zero. This metric is a candidate for a monitor alert — that setup is Stage 2 scope. For now, note the free storage trend and its current value. A database that runs out of disk at 03:00 AM is a preventable P0 incident.

- **Using the Containers view CPU% column as the only signal for a slow service.** CPU throttling on ECS Fargate shows as a CPU% near 100% sustained, but a slow service can also be caused by network latency (the container is waiting for RDS, not consuming CPU), JVM garbage collection pauses (CPU spikes briefly then drops), or lock contention inside the application. Always cross-reference CPU metrics with APM latency and RDS metrics before concluding CPU is the bottleneck.
