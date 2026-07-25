# Day 15 Lab — event-sourced Order aggregate + CQRS projection

Append Order events to an append-only Postgres table, fold them to rebuild state,
project a read model, prove replay reconstructs state — then fix a seeded
projection bug by **replaying**, the thing CRUD can't do.

## Setup

```bash
cd ../../../labs && docker compose up -d postgres && cd -
# apply the schema (event store + read model + checkpoint):
docker compose -f ../../../labs/docker-compose.yml exec -T postgres \
  psql -U postgres -d app < schema.sql
go mod tidy   # once, needs network
```

## Step 1 — write commands (append events)

```bash
go run . place order-1 SKU1 2 5000     # OrderPlaced (total 5000c)
go run . pay   order-1                 # OrderPaid
go run . ship  order-1 UPS             # OrderShipped

go run . place order-2 SKU2 1 1500     # OrderPlaced
go run . pay   order-2                 # OrderPaid
go run . cancel order-2 "changed mind" # OrderCancelled  <-- the interesting one
```

Inspect the raw log:

```bash
go run . log
```

## Step 2 — fold to rebuild state (rehydration)

```bash
go run . state order-1     # FOLD -> status=SHIPPED
go run . state order-2     # FOLD -> status=CANCELLED   (the fold is always correct)
```

The fold reads the event stream and replays it through the pure `apply` function.
State is *computed*, never stored.

## Step 3 — project the read model

```bash
go run . project           # builds order_status_view from the log
go run . view
```

**Observe the bug.** `order-2`'s fold says `CANCELLED` (Step 2), but the projection
shows `PAID`. The projector (`applyToView` in `main.go`) never handled
`OrderCancelled` — a classic read-model bug. In CRUD you'd now write a migration
script guessing which rows are wrong.

## Step 4 — prove replay reconstructs identical state

```bash
go run . replay            # TRUNCATE the view + rebuild from global_seq 0
go run . view
```

The read model is byte-for-byte what `project` produced — the read model is a pure
function of the log. (order-2 is still wrong; the *code* is still buggy — replay
faithfully reproduces the bug, which is the point of the next step.)

## Step 5 — BREAK-IT / FIX-IT: fix the projection bug, then replay

1. In `main.go`, `applyToView`, **uncomment the `case "OrderCancelled":` block**
   (marked `TODO`).
2. Replay to correct every read model from true history:
   ```bash
   go run . replay
   go run . view          # order-2 now shows CANCELLED
   ```

**The superpower:** you fixed a read-model bug with *code + replay*, not a
data-migration script — no guessing which rows are wrong, fully idempotent, and it
would correct millions of rows the same way. Confirm the fold and the projection now
agree:

```bash
go run . state order-2    # CANCELLED
go run . view             # order-2: CANCELLED
```

## (Optional) feel the append-only guarantee

```bash
docker compose -f ../../../labs/docker-compose.yml exec postgres \
  psql -U postgres -d app -c "UPDATE events SET event_type='x' WHERE global_seq=1;"
# -> ERROR: events is append-only ...  (you append a correcting event instead)
```

## Teardown

```bash
cd ../../../labs && docker compose down -v
```

Record measurements and observations in `results.md`.
