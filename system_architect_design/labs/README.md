# Labs — shared stack

One docker-compose stack, reused across days. Bring up **only what a day needs**,
and always tear down at the end (`docker compose down -v`).

## Quick reference

```bash
# From this labs/ directory:
docker compose up -d postgres redis      # relational + cache days (3, 6, 8, 15, 16)
docker compose up -d kafka               # event/log days (14, 16)
docker compose --profile fault up -d toxiproxy   # fault injection (4, 8, 9)
docker compose --profile obs up -d       # + jaeger (:16686) + prometheus (:9090)  (Day 11)

docker compose ps                        # what's running
docker compose logs -f kafka             # tail a service
docker compose down -v                   # TEARDOWN (removes volumes) — do this daily
```

## Connection details

| Service | Address | Notes |
|---------|---------|-------|
| Postgres | `localhost:5432` | db `app`, user `postgres`, pass `pass` |
| Redis | `localhost:6379` | no auth |
| Kafka | `localhost:9092` | KRaft, single broker, `PLAINTEXT` |
| Toxiproxy API | `localhost:8474` | add "toxics" (latency, down) via REST/CLI |
| Jaeger UI | `localhost:16686` | traces (Day 11) |
| Prometheus | `localhost:9090` | metrics (Day 11) |

## The reusable echo service

`services/echo/` is a tiny HTTP service used to build topologies:
`/health`, `/work?ms=&fail=`, `/call?url=`. Run two instances for A→B labs:

```bash
cd services/echo
PORT=8080 NAME=A go run . &
PORT=8081 NAME=B go run . &
# A calls B:
curl "http://localhost:8080/call?url=http://localhost:8081/work?ms=50"
```

## Toxiproxy quick recipe (Day 9 cascade)

```bash
# Route A's calls to B through Toxiproxy, then inject 3s latency:
curl -s localhost:8474/proxies -d '{"name":"b","listen":"0.0.0.0:18080","upstream":"host.docker.internal:8081"}'
curl -s localhost:8474/proxies/b/toxics -d '{"type":"latency","attributes":{"latency":3000}}'
# Now point A at http://localhost:18080 instead of :8081 and watch it cascade.
# Remove the toxic:
curl -s -X DELETE localhost:8474/proxies/b/toxics/latency_downstream
```

## k6

`k6/example.js` is a ramping-spike template. Copy per day:
`k6 run --env BASE=http://localhost:8080 k6/example.js`.

## Per-day lab code

Each day's specific lab code, SQL, and configs live in
`../days/dayNN-*/lab/`, with a `results.md` for your measurements.
