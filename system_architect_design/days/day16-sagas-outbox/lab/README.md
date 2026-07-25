# Day 16 lab — transactional outbox survives a crash; idempotent consumer dedupes

**Goal:** prove the outbox solves the dual-write problem. Place an order (DB
commits), kill the relay *before* it publishes, restart it, and confirm the event
is still delivered — no lost event. Then force a *duplicate* publish and watch the
idempotent consumer dedupe it. Finally, run the order saga and trigger a
compensation.

Uses the shared `labs/` stack: **postgres** + **kafka**. Everything else is in
this folder (Go module `lab/saga-outbox`).

## 0. Bring up infra + schema

```bash
# from the repo root
cd labs && docker compose up -d postgres kafka
docker compose ps                       # postgres + kafka should be running/healthy

# apply the schema
psql "postgres://postgres:pass@localhost:5432/app" \
  -f ../days/day16-sagas-outbox/lab/schema.sql

# build the lab binary
cd ../days/day16-sagas-outbox/lab
go mod tidy                             # resolves pgx + kafka-go, writes go.sum
```

Open **four terminals** in `days/day16-sagas-outbox/lab/` (api, relay, consumer,
and a scratch terminal for curl/psql/status).

## 1. Build: outbox end-to-end (happy path)

```bash
# T1: API
go run . api

# T3: consumer (leave it running; it prints APPLIED / DUPLICATE lines)
go run . consumer

# T4 (scratch): place an order — commits order + outbox row in ONE tx
curl -s -XPOST localhost:8090/placeOrder -d '{"product":"widget","qty":2}'
#  -> {"order_id":1,"event_id":"...."}

go run . status
#  -> orders=1  outbox_unsent=1  outbox_sent=0  processed_events=0
#     (event is durable in the DB but NOT yet published — relay hasn't run)

# T2: start the relay -> it publishes the unsent row, consumer APPLIES it
go run . relay

go run . status
#  -> outbox_unsent=0  outbox_sent=1  processed_events=1   widget stock 3
```

You just watched the event live in the DB *before* it reached Kafka. That gap is
exactly where a naive DB-then-publish loses events.

## 2. Break it (core): kill the relay before publish, prove no loss

Stop the relay (Ctrl-C in T2). Place another order while the relay is down, then
restart the relay with the crash flag that exits **before** publishing:

```bash
# T4: order commits; relay is not running, so it is unsent
curl -s -XPOST localhost:8090/placeOrder -d '{"product":"widget","qty":1}'
go run . status                         # outbox_unsent=1  (durable, not lost)

# T2: relay crashes before it can publish, then you restart it clean
CRASH_BEFORE_PUBLISH=1 go run . relay   # logs "still unsent", exit(1)
go run . status                         # STILL outbox_unsent=1 — nothing lost
go run . relay                          # normal start -> publishes it now
go run . status                         # outbox_unsent=0, processed_events=2
```

**Observe:** the crash never loses the event because it lives in Postgres. On a
clean restart the poll query `WHERE sent_at IS NULL` finds and publishes it.
*This is the dual-write problem, solved.*

## 3. Break it (duplicate): crash AFTER publish, prove the consumer dedupes

```bash
# T4: place an order
curl -s -XPOST localhost:8090/placeOrder -d '{"product":"widget","qty":1}'

# T2: relay publishes, then crashes BEFORE marking the row sent
CRASH_AFTER_PUBLISH=1 go run . relay    # logs "published ... will REPUBLISH", exit(1)
# consumer (T3) prints: APPLIED  event_id=<X>

# T2: restart clean -> the row is still unsent, so it republishes the SAME event_id
go run . relay
# consumer (T3) prints: DUPLICATE event_id=<X> -> deduped, no side effect
```

**Observe:** at-least-once delivery produced a duplicate; the `processed_events`
`ON CONFLICT DO NOTHING` check made processing effectively-once. Inventory was
decremented exactly once even though the event was delivered twice.

## 4. The saga (payment -> inventory) with compensation

```bash
go run . saga widget 2    # SAGA RESULT: order N CONFIRMED
go run . saga gadget 1    # inventory fails (stock 0) -> refunds payment -> CANCELLED
```

Inspect the compensation:

```bash
psql "postgres://postgres:pass@localhost:5432/app" \
  -c "SELECT o.id, o.status, p.status AS payment FROM orders o JOIN payments p ON p.order_id=o.id ORDER BY o.id DESC LIMIT 4;"
```

The `gadget` saga leaves the order `CANCELLED` and its payment `REFUNDED` — the
compensating transaction undid the completed step.

## 5. Teardown (mandatory)

```bash
cd ../../../labs && docker compose down -v
```

## What to record in `results.md`
- Outbox state (`unsent`/`sent`) at each step of parts 1–3.
- The consumer log line proving APPLIED-once vs DUPLICATE-deduped.
- Inventory stock before/after the duplicate test (should drop by qty only once).
- The saga compensation result (order CANCELLED, payment REFUNDED).

> **TODO for you (the one insight to implement):** part 3 leaves the outbox row
> `sent` but never *prunes* it — write the `DELETE FROM outbox WHERE sent_at <
> now() - interval '1 hour'` retention step (or a scheduled job) and note where
> you'd run it. Everything else runs as-is.
