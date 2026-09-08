#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Four independent checks (see README.md for the four deliverables they
# correspond to). All four must pass -- finding the right index and
# recognising the wrong ones are both graded, and so is the MongoDB fix.

MERCHANT_ID_FOR_MONGO=1950
THRESHOLD_MS=2000

echo "== check 1: stated index column order =="
if answer_check /tmp/.day03-target pg; then
  pass "index_columns in /tmp/answer (inside ws) matches this run's target"
else
  fail "index_columns in /tmp/answer (inside ws) does not match this run's target"
fi

echo
echo "== check 2: report query now uses an index, under the time threshold =="
query_text="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day03-query.sql)"
plan="$(in_pg "EXPLAIN (ANALYZE, BUFFERS) ${query_text}")"

if echo "$plan" | grep -q 'Seq Scan'; then
  fail "plan still contains a Seq Scan -- see the plan above your run wrote to /tmp/day03-query.sql"
elif echo "$plan" | grep -qE 'Index( Only)? Scan'; then
  pass "plan uses an Index Scan or Index Only Scan, no Seq Scan"
else
  fail "plan contains neither an Index Scan nor a Seq Scan -- unexpected plan shape"
fi

exec_ms="$(echo "$plan" | grep -oE 'Execution Time: [0-9.]+' | grep -oE '[0-9.]+' || true)"
if [ -n "$exec_ms" ] && awk -v t="$exec_ms" -v thr="$THRESHOLD_MS" 'BEGIN { exit !(t < thr) }'; then
  pass "execution time ${exec_ms} ms is under the ${THRESHOLD_MS} ms threshold"
else
  fail "execution time (${exec_ms:-unknown} ms) is not under the ${THRESHOLD_MS} ms threshold"
fi

# The disputed-payment-listing scenario's target index_columns is the
# single column "created_at" -- and that scenario is only really fixed
# by a PARTIAL index (WHERE status = 'disputed'). At this predicate's
# ~1% selectivity, a plain full index on created_at also satisfies the
# Index Scan and timing checks above, which would let this scenario's
# actual lesson -- scoping the index to the skewed predicate -- go
# ungraded. Read the stash (never printed) to detect this scenario
# specifically, and require a partial index only then; the other two
# scenarios are unaffected.
stash_cols="$(docker compose -p "$COMPOSE_PROJECT" exec -T pg cat /tmp/.day03-target 2>/dev/null \
  | sed -e 's/^index_columns=//' -e 's/[[:space:]]*$//' \
  | tr '[:upper:]' '[:lower:]')"
if [ "$stash_cols" = "created_at" ]; then
  used_index="$(echo "$plan" | grep -oE 'using [A-Za-z0-9_]+' | head -1 | awk '{print $2}')"
  if [ -z "$used_index" ]; then
    fail "could not determine which index the plan used to check for a partial predicate"
  else
    is_partial="$(in_pg "SELECT indpred IS NOT NULL FROM pg_index WHERE indexrelid = '${used_index}'::regclass;" | tr -d '[:space:]')"
    if [ "$is_partial" = "t" ]; then
      pass "the index used (${used_index}) is a partial index, as this scenario requires"
    else
      fail "the index used (${used_index}) is not partial -- this scenario's lesson is a partial index scoped to the disputed predicate, not a full index on the same column"
    fi
  fi
fi

echo
echo "== check 3: all three decoy indexes are gone =="
decoy_count="$(in_pg "SELECT count(*) FROM pg_stat_user_indexes WHERE indexrelname LIKE 'idx_decoy_%';")"
if [ "${decoy_count//[[:space:]]/}" = "0" ]; then
  pass "no idx_decoy_% index remains on payments"
else
  fail "at least one idx_decoy_% index still exists (pg_stat_user_indexes: ${decoy_count} row(s))"
fi

echo
echo "== check 4: MongoDB payment_events query uses an index =="
mongo_result="$(in_mongo "
  const r = db.payment_events
    .find({ merchant_id: ${MERCHANT_ID_FOR_MONGO} })
    .sort({ ts: -1 })
    .limit(20)
    .explain('executionStats');
  const stage = JSON.stringify(r.queryPlanner.winningPlan);
  print(stage.includes('IXSCAN') ? 'IXSCAN' : 'NO_IXSCAN');
  print(r.executionStats.totalDocsExamined);
  print(r.executionStats.nReturned);
")"

stage_seen="$(echo "$mongo_result" | sed -n '1p')"
docs_examined="$(echo "$mongo_result" | sed -n '2p' | tr -d '[:space:]')"
n_returned="$(echo "$mongo_result" | sed -n '3p' | tr -d '[:space:]')"

if [ "$stage_seen" = "IXSCAN" ]; then
  pass "winning plan includes an IXSCAN stage"
else
  fail "winning plan does not include an IXSCAN stage -- still collection-scanning"
fi

if [ -n "$n_returned" ] && [ "$n_returned" -gt 0 ] 2>/dev/null; then
  if awk -v e="$docs_examined" -v n="$n_returned" 'BEGIN { exit !(e / n <= 2) }'; then
    pass "totalDocsExamined/nReturned = ${docs_examined}/${n_returned}, at or under 2"
  else
    fail "totalDocsExamined/nReturned = ${docs_examined}/${n_returned}, over 2"
  fi
else
  fail "query returned no documents (nReturned=${n_returned:-0}) -- cannot judge the examined/returned ratio"
fi

echo
exit "${FAILED:-0}"
