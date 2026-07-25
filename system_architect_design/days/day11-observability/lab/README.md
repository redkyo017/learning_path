# Day 11 Lab — instrument A→B with OTel, read the trace, find an injected fault

**Goal:** add Jaeger + Prometheus + OpenTelemetry to the stack, instrument the
A→B call from Day 9 with a **propagated trace** + **RED metrics**, read the
end-to-end trace in Jaeger, define/measure an SLI in Prometheus, then **inject a
Toxiproxy latency into B and locate it from the trace/metrics alone — without
reading code.**

Uses the `svc/` Go program (runs as A or B) and the `--profile obs` stack already
defined in `labs/docker-compose.yml`.

> Prereq: Go 1.22+, Docker. The Go module needs the network **once** to resolve
> OTel/Prometheus deps.

---

## 0. Fetch modules (once, needs internet)

```bash
cd svc && go mod tidy && go build ./... && cd ..
```

## 1. Bring up the observability stack

```bash
cd ../../../labs
docker compose --profile obs up -d jaeger prometheus     # Jaeger :16686, Prometheus :9090
docker compose --profile fault up -d toxiproxy            # for the break-it step
docker compose ps
cd -   # back to this lab/ dir
```

- Jaeger UI: http://localhost:16686 · Prometheus: http://localhost:9090
- Prometheus is pre-configured (`labs/prometheus.yml`) to scrape
  `host.docker.internal:8080` and `:8081` — i.e. services A and B below.

## 2. Run the two instrumented services

```bash
# service B (downstream) — terminal 1:
( cd svc && NAME=B PORT=8081 go run . )
# service A (calls B) — terminal 2:
( cd svc && NAME=A PORT=8080 UPSTREAM=http://localhost:8081 go run . )
```

## 3. Generate a request and read the end-to-end trace

```bash
curl "http://localhost:8080/call?ms=50"     # A calls B; one trace, two services
```

Open Jaeger → service **A** → **Find Traces**. Open the trace and read the
**waterfall**:
- `A: GET /call` (root span) contains
- `A: GET /work` (client span, the outbound call — otelhttp injected `traceparent`), containing
- `B: GET /work` (B's server span), containing
- `B: do-work` (the sleep, ~50ms) with attribute `work.ms=50`.

You are seeing **one trace across two processes** because A's client transport
propagated the W3C trace context and B extracted it. Record in `results.md`: the
trace_id, the total duration, and B's share.

## 4. Define + measure an SLI in Prometheus

Send a little traffic so histograms fill:

```bash
for i in $(seq 1 200); do curl -s "http://localhost:8080/call?ms=50" >/dev/null; done
```

Open Prometheus (http://localhost:9090) and run the queries from `promql.md` — at
minimum the **p95 duration** and the **error ratio**. Write your SLI/SLO down
(e.g. *"99% of `/call` < 300ms over the window"*) and note the current p95.

## 5. BREAK IT — inject latency into B and find it from telemetry alone

Route A→B **through Toxiproxy**, then add a latency toxic:

```bash
# create a proxy in front of B, then add +400ms latency:
curl -s localhost:8474/proxies \
  -d '{"name":"b","listen":"0.0.0.0:18080","upstream":"host.docker.internal:8081"}'
curl -s localhost:8474/proxies/b/toxics \
  -d '{"type":"latency","attributes":{"latency":400}}'
```

Restart A pointing at the proxy instead of B directly:

```bash
# stop A (Ctrl-C in its terminal), then:
( cd svc && NAME=A PORT=8080 UPSTREAM=http://localhost:18080 go run . )
curl "http://localhost:8080/call?ms=50"
```

Now **diagnose from the trace/metrics — do NOT look at the code or the toxiproxy
command you just ran** (pretend a teammate did it):

- In Jaeger, the new trace shows **A's client span `GET /work` ≈ 450ms** but
  **B's `do-work` span still ≈ 50ms**. The ~400ms is *between A's send and B's
  receive* → the time is **in the call to B, not in B's work** → network/proxy,
  not B's logic. That is the whole skill: the waterfall localizes the fault.
- In Prometheus, `/call` p95 jumps ~400ms while B's own `/work` p95 is flat —
  same conclusion from metrics.

Record the trace_id, the two span durations, and your one-line diagnosis in
`results.md`. Remove the toxic and re-verify recovery:

```bash
curl -s -X DELETE localhost:8474/proxies/b/toxics/latency_downstream
```

(Optional) add an error toxic or run `/work?ms=50&fail=0.3` on B and watch
`http_requests_total{status="500"}` and the error branch's span attribute
`work.failed=true`.

## 6. Teardown

```bash
# stop the two go processes (Ctrl-C), then:
cd ../../../labs && docker compose --profile obs --profile fault down -v
```
