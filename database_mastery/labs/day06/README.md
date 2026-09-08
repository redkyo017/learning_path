# Day 6 lab — durability and operations

## Goal

`break.sh` sets up three independent incidents:

1. **A wrongly-scoped bulk `UPDATE`.** It takes a fresh `pg_basebackup`
   (confirming WAL archiving is actually live first — PITR is impossible
   otherwise), stashes the pre-damage `status` and `amount_minor` of one
   specific `payments` row, then commits `UPDATE payments SET
   status='failed'` against a predicate that's missing the filters it
   should have had, changing far more rows than intended.
2. **A bloat pathology on `idempotency_keys`**, a table it creates for
   the purpose, representing the kind of high-churn operational table
   real payment systems keep for request deduplication: autovacuum
   disabled, then churned through several full-table update cycles.
3. **A deleted batch of MongoDB `payment_events` documents.** It takes a
   fresh `mongodump --oplog` of the whole Mongo deployment, stashes the
   pre-damage content of every `payment_events` document for one
   merchant, one event type, and a six-hour window, then deletes exactly
   those documents.

There are **five deliverables**, and `verify.sh` checks all five
independently:

1. Write `recovery_seconds=`, `bloat_ratio_before=`, and
   `recovered_status=` to `/tmp/answer` **inside `ws`** — the first two
   are your own measurements (plausibility-checked, not compared against
   a stash), the third is compared against this run's stashed pre-damage
   value.
2. Restore the specific row `break.sh` names to its pre-damage `status`
   and leave its `amount_minor` untouched.
3. Bring `idempotency_keys`' dead-tuple percentage back under threshold
   **and** re-enable autovacuum on it with retuned, non-default
   thresholds — a plain one-off `VACUUM` that leaves autovacuum disabled
   does not pass this.
4. Leave no `idle in transaction` session older than 60 seconds behind —
   one would silently defeat the vacuum fix regardless of what else you
   did.
5. Restore the deleted `payment_events` documents into the live Mongo
   collection with every field matching their pre-damage values, not
   only the right document count.

**The crash itself is yours to cause by hand** — this lab's whole point
is watching a real container die and come back, not reading about it.

**Disk note:** `break.sh` writes a full `pg_basebackup`, and the PITR
drill below writes a second scratch restore copy on top of it, both
inside the `pg` container's writable layer — briefly roughly doubling
Postgres's share of the disk budget in the repo root `README.md`'s
Prerequisites. Separately, `break.sh`'s `mongodump --oplog` is a full
deployment dump — every collection in `payments` (`payment_events`,
`merchant_catalog` or its Day 2 restructuring, `catalog_seed_meta`),
sized by whatever `SCALE` the stack was seeded at — written inside `ws`,
and the Mongo recovery drill below writes a second copy of that same data
into a scratch `mongod`'s `--dbpath` inside the `mongo` container. Confirm
you have the extra headroom on both containers before starting this lab,
not partway through it.

## Success signal

`labs/day06/verify.sh` exits `0`.

## How to run

From `database_mastery`, with the stack up
(`docker compose -p dbmastery up -d --build` in `labs/stack`):

```bash
bash labs/day06/break.sh
```

Read the `SYMPTOM` line and the target row it names. Then read the pg
container's logs — `log_min_duration_statement=500` in
`labs/stack/conf/postgresql.conf` means the damaging bulk `UPDATE` is
slow enough to show up here, timestamped:

```bash
docker compose -p dbmastery logs pg --since 10m | grep -i "SET status = 'failed'"
```

If that returns nothing — you read `content/day06.md` for a while before
running this, say, and the UPDATE is now further back than 10 minutes —
widen the window (`--since 30m`, `--since 1h`, ...) and re-run it; the log
line itself does not expire.

Note that timestamp — you'll need it in a few steps, as the moment
*before* which you want to recover.

### 1. Cause the crash

```bash
docker compose -p dbmastery kill -s SIGKILL pg
docker compose -p dbmastery start pg
```

### 2. Read crash recovery from the log

```bash
docker compose -p dbmastery logs pg --since 5m
```

If the recovery lines below aren't in that window — the restart took a
moment to reach, or you paused between step 1 and here — widen it
(`--since 15m`, `--since 1h`, ...) and re-run it.

Find the lines matching "Read the instrument first" in `content/day06.md`
— `database system was interrupted`, `redo starts at`, `redo done at`,
`database system is ready to accept connections`. Subtract the first
timestamp from the last to get your `recovery_seconds`.

### 3. Measure the bloat, before touching it

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "CREATE EXTENSION IF NOT EXISTS pgstattuple;"
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "SELECT * FROM pgstattuple('idempotency_keys');"
```

Record `dead_tuple_percent` as `bloat_ratio_before`.

### 4. Restore to a point in time

Copy the base backup `break.sh` already took into a scratch directory,
and configure it to replay WAL up to a moment before the damaging
`UPDATE`'s logged timestamp (from the very first command above):

```bash
docker compose -p dbmastery exec pg bash -c '
  rm -rf /tmp/day06-pitr
  cp -a /tmp/day06-basebackup /tmp/day06-pitr
'

docker compose -p dbmastery exec pg bash -c "
cat >> /tmp/day06-pitr/postgresql.auto.conf <<CONF
restore_command = 'cp /var/lib/postgresql/archive/%f %p'
recovery_target_time = '<timestamp from step 0, minus a second>'
recovery_target_action = 'pause'
CONF
touch /tmp/day06-pitr/recovery.signal
chown -R postgres:postgres /tmp/day06-pitr
"
```

Start it on a different port, inside the same container, and wait for it
to pause at the target:

```bash
docker compose -p dbmastery exec -u postgres pg bash -c \
  "pg_ctl -D /tmp/day06-pitr -o '-p 5544 -c unix_socket_directories=/tmp' -l /tmp/day06-pitr.log start"
docker compose -p dbmastery exec pg tail -20 /tmp/day06-pitr.log
```

Look for `recovery has paused` in that log before continuing — if the
target time was set wrong (too late, most likely, so it replayed straight
past the damage), stop it (`pg_ctl -D /tmp/day06-pitr stop`), adjust
`recovery_target_time`, and try again; that is exactly why
`recovery_target_action = 'pause'` rather than `'promote'` is worth using
for a drill like this one — a paused instance costs nothing to retry, a
promoted one is a one-way decision.

Confirm the pre-damage value directly:

```bash
docker compose -p dbmastery exec pg bash -c \
  "PGPASSWORD=dbmastery psql -h 127.0.0.1 -p 5544 -U dbm -d payments -c \
   \"SELECT payment_id, status, amount_minor FROM payments WHERE payment_id = <target_payment_id from break.sh's output>;\""
```

That `status` value is your `recovered_status`.

### 5. Repair the live database using the recovered instance as source

Promoting the whole restored instance into production would mean a full
outage over one wrongly-scoped column update — instead, pull the correct
`status` for every row the bad predicate touched out of the paused
instance, and backfill only that:

```bash
docker compose -p dbmastery exec pg bash -c "
  PGPASSWORD=dbmastery psql -h 127.0.0.1 -p 5544 -U dbm -d payments -Atc \
    \"COPY (SELECT payment_id, status FROM payments WHERE created_at >= '<the cutoff break.sh used>') TO STDOUT WITH (FORMAT csv)\" \
  > /tmp/day06-recovered-status.csv
"

docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "CREATE TABLE day06_recovered_status (payment_id BIGINT PRIMARY KEY, status TEXT NOT NULL);"

docker compose -p dbmastery exec -T pg bash -c 'cat /tmp/day06-recovered-status.csv' | \
  docker compose -p dbmastery exec -T pg psql -U dbm -d payments -c \
  "\copy day06_recovered_status FROM STDIN WITH (FORMAT csv)"

docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "UPDATE payments p SET status = r.status
   FROM day06_recovered_status r
   WHERE p.payment_id = r.payment_id AND p.status <> r.status;"

docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "DROP TABLE day06_recovered_status;"

docker compose -p dbmastery exec -u postgres pg pg_ctl -D /tmp/day06-pitr stop
```

The bad predicate's exact cutoff date is discoverable from the same log
line that gave you the timestamp in step 0 — it names the whole
`UPDATE` statement.

### 6. Fix the bloat by retuning, not by vacuuming once

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "ALTER TABLE idempotency_keys SET (
     autovacuum_enabled = true,
     autovacuum_vacuum_scale_factor = 0.02,
     autovacuum_vacuum_threshold = 500
   );"
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "VACUUM (VERBOSE) idempotency_keys;"
```

The retuned thresholds are the graded part — `verify.sh` reads them back
from `pg_class.reloptions`. If you want to see `pg_repack` actually
reclaim disk instead of only marking space reusable:

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "CREATE EXTENSION IF NOT EXISTS pg_repack;"
docker compose -p dbmastery exec ws sh -c \
  "PGPASSWORD=dbmastery pg_repack -h pg -p 5432 -U dbm -d payments -t idempotency_keys"
```

If that fails with something like `program version does not match library
version`, see `content/day06.md`'s "Known issue" note — it means the
`pg_repack` client on `ws` and the extension on `pg` were built from
package sets that drifted apart, and the fix is rebuilding both images
together, not retrying the command.

### 7. Recover the deleted MongoDB documents

`break.sh` printed the merchant/type/window it damaged and the unix
timestamp its `mongodump --oplog` finished at. Restore that dump into a
scratch, standalone `mongod` on a different port inside the same `mongo`
container — never into the live `payments` database directly, since the
dump's `admin`/`config` copies must not touch the running deployment's
real ones (`mongodump` never dumps `local` at all — see `content/day06.md`
— so there is no `local` copy to worry about either), and re-inserting the
whole collection into the live one would fight millions of documents that
were never deleted:

```bash
docker compose -p dbmastery exec mongo bash -c '
  rm -rf /tmp/day06-mongo-restore /tmp/day06-mongo-restore.log
  mkdir -p /tmp/day06-mongo-restore
  mongod --dbpath /tmp/day06-mongo-restore --port 27018 \
    --bind_ip_all --wiredTigerCacheSizeGB 0.25 \
    --logpath /tmp/day06-mongo-restore.log --fork
'
```

`--wiredTigerCacheSizeGB 0.25` matters in this stack specifically: the live
`mongo` server is capped at `cacheSizeGB: 0.5` (see
`labs/stack/conf/mongod.conf` — do not raise it), and this repo asks for
only 4 GB of Docker memory total, so a second, uncapped `mongod` in the
same container would default to roughly half of *available* RAM and crowd
out everything else sharing that memory budget.

`--bind_ip_all` matters here specifically because `mongorestore`,
`mongoexport`, and `mongoimport` only exist in `ws` (see
`labs/stack/Dockerfile.ws`) — every command against this scratch instance
below reaches it over the compose network at `mongo:27018`, not from a
process inside the `mongo` container itself, so binding to loopback only
would refuse every one of them.

Restore the dump (including its oplog) into that scratch instance:

```bash
docker compose -p dbmastery exec ws mongorestore \
  --uri="mongodb://mongo:27018/" \
  --oplogReplay \
  --dir /tmp/day06-mongodump
```

You might expect to scope this to `--nsInclude 'payments.payment_events'`
so a full deployment restore isn't necessary for one collection — but
`mongorestore` refuses that combination outright: `--oplogReplay` can only
run against a full, unfiltered restore, and errors with "Can only replay
oplog on full restore" if `--nsInclude` (or `--nsExclude`, or `--db`/
`--collection`) is present alongside it. A full restore is genuinely
unavoidable here, which is also why `mongodump --oplog` itself refuses
`--db`/`--collection` in the first place (see `content/day06.md`'s
"MongoDB backup and recovery" section) — the two flags share one
constraint for the same reason.

Expect this command to print errors for the `admin` and `config`
namespaces and to exit non-zero even on a fully successful run: this
scratch instance is a bare standalone `mongod` with no matching
replica-set/sharding topology, no existing users, and no prior admin
state, so restoring `admin`'s and `config`'s system collections into it
hits namespace conflicts and protected-collection restrictions that have
nothing to do with `payments`. On a day that teaches you to take a
non-zero restore exit seriously, that matters: check the command's own
output for `payments.payment_events` specifically (a completed collection
with a nonzero document count and no errors against that one namespace) —
don't let the accompanying `admin`/`config` noise, or the exit code, spook
you off a restore that actually worked for the collection you care about.

If you want to pin the exact restore point rather than relying on the
dump's own end, add `--oplogLimit <the unix ts break.sh printed>:1`.
`--oplogLimit` is exclusive: it applies every oplog entry *before* the
given timestamp and stops there, so an entry stamped at exactly that
second is not applied, not the last one that is.

Confirm the documents read back correctly on the scratch instance before
touching the live one:

```bash
docker compose -p dbmastery exec mongo mongosh --quiet --port 27018 payments --eval \
  "db.payment_events.find({merchant_id: 1, type: 'chargeback', ts: {\$gte: ISODate('2025-01-01T00:00:00.000Z'), \$lt: ISODate('2025-01-01T06:00:00.000Z')}}).count()"
```

Pull those exact documents back out with `mongoexport`, keeping every
field (including `_id`) intact, and backfill only them into the live
collection with `mongoimport --mode=upsert`, keyed by `_id`, so a re-run
never creates duplicates:

```bash
docker compose -p dbmastery exec ws mongoexport \
  --uri="mongodb://mongo:27018/payments" \
  --collection=payment_events \
  --query='{"merchant_id":1,"type":"chargeback","ts":{"$gte":{"$date":"2025-01-01T00:00:00.000Z"},"$lt":{"$date":"2025-01-01T06:00:00.000Z"}}}' \
  --out=/tmp/day06-recovered-events.jsonl

docker compose -p dbmastery exec ws mongoimport \
  --uri="mongodb://mongo:27017/payments?replicaSet=rs0" \
  --collection=payment_events \
  --file=/tmp/day06-recovered-events.jsonl \
  --mode=upsert --upsertFields=_id
```

`mongoimport` reports how many documents it upserted — confirm that
number matches the count `break.sh` printed as deleted. Stop the scratch
instance once the backfill is confirmed:

```bash
docker compose -p dbmastery exec mongo mongosh --quiet --port 27018 admin --eval \
  "db.shutdownServer({force: true})"
```

The merchant, type, and window used above match what `break.sh` prints in
its own "committing the Mongo damage" line — re-read that line if you
changed any of `break.sh`'s `MONGO_TARGET_*`/`MONGO_WINDOW_*` constants
before running it.

### 8. Confirm no stray Postgres session, then answer

```bash
docker compose -p dbmastery exec pg psql -U dbm -d payments -c \
  "SELECT pid, now() - xact_start AS age FROM pg_stat_activity WHERE state = 'idle in transaction';"
```

If anything shows up here older than 60 seconds, end it — it will
silently defeat the vacuum fix regardless of everything else you did
correctly. Then write your answer:

```bash
docker compose -p dbmastery exec ws sh -c 'cat > /tmp/answer' <<EOF
recovery_seconds=<your measured value>
bloat_ratio_before=<your measured value>
recovered_status=<the value you confirmed in step 4>
EOF
```

### 9. Verify

```bash
bash labs/day06/verify.sh
```

If it exits non-zero, its output names exactly which of the five checks
still fails. When it exits `0`, follow `teardown.md` before starting
Day 7 — the base backup, both scratch directories, `idempotency_keys`,
and the Mongo dump are all lab-only artifacts that should not carry
forward.

No further hints here. `SOLUTION.md` has the complete worked chain if you
get stuck, but reading it before you've caused your own crash and read
your own log skips the lesson this lab exists to force.
