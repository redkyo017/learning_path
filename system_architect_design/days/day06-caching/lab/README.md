# Day 6 lab — cache-aside, hit ratio, stampede, and the singleflight fix

**Goal:** measure the latency/DB-load win of cache-aside, then deliberately
trigger a **cache stampede** on a hot key and fix it with request coalescing
(`singleflight`).

Prereqs: Docker (Postgres + Redis), Go 1.22+, k6. Run app commands from the
`cacheapp/` dir; k6 from the `k6/` dir.

---

## 1. Bring up Postgres + Redis and seed

```bash
cd labs
docker compose up -d postgres redis
docker compose ps                       # postgres + redis healthy
```

Seed and start the service (the app seeds itself, then keeps serving):

```bash
cd ../days/day06-caching/lab/cacheapp
go mod tidy
go run . -seed 1000                     # seeds code-0..code-999 + 'hot', then serves on :8090
```

Leave it running. Open a second terminal for load + curls.

## 2. Baseline — WITHOUT cache (measure the DB-bound p95)

In a new terminal, restart the app with the cache off:

```bash
# stop the running app (Ctrl-C in its terminal), then:
cd days/day06-caching/lab/cacheapp
CACHE=off go run .                       # every /lookup goes straight to DB (+50ms)
```

Drive read load and record p95:

```bash
cd ../k6
k6 run --env BASE=http://localhost:8090 read_load.js
# p95 will sit around the DB delay (~50ms+) — every read pays the DB cost.
```

## 3. WITH cache — measure hit ratio and the p95 win

Restart with cache on (default), reset counters, drive load:

```bash
# Ctrl-C the app, then:
cd ../cacheapp && go run .               # CACHE defaults to on, SINGLEFLIGHT off
```
```bash
# other terminal:
curl -s "http://localhost:8090/reset"
cd days/day06-caching/lab/k6
k6 run --env BASE=http://localhost:8090 read_load.js
curl -s "http://localhost:8090/stats" | jq
# Expect a high hitRatio (~0.9+) and p95 far below the no-cache baseline.
# dbQueries << total requests — the cache absorbed the reads.
```

Record no-cache vs with-cache p95 and the hit ratio in `results.md`.

## 4. BREAK IT — trigger the stampede

The `hot` key is hammered; we simulate its TTL expiring at peak, with **no**
stampede protection (singleflight off):

```bash
curl -s "http://localhost:8090/reset"
curl -s "http://localhost:8090/bust?code=hot"      # delete the hot key = simulate expiry
cd days/day06-caching/lab/k6
k6 run --env BASE=http://localhost:8090 stampede.js  # 200 VUs blast the one key for 2s
curl -s "http://localhost:8090/stats" | jq
```

**What you should see:** `dbQueries` jumped by *dozens* (roughly the number of
requests that arrived during the ~50 ms refill window) — the herd all missed and
all hit the DB for the *same* key. That's the stampede: a momentary hit-ratio
collapse that amplifies load onto the DB exactly when the key is hottest.

## 5. FIX IT — coalesce with singleflight

Restart the app with singleflight on and repeat the exact same break:

```bash
# Ctrl-C the app, then:
cd days/day06-caching/lab/cacheapp
SINGLEFLIGHT=on go run .
```
```bash
# other terminal:
curl -s "http://localhost:8090/reset"
curl -s "http://localhost:8090/bust?code=hot"
cd days/day06-caching/lab/k6
k6 run --env BASE=http://localhost:8090 stampede.js
curl -s "http://localhost:8090/stats" | jq
```

**What you should see:** `dbQueries` increased by ~**1** for this burst — the
first miss recomputed while the other ~199 requests waited on the same in-flight
call and shared its result. Same herd, one DB query. Record before/after
`dbQueries` in `results.md`.

## 6. Learner TODO (the insight to implement yourself)

`loadFromDB` in `cacheapp/main.go` has a marked TODO for **negative caching**:
cache the "not found" result with a short TTL so repeated lookups of a
non-existent code (cache *penetration*) stop hammering the DB. Implement it, then
drive `read_load.js` against random *non-existent* codes (edit it to
`code-${9_000_000 + i}`) and show `dbQueries` stops climbing. Record it.

## 7. TEARDOWN (mandatory)

```bash
cd labs
docker compose down -v
```

---

## What you should have observed

| Scenario | p95 | hitRatio | dbQueries (per burst) |
|----------|-----|----------|-----------------------|
| No cache | ~DB latency | n/a | = requests |
| Cache-aside | low | ~0.9+ | ≪ requests |
| Stampede (singleflight off) | spike | — | dozens (the herd) |
| Stampede (singleflight on) | flat | — | ~1 (coalesced) |

The lesson from `../../../content/day06.md`: a cache's *failure modes* — stampede,
penetration, avalanche — are the real engineering. singleflight/leases,
negative caching, and TTL jitter are the standard fixes.
