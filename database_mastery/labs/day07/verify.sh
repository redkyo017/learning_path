#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Day 7 has no break.sh -- there is no per-run stashed value to compare
# /tmp/answer against, because nothing here is an injected pathology.
# The three deliverables (failover_seconds, top_wait_event,
# hot_shard_reason) live in the learner's own AWS and Atlas accounts, and
# genuinely vary by region, instance class, and the moment the lab was
# run. This script cannot compute the truth the way every other day's
# verify.sh does -- see README.md's "The honest limitation of verify.sh"
# for the full statement. What it can check: that each answer is present,
# well-formed, and in a plausible range; that the stated wait event is a
# real Performance Insights event name; and, by delegating to
# labs/verify-teardown.sh at the end, that teardown genuinely left
# nothing billing. A passing run here is not proof any of the three
# numbers is correct -- it is proof they are present, sane, and that
# nothing is still running.

# Common Performance Insights wait-event names for RDS PostgreSQL 16,
# named the way PostgreSQL 13+ reports them (PG13 renamed several
# pre-13 snake_case LWLock names and reclassified a few events into
# different wait_event_types -- this list intentionally does not mix the
# two eras). Not exhaustive -- AWS adds to this vocabulary over time, and
# this is a curated list of commonly-seen events sourced from PostgreSQL's
# own wait_event documentation, not a guaranteed-complete enumeration.
PI_WAIT_EVENTS=(
  "CPU"
  "IO:DataFileRead"
  "IO:DataFileWrite"
  "IO:DataFilePrefetch"
  "IO:WALWrite"
  "IO:WALSync"
  "IO:WALInitWrite"
  "IO:BufFileRead"
  "IO:BufFileWrite"
  "Lock:transactionid"
  "Lock:relation"
  "Lock:tuple"
  "Lock:page"
  "LWLock:BufferMapping"
  "LWLock:WALWrite"
  "LWLock:LockManager"
  "LWLock:BufferContent"
  "LWLock:BufferIO"
  "LWLock:WALInsert"
  "Client:ClientRead"
  "Client:ClientWrite"
  "Timeout:VacuumDelay"
  "BufferPin:BufferPin"
)

echo "== /tmp/answer on ws =="
answer_raw="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"

get_field() {
  printf '%s\n' "$answer_raw" | grep -i "^$1=" | head -1 | cut -d= -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

failover_seconds="$(get_field failover_seconds)"
top_wait_event="$(get_field top_wait_event)"
hot_shard_reason="$(get_field hot_shard_reason)"

echo
echo "== 1) failover_seconds -- present, numeric, plausible range =="
if [[ "$failover_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  # Use awk for the comparison so a fractional value (e.g. "87.4") is
  # handled correctly rather than failing bash's integer-only [[ ]] test.
  if awk -v v="$failover_seconds" 'BEGIN{exit !(v >= 20 && v <= 600)}'; then
    pass "failover_seconds ($failover_seconds) is numeric and in the plausible 20-600s range"
  else
    fail "failover_seconds ($failover_seconds) is numeric but outside the plausible 20-600s range -- re-check how you measured it (RDS Multi-AZ failovers typically land around 60-120s)"
  fi
else
  fail "failover_seconds is missing or not a plain number (\"$failover_seconds\")"
fi

echo
echo "== 2) top_wait_event -- present, matches a real Performance Insights event name =="
# Case-insensitive, matching hot_shard_reason's own check below -- a
# learner who copies the exact name off their console in whatever case
# the console happens to render it should never fail on capitalization
# alone.
top_wait_event_lc="$(printf '%s' "$top_wait_event" | tr '[:upper:]' '[:lower:]')"
matched=0
if [ -n "$top_wait_event" ]; then
  for evt in "${PI_WAIT_EVENTS[@]}"; do
    evt_lc="$(printf '%s' "$evt" | tr '[:upper:]' '[:lower:]')"
    if [ "$evt_lc" = "$top_wait_event_lc" ]; then
      matched=1
      break
    fi
  done
fi
if [ "$matched" -eq 1 ]; then
  pass "top_wait_event ($top_wait_event) is a real Performance Insights wait-event name"
else
  fail "top_wait_event (\"${top_wait_event:-<empty>}\") does not match a known Performance Insights wait-event name -- check the exact spelling against the RDS console (e.g. CPU, IO:DataFileRead, Lock:transactionid, LWLock:BufferMapping, Client:ClientRead)"
fi

echo
echo "== 3) hot_shard_reason -- present, names monotonicity as the mechanism =="
reason_lc="$(printf '%s' "$hot_shard_reason" | tr '[:upper:]' '[:lower:]')"
if [ -n "$hot_shard_reason" ] && printf '%s' "$reason_lc" | grep -qE 'monoton'; then
  pass "hot_shard_reason mentions monotonicity"
else
  fail "hot_shard_reason (\"${hot_shard_reason:-<empty>}\") does not mention monotonicity -- a correct answer names the mechanism (every write lands on the newest chunk because the key never revisits an old range), not only \"the key is bad\" or \"cardinality is too low\" (payment_events.ts has high cardinality; that isn't what makes it a bad shard key)"
fi

echo
echo "== 4) teardown -- delegate to labs/verify-teardown.sh =="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEARDOWN_SCRIPT="$(cd "$SCRIPT_DIR/.." && pwd)/verify-teardown.sh"
teardown_status=0
bash "$TEARDOWN_SCRIPT" || teardown_status=$?

# verify-teardown.sh's exit codes are not interchangeable: 0 is a
# genuine clean pass, 1 is a genuine "something is still billing," and 2
# means it could not even check (no AWS CLI, or no configured
# credentials) -- a caller that collapsed 1 and 2 into the same "FAIL"
# would hide the difference between "you left something running" and "we
# never actually looked." Preserve that distinction in this script's own
# exit status rather than flattening it through common.sh's binary
# FAILED flag.
case "$teardown_status" in
  0)
    pass "labs/verify-teardown.sh reports a clean teardown"
    ;;
  2)
    echo "verify-teardown.sh could not verify teardown at all (exit 2) -- see its output above. Install/configure the AWS CLI and re-run before considering Day 7 closed." >&2
    FAILED=2
    ;;
  *)
    fail "labs/verify-teardown.sh did not report a clean teardown (exit $teardown_status) -- see its output above"
    ;;
esac

echo
exit "${FAILED:-0}"
