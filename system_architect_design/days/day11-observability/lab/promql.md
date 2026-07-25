# PromQL for the Day 11 RED metrics

The services expose `http_requests_total{route,method,status}` and
`http_request_duration_seconds{route,method}` (a histogram → `_bucket`, `_count`,
`_sum`). Run these in the Prometheus UI (http://localhost:9090).

## Duration (the D in RED) — p95 / p99 per route

```promql
# p95 latency per route over the last 5m (seconds)
histogram_quantile(0.95,
  sum by (le, route) (rate(http_request_duration_seconds_bucket[5m])))

# p99
histogram_quantile(0.99,
  sum by (le, route) (rate(http_request_duration_seconds_bucket[5m])))
```

Why `histogram_quantile` over buckets and not an average: percentiles cannot be
averaged across instances; you must aggregate the raw histogram buckets. See
`content/day11.md`.

## Rate (the R) — requests/sec per route

```promql
sum by (route) (rate(http_requests_total[1m]))
```

## Errors (the E) — 5xx ratio (an availability SLI)

```promql
# error ratio per route (fraction of requests that were 5xx)
sum by (route) (rate(http_requests_total{status=~"5.."}[5m]))
  /
sum by (route) (rate(http_requests_total[5m]))
```

## A latency SLI as a ratio (good-events / total)

```promql
# fraction of /call requests served under 300ms (SLI for SLO "99% < 300ms")
sum(rate(http_request_duration_seconds_bucket{route="/call",le="0.3"}[5m]))
  /
sum(rate(http_request_duration_seconds_count{route="/call"}[5m]))
```

Compare A's `/call` p95 to B's `/work` p95 during the break-it step: A's spikes
(it includes the Toxiproxy latency), B's stays flat — the metrics agree with the
trace that the time is in the *call to* B, not in B.
