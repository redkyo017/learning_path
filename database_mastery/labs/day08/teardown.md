# Day 8 teardown

## 1. Reset the gauntlet

```bash
bash labs/day08/gauntlet.sh --reset
```

This removes every pathology the pool can have applied, from all eight
members, regardless of which five your last run selected: it terminates
any surviving long-running or blocked PostgreSQL session the way Day 5's
own teardown does (anything genuinely idle in transaction for over a
minute), drops every gauntlet-created index, resets `ledger_entries`'
statistics overrides and `autovacuum_enabled`, **restores every
`ledger_entries.account_id` value `stale_stats` reassigned** from the
side table it was saved to before the bulk `UPDATE` ran (the same
technique Day 4's own `break.sh` uses for `payments.merchant_id`) and
drops that side table, restores the MongoDB `payment_events` index set
to only `_id_` and removes the mongo_regex query file from `ws`, drops
the dedicated `day08_deadlock_accounts` fixture table the InnoDB
deadlock pathology runs against (never the real `accounts` table, so
there is nothing there to restore) along with the two MySQL transfer
scripts on `ws`, and resets `pg_stat_statements` (a genuine side effect
— the N+1 pathology's whole signal lives in that view's aggregates, so
clearing it is the only way to fully remove that one; if you want the
aggregate history from earlier days preserved, capture it before running
`--reset`).

Confirm the reset actually landed, the same way you'd confirm any fix in
this path — by reading the instrument, not by trusting the script printed
"restored":

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "SELECT pid, state, now() - xact_start AS age FROM pg_stat_activity
   WHERE datname = 'payments' AND pid <> pg_backend_pid();"
```

returns no row with `state = 'idle in transaction'`.

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "SELECT indexname FROM pg_indexes
   WHERE indexname LIKE 'idx_gauntlet_%' OR indexname LIKE 'ix_ledger_entries_%';"
```

returns no rows.

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "SELECT to_regclass('day08_original_ledger_accounts');"
```

returns `NULL` — the `stale_stats` side table is gone, meaning its
restore already ran (a `NULL` here is what "fully reversed," not merely
"cleaned up," looks like).

```bash
docker compose -p dbmastery exec mongo mongosh --quiet payments \
  --eval 'db.payment_events.getIndexes().map(ix => ix.name)'
```

returns only `[ '_id_' ]`.

```bash
docker compose -p dbmastery exec my mysql -u dbm -pdbmastery payments \
  -e "SHOW TABLES LIKE 'day08_deadlock_accounts';"
```

returns no rows.

## 2. Data drift

None, by design. Every pool member that mutates data reverses itself in
`reset_*`, not merely in a full reseed: `stale_stats` restores the
`ledger_entries.account_id` values it reassigned from a side table saved
before the bulk `UPDATE` ran; `bloated_index`'s six status-churn cycles
are an even number of steps through a three-value rotation, so
`disputes.status` already returns to its original values on its own,
with nothing left for `--reset` to undo there; and `innodb_deadlock`
never touches the seeded `accounts` table at all, running instead
against a dedicated `day08_deadlock_accounts` fixture table that
`--reset` drops outright. If you ever suspect drift anyway — a run
interrupted mid-incident, or `--reset` not run before closing the
terminal — a full reseed is always available as a fallback, not a
requirement:

```bash
cd labs/stack/seed && SCALE=10 FORCE=1 bash seed.sh
```

## 3. Stack teardown

If this is the last lab of your session:

```bash
cd labs/stack && docker compose -p dbmastery down
```

adding `-v` only if you also want the seeded volumes gone (you'll need to
reseed before any day's labs work again). If you're continuing straight
into the design half of Day 8, leave the stack running — none of
`DESIGN-BRIEF.md`, `DESIGN-RUBRIC.md`, or `REFERENCE-DESIGN.md` touches
it.

## 4. If Day 7 was done recently

Day 7's RDS instance and Atlas cluster are the only billable resources
anywhere in this path. If you worked through Day 7 in the same session
(or recently) and haven't already confirmed teardown, do it now — do not
let it ride because Day 8 felt like the finish line:

```bash
bash labs/verify-teardown.sh
```

It fails loudly, and refuses to report a false pass, if it cannot
actually reach AWS or Atlas to check. Do not consider this path closed
until it exits `0`.
