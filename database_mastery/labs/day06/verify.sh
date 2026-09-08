#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Five independent checks (see README.md and content/day06.md for the
# five deliverables they correspond to). All five must pass.
#
# Check 1 reads /tmp/answer as a multi-key file (recovery_seconds=,
# bloat_ratio_before=, recovered_status=) -- the same shape Day 2's
# verify.sh uses for a multi-field answer. common.sh's answer_check does
# a whole-file comparison of a single stashed value against the whole of
# /tmp/answer, which does not fit a file carrying three independent keys,
# so recovered_status is compared here by hand against the stash instead,
# using the same trim-and-lowercase rule answer_check itself uses. It is
# still never printed on failure.

DEAD_PCT_MAX=10
BLOAT_BEFORE_MIN=15
BLOAT_BEFORE_MAX=100
RECOVERY_SECONDS_MIN=0
RECOVERY_SECONDS_MAX=180
IDLE_MAX_AGE_SECONDS=60
DAMAGE_CUTOFF="2025-01-01 00:00:00+00"

trim_lower() {
  printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]'
}

echo "== check 1: /tmp/answer fields =="

answer_raw="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"
recovery_seconds="$(printf '%s\n' "$answer_raw" | grep -i '^recovery_seconds=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
bloat_ratio_before="$(printf '%s\n' "$answer_raw" | grep -i '^bloat_ratio_before=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
recovered_status_raw="$(printf '%s\n' "$answer_raw" | grep -i '^recovered_status=' | head -1 | cut -d= -f2-)"

if [ -n "$recovery_seconds" ] && awk -v v="$recovery_seconds" -v lo="$RECOVERY_SECONDS_MIN" -v hi="$RECOVERY_SECONDS_MAX" 'BEGIN { exit !(v+0 > lo && v+0 <= hi) }' 2>/dev/null; then
  pass "recovery_seconds=${recovery_seconds} is a plausible number of seconds"
else
  fail "recovery_seconds is missing or not a plausible number of seconds (0, ${RECOVERY_SECONDS_MAX}] (got '${recovery_seconds:-<empty>}')"
fi

if [ -n "$bloat_ratio_before" ] && awk -v v="$bloat_ratio_before" -v lo="$BLOAT_BEFORE_MIN" -v hi="$BLOAT_BEFORE_MAX" 'BEGIN { exit !(v+0 >= lo && v+0 <= hi) }' 2>/dev/null; then
  pass "bloat_ratio_before=${bloat_ratio_before} is a plausible pre-fix bloat percentage"
else
  fail "bloat_ratio_before is missing or outside the plausible range [${BLOAT_BEFORE_MIN}, ${BLOAT_BEFORE_MAX}] (got '${bloat_ratio_before:-<empty>}') -- this should reflect the genuinely bloated table, before you vacuumed it"
fi

stash_raw="$(docker compose -p "$COMPOSE_PROJECT" exec -T pg cat /tmp/.day06-target 2>/dev/null || true)"
target_payment_id="$(printf '%s\n' "$stash_raw" | grep -i '^target_payment_id=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
stash_pre_status="$(printf '%s\n' "$stash_raw" | grep -i '^pre_status=' | head -1 | cut -d= -f2-)"
stash_pre_amount="$(printf '%s\n' "$stash_raw" | grep -i '^pre_amount_minor=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
stash_affected_before="$(printf '%s\n' "$stash_raw" | grep -i '^affected_before=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"

learner_status="$(trim_lower "$recovered_status_raw")"
expected_status="$(trim_lower "$stash_pre_status")"

if [ -n "$learner_status" ] && [ -n "$expected_status" ] && [ "$learner_status" = "$expected_status" ]; then
  pass "recovered_status in /tmp/answer matches this run's pre-damage value"
else
  fail "recovered_status in /tmp/answer does not match this run's pre-damage value"
fi

echo
echo "== check 2: the damaged row is actually restored =="

if [ -z "$target_payment_id" ]; then
  fail "no stash found at /tmp/.day06-target inside pg -- run break.sh first"
else
  live_row="$(in_pg "SELECT amount_minor || '|' || status FROM payments WHERE payment_id = ${target_payment_id};")"
  live_amount="$(echo "$live_row" | cut -d'|' -f1 | tr -d '[:space:]')"
  live_status="$(trim_lower "$(echo "$live_row" | cut -d'|' -f2)")"

  if [ "$live_status" = "$expected_status" ]; then
    pass "payment_id=${target_payment_id} status restored to its pre-damage value"
  else
    fail "payment_id=${target_payment_id} status has not been restored to its pre-damage value"
  fi

  if [ -n "$live_amount" ] && [ "$live_amount" = "$stash_pre_amount" ]; then
    pass "payment_id=${target_payment_id} amount_minor is unchanged from its pre-damage value"
  else
    fail "payment_id=${target_payment_id} amount_minor does not match its pre-damage value -- the fix touched a column it should not have"
  fi

  # A restore that only fixes target_payment_id (a one-row UPDATE against
  # the scratch instance's recovered value, say) passes the two checks
  # above by luck, not diagnosis, while leaving the other ~third of
  # `payments` still marked 'failed'. This check requires the whole
  # damaged population to be back at its pre-damage count, not only the
  # one graded row. affected_before is the pre-damage count of rows at the
  # cutoff that were NOT already 'failed'; the population at the cutoff is
  # otherwise unchanged by an UPDATE-only incident, so
  # (live total at cutoff) - affected_before is the pre-damage count of
  # rows that WERE already 'failed', and a correct restore returns
  # count(status = 'failed') at the cutoff to exactly that value -- never
  # printed on failure, same as the per-row stash above.
  if [ -z "$stash_affected_before" ]; then
    fail "no affected_before found in the /tmp/.day06-target stash -- re-run break.sh"
  else
    live_total_at_cutoff="$(in_pg "SELECT count(*) FROM payments WHERE created_at >= '${DAMAGE_CUTOFF}';" | tr -d '[:space:]')"
    live_failed_at_cutoff="$(in_pg "SELECT count(*) FROM payments WHERE created_at >= '${DAMAGE_CUTOFF}' AND status = 'failed';" | tr -d '[:space:]')"
    expected_failed_at_cutoff="$((live_total_at_cutoff - stash_affected_before))"
    if [ -n "$live_failed_at_cutoff" ] && [ "$live_failed_at_cutoff" = "$expected_failed_at_cutoff" ]; then
      pass "payments.status = 'failed' count for created_at >= ${DAMAGE_CUTOFF} restored across the whole damaged population, not only the graded row"
    else
      fail "payments.status = 'failed' count for created_at >= ${DAMAGE_CUTOFF} has not returned to its pre-damage value -- the restore covered fewer rows than the damaging UPDATE touched"
    fi
  fi
fi

echo
echo "== check 3: idempotency_keys bloat resolved by retuning, not a one-off vacuum =="

in_pg "CREATE EXTENSION IF NOT EXISTS pgstattuple;" >/dev/null 2>&1 || true

dead_pct="$(in_pg "SELECT round(dead_tuple_percent, 1) FROM pgstattuple('idempotency_keys');" 2>/dev/null | tr -d '[:space:]')" || dead_pct=""
if [ -n "$dead_pct" ] && awk -v v="$dead_pct" -v hi="$DEAD_PCT_MAX" 'BEGIN { exit !(v+0 < hi) }' 2>/dev/null; then
  pass "idempotency_keys dead_tuple_percent=${dead_pct}, under the ${DEAD_PCT_MAX}% threshold"
else
  fail "idempotency_keys dead_tuple_percent is ${dead_pct:-unknown}, not under the ${DEAD_PCT_MAX}% threshold -- vacuum it"
fi

reloptions="$(in_pg "SELECT coalesce(array_to_string(reloptions, ','), '') FROM pg_class WHERE relname = 'idempotency_keys';" 2>/dev/null)" || reloptions=""
if echo "$reloptions" | grep -qi 'autovacuum_enabled=false'; then
  fail "idempotency_keys still has autovacuum_enabled=false in pg_class.reloptions -- re-enable it"
elif echo "$reloptions" | grep -qiE 'autovacuum_vacuum_scale_factor=|autovacuum_vacuum_threshold='; then
  pass "idempotency_keys has retuned, non-default autovacuum thresholds in pg_class.reloptions (${reloptions})"
else
  fail "idempotency_keys has no autovacuum_vacuum_scale_factor or autovacuum_vacuum_threshold set in pg_class.reloptions -- a plain VACUUM with no retuning does not pass this check"
fi

echo
echo "== check 4: no idle-in-transaction session survives past ${IDLE_MAX_AGE_SECONDS}s =="

stale_idle="$(in_pg "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction' AND now() - xact_start > interval '${IDLE_MAX_AGE_SECONDS} seconds';" | tr -d '[:space:]')"
if [ "${stale_idle:-x}" = "0" ]; then
  pass "no idle-in-transaction session older than ${IDLE_MAX_AGE_SECONDS}s"
else
  fail "${stale_idle} idle-in-transaction session(s) older than ${IDLE_MAX_AGE_SECONDS}s survive -- this alone would defeat the vacuum fix regardless of the other checks"
fi

echo
echo "== check 5: deleted payment_events documents are back in Mongo with their original values =="

mongo_target_merchant_id="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_target_merchant_id=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
mongo_target_type="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_target_type=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
mongo_window_start="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_window_start=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
mongo_window_end="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_window_end=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
mongo_deleted_count_stash="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_deleted_count=' | head -1 | cut -d= -f2- | tr -d '[:space:]')"
mongo_docs_stash="$(printf '%s\n' "$stash_raw" | grep -i '^mongo_docs=' | head -1 | cut -d= -f2-)"

if [ -z "$mongo_target_merchant_id" ] || [ -z "$mongo_docs_stash" ]; then
  fail "no Mongo damage stash found in /tmp/.day06-target inside pg -- run break.sh first"
else
  mongo_filter="{merchant_id: ${mongo_target_merchant_id}, type: '${mongo_target_type}', ts: {\$gte: ISODate('${mongo_window_start}'), \$lt: ISODate('${mongo_window_end}')}}"

  live_mongo_count="$(in_mongo "db.payment_events.countDocuments(${mongo_filter})" | tr -d '[:space:]')"
  if [ -n "$live_mongo_count" ] && [ "$live_mongo_count" = "$mongo_deleted_count_stash" ]; then
    pass "payment_events: ${live_mongo_count} document(s) present again matching the damaged merchant/type/window"
  else
    fail "payment_events document count for the damaged merchant/type/window does not match the pre-damage count -- restore the deleted documents from the mongodump --oplog backup"
  fi

  # Byte-for-byte comparison of every restored document's identity and
  # value fields against the pre-damage stash, sorted the same way on both
  # sides -- a restore that only gets the right COUNT back (say, by
  # re-inserting the right number of documents with guessed field values)
  # fails here even though the check above would have passed it. Never
  # printed on failure, same discipline as the PostgreSQL stash above.
  live_mongo_docs="$(in_mongo "db.payment_events.find(${mongo_filter}).sort({_id:1}).toArray().map(function(d){return [d._id.toHexString(), d.payment_id, d.merchant_id, d.type, d.ts.toISOString(), d.payload.amount_minor, d.payload.channel].join('|');}).join(';')" 2>/dev/null | tr -d '\r')" || live_mongo_docs=""

  if [ -n "$live_mongo_docs" ] && [ "$live_mongo_docs" = "$mongo_docs_stash" ]; then
    pass "payment_events documents for the damaged window match their pre-damage values exactly"
  else
    fail "payment_events documents for the damaged window do not match their pre-damage values -- restore them from the mongodump --oplog backup, not by re-inserting guessed data"
  fi
fi

echo
exit "${FAILED:-0}"
