#!/usr/bin/env bash
set -euo pipefail

# labs/day08/verify.sh
#
# Scores the five incidents gauntlet.sh applied, INDEPENDENTLY. Each one
# requires two things to both be true: the pathology is genuinely resolved
# (checked the same class of way its origin day checked it -- a plan
# shape, a catalog counter, a replayed interleaving), AND the learner's
# stated diagnosis for that specific incident matches what gauntlet.sh
# stashed, via answer_check. Getting four of five exactly right is not a
# pass -- an on-call engineer does not get partial credit for four
# incidents out of five closed.
#
# A note on how answer_check gets used here, because it looks different
# from every earlier day: answer_check compares two WHOLE FILES for exact
# equality. Every earlier day has exactly one answer key, so that whole-
# file compare IS the per-incident compare. Day 8 has up to five keys
# sharing one consolidated /tmp/answer on ws (see gauntlet.sh's header),
# so checking five incidents independently through the same function
# means extracting one key's line at a time, writing it alone into
# /tmp/answer, checking it against a stash file holding only that same
# key, then moving to the next -- never touching common.sh, and restoring
# the learner's real /tmp/answer when done (see check_answer_key and the
# EXIT trap below).

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

FAILED=0
GAUNTLET_START_EPOCH="$(date +%s)"

SELECTED_RAW="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/.day08-selected 2>/dev/null || true)"
if [ -z "${SELECTED_RAW//[[:space:]]/}" ]; then
  echo "No Day 8 incidents are recorded as applied." >&2
  echo "Run 'bash labs/day08/gauntlet.sh' first, then diagnose all five before running this." >&2
  exit 1
fi

TARGETS="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/.day08-targets 2>/dev/null || true)"
ORIGINAL_ANSWER="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"

restore_answer_files() {
  printf '%s\n' "$ORIGINAL_ANSWER" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/answer' >/dev/null 2>&1 || true
  printf '%s\n' "$TARGETS" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/.day08-targets' >/dev/null 2>&1 || true
}
trap restore_answer_files EXIT

# check_answer_key key expected_line
# Extracts the learner's own line for `key` out of the ORIGINAL /tmp/answer
# (captured once, above, before any of this file's own overwrites), writes
# it alone into /tmp/answer, writes `expected_line` alone into
# /tmp/.day08-targets, and calls the real answer_check against those two
# single-line files. Returns 0 on a match, 1 otherwise -- never prints
# either value, on a pass or a fail, exactly like every other day.
#
# answer_check trims only leading/trailing whitespace on the whole line,
# so a correct comma-list answer written with internal spaces
# ("customer_id, status, created_at") would otherwise fail against a
# stash written without them. Both sides get every internal whitespace
# character stripped before the comparison, below -- since the same
# normalisation is applied to both the stash and the learner's line, this
# can only make a genuine match succeed, never turn a genuine mismatch
# into a false pass.
check_answer_key() {
  local key="$1" expected_line="$2" learner_line result=1
  if [ -z "$expected_line" ]; then
    fail "no stashed target for key '${key}' -- was this incident actually applied by gauntlet.sh?"
    return 1
  fi
  learner_line="$(grep -i "^${key}=" <<<"$ORIGINAL_ANSWER" | tail -n1 | tr -d '[:space:]')"
  expected_line="$(printf '%s' "$expected_line" | tr -d '[:space:]')"
  printf '%s\n' "$learner_line" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/answer'
  printf '%s\n' "$expected_line" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/.day08-targets'
  if answer_check /tmp/.day08-targets ws; then
    result=0
  fi
  return "$result"
}

target_for() {
  grep "^$1=" <<<"$TARGETS" | tail -n1
}

# ---------------------------------------------------------------------
# check_<pathology> -- one per pool member. Each prints its own pass/fail
# lines via pass()/fail() and returns 0 only if every sub-check passed.
# ---------------------------------------------------------------------

check_missing_index() {
  local ok=1 cust plan ms
  cust="$(in_pg "SELECT customer_id FROM payments
                  WHERE status = 'captured'
                  ORDER BY customer_id
                  OFFSET (SELECT count(*) / 3 FROM payments WHERE status = 'captured')
                  LIMIT 1;" | tr -d '[:space:]')"
  plan="$(in_pg "EXPLAIN (ANALYZE)
    SELECT payment_id, amount_minor, created_at
    FROM payments
    WHERE customer_id = ${cust} AND status = 'captured'
    ORDER BY created_at DESC LIMIT 20;")"

  if echo "$plan" | grep -q 'Seq Scan'; then
    fail "missing_index: plan still shows a Seq Scan on payments"; ok=0
  elif echo "$plan" | grep -qE 'Index( Only)? Scan'; then
    pass "missing_index: plan now uses an Index Scan / Index Only Scan"
  else
    fail "missing_index: plan shows neither an Index Scan nor a Seq Scan -- unexpected shape"; ok=0
  fi

  ms="$(echo "$plan" | grep -oE 'Execution Time: [0-9.]+' | grep -oE '[0-9.]+' || true)"
  if [ -n "$ms" ] && awk -v t="$ms" 'BEGIN{exit !(t<2000)}'; then
    pass "missing_index: execution time ${ms} ms is under 2000 ms"
  else
    fail "missing_index: execution time (${ms:-unknown} ms) is not under 2000 ms"; ok=0
  fi

  if check_answer_key "index_columns" "$(target_for index_columns)"; then
    pass "missing_index: index_columns answer matches"
  else
    fail "missing_index: index_columns answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_stale_stats() {
  local ok=1 target exec_line ms attopts off
  target="$(in_pg "SELECT account_id FROM accounts
                    ORDER BY account_id
                    OFFSET (SELECT count(*) / 4 FROM accounts)
                    LIMIT 1;" | tr -d '[:space:]')"

  exec_line="$(in_pg "EXPLAIN (ANALYZE)
    SELECT a.account_id, l.direction, count(*) AS n, sum(l.amount_minor) AS total_minor
    FROM accounts a
    JOIN ledger_entries l ON l.account_id = a.account_id
    WHERE a.account_id = ${target}
    GROUP BY a.account_id, l.direction;" | grep -i 'Execution Time' || true)"
  ms="$(echo "$exec_line" | grep -oE '[0-9]+\.[0-9]+' | head -n1)"

  if [ -n "$ms" ] && awk -v a="$ms" 'BEGIN{exit !(a<3000)}'; then
    pass "stale_stats: account ledger report completed in ${ms} ms (under 3000 ms)"
  else
    fail "stale_stats: account ledger report took ${ms:-unknown} ms -- still above 3000 ms"; ok=0
  fi

  attopts="$(in_pg "SELECT coalesce(attoptions::text, '')
                     FROM pg_attribute
                     WHERE attrelid = 'ledger_entries'::regclass AND attname = 'account_id';")"
  if echo "$attopts" | grep -qi 'n_distinct'; then
    fail "stale_stats: ledger_entries.account_id still carries an n_distinct override"; ok=0
  else
    pass "stale_stats: n_distinct override on ledger_entries.account_id is gone"
  fi

  off="$(in_pg "SELECT name FROM pg_settings
                 WHERE name IN ('enable_nestloop','enable_hashjoin','enable_seqscan')
                   AND setting <> 'on';")"
  if [ -n "$off" ]; then
    fail "stale_stats: a planner method is force-disabled -- that hides the estimate error instead of fixing it"; ok=0
  else
    pass "stale_stats: no planner method is force-disabled"
  fi

  if check_answer_key "divergent_node" "$(target_for divergent_node)"; then
    pass "stale_stats: divergent_node answer matches"
  else
    fail "stale_stats: divergent_node answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_lock_chain() {
  local ok=1 root_pid tries=15 root_alive blocked

  root_pid="$(target_for root_pid | sed -n 's/^root_pid=//p' | tr -d '[:space:]')"

  root_alive="$(in_pg "SELECT count(*) FROM pg_stat_activity WHERE pid = ${root_pid:-0};" | tr -d '[:space:]')"
  while [ "$tries" -gt 0 ] && [ "${root_alive:-1}" != "0" ]; do
    sleep 1
    root_alive="$(in_pg "SELECT count(*) FROM pg_stat_activity WHERE pid = ${root_pid:-0};" | tr -d '[:space:]')"
    tries=$((tries - 1))
  done

  tries=15
  blocked="$(in_pg "SELECT count(*) FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
                     WHERE c.relname = 'accounts' AND NOT l.granted;" | tr -d '[:space:]')"
  while [ "$tries" -gt 0 ] && [ "${blocked:-1}" != "0" ]; do
    sleep 1
    blocked="$(in_pg "SELECT count(*) FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
                       WHERE c.relname = 'accounts' AND NOT l.granted;" | tr -d '[:space:]')"
    tries=$((tries - 1))
  done

  if [ "${root_alive:-1}" = "0" ] && [ "${blocked:-1}" = "0" ]; then
    pass "lock_chain: the root session is gone and no lock wait remains on accounts"
  else
    fail "lock_chain: root session still connected (${root_alive:-?}) or a lock wait remains on accounts (${blocked:-?}) -- end the root blocker's transaction, not a downstream waiter"
    ok=0
  fi

  if check_answer_key "root_pid" "$(target_for root_pid)"; then
    pass "lock_chain: root_pid answer matches"
  else
    fail "lock_chain: root_pid answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_vacuum_starvation() {
  local ok=1 pinning_pid tries=15 remaining dead_tup

  pinning_pid="$(target_for pinning_pid | sed -n 's/^pinning_pid=//p' | tr -d '[:space:]')"

  remaining="$(in_pg "SELECT count(*) FROM pg_stat_activity WHERE pid = ${pinning_pid:-0};" | tr -d '[:space:]')"
  while [ "$tries" -gt 0 ] && [ "${remaining:-1}" != "0" ]; do
    sleep 1
    remaining="$(in_pg "SELECT count(*) FROM pg_stat_activity WHERE pid = ${pinning_pid:-0};" | tr -d '[:space:]')"
    tries=$((tries - 1))
  done
  if [ "${remaining:-1}" != "0" ]; then
    fail "vacuum_starvation: the pinning session is still open -- end (or kill) its transaction first"
    ok=0
  else
    pass "vacuum_starvation: the pinning session is gone"
    in_pg "VACUUM (VERBOSE) refunds;" >/dev/null 2>&1 || true
    dead_tup="$(in_pg "SELECT n_dead_tup FROM pg_stat_user_tables WHERE relname = 'refunds';" | tr -d '[:space:]')"
    if [ -n "$dead_tup" ] && [ "$dead_tup" -lt 1000 ] 2>/dev/null; then
      pass "vacuum_starvation: refunds.n_dead_tup is ${dead_tup} after a fresh VACUUM (under 1000)"
    else
      fail "vacuum_starvation: refunds.n_dead_tup is ${dead_tup:-unknown} after a fresh VACUUM -- still not reclaiming"
      ok=0
    fi
  fi

  if check_answer_key "pinning_pid" "$(target_for pinning_pid)"; then
    pass "vacuum_starvation: pinning_pid answer matches"
  else
    fail "vacuum_starvation: pinning_pid answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_mongo_regex() {
  local ok=1 query_js result stage examined returned

  # Read and run the LEARNER'S OWN repaired query from ws, never a
  # hardcoded stand-in -- otherwise a fix that only builds an index on
  # `type` and leaves the original unanchored /charge/ pattern in place
  # would pass this check despite still being unable to use that index at
  # all (an unanchored regex cannot use ANY index, regardless of what
  # index exists -- the point of this pathology, not an incidental
  # detail). A trailing semicolon, if the learner left one on the
  # expression, is stripped so it can be wrapped in a JS expression below.
  query_js="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day08-mongo-regex-query.js 2>/dev/null | sed 's/;[[:space:]]*$//')"

  if [ -z "$query_js" ]; then
    fail "mongo_regex: /tmp/day08-mongo-regex-query.js is missing on ws -- edit it, don't delete it"
    ok=0
  else
    result="$(in_mongo "
      const r = (${query_js}).explain('executionStats');
      print(JSON.stringify(r.queryPlanner.winningPlan).includes('IXSCAN') ? 'IXSCAN' : 'NO_IXSCAN');
      print(r.executionStats.totalDocsExamined);
      print(r.executionStats.nReturned);
    " 2>/dev/null || true)"
    stage="$(echo "$result" | sed -n '1p' | tr -d '[:space:]')"
    examined="$(echo "$result" | sed -n '2p' | tr -d '[:space:]')"
    returned="$(echo "$result" | sed -n '3p' | tr -d '[:space:]')"

    if [ "$stage" = "IXSCAN" ]; then
      pass "mongo_regex: the repaired query in day08-mongo-regex-query.js now uses an IXSCAN"
    else
      fail "mongo_regex: the query in day08-mongo-regex-query.js still has no IXSCAN -- still collection-scanning (an unanchored regex can't use an index no matter which one exists -- check whether the pattern itself is still unanchored)"
      ok=0
    fi

    if [ -n "$returned" ] && [ "$returned" -gt 0 ] 2>/dev/null && \
       awk -v e="$examined" -v n="$returned" 'BEGIN{exit !(e/n<=2)}'; then
      pass "mongo_regex: totalDocsExamined/nReturned = ${examined}/${returned}, at or under 2"
    else
      fail "mongo_regex: totalDocsExamined/nReturned = ${examined:-?}/${returned:-0} -- over 2, or no rows returned"; ok=0
    fi
  fi

  # regex_reason is free text, structurally identical to Day 7's
  # hot_shard_reason -- graded the same way Day 7 grades that field
  # (labs/day07/verify.sh), on a case-insensitive substring, not an exact
  # match against one specific wording. "not anchored", "the pattern is
  # unanchored", and "no prefix anchor" all name the same mechanism and
  # all pass.
  local regex_reason_raw regex_reason_lc
  regex_reason_raw="$(grep -i '^regex_reason=' <<<"$ORIGINAL_ANSWER" | tail -n1 | cut -d= -f2-)"
  regex_reason_lc="$(printf '%s' "$regex_reason_raw" | tr '[:upper:]' '[:lower:]')"
  if [ -n "$regex_reason_raw" ] && printf '%s' "$regex_reason_lc" | grep -qE 'anchor'; then
    pass "mongo_regex: regex_reason names the anchoring problem"
  else
    fail "mongo_regex: regex_reason does not name the anchoring problem -- name WHY the original pattern couldn't use an index (it isn't anchored to the start of the string), not which field it filtered on"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_innodb_deadlock() {
  local ok=1 a_content b_content attempt out_a out_b pid_a pid_b deadlock_seen=""
  a_content="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day08-transfer-a.sql 2>/dev/null || true)"
  b_content="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day08-transfer-b.sql 2>/dev/null || true)"

  if [ -z "$a_content" ] || [ -z "$b_content" ]; then
    fail "innodb_deadlock: /tmp/day08-transfer-a.sql or -b.sql is missing on ws -- edit them, don't delete them"
    ok=0
  else
    for attempt in 1 2 3 4 5; do
      out_a="$(mktemp)"; out_b="$(mktemp)"
      docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day08-transfer-a.sql | \
        docker compose -p "$COMPOSE_PROJECT" exec -T my mysql -u dbm -pdbmastery payments >"$out_a" 2>&1 &
      pid_a=$!
      docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/day08-transfer-b.sql | \
        docker compose -p "$COMPOSE_PROJECT" exec -T my mysql -u dbm -pdbmastery payments >"$out_b" 2>&1 &
      pid_b=$!
      wait "$pid_a" || true
      wait "$pid_b" || true
      if grep -qi 'deadlock' "$out_a" "$out_b" 2>/dev/null; then
        deadlock_seen=1
      fi
      rm -f "$out_a" "$out_b"
    done

    if [ -n "$deadlock_seen" ]; then
      fail "innodb_deadlock: replaying the two scripts concurrently still deadlocks at least once in 5 attempts -- their update order is still inconsistent"
      ok=0
    else
      pass "innodb_deadlock: 5 concurrent replays of the two scripts completed with no deadlock"
    fi
  fi

  if check_answer_key "deadlock_accounts" "$(target_for deadlock_accounts)"; then
    pass "innodb_deadlock: deadlock_accounts answer matches"
  else
    fail "innodb_deadlock: deadlock_accounts answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_bloated_index() {
  local ok=1 density dead_pct
  in_pg "CREATE EXTENSION IF NOT EXISTS pgstattuple;" >/dev/null 2>&1 || true

  density="$(in_pg "SELECT round(avg_leaf_density::numeric, 1) FROM pgstatindex('idx_gauntlet_disputes_status');" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$density" ] && awk -v d="$density" 'BEGIN{exit !(d>=80)}'; then
    pass "bloated_index: idx_gauntlet_disputes_status avg_leaf_density is ${density}% (at or above 80%)"
  else
    fail "bloated_index: idx_gauntlet_disputes_status avg_leaf_density is ${density:-unknown}% -- still bloated"
    ok=0
  fi

  dead_pct="$(in_pg "SELECT round(dead_tuple_percent::numeric, 1) FROM pgstattuple('disputes');" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$dead_pct" ] && awk -v d="$dead_pct" 'BEGIN{exit !(d<10)}'; then
    pass "bloated_index: disputes itself is clean (dead_tuple_percent ${dead_pct}%)"
  else
    fail "bloated_index: disputes shows ${dead_pct:-unknown}% dead tuples -- unexpected, the table should already read as clean"
    ok=0
  fi

  if check_answer_key "bloated_index" "$(target_for bloated_index)"; then
    pass "bloated_index: bloated_index answer matches"
  else
    fail "bloated_index: bloated_index answer does not match"; ok=0
  fi
  [ "$ok" -eq 1 ]
}

check_n_plus_one() {
  local ok=1 row calls rowsc ratio expected_n1 learner_n1 within

  # Assert the OUTCOME -- some ledger_entries/payment_id query now
  # achieves a high rows-per-call ratio -- not one specific syntax for
  # getting there. `= ANY(...)`, `IN (...)`, a VALUES-list join, and a
  # joined temp table are all equally valid batched replacements for the
  # per-row loop; picking the BEST ratio among every query touching both
  # words, rather than requiring a literal fragment, finds whichever one
  # the learner actually used. The original per-row queryid itself also
  # matches this filter, at a ratio near 1 -- exactly why an unfixed
  # incident correctly fails this check instead of vacuously passing.
  row="$(in_pg "SELECT calls, rows FROM pg_stat_statements
                 WHERE query ILIKE '%ledger_entries%'
                   AND query ILIKE '%payment_id%'
                 ORDER BY (rows::numeric / GREATEST(calls, 1)) DESC LIMIT 1;")"
  calls="$(echo "$row" | awk -F'|' '{print $1}' | tr -d '[:space:]')"
  rowsc="$(echo "$row" | awk -F'|' '{print $2}' | tr -d '[:space:]')"

  if [ -n "$calls" ] && [ -n "$rowsc" ] && [ "$calls" -gt 0 ] 2>/dev/null && \
     awk -v r="$rowsc" -v c="$calls" 'BEGIN{exit !(r/c>=20)}'; then
    ratio="$(awk -v r="$rowsc" -v c="$calls" 'BEGIN{printf "%.1f", r/c}')"
    pass "n_plus_one: found a batched ledger_entries/payment_id query (calls=${calls}, rows=${rowsc}, rows/call=${ratio})"
  else
    fail "n_plus_one: the best rows-per-call ratio among ledger_entries/payment_id queries in pg_stat_statements is still low -- no batched replacement for the per-row loop found yet"
    ok=0
  fi

  # n1_calls is a moving target by construction: pg_stat_statements.calls
  # for the offending queryid keeps incrementing with any further
  # execution of that same normalised shape, including the learner's own
  # diagnostic EXPLAINs while investigating it. An exact match would
  # penalise a learner who read the counter honestly after doing exactly
  # the diagnostic work this lab wants -- accept anything at or above the
  # value gauntlet.sh recorded, within a generous margin above it, rather
  # than requiring an exact, already-stale figure.
  expected_n1="$(target_for n1_calls | sed -n 's/^n1_calls=//p' | tr -d '[:space:]')"
  learner_n1="$(grep -i '^n1_calls=' <<<"$ORIGINAL_ANSWER" | tail -n1 | sed -n 's/^[Nn]1_[Cc]alls=//p' | tr -d '[:space:]')"

  if [ -z "$expected_n1" ]; then
    fail "n_plus_one: no stashed target for key 'n1_calls' -- was this incident actually applied by gauntlet.sh?"
    ok=0
  elif [ -z "$learner_n1" ] || ! [[ "$learner_n1" =~ ^[0-9]+$ ]]; then
    fail "n_plus_one: n1_calls in /tmp/answer is missing or not a plain integer"
    ok=0
  else
    within="$(awk -v e="$expected_n1" -v l="$learner_n1" \
      'BEGIN{slack = (e*0.2 > 30) ? e*0.2 : 30; print (l >= e && l <= e + slack) ? "yes" : "no"}')"
    if [ "$within" = "yes" ]; then
      pass "n_plus_one: n1_calls is consistent with the value pg_stat_statements showed for this incident (allowing for further diagnostic calls since)"
    else
      fail "n_plus_one: n1_calls does not match the offending queryid's call count for this run (read pg_stat_statements.calls again, sorted by total_exec_time)"
      ok=0
    fi
  fi
  [ "$ok" -eq 1 ]
}

# ---------------------------------------------------------------------
# Run every selected incident, independently, in the order it was
# presented as a SYMPTOM line.
# ---------------------------------------------------------------------

mapfile -t SELECTED <<<"$SELECTED_RAW"

SCORE=0
TOTAL=${#SELECTED[@]}
n=0
for name in "${SELECTED[@]}"; do
  [ -z "$name" ] && continue
  n=$((n + 1))
  echo
  echo "== incident ${n}/${TOTAL} =="
  if "check_${name}"; then
    SCORE=$((SCORE + 1))
  fi
done

# The score is the authoritative pass/fail signal, checked explicitly
# here rather than trusted to have propagated correctly through every
# fail() call along the way -- fail() (sourced from common.sh) does set
# FAILED=1 as a side effect in this shell, but a scoring script's exit
# code is exactly the kind of thing that must never depend on an
# assumption holding all the way through every code path above. Below
# 5/5 (or whatever TOTAL is) always leaves FAILED=1, unconditionally.
[ "$SCORE" -eq "$TOTAL" ] || FAILED=1

echo
echo "score: ${SCORE}/${TOTAL}"

start_ts="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/.day08-start 2>/dev/null | tr -d '[:space:]')"
if [ -n "$start_ts" ] && [ "$start_ts" -le "$GAUNTLET_START_EPOCH" ] 2>/dev/null; then
  elapsed=$((GAUNTLET_START_EPOCH - start_ts))
  echo "elapsed since gauntlet.sh started this run: $((elapsed / 60)) min (target: 90 min -- reported only, does not affect pass/fail)"
fi

exit "${FAILED:-0}"
