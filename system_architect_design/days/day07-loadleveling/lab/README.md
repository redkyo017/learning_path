# Day 7 lab — a queue absorbs a spike; a bound sheds gracefully

Goal: watch a synchronous service fall over under a 10× spike, then insert a
bounded queue + workers and watch ingress latency stay flat while queue **depth**
absorbs the burst — then break it (unbounded) and fix it (bound + 429).

Prereqs: Docker, Go 1.22+, `k6` (`brew install k6`). All paths below are absolute.

```
BASE=/Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design
```

## 0. Bring up Redis (the queue backing store)

```bash
cd $BASE/labs
docker compose up -d redis
docker compose ps        # redis healthy
```

## Stage A — spike a SYNCHRONOUS service (watch it fall over)

Run the shared echo service (50ms of "work" per request):

```bash
cd $BASE/labs/services/echo
PORT=8080 NAME=sync go run .
```

In another terminal, spike it:

```bash
cd $BASE
k6 run days/day07-loadleveling/lab/k6/spike-sync.js
```

**Observe & record:** during the 500-VU spike, `http_req_duration` p95/p99 climbs
far past 50ms (requests queue up inside the server's accept backlog), and
`http_req_failed` rises as k6's client-side timeouts fire. This is congestion
collapse — the server is busiest doing work nobody is still waiting for.
Record p50/p95/p99 + error rate in `results.md` (the **before** row).

Stop echo (Ctrl-C).

## Stage B — insert a bounded queue + workers (watch it absorb)

Start the queue service. First run is UNBOUNDED-off-by-default; here we set a
generous bound and the natural service rate μ = WORKERS/WORK_MS = 4/50ms = 80/s:

```bash
cd $BASE/days/day07-loadleveling/lab/queue
go mod download        # fetches go-redis (needs network once)
QUEUE_MAX=2000 WORKERS=4 WORK_MS=50 REDIS_ADDR=localhost:6379 go run .
# logs: "... => mu=80 jobs/s"
```

Watch queue depth in a third terminal while you drive load:

```bash
# sample depth once a second
while true; do redis-cli LLEN day7:jobs; sleep 1; done
# or hit the service:  watch -n1 'curl -s localhost:8090/depth'
```

Drive the same spike at the queue's ingress:

```bash
cd $BASE
k6 run days/day07-loadleveling/lab/k6/spike-queue.js
```

**Observe & record:** `http_req_duration` for `/enqueue` stays **flat and low**
(single-digit ms) through the entire spike — the handler only does an LPUSH. The
burst appears as queue **depth** climbing (hundreds→toward the bound) and draining
afterward at ~80/s. Check final tallies:

```bash
curl -s localhost:8090/stats   # {enqueued, shed, processed, depth}
```

Record the ingress p95 (should be ~flat vs Stage A) and the peak/observed depth.

## Stage C — BREAK IT, then fix it

**Break it (unbounded):** stop the queue service, restart with `QUEUE_MAX=0`
(unbounded) and drive *sustained* over-capacity load. Depth grows without limit —
this is the OOM / latency→∞ failure mode.

```bash
cd $BASE/days/day07-loadleveling/lab/queue
QUEUE_MAX=0 WORKERS=4 WORK_MS=50 go run .
# in another terminal, sustained overload (edit the script or just hold VUs):
cd $BASE && k6 run --vus 300 --duration 60s days/day07-loadleveling/lab/k6/spike-queue.js
# watch depth climb monotonically and never recover during the run:
while true; do redis-cli LLEN day7:jobs; sleep 1; done
```

At 300 VUs the arrival rate λ far exceeds μ=80/s, so depth grows by ~(λ−80)/s the
whole time. A job enqueued at second 50 won't be processed for ~depth/80 seconds —
long after any real client has given up. **This is why unbounded queues are a
latent outage.** Record the ending depth and estimate the tail latency (depth/μ).

**Fix it (bound + 429):** restart with a real bound and repeat the sustained load.

```bash
QUEUE_MAX=500 WORKERS=4 WORK_MS=50 go run .
cd $BASE && k6 run --vus 300 --duration 60s days/day07-loadleveling/lab/k6/spike-queue.js
curl -s localhost:8090/stats   # note "shed" > 0 now
```

**Observe & record:** depth pins at ~500 and stops growing; excess requests get
**429 + Retry-After** (the `shed_429` k6 counter and `stats.shed` climb). Max added
latency is bounded at depth/μ = 500/80 ≈ 6.25s — a number you chose, not an
accident. The system now degrades *gracefully*: it protects the downstream and
tells clients honestly to back off (which they should do with jitter — Day 8).

## Teardown

```bash
# Ctrl-C the go and k6 processes, then:
cd $BASE/labs && docker compose down -v
```

## What to write up in `results.md`

- Stage A vs Stage B ingress p50/p95/p99 + error rate (the headline: flat ingress).
- Peak queue depth in Stage B and how long it took to drain.
- Stage C unbounded: ending depth + estimated tail latency (depth/μ).
- Stage C bounded: shed count, the pinned depth, the max added latency you chose.
- Little's Law check: does observed drain rate ≈ WORKERS/WORK_MS?
