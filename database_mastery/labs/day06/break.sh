#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Day 6 plants three independent incidents in one run:
#
#   1. A base backup plus a wrongly-scoped bulk UPDATE against `payments`,
#      to be undone with point-in-time recovery. The learner causes the
#      actual crash by hand (see README.md) -- this script never kills the
#      container itself, only sets up what the learner needs to recover
#      from once they do.
#   2. A bloat pathology on `idempotency_keys`, a table this script
#      creates for the purpose: autovacuum disabled, then churned with
#      repeated full-table update cycles.
#   3. A `mongodump --oplog` backup of the whole Mongo deployment, followed
#      by the deletion of a bounded set of `payment_events` documents, to
#      be undone by restoring that dump (plus its oplog) into a scratch,
#      standalone `mongod` and backfilling the live collection from it.
#
# Idempotent: re-running this drops and rebuilds the base backup,
# idempotency_keys, and the mongodump directory from scratch, and re-runs
# both the damaging UPDATE and the payment_events delete, so a learner who
# wants a clean second attempt -- one where the Mongo recovery below was
# already completed, or never started -- can re-run it directly. The one
# case this deliberately does NOT paper over: re-running after the Mongo
# damage has been committed but before it has been recovered. Doing that
# blindly would delete the only surviving copy of the missing documents
# (the mongodump this script is about to take) and replace it with a fresh
# dump of the already-damaged collection -- so this script checks the live
# document count before it touches the existing dump directory at all, and
# refuses to proceed (with the existing dump left untouched) if it looks
# like a prior run's damage was never recovered.

BASEBACKUP_DIR="/tmp/day06-basebackup"
DAMAGE_CUTOFF="2025-01-01 00:00:00+00"
CHURN_ROWS=300000
CHURN_CYCLES=6

# mongodump/mongorestore/mongoexport live in the `ws` container's
# mongodb-database-tools install (see labs/stack/Dockerfile.ws) -- the
# `mongo` service itself runs the plain mongo:7 server image and does not
# ship these client tools, so every Mongo dump/restore command below runs
# against `ws`, reaching the server over the compose network by its
# service name.
MONGO_DUMP_DIR="/tmp/day06-mongodump"
MONGO_URI="mongodb://mongo:27017/?replicaSet=rs0"
MONGO_TARGET_MERCHANT_ID=1
MONGO_TARGET_TYPE="chargeback"
MONGO_WINDOW_START="2025-01-01T00:00:00.000Z"
MONGO_WINDOW_END="2025-01-01T06:00:00.000Z"
MONGO_MIN_DOCS=3

echo "Resetting Day 6 baseline (idempotent)..."

# Clear any stale answer/stash from a previous attempt before planting a
# fresh incident.
docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -f /tmp/answer >/dev/null
docker compose -p "$COMPOSE_PROJECT" exec -T pg rm -f /tmp/.day06-target >/dev/null

echo
echo "== 1) confirming WAL archiving is actually live =="
# archive_mode cannot be changed without a server restart (see
# labs/stack/conf/postgresql.conf), so this is a live check that Task 1's
# durability settings took effect, not something this script can fix if
# it's wrong. If this fails, the stack itself is missing the WAL-archiving
# setup PITR depends on -- fix labs/stack, don't work around it here.
archive_mode="$(in_pg "SHOW archive_mode;" | tr -d '[:space:]')"
if [ "$archive_mode" != "on" ]; then
  echo "ERROR: archive_mode is '${archive_mode}', not 'on'. Day 6's PITR lab" >&2
  echo "requires labs/stack/conf/postgresql.conf's archive_mode=on to be in" >&2
  echo "effect. Fix the stack (it needs a restart after any config change" >&2
  echo "to this setting), then re-run this script." >&2
  exit 1
fi

# Force a WAL segment switch so the archiver has something to archive
# immediately, rather than waiting on however much write traffic it takes
# to fill a segment on its own.
in_pg "SELECT pg_switch_wal();" >/dev/null
sleep 2
archived_count="$(in_pg "SELECT archived_count FROM pg_stat_archiver;" | tr -d '[:space:]')"
if [ -z "$archived_count" ] || [ "$archived_count" = "0" ]; then
  echo "ERROR: pg_stat_archiver.archived_count is still 0 after forcing a" >&2
  echo "WAL segment switch. archive_command (labs/stack/conf/postgresql.conf)" >&2
  echo "is not successfully copying WAL into the pgarchive volume -- check" >&2
  echo "that /var/lib/postgresql/archive exists and is owned by postgres" >&2
  echo "inside the pg container (labs/stack/Dockerfile.pg is responsible" >&2
  echo "for that)." >&2
  exit 1
fi
echo "WAL archiving confirmed live: archived_count=${archived_count}."

echo
echo "== 2) taking a fresh base backup for this run's PITR drill =="
docker compose -p "$COMPOSE_PROJECT" exec -T pg rm -rf "$BASEBACKUP_DIR" >/dev/null
docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c \
  "PGPASSWORD=dbmastery pg_basebackup -h 127.0.0.1 -p 5432 -U dbm -D '${BASEBACKUP_DIR}' -Fp -Xs -c fast" >/dev/null
echo "Base backup written inside pg at ${BASEBACKUP_DIR}."

echo
echo "== 3) picking the row this run's fix will be checked against =="
# Any payment created on or after the (wrong) cutoff whose status isn't
# already 'failed' works -- the bulk UPDATE below is guaranteed to change
# it, so its pre-damage value is a real fact to recover, not a no-op.
TARGET_PAYMENT_ID="$(in_pg "SELECT payment_id FROM payments WHERE created_at >= '${DAMAGE_CUTOFF}' AND status <> 'failed' ORDER BY payment_id LIMIT 1;" | tr -d '[:space:]')"
if [ -z "$TARGET_PAYMENT_ID" ]; then
  echo "ERROR: could not find a target row for the damage cutoff ${DAMAGE_CUTOFF}." >&2
  exit 1
fi

pre_row="$(in_pg "SELECT amount_minor || '|' || status FROM payments WHERE payment_id = ${TARGET_PAYMENT_ID};")"
pre_amount_minor="$(echo "$pre_row" | cut -d'|' -f1 | tr -d '[:space:]')"
pre_status="$(echo "$pre_row" | cut -d'|' -f2 | tr -d '[:space:]')"

# Stash the pre-damage facts inside pg -- never printed, never written
# anywhere the learner's shell sees it. verify.sh reads this file back to
# grade the restore; it does not tell the learner what payment_id will be
# graded, only what this script prints below (the id, not the value).
echo
echo "== 4) committing the damage =="
# The intended change was "mark this one merchant's stale pending
# authorizations as failed" -- the actual predicate below dropped both the
# merchant_id filter and the status = 'pending' filter, leaving only the
# date bound, so every payment on or after the cutoff gets marked failed
# regardless of its real status: captured, refunded, disputed, all of it.
affected_before="$(in_pg "SELECT count(*) FROM payments WHERE created_at >= '${DAMAGE_CUTOFF}' AND status <> 'failed';" | tr -d '[:space:]')"
in_pg "UPDATE payments SET status = 'failed' WHERE created_at >= '${DAMAGE_CUTOFF}';" >/dev/null
echo "Committed: UPDATE payments SET status='failed' WHERE created_at >= '${DAMAGE_CUTOFF}' -- ${affected_before} rows changed that should not have been."

# Stash the pre-damage facts inside pg -- never printed, never written
# anywhere the learner's shell sees it. verify.sh reads this file back to
# grade the restore; it does not tell the learner what payment_id will be
# graded, only what this script prints above (the id, not the value), and
# affected_before is the count of rows the damaging UPDATE actually
# touched, needed to confirm the whole table came back, not only the one
# row named above.
docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/.day06-target' <<EOF
target_payment_id=${TARGET_PAYMENT_ID}
pre_status=${pre_status}
pre_amount_minor=${pre_amount_minor}
affected_before=${affected_before}
EOF
echo "Target row for your restore check: payment_id=${TARGET_PAYMENT_ID} (its correct pre-damage status and amount are not shown here -- recover them, don't guess them)."

echo
echo "== 5) creating the bloat pathology on idempotency_keys =="
in_pg "DROP TABLE IF EXISTS idempotency_keys;" >/dev/null
in_pg "CREATE TABLE idempotency_keys (
  key_id        BIGINT PRIMARY KEY,
  key_hash      TEXT NOT NULL,
  hit_count     BIGINT NOT NULL,
  last_seen_at  TIMESTAMPTZ NOT NULL
);" >/dev/null
in_pg "INSERT INTO idempotency_keys (key_id, key_hash, hit_count, last_seen_at)
       SELECT gs, md5(gs::text), 1, now() - (random() * interval '30 days')
       FROM generate_series(1, ${CHURN_ROWS}) AS gs;" >/dev/null

# Disabled here to reproduce a real mistake: someone turns this off during
# a migration "to reduce write amplification" and never turns it back on.
# Left this way, ordinary retry traffic against this table (every duplicate
# payment request bumps hit_count and last_seen_at) never gets vacuumed.
in_pg "ALTER TABLE idempotency_keys SET (autovacuum_enabled = false);" >/dev/null

echo "Churning idempotency_keys for ${CHURN_CYCLES} update cycles with autovacuum disabled..."
for i in $(seq 1 "$CHURN_CYCLES"); do
  in_pg "UPDATE idempotency_keys SET hit_count = hit_count + 1, last_seen_at = now();" >/dev/null
done

echo
echo "== 6) picking the payment_events documents this run's Mongo recovery will be checked against =="
# merchant_id 1 is the single most active merchant under this seed's
# Zipf(s=1) power law (see labs/stack/seed/30-mongo-load.js), so it is
# guaranteed to exist at any SCALE the stack was seeded at; the type and
# ts-window filters bound the damage to a small, specific set rather than
# an open-ended tail of the collection.
#
# This count runs BEFORE the mongodump below (and before touching any
# existing dump directory) specifically so a re-run can tell the
# difference between "this seed never had enough matching documents" and
# "a previous run already deleted them and they were never recovered" --
# see the idempotency note at the top of this file. Reordering this ahead
# of the dump is the fix for that; do not move it back below the dump.
MONGO_FILTER="{merchant_id: ${MONGO_TARGET_MERCHANT_ID}, type: '${MONGO_TARGET_TYPE}', ts: {\$gte: ISODate('${MONGO_WINDOW_START}'), \$lt: ISODate('${MONGO_WINDOW_END}')}}"

mongo_deleted_count="$(in_mongo "db.payment_events.countDocuments(${MONGO_FILTER})" | tr -d '[:space:]')"
if ! [[ "$mongo_deleted_count" =~ ^[0-9]+$ ]] || [ "$mongo_deleted_count" -lt "$MONGO_MIN_DOCS" ]; then
  # Two very different situations produce the exact same symptom here --
  # too few (or zero) live matches -- and it matters which one this is
  # before doing anything else. If a mongodump from a previous run is
  # still on disk, the far more likely explanation is that this script
  # already ran once, already deleted these documents, and the Mongo
  # recovery (README.md step 7) was never completed -- NOT a seed/SCALE
  # problem. Treat that dump as the only surviving copy of the missing
  # documents and leave it alone: do not delete or overwrite it here.
  if docker compose -p "$COMPOSE_PROJECT" exec -T ws test -f "${MONGO_DUMP_DIR}/payments/payment_events.bson" 2>/dev/null; then
    echo "ERROR: only ${mongo_deleted_count:-0} live payment_events document(s) match merchant_id=${MONGO_TARGET_MERCHANT_ID}, type=${MONGO_TARGET_TYPE}, ts in [${MONGO_WINDOW_START}, ${MONGO_WINDOW_END}) -- need at least ${MONGO_MIN_DOCS} -- and a mongodump from a previous run already exists at ${MONGO_DUMP_DIR} inside ws." >&2
    echo "This looks like a previous run's Mongo damage that was never recovered, not a seed problem: break.sh already deleted these documents once, and labs/day06/README.md step 7's recovery was not completed before break.sh was run again." >&2
    echo "Either finish that recovery now using the existing dump at ${MONGO_DUMP_DIR} as your source (it has not been touched), or, for a genuinely clean slate, re-seed the whole stack (labs/stack/seed/README.md) and then re-run break.sh once." >&2
    exit 1
  fi
  echo "ERROR: only ${mongo_deleted_count:-0} payment_events document(s) matched merchant_id=${MONGO_TARGET_MERCHANT_ID}, type=${MONGO_TARGET_TYPE}, ts in [${MONGO_WINDOW_START}, ${MONGO_WINDOW_END}) -- need at least ${MONGO_MIN_DOCS}." >&2
  echo "This almost always means the seed was loaded at a SCALE other than the default 10, where payment_events density shrinks with it." >&2
  echo "Re-seed at SCALE=10, or pick a different merchant/type/window (edit MONGO_TARGET_MERCHANT_ID / MONGO_WINDOW_START / MONGO_WINDOW_END here, and the matching values in verify.sh, README.md, and SOLUTION.md)." >&2
  exit 1
fi

# Full pre-damage content of every matching document, sorted by _id, over
# exactly the fields a correct restore must reproduce -- captured from the
# LIVE collection, before the mongodump and the delete below. Never
# printed, only stashed for verify.sh to compare against later.
mongo_docs="$(in_mongo "db.payment_events.find(${MONGO_FILTER}).sort({_id:1}).toArray().map(function(d){return [d._id.toHexString(), d.payment_id, d.merchant_id, d.type, d.ts.toISOString(), d.payload.amount_minor, d.payload.channel].join('|');}).join(';')")"

echo
echo "== 7) taking a fresh mongodump --oplog for this run's Mongo recovery drill =="
# --oplog only produces a point-in-time-consistent dump when it can tail
# the WHOLE deployment's oplog for the dump's duration -- MongoDB refuses
# --oplog together with --db/--collection for exactly this reason (see
# content/day06.md's "MongoDB backup and recovery" section). A full
# deployment dump it is, same as a real backup job would take. By this
# point the check above has already confirmed the live collection still
# holds the target documents, so it is safe to drop whatever dump
# directory exists and take a fresh one -- this dump will still capture
# them, because the delete below hasn't happened yet.
docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -rf "$MONGO_DUMP_DIR" >/dev/null
docker compose -p "$COMPOSE_PROJECT" exec -T ws \
  mongodump --uri="$MONGO_URI" --oplog --out="$MONGO_DUMP_DIR" >/dev/null
# Sourced from the mongod server's own clock, not the learner's host or
# the ws container running this script -- in_mongo execs mongosh inside
# the `mongo` container itself, so Date.now() here reads the same clock
# the oplog's own `ts` entries are stamped from. A timestamp meant for
# comparison against oplog entries should always come from the server
# (or from the last `ts` actually in oplog.bson), never from a client
# host that could be running on a different clock entirely.
MONGO_DUMP_DONE_TS="$(in_mongo 'Math.floor(Date.now()/1000)' | tr -d '[:space:]')"
echo "mongodump --oplog written inside ws at ${MONGO_DUMP_DIR} (completed at unix ts ${MONGO_DUMP_DONE_TS} -- pass this as --oplogLimit ${MONGO_DUMP_DONE_TS}:1 if you want to pin the restore point explicitly rather than relying on the dump's own end)."

echo
echo "== 8) committing the Mongo damage =="
in_mongo "db.payment_events.deleteMany(${MONGO_FILTER})" >/dev/null

# Confirm the damage actually landed before printing anything about it --
# the same discipline as step 1's live check of WAL archiving, applied to
# a delete instead of a config setting.
mongo_remaining="$(in_mongo "db.payment_events.countDocuments(${MONGO_FILTER})" | tr -d '[:space:]')"
if [ "$mongo_remaining" != "0" ]; then
  echo "ERROR: expected 0 payment_events documents left matching the damage filter after deleteMany, found ${mongo_remaining} -- the delete did not land." >&2
  exit 1
fi
echo "Committed: deleted ${mongo_deleted_count} payment_events document(s) (merchant_id=${MONGO_TARGET_MERCHANT_ID}, type=${MONGO_TARGET_TYPE}, ts in [${MONGO_WINDOW_START}, ${MONGO_WINDOW_END})) -- confirmed 0 remain live."

# Append the Mongo damage's pre-damage facts into the SAME stash file the
# PostgreSQL incident above uses -- same path, same contract (never
# printed, read back by verify.sh). It lives inside the pg container only
# because that file already exists there: the stash's location is a
# filename convention this day picked, not a statement about which engine
# owns it.
docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat >> /tmp/.day06-target' <<EOF
mongo_target_merchant_id=${MONGO_TARGET_MERCHANT_ID}
mongo_target_type=${MONGO_TARGET_TYPE}
mongo_window_start=${MONGO_WINDOW_START}
mongo_window_end=${MONGO_WINDOW_END}
mongo_deleted_count=${mongo_deleted_count}
mongo_docs=${mongo_docs}
EOF

say_symptom "a bulk status update ran against payments with the wrong predicate roughly twelve minutes ago, idempotency_keys is growing without bound even though nothing is inserting new rows into it, and a batch of chargeback events for merchant ${MONGO_TARGET_MERCHANT_ID} has vanished from payment_events."
