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
