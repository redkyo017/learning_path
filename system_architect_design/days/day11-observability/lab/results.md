# Day 11 Lab results — trace + RED metrics + fault localization

## End-to-end trace (healthy)
- trace_id: __________
- A `GET /call` total: ______ ms
- B `do-work` span: ______ ms  (B's share of total ≈ ____%)
- Confirmed one trace spans both A and B (context propagated)? (yes/no): ____

## SLI / SLO
- SLI defined: __________________ (e.g. fraction of /call < 300ms)
- SLO target: __________ over __________ window
- Current p95 `/call`: ______ ms   Current 5xx ratio: ______
- Can I actually MEASURE this SLI with what I emit today? (red-team): ____

## BREAK-IT — injected Toxiproxy latency (find it from telemetry alone)
| Metric | Before toxic | After +400ms toxic |
|--------|--------------|--------------------|
| A `/call` p95 |  |  |
| B `/work` (do-work) p95 |  |  |
| A client span `GET /work` (Jaeger) |  |  |
| B server `do-work` span (Jaeger) |  |  |

- Diagnosis from the trace ALONE (no code): __________________________
  (expect: "time is in the call to B, not in B's work → network/proxy")
- How the metrics corroborated it: __________
- trace_id of the slow request: __________

## Cardinality check
- Did I keep user/order/raw-path OFF the metric labels? (yes/no): ____
- Where would high-cardinality context go instead: __________ (span attributes)

## Takeaway
- One-line: a metric told me *that* /call breached; the trace told me *where*
  (the hop to B); ____ told me *why*.
