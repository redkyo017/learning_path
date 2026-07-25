# Day 8 lab — prove no double-charge; then feel fixed vs jittered backoff

Goal: fire the same idempotency key 100× concurrently and prove **exactly one**
charge; break the guard and watch N charges; then compare fixed vs full-jitter
backoff against a flaky downstream.

Prereqs: Docker, Go 1.22+, `psql`. All paths absolute.

```
BASE=/Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design
DSN="postgres://postgres:pass@localhost:5432/app?sslmode=disable"
```

## 0. Postgres up + schema loaded

```bash
cd $BASE/labs
docker compose up -d postgres
docker compose ps                     # postgres healthy
psql "$DSN" -f $BASE/days/day08-idempotency-retries/lab/sql/schema.sql
```

## 1. Run the charge service (guard ON)

```bash
cd $BASE/days/day08-idempotency-retries/lab/charge
go mod download                       # fetches lib/pq (needs network once)
DATABASE_URL="$DSN" IDEMPOTENT=true go run .
# logs: "charge up on :8095  IDEMPOTENT=true ..."
```

## 2. MEASURE — fire the SAME key 100× concurrently

```bash
cd $BASE/days/day08-idempotency-retries/lab/fire
N=100 MODE=same go run .
```

**Observe & record:** output shows ~`created(201): 1` and `replayed(200): 99`.
Confirm in the DB there is exactly one row for the key:

```bash
psql "$DSN" -c "SELECT idempotency_key, count(*) FROM charges GROUP BY 1 ORDER BY 2 DESC;"
# expect: day8-demo-key | 1
```

Why one? The UNIQUE index + `INSERT ... ON CONFLICT DO NOTHING` lets exactly one
concurrent insert win; the other 99 block until it commits, then take the replay
branch. The database arbitrates the race.

## 3. BREAK IT — remove the guard, get N charges

Stop the service. Drop the constraint and re-run in non-idempotent mode:

```bash
psql "$DSN" -c "TRUNCATE charges;"
psql "$DSN" -c "ALTER TABLE charges DROP CONSTRAINT charges_idempotency_key_uniq;"

cd $BASE/days/day08-idempotency-retries/lab/charge
DATABASE_URL="$DSN" IDEMPOTENT=false go run .        # plain INSERT, no guard
```

```bash
cd $BASE/days/day08-idempotency-retries/lab/fire
N=100 MODE=same go run .
psql "$DSN" -c "SELECT count(*) FROM charges;"       # expect ~100 — DOUBLE-CHARGE
```

**Observe & record:** up to 100 charge rows for one logical operation. This is the
double-charge bug that any client retry (or a proxy replay) would trigger in prod.
Record the count. Then restore the guard for the next step:

```bash
psql "$DSN" -c "TRUNCATE charges;"
psql "$DSN" -c "ALTER TABLE charges ADD CONSTRAINT charges_idempotency_key_uniq UNIQUE (idempotency_key);"
```

## 4. Backoff vs jitter against a flaky downstream (Toxiproxy)

Bring up a downstream (shared echo) and put it behind Toxiproxy so we can make it
flaky/slow. echo's `/work?ms=&fail=` already injects 500s; Toxiproxy adds latency
to force *timeouts*.

```bash
# echo as the "payment provider"
cd $BASE/labs/services/echo && PORT=8081 NAME=provider go run . &

# Toxiproxy, route :18080 -> echo :8081, add 2500ms latency (> the 2s client timeout)
cd $BASE/labs && docker compose --profile fault up -d toxiproxy
curl -s localhost:8474/proxies -d \
  '{"name":"provider","listen":"0.0.0.0:18080","upstream":"host.docker.internal:8081"}'
curl -s localhost:8474/proxies/provider/toxics -d \
  '{"type":"latency","attributes":{"latency":2500}}'
```

Run the charge service pointing at the flaky provider, once with **fixed** backoff
and once with **full jitter**, and fire many *unique* keys:

```bash
# FIXED backoff
cd $BASE/days/day08-idempotency-retries/lab/charge
DATABASE_URL="$DSN" PROVIDER_URL="http://localhost:18080/work?ms=50&fail=0.5" \
  BACKOFF=fixed MAX_ATTEMPTS=4 BASE_MS=100 go run .
# in another terminal:
cd $BASE/days/day08-idempotency-retries/lab/fire && N=200 MODE=unique go run .
curl -s localhost:8095/stats     # note provider_calls (total downstream attempts)

# restart the service with BACKOFF=jitter, TRUNCATE charges, re-fire, compare
```

**Observe & record:** with `fail=0.5`, roughly half of first attempts fail and get
retried. Under **fixed** backoff every retry lands at the same offset → the
provider sees synchronized retry *bursts*. Under **full jitter** retries spread
across the window → smoother provider load and (under contention) faster overall
completion. Compare `provider_calls`, `provider_failed`, and wall-clock time for
the two runs. Also remove the latency toxic to see the timeout-driven retries stop:

```bash
curl -s -X DELETE localhost:8474/proxies/provider/toxics/latency_downstream
```

## Teardown

```bash
# Ctrl-C go processes, then:
cd $BASE/labs && docker compose down -v
```

## What to write up in `results.md`
- Guard ON, 100× same key: created / replayed counts + DB row count (= 1).
- Guard OFF (break-it): DB row count (~100) — the double-charge.
- Fixed vs jitter: provider_calls, provider_failed, completion time; the load-shape
  difference in your own words.
