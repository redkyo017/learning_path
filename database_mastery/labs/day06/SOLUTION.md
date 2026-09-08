# Day 6 solution — crash recovery, point-in-time restore, a bloat retune, and a MongoDB oplog recovery

Three chains, mirroring `journal.md`'s exact template. Every timestamp,
LSN, row count, and percentage below is a worked illustration of realistic
shape, not a number your own run is expected to reproduce exactly — the
cutoff date, target `payment_id`, document counts, and every measured
figure are specific to this run of `break.sh`, read your own instruments
for your own values.

---

## Chain 1 — the wrongly-scoped bulk `UPDATE`

**Predictions (written before running anything):**
- Crash recovery time after a hard kill: predicted 2-5 seconds, assuming
  a few seconds of WAL accumulated since the last checkpoint
- The damaged row's `status` at the chosen recovery target: predicted
  `captured`, the most common status in this dataset (roughly 80% of
  `payments`)

**Symptom (verbatim, no interpretation):**
`SYMPTOM: a bulk status update ran against payments with the wrong
predicate roughly twelve minutes ago, and separately, idempotency_keys is
growing without bound even though nothing is inserting new rows into it.`

**Layer:** durability

**Chain of evidence:**

1. Claim: the container was hard-killed and, on restart, performed a
   genuine WAL replay, not a clean startup. | Proof:
   `docker compose -p dbmastery logs pg --since 5m` →
   ```
   LOG:  database system was interrupted; last known up at 2026-03-14 09:11:58 UTC
   LOG:  database system was not properly shut down; automatic recovery in progress
   LOG:  redo starts at 0/5C0000A0
   LOG:  redo done at 0/5C10F8F0 system usage: CPU: 0.09s/0.03s [user/sys] elapsed: 0.20s
   LOG:  database system is ready to accept connections
   ```
   Elapsed: 0.20 s between the first log line after restart and "ready to
   accept connections" — recovery took under a quarter of a second, a
   function of how little WAL existed between the last checkpoint and the
   kill, not of the database's total size.
2. Claim: a bulk `UPDATE` against `payments` ran with a predicate that
   dropped its intended filters. | Proof:
   `docker compose -p dbmastery logs pg --since 30m | grep "SET status"` →
   ```
   LOG:  duration: 2841.203 ms  statement: UPDATE payments SET status = 'failed' WHERE created_at >= '2025-01-01 00:00:00+00';
   ```
   at `2026-03-14 09:00:12.114 UTC` — no `merchant_id` filter, no
   `status = 'pending'` filter, only the date bound.
3. Claim: that predicate changed rows that were never meant to move —
   captured, refunded, and disputed payments alongside any genuinely
   stale pending ones. | Proof: `SELECT status, count(*) FROM payments
   WHERE created_at >= '2025-01-01' GROUP BY status;` → every row in the
   range reports `failed`, where before the incident this range's
   `status` distribution matched the rest of the table (roughly 80%
   `captured`, 8% `pending`, 7% `failed`, 4% `refunded`, 1% `disputed`).
4. Claim: `pg_basebackup` plus the continuous WAL archive taken before the
   damage make a point-in-time restore to a moment before `09:00:12`
   possible. | Proof: `pg_stat_archiver.archived_count` was confirmed
   nonzero and increasing before the damage ran (`break.sh`'s own setup
   check), and the base backup at `/tmp/day06-basebackup` predates it.

**Diagnosis:** the intended operation — fail a single merchant's stale
pending authorizations — lost its `merchant_id` and `status = 'pending'`
filters somewhere before it ran, leaving only the date bound, and
committed against every payment in that date range regardless of its real
status. The fix is not a logical guess at which rows to revert; it is a
restore to the instant before `09:00:12.114 UTC`, reading the true
pre-damage values back out of WAL, because nothing in the live database
after the damage records what any individual row's status used to be.

**Fix applied:**
1. Restored `/tmp/day06-basebackup` into a scratch directory
   `/tmp/day06-pitr`, with `recovery_target_time = '2026-03-14
   09:00:11 UTC'` (one second before the logged statement) and
   `recovery_target_action = 'pause'`.
2. Started it on port 5544 inside the same `pg` container and confirmed,
   read-only, while paused: `SELECT status, amount_minor FROM payments
   WHERE payment_id = 4213087;` → `captured`, `184203` — matching the
   prediction of `captured`.
3. Pulled `(payment_id, status)` for every row with `created_at >=
   '2025-01-01'` out of the paused instance via `\copy ... TO STDOUT`,
   loaded it into a staging table on the live database, and applied
   `UPDATE payments p SET status = r.status FROM day06_recovered_status r
   WHERE p.payment_id = r.payment_id AND p.status <> r.status;` —
   surgical, not a full-database restore, because only one column on a
   known subset of rows needed correcting.
4. Stopped the scratch instance (`pg_ctl -D /tmp/day06-pitr stop`) once
   the backfill was confirmed.

**Proof the fix worked (same instrument re-read):** `SELECT payment_id,
status, amount_minor FROM payments WHERE payment_id = 4213087;` on the
live database now reports `captured`, `184203` — matching both the
scratch instance's read and the stash `break.sh` never revealed.
`SELECT status, count(*) FROM payments WHERE created_at >= '2025-01-01'
GROUP BY status;` shows the distribution restored to roughly its
pre-incident shape, not 100% `failed`.

**Prediction error and what it tells me:** the recovery-time prediction
(2-5 s) landed an order of magnitude above the actual 0.20 s — the model
behind that guess was "recovery scales with how much time has passed
since the crash," when it actually scales with how much WAL accumulated
since the *last checkpoint*, a much shorter and more controllable window
in a system checkpointing every five minutes by default. The `status`
prediction (`captured`) landed correctly, because 80% of the table
carries that value and nothing about which row `break.sh` would pick
argued for a different one.

**What I would check first next time:** the exact timestamp of the
damaging statement, from the log, before doing anything else —
`recovery_target_time` is only as good as that timestamp, and guessing at
it instead of reading it back from `log_min_duration_statement` output
wastes restore attempts on a paused instance that replayed past (or
short of) the actual damage.

---

## Chain 2 — `idempotency_keys` bloat from a disabled autovacuum

**Predictions (written before running anything):**
- `pgstattuple`'s `dead_tuple_percent` before vacuuming: predicted
  around 70%, from six full-table update cycles over rows that started
  with none

**Symptom (verbatim, no interpretation):** part of the same `SYMPTOM`
line above: "idempotency_keys is growing without bound even though
nothing is inserting new rows into it."

**Layer:** durability

**Chain of evidence:**

1. Claim: `idempotency_keys` has autovacuum explicitly disabled. | Proof:
   `SELECT reloptions FROM pg_class WHERE relname = 'idempotency_keys';`
   → `{autovacuum_enabled=false}`.
2. Claim: the table has been churned repeatedly since its rows were
   inserted, without a single vacuum reclaiming any of it. | Proof:
   `SELECT n_live_tup, n_dead_tup, last_autovacuum, last_vacuum FROM
   pg_stat_user_tables WHERE relname = 'idempotency_keys';` →
   `n_live_tup=300000`, `n_dead_tup=1800000`, both `last_autovacuum` and
   `last_vacuum` null.
3. Claim: the true bloat is severe, not merely what the cheap estimate
   suggests. | Proof: `SELECT * FROM pgstattuple('idempotency_keys');` →
   `dead_tuple_percent ≈ 84.2`, close to the 1,800,000 dead ÷ 2,100,000
   total figure implied by step 2's exact counts — six update cycles over
   an initially-clean 300,000-row table produces almost exactly 6× as
   many dead versions as live rows.
4. Claim: at this table's row count, the default autovacuum threshold
   would have let bloat run even further before ever triggering — the
   disabled flag isn't the whole story. | Proof: default
   `autovacuum_vacuum_scale_factor=0.2` and `autovacuum_vacuum_threshold=50`
   imply a trigger point of `50 + 0.2 × 300,000 = 60,050` dead tuples —
   this run's actual 1,800,000 is 30× past even that lenient default,
   confirming the disabled flag (not merely a slow default) is the
   proximate cause, but the default would still have been slow to react
   here even if autovacuum had been left on.

**Diagnosis:** autovacuum was explicitly turned off on this table (the
`autovacuum_enabled=false` storage parameter), so none of the six update
cycles' dead tuples were ever reclaimed. Separately, even the default
scale factor would tolerate 60,050 dead tuples before reacting on a
300,000-row table — survivable here, but the same 0.2 scale factor on a
10,000,000-row table (this course's `ledger_entries`, for scale) would
tolerate `50 + 0.2 × 10,000,000 = 2,000,050` dead tuples before autovacuum
even starts — two million rows of accumulated bloat is not a reasonable
steady-state to tolerate on a table that size, which is why "re-enable
the default" is not the same fix as "retune it for this table's actual
row count."

**Fix applied:**
```sql
ALTER TABLE idempotency_keys SET (
  autovacuum_enabled = true,
  autovacuum_vacuum_scale_factor = 0.02,
  autovacuum_vacuum_threshold = 500
);
VACUUM (VERBOSE) idempotency_keys;
```
The retuned scale factor drops this table's own trigger point to
`500 + 0.02 × 300,000 = 6,500` dead tuples — roughly 9× more responsive
than the default's 60,050, appropriate for a table whose entire purpose
is being churned continuously. Applied to the hypothetical 10,000,000-row
table above, the same `0.02` factor drops the trigger to `500 + 0.02 ×
10,000,000 = 200,500` — an order of magnitude improvement over the
default's 2,000,050, though still large in absolute terms, which is why
very large, very hot tables often pair a small scale factor with a
capped absolute threshold rather than relying on either alone.

**Proof the fix worked (same instrument re-read):** `SELECT * FROM
pgstattuple('idempotency_keys');` after the `VACUUM` → `dead_tuple_percent
≈ 0.3`. `SELECT reloptions FROM pg_class WHERE relname =
'idempotency_keys';` → `{autovacuum_enabled=true,autovacuum_vacuum_scale_factor=0.02,autovacuum_vacuum_threshold=500}`
— both the immediate cleanup and the retuning that prevents recurrence
are visible in the same two instruments used to diagnose the problem.

**Prediction error and what it tells me:** the 70% prediction landed
close to the measured 84.2% but underneath it — the model behind the
guess treated "six update cycles" as producing "six times the row count"
in dead tuples in a simple, linear way, without accounting for the
initial insert itself also contributing to the eventual live/dead ratio
denominator; the actual ratio (dead ÷ (live + dead)) climbs faster than a
naive "cycles × rows" estimate suggests once dead tuples make up the
majority of the table.

**What I would check first next time:** `pg_class.reloptions` for
`autovacuum_enabled=false` as the very first diagnostic step on any table
whose row count "shouldn't" be growing — it is a one-query check that
would have identified the root cause before ever running `pgstattuple`,
and a plain `VACUUM` without also fixing this reloption guarantees the
exact same incident recurs on the next churn cycle.

---

## Chain 3 — deleted `payment_events` documents, recovered from a `mongodump --oplog` backup

**Predictions (written before running anything):** not applicable to this
chain in the same numeric sense as Chains 1-2 — the deliverable here is
the recovered document content itself, and predicting the exact
pre-damage `payload.amount_minor` of two dozen essentially-random
documents ahead of time carries no diagnostic value the way predicting a
mostly-`captured` `status` distribution does.

**Symptom (verbatim, no interpretation):** part of the same `SYMPTOM`
line above: "a batch of chargeback events for merchant 1 has vanished
from payment_events."

**Layer:** durability

**Chain of evidence:**

1. Claim: `payment_events` is missing a specific, bounded set of
   documents that should exist. | Proof: `db.payment_events.countDocuments
   ({merchant_id: 1, type: 'chargeback', ts: {$gte: ISODate('2025-01-
   01T00:00:00.000Z'), $lt: ISODate('2025-01-01T06:00:00.000Z')}})` → `0`,
   where a merchant this active, over a 6-hour window, having zero
   `chargeback` events is not a plausible gap in an otherwise
   evenly-distributed event type — every other `type` value returns a
   nonzero count over the same window for the same merchant.
2. Claim: a `mongodump --oplog` backup taken before the deletion exists
   and is usable. | Proof: `/tmp/day06-mongodump/payments/payment_events.bson`
   and `/tmp/day06-mongodump/oplog.bson` both exist inside `ws`, and
   `mongorestore --oplogReplay` against a scratch instance completes
   without error, reporting a nonzero document count restored for
   `payments.payment_events`.
3. Claim: the scratch-restored collection has the documents the live one
   is missing. | Proof: on the scratch instance (port 27018),
   `db.payment_events.countDocuments({merchant_id: 1, type: 'chargeback',
   ts: {$gte: ISODate('2025-01-01T00:00:00.000Z'), $lt:
   ISODate('2025-01-01T06:00:00.000Z')}})` → `23` (this run's actual
   count), matching neither `0` nor a guess — a real number read off a
   real restored instance.
4. Claim: `mongodump --oplog` could not have been scoped to `payments`
   alone, which is why the dump directory also contains `admin` and
   `config`. | Proof: `ls /tmp/day06-mongodump` lists `admin`, `config`,
   `payments`, and `oplog.bson` — **not** `local`: `mongodump` excludes
   the `local` database unconditionally, in every mode, and its tailed
   entries are extracted into the standalone `oplog.bson` file rather
   than copied into the dump as a `local` collection at all. Seeing three
   database directories plus that one file, not four directories, is the
   dump working correctly — it confirms the "one idea, seen four ways"
   section's claim that `--oplog`'s consistency guarantee is
   deployment-wide, not `--db`-scoped, which is why the restore target
   was a disposable scratch `mongod`, not the live one.

**Diagnosis:** `payment_events` lost a bounded, specific set of
`chargeback` documents for merchant 1 — not a gradual data-quality drift,
a single deletion with a clean before/after boundary. Nothing live in the
collection records what those documents contained; the only place that
information still exists is the oplog-consistent `mongodump` snapshot
taken before the deletion. The fix is a restore of that snapshot into an
isolated instance, read the true values back out, and backfill only the
missing documents.

A direct `mongorestore` into the live deployment would not have been
refused, and it would not have been destructive either — worth being
precise about, since "it would have broken things" is not the real
reason to avoid it. Without `--drop`, `mongorestore` is insert-only: it
would have collided on `_id` for every surviving document, logged an
`E11000` duplicate-key error for each one, and exited non-zero — while
still successfully inserting the documents this incident actually needed
back. Overstating the danger ("it would corrupt the live database") is
its own mistake; the honest reason to avoid it is professional practice,
not safety theater: never point a restore at a live primary you cannot
roll back if something about the dump surprises you. Restore to a
disposable scratch instance, verify the recovered data is actually
correct there, and only then backfill the live collection surgically, by
`_id` — that sequencing is what makes a restore reversible up until the
last, deliberate step, and it is the real reason this fix used a scratch
`mongod` instead of restoring straight into `payments`.

**Fix applied:**
1. Started a scratch, standalone `mongod` inside the `mongo` container on
   port 27018, `--dbpath /tmp/day06-mongo-restore`, `--bind_ip_all` (so
   `ws`, where `mongorestore`/`mongoexport`/`mongoimport` actually live,
   can reach it), no `--replSet` — a disposable target, not a rejoin of
   `rs0`.
2. `mongorestore --uri="mongodb://mongo:27018/" --oplogReplay --dir
   /tmp/day06-mongodump` — restores every dumped database into the
   scratch instance and replays `oplog.bson` on top, bringing every
   collection to the single instant the dump finished (well before the
   deletion, in this run). Worth being precise about what actually
   recovers the documents here: the deletion happened *after* the dump
   completed, so it was never observed by the oplog tailer and does not
   appear anywhere in `oplog.bson` — oplog replay only rolls forward, it
   cannot undo an operation it never recorded. Every recovered document
   in this chain comes from `payments/payment_events.bson` itself, the
   dumped collection data; `--oplogReplay` here only brings the
   *surrounding* state to a consistent instant across collections, and
   contributes nothing to recovering the deleted documents specifically.
   Do not conclude from a successful restore that the oplog replay is
   what saved the data — in this incident, it did not.
3. Confirmed the target documents on the scratch instance:
   `db.payment_events.countDocuments(...)` → `23`, matching the live
   collection's pre-damage count that `break.sh` never revealed.
4. `mongoexport --uri="mongodb://mongo:27018/payments"
   --collection=payment_events --query='{"merchant_id":1,"type":
   "chargeback","ts":{"$gte":{"$date":"2025-01-01T00:00:00.000Z"},"$lt":
   {"$date":"2025-01-01T06:00:00.000Z"}}}'
   --out=/tmp/day06-recovered-events.jsonl`, then `mongoimport
   --uri="mongodb://mongo:27017/payments?replicaSet=rs0"
   --collection=payment_events --file=/tmp/day06-recovered-events.jsonl
   --mode=upsert --upsertFields=_id` against the live deployment —
   surgical, keyed by each document's original `_id`, not a full
   collection replace.
5. Shut down the scratch instance (`db.shutdownServer({force: true})`
   against port 27018) once the backfill was confirmed.

**Proof the fix worked (same instrument re-read):**
`db.payment_events.countDocuments({merchant_id: 1, type: 'chargeback',
ts: {$gte: ISODate('2025-01-01T00:00:00.000Z'), $lt: ISODate('2025-01-
01T06:00:00.000Z')}})` on the live collection now reports `23`, matching
the scratch instance's read. Spot-checking one document's `payload.
amount_minor` and `payload.channel` against the same document read off
the scratch instance before it was shut down confirms the values match
exactly, not merely the count.

**Prediction error and what it tells me:** not applicable — see the
predictions note above.

**What I would check first next time:** whether a `mongodump --oplog`
backup exists and is recent enough to cover the loss, before attempting
anything else — for a deletion this bounded, the oplog itself (if still
within its wrap window, per "MongoDB backup and recovery" in
`content/day06.md`) can answer the same question without a restore at
all, by reading the `o` (operation) documents for the deletion directly
out of `local.oplog.rs`; a restore is only strictly necessary once the
live oplog has already wrapped past the operation in question.
