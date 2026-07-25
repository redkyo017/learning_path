# Day 2 Lab — validate a capacity estimate with k6

Goal: you estimated the shortener's write throughput in Beat 2. Now **measure a real
single instance** and compare. The insight isn't "did the laptop hit 6,000/s" (it
won't) — it's understanding *why* one instance ceilings where it does, and what that
implies for the fleet-level estimate.

Prereqs: Docker + the shared `labs/` stack, Go 1.22+, k6 (`brew install k6`).
Everything runs locally; **tear down at the end**.

## 1. Bring up Postgres (from the shared stack)
```bash
cd /Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design/labs
docker compose up -d postgres
docker compose ps          # postgres should be healthy
```

## 2. Run the shortener service
```bash
cd ../days/day02-estimation/lab/shortener
go mod tidy                # resolves github.com/lib/pq (writes go.sum)
go run .                   # auto-creates the short_urls table; listens on :8080
```
Sanity check in another terminal:
```bash
curl -s localhost:8080/health
curl -s -XPOST localhost:8080/shorten -H 'Content-Type: application/json' -d '{"url":"https://example.com"}'
# -> {"code":"aZ3k9Qs"}   then follow it:
curl -si localhost:8080/r/aZ3k9Qs | head -1     # -> HTTP/1.1 302 Found
```

## 3. Drive your estimated write QPS (MODE=rate)
Set `TARGET_RPS` to a fraction of your Day-2 peak estimate and watch the p95 vs your
latency budget. Start modest and climb:
```bash
cd ../k6
k6 run --env MODE=rate --env TARGET_RPS=1000 --env LAT_BUDGET_MS=100 shorten.js
k6 run --env MODE=rate --env TARGET_RPS=3000 --env LAT_BUDGET_MS=100 shorten.js
```
Read from the k6 summary: `http_reqs` (achieved RPS = count/60s), `http_req_duration`
p95, and `http_req_failed` rate. If k6 warns *"insufficient VUs to reach target rate,"*
that itself is a finding — the service can't keep up, so requests queue.

## 4. Break-it — find the single-instance ceiling (MODE=spike)
```bash
k6 run --env MODE=spike --env LAT_BUDGET_MS=100 shorten.js
```
**What you should observe:** as VUs climb, p95 stays flat, then bends sharply upward at
some RPS — that knee is your single-instance ceiling. Past it, `http_req_failed` rises
(timeouts / pool exhaustion). This is Little's Law in the flesh (`L = λ × W`): when W
climbs, in-flight count L exceeds the connection pool and requests wait.

Now make the ceiling move to *prove the mechanism*:
```bash
# Restart the service with a tiny pool and repeat the spike — the knee arrives sooner:
cd ../shortener
MAX_OPEN_CONNS=4 go run .
# (re-run the spike in the k6 terminal)
```
A smaller `MAX_OPEN_CONNS` should lower the ceiling → confirms the DB connection pool
(not CPU) is the binding constraint here.

## 5. Compare to your estimate
- Your Day-2 **fleet** estimate was ~6,000 writes/s peak. A single laptop instance will
  ceiling far below that (often a few hundred to a few thousand RPS depending on disk
  fsync + pool). **That gap is the design decision:** `instances ≈ peak_QPS / per_instance_ceiling`.
  Measuring the denominator is exactly why you validate estimates instead of trusting them.
- Record everything in `results.md` and answer: *was my estimate right, and what did the
  measurement change?*

## 6. Teardown (mandatory)
```bash
cd /Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design/labs
docker compose down -v
```

---
### Offline / no-network fallback for `go mod tidy`
If the module cache can't fetch `github.com/lib/pq`, you have two options:
1. Use k6 against the **shared echo service** instead (`labs/services/echo`, no DB deps)
   to at least exercise the spike profile and see a latency knee — you lose the DB write
   path but keep the Little's-Law lesson. Point `--env BASE=...` at echo and change the
   script's request to `GET /work?ms=5`.
2. Pre-warm the cache when you do have network: `go mod download github.com/lib/pq`.
