# Day 9 lab — cascade, then contain

Goal: make dependency B slow, watch service A cascade (unprotected), then add a
breaker + timeout + bulkhead + cached fallback and watch A stay responsive with
degraded results — and watch the breaker transition states as B flaps.

Prereqs: Docker, Go 1.22+, `k6`. All paths absolute.

```
BASE=/Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design
```

## 0. Start B (dependency) and put it behind Toxiproxy

```bash
# B = shared echo, normally 50ms of work
cd $BASE/labs/services/echo && PORT=8081 NAME=B go run . &

# Toxiproxy: route :18080 -> B :8081 (no toxic yet = healthy)
cd $BASE/labs && docker compose --profile fault up -d toxiproxy
curl -s localhost:8474/proxies -d \
  '{"name":"b","listen":"0.0.0.0:18080","upstream":"host.docker.internal:8081"}'
```

`host.docker.internal` lets the container reach B on your host. A always calls B
*through* Toxiproxy at `localhost:18080`, so we can degrade B on demand.

## Stage A — CASCADE (unprotected)

Run the gateway (service A) unprotected, then warm the cache with one healthy call,
then degrade B and drive load:

```bash
cd $BASE/days/day09-circuit-breakers/lab/gateway
go mod download        # fetches sony/gobreaker (needs network once)
TARGET="http://localhost:18080/work?ms=50" PROTECT=off POOL=10 go run .
```

```bash
# healthy baseline first
cd $BASE && k6 run --duration 15s days/day09-circuit-breakers/lab/k6/load.js   # p95 ~ fine

# now DEGRADE B: +3000ms latency toxic
curl -s localhost:8474/proxies/b/toxics -d \
  '{"type":"latency","attributes":{"latency":3000}}'

# drive load again and watch A collapse
cd $BASE && k6 run days/day09-circuit-breakers/lab/k6/load.js
```

**Observe & record:** with B at +3000ms and A's pool = 10, Little's Law says A
needs 200 × ~3s = 600 in-flight but has 10 connections → requests block on the
pool, A's `http_req_duration` p95/p99 explode toward the client limit, and errors
(502/timeouts) climb. **One slow leaf dependency took A down.** Record before p95 +
error rate. Stop the gateway (Ctrl-C).

## Stage B — CONTAIN (protected)

Restart the gateway with protections on (keep the +3000ms toxic active):

```bash
cd $BASE/days/day09-circuit-breakers/lab/gateway
TARGET="http://localhost:18080/work?ms=50" PROTECT=on POOL=10 \
  TIMEOUT_MS=200 BULKHEAD=10 go run .
```

```bash
# warm the fallback cache with B healthy for a moment: remove toxic, one call, re-add
curl -s -X DELETE localhost:8474/proxies/b/toxics/latency_downstream
curl -s localhost:8082/get                       # populates lastGood cache
curl -s localhost:8474/proxies/b/toxics -d '{"type":"latency","attributes":{"latency":3000}}'

# drive load under the degraded B
cd $BASE && k6 run days/day09-circuit-breakers/lab/k6/load.js
watch -n1 'curl -s localhost:8082/state'          # in another terminal
```

**Observe & record:** each call to B now times out at 200ms (not 3s), so the pool
never exhausts; after ~20 failures cross the >50% threshold the breaker **opens**
(`/state` shows `breaker=open`) and calls fail *instantly* into the cached
fallback. A's p95 stays low, `served_fallback` climbs, and A returns 200s with
`X-Source: fallback-cache` — **degraded but up**. Record after p95 + error rate and
the breaker state.

## Break-it (also core) — flap B and watch the state machine

```bash
# heal B: A's half-open probes should succeed and the breaker should CLOSE
curl -s -X DELETE localhost:8474/proxies/b/toxics/latency_downstream
watch -n1 'curl -s localhost:8082/state'   # open -> (after 5s sleep window) half-open -> closed

# break B again: breaker re-opens after the failure threshold
curl -s localhost:8474/proxies/b/toxics -d '{"type":"latency","attributes":{"latency":3000}}'
```

Watch the gateway logs for the `breaker B: closed -> open -> half-open -> closed`
transitions. Note the half-open probe count (`MaxRequests=3`) prevents a recovery
stampede.

**Bonus break-it (no fallback):** hit `/get` before warming the cache while B is
down → you get `503 no fallback available`. This is the "when NOT a breaker"
lesson: with no safe fallback, the breaker only makes you fail faster.

## Teardown

```bash
# Ctrl-C the go + k6 processes, then:
cd $BASE/labs && docker compose down -v
```

## What to write up in `results.md`
- Stage A (unprotected) vs Stage B (protected): p50/p95/p99 + error rate under the
  same +3000ms B.
- served_live / served_fallback / served_error counts in Stage B.
- The breaker state transitions you observed as B flapped.
- The 503-no-fallback observation and what it teaches.
