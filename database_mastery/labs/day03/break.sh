#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Day 3 plants a diagnostic incident across two engines at once:
#
#   PostgreSQL: one of three report queries, chosen at random, is missing
#   its correct composite (or partial) index. Three decoy indexes --
#   idx_decoy_1, idx_decoy_2, idx_decoy_3 -- sit in the schema instead,
#   each wrong in a different, plausible-looking way (see content/day03.md,
#   Core concepts). Recognising that the decoys are wrong is half the lab;
#   building the right index is the other half.
#
#   MongoDB: payment_events has no index supporting a query that filters
#   on merchant_id and sorts by ts, so it collection-scans the whole
#   collection and sorts in memory for every request.
#
# Idempotent: re-running this drops any correct index or decoy this
# script (or a previous attempt) left behind, and re-rolls the random
# report-query choice, before planting the incident again.

MERCHANT_ID_FOR_MONGO=1950

echo "Resetting Day 3 baseline (idempotent)..."

# Drop anything a previous run of this lab (correct fix or partial
# attempt) may have left behind, so this run starts from the same
# index-free baseline every time.
in_pg "DROP INDEX IF EXISTS idx_payments_merchant_created;" >/dev/null
in_pg "DROP INDEX IF EXISTS idx_payments_disputed_created;" >/dev/null
in_pg "DROP INDEX IF EXISTS idx_ledger_direction_posted;" >/dev/null
in_pg "DROP INDEX IF EXISTS idx_decoy_1;" >/dev/null
in_pg "DROP INDEX IF EXISTS idx_decoy_2;" >/dev/null
in_pg "DROP INDEX IF EXISTS idx_decoy_3;" >/dev/null

# Three decoys, each wrong in a different way (content/day03.md, Core
# concepts, spells out the reasoning for each):
#   idx_decoy_1 -- single column on low-selectivity `status`
#                  (~80% of rows are 'captured'; an index here is
#                  correctly ignored by the planner for most queries).
#   idx_decoy_2 -- composite index with the range column first and the
#                  equality column second -- backwards order, so the
#                  equality predicate can no longer prune the leaf range
#                  the scan walks.
#   idx_decoy_3 -- a single-column index that is a strict, redundant
#                  leftmost prefix of idx_decoy_2.
echo "Planting three decoy indexes..."
in_pg "CREATE INDEX idx_decoy_1 ON payments (status);" >/dev/null
in_pg "CREATE INDEX idx_decoy_2 ON payments (created_at, merchant_id);" >/dev/null
in_pg "CREATE INDEX idx_decoy_3 ON payments (created_at);" >/dev/null

# Pick one of three report queries at random. Each has a genuinely
# different correct index shape -- see content/day03.md and SOLUTION.md.
pick=$(( (RANDOM % 3) + 1 ))

case "$pick" in
  1)
    query_sql="SELECT date_trunc('day', created_at) AS settlement_day,
       count(*)                      AS payment_count,
       sum(amount_minor)             AS gross_amount_minor
FROM payments
WHERE merchant_id = 15
  AND status = 'captured'
  AND created_at >= '2024-06-01'
  AND created_at <  '2024-07-01'
GROUP BY settlement_day
ORDER BY settlement_day;"
    target_cols="merchant_id,created_at"
    ;;
  2)
    query_sql="SELECT payment_id, merchant_id, amount_minor, created_at
FROM payments
WHERE status = 'disputed'
ORDER BY created_at DESC
LIMIT 50;"
    target_cols="created_at"
    ;;
  3)
    query_sql="SELECT posted_date, sum(amount_minor) AS net_volume_minor
FROM ledger_entries
WHERE direction = 'C'
  AND posted_date >= DATE '2024-06-01'
  AND posted_date <  DATE '2024-07-01'
GROUP BY posted_date
ORDER BY posted_date;"
    target_cols="direction,posted_date"
    ;;
esac

echo "Writing this run's report query to /tmp/day03-query.sql on ws..."
docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/day03-query.sql' <<EOF
$query_sql
EOF

# Stash the correct ordered column list for this run's query inside pg,
# where answer_check will read it. Never printed; never echoed to the
# learner's terminal.
docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/.day03-target' <<EOF
index_columns=${target_cols}
EOF

# Also clear any stale answer from a previous attempt. answer_check
# reads the learner's /tmp/answer from ws (the stash above lives in pg
# instead, per its own comment).
docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -f /tmp/answer >/dev/null

echo "Refreshing planner statistics..."
in_pg "ANALYZE payments; ANALYZE ledger_entries;" >/dev/null

echo "Resetting the MongoDB payment_events pathology..."
in_mongo '
db.payment_events.getIndexes().forEach(function (ix) {
  if (ix.name !== "_id_") { db.payment_events.dropIndex(ix.name); }
});
' >/dev/null

# MERCHANT_ID_FOR_MONGO is only guaranteed cold-but-present at the
# default SCALE=10 (2,000 merchants). At a smaller SCALE that merchant
# id may not exist at all, or may have fewer documents than the query's
# LIMIT (20) -- either way verify.sh's check 4 would then divide by
# nReturned=0 and the lab would be unpassable through no fault of the
# learner's. Fail loudly here instead of letting that happen silently.
event_count="$(in_mongo "db.payment_events.countDocuments({ merchant_id: ${MERCHANT_ID_FOR_MONGO} })" | tr -d '[:space:]')"
if ! [[ "$event_count" =~ ^[0-9]+$ ]] || [ "$event_count" -lt 20 ]; then
  echo "ERROR: merchant_id ${MERCHANT_ID_FOR_MONGO} has only ${event_count:-0} payment_events document(s) -- this lab needs at least 20 (the query's LIMIT) for a valid nReturned>0 check." >&2
  echo "This almost always means the seed was loaded at a SCALE other than the default 10, where payment_events and its merchant range shrink together." >&2
  echo "Re-seed at SCALE=10, or pick a different MERCHANT_ID_FOR_MONGO (edit it here and in verify.sh, README.md, and SOLUTION.md) that is cold but present at your SCALE." >&2
  exit 1
fi

say_symptom "the report query takes over 40 seconds to run, and the payment_events query for merchant $MERCHANT_ID_FOR_MONGO examines roughly 50,000 documents for every one it returns."
