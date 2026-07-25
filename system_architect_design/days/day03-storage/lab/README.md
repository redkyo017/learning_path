# Day 3 Lab — Postgres vs Redis for point lookups (and the range-query break-it)

Goal: load the same 1M `code → URL` dataset into Postgres (indexed) and Redis (KV),
measure point-lookup latency on both, then run a **range query** and feel the
missing-index pain that Redis-as-KV can't handle. Two stores, same access pattern,
different verdicts per query shape — that's the whole Day-3 lesson made measurable.

Prereqs: Docker + shared `labs/` stack, Go 1.22+. **Tear down at the end.**

## 1. Bring up Postgres + Redis
```bash
cd /Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design/labs
docker compose up -d postgres redis
docker compose ps          # both healthy
```

## 2. Create schema + seed 1M rows into Postgres
```bash
cd ../days/day03-storage/lab/sql
psql "postgres://postgres:pass@localhost:5432/app" -f schema.sql
psql "postgres://postgres:pass@localhost:5432/app" -f seed.sql     # a few seconds
psql "postgres://postgres:pass@localhost:5432/app" -c "SELECT count(*) FROM short_urls;"
# -> ~1000000
```

## 3. Mirror the rows into Redis
```bash
cd ../bench
go mod tidy
go run . -op=load-redis          # SET code url for every row (pipelined)
```

## 4. Measure point lookups on each store
```bash
go run . -op=bench -store=postgres -n=20000
go run . -op=bench -store=redis    -n=20000
```
Each prints `mean / p50 / p95 / p99 / max`. Record in `results.md`.
**Expected shape:** both are fast (indexed PK vs in-memory GET). Redis usually wins p50
by being in-RAM with no query planner; Postgres is close because the PK btree + buffer
cache keep the hot pages in memory. The gap is smaller than people assume — which is
exactly why "Postgres + a cache" (Day 6) beats "replace Postgres with Redis."

Optional, to see *why* Postgres is fast on the point lookup:
```bash
psql "postgres://postgres:pass@localhost:5432/app" \
  -c "EXPLAIN ANALYZE SELECT url FROM short_urls WHERE code='<paste a real code>';"
# -> Index Scan using short_urls_pkey ...
```

## 5. Break-it — the range query "codes created today"
```bash
go run . -op=range -store=postgres     # indexed range scan: fast, returns a count
go run . -op=range -store=redis        # full keyspace SCAN: O(N) and STILL can't filter by time
```
**What you should observe:**
- **Postgres** answers "created today" via `idx_short_urls_created_at` — one range
  scan, milliseconds. Confirm with:
  ```bash
  psql "postgres://postgres:pass@localhost:5432/app" \
    -c "EXPLAIN ANALYZE SELECT count(*) FROM short_urls WHERE created_at >= date_trunc('day', now());"
  # -> Index Scan / Bitmap Index Scan on idx_short_urls_created_at
  ```
- **Redis** has to `SCAN` the entire keyspace just to enumerate keys, and it *still*
  can't answer the question — the KV never stored `created_at`, and there's no
  secondary index. To support this query in Redis you'd hand-build the index the
  relational engine gave you for free (e.g. a sorted set `ZADD created_idx <ts> <code>`).

Record both timings and the verdict-per-query-shape in `results.md`.

## 6. Note which workload each store wins
- **Point lookup by key at scale** → Redis edges it (in-memory), but Postgres is close
  and durable → cache-in-front, not replace.
- **Ad-hoc / range / relational queries** → Postgres wins outright; the KV can't
  without re-implementing indexing in the app.
This is the evidence behind ADR-0003 (`../adr/`): cite these numbers, not adjectives.

## 7. Teardown (mandatory)
```bash
cd /Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/system_architect_design/labs
docker compose down -v
```

---
### Offline fallback
If `go mod tidy` can't fetch `go-redis`, you can still do the **Postgres** half and the
range break-it purely in `psql` (schema + seed + the two `EXPLAIN ANALYZE` queries) and
reason about the Redis side from `content/day03.md`. Pre-warm with
`go mod download github.com/redis/go-redis/v9 github.com/lib/pq` when you have network.
