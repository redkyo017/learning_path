#!/usr/bin/env bash
set -euo pipefail

# labs/day05/harness.sh
#
# The two-session race runner for the write-skew defence. Kept
# parameterised (every constant below is overridable by environment
# variable, and the transaction-body path is a plain argument) so it is
# not hardwired to this lab's specific account/payment ids -- reusable by
# name, not because anything else in this path currently calls it.
#
# Interface: the transaction body at $1 (default:
# labs/day05/answers/withdraw.sql) is run once per session per round, with
# four variables bound via psql's `-v`:
#   :account_id        the funded test account
#   :payment_id         a valid payment_id to satisfy ledger_entries' FK
#   :withdraw_amount    the amount to withdraw, in minor units, as a
#                        POSITIVE magnitude -- amount_minor is signed in
#                        this schema (credits positive, debits negative),
#                        so the debit row this session inserts must use
#                        -:withdraw_amount, not :withdraw_amount
#   :entry_id           a fresh, session-specific ledger_entries.entry_id
#         this session should INSERT if (and only if) the withdrawal is
#         covered by the account's TRUE, ledger-derived balance
#         (SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries
#         WHERE account_id = :account_id).
#
# Each round funds the account for exactly one withdrawal, then runs the
# body in two concurrent sessions. Whether a session actually "succeeded"
# is read back from the ledger itself (did entry_id land?), never from the
# client's exit code alone -- a correct defence is free to reject the
# losing side with a plain ROLLBACK, no error at all, which would look
# identical to success if success were judged by exit code.
#
# A session is retried, up to MAX_RETRIES times, ONLY when it fails with a
# serialization failure or a deadlock -- the two errors that are, by
# definition, the caller's obligation to retry rather than a defect in the
# transaction body. Any other non-zero result (a materialised constraint's
# own raised exception, an explicit ROLLBACK after finding insufficient
# funds, ...) is accepted as a legitimate single-shot result for the round.
#
# Rendezvous barrier: launching two `docker compose exec` processes with a
# bare `&` is NOT enough synchronisation on its own. Compose CLI startup
# is hundreds of milliseconds with hundreds of milliseconds of variance;
# the transaction body itself typically runs in single-digit milliseconds.
# Left to plain OS scheduling, the two sessions' critical sections would
# rarely land inside the same window at all, and an undefended withdrawal
# body would sail through 50/50 rounds having never once been tested
# against a genuine concurrent attempt. Every round therefore computes a
# single future timestamp (this database's own clock, not the host's) and
# hands it, identically, to both sessions; each session's very first
# statement is a `pg_sleep` that blocks until that shared instant, so both
# sessions enter the transaction body within milliseconds of each other
# regardless of how much docker-exec jitter came before it. That barrier
# statement runs and completes BEFORE either session's own `BEGIN`, so it
# is never part of either session's transaction.
#
# Contention assertion: the barrier makes overlap likely, not proven.
# Every round therefore also records concrete evidence that the two
# sessions actually contended -- either session retried on a
# serialization failure/deadlock (a direct, unambiguous signal, but one
# that only fires for SERIALIZABLE/deadlock-shaped defences), OR the two
# sessions' own [DAY05_START, DAY05_END] wall-clock intervals -- read via
# clock_timestamp() on each session's own connection, immune to
# docker-exec jitter since both are read after the barrier already
# resolved -- actually overlap in time. A session that aborts via a
# raised exception (a blessed defence: "a materialised constraint's own
# raised exception" above) never reaches its DAY05_END marker, because
# ON_ERROR_STOP halts the script the instant the error fires -- that
# session's interval is then treated as the degenerate point [start,
# start] rather than discarded, so its evidence is still counted: B
# having entered its body while A was inside its own is a genuine
# overlap even though B's own end was never measured. Overlap, not
# duration, is the property that matters here, because a temporary index
# (built below, dropped at the end) makes every read fast regardless of
# whether the two sessions actually raced -- "this session took a while"
# would prove nothing either way, which is exactly why it is not what is
# measured. If NONE of the ROUNDS rounds shows either kind of evidence,
# the run fails outright, even if every round otherwise held the
# invariants below -- a pass with no evidence of contention proves
# nothing about the defence under test, and this script refuses to call
# that PASS.
#
# Three properties are asserted every round: exactly one session's
# entry_id lands (not zero -- a no-op body that never writes anything
# would otherwise sail through on an unchanged, non-negative balance --
# and not both), and the derived balance never goes negative. Any
# violation -- of these three, or of the contention requirement above --
# fails the whole run, with full per-round output so the learner can see
# exactly which round (or which absence) broke it.
#
# Temporary index: every round does three full passes of ledger_entries
# (the fixture DELETE, both sessions' own balance reads, the post-round
# SUM) against a table with no index beyond its primary key in the
# shipped schema -- a sequential scan of a 10M-row table each time, which
# would put a full 50-round run at 25-30 minutes. None of this lab's
# lessons depend on that scan being slow (break.sh's write-skew window is
# gated by an explicit pg_sleep, not by scan latency), so this script
# builds a plain index on ledger_entries(account_id) once, up front, and
# drops it on exit via `trap` -- including on an interrupted run -- so it
# never leaks into the rest of the stack.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITHDRAW_SQL="${1:-${LAB_DIR}/answers/withdraw.sql}"

ROUNDS="${ROUNDS:-50}"
TEST_ACCOUNT_ID="${TEST_ACCOUNT_ID:-999999999}"
TEST_PAYMENT_ID="${TEST_PAYMENT_ID:-999999999}"
FUND_AMOUNT="${FUND_AMOUNT:-500000}"
WITHDRAW_AMOUNT="${WITHDRAW_AMOUNT:-500000}"
MAX_RETRIES="${MAX_RETRIES:-5}"
BARRIER_LEAD_SECONDS="${BARRIER_LEAD_SECONDS:-3}"

if [ ! -f "${WITHDRAW_SQL}" ]; then
  echo "harness.sh: no transaction body found at ${WITHDRAW_SQL}" >&2
  echo "Write your withdrawal transaction there first -- see README.md." >&2
  exit 1
fi

echo "== harness: fixture setup =="

merchant_id="$(in_pg "SELECT merchant_id FROM merchants ORDER BY merchant_id LIMIT 1;" | tr -d '[:space:]')"
customer_id="$(in_pg "SELECT customer_id FROM customers ORDER BY customer_id LIMIT 1;" | tr -d '[:space:]')"
payment_method_id="$(in_pg "SELECT payment_method_id FROM payment_methods ORDER BY payment_method_id LIMIT 1;" | tr -d '[:space:]')"

in_pg "INSERT INTO accounts (account_id, owner_type, owner_id, currency, balance_minor, created_at)
       VALUES (${TEST_ACCOUNT_ID}, 'test', 0, 'USD', 0, now())
       ON CONFLICT (account_id) DO NOTHING;" >/dev/null

in_pg "INSERT INTO payments (payment_id, merchant_id, customer_id, payment_method_id,
         amount_minor, currency, status, created_at, description)
       VALUES (${TEST_PAYMENT_ID}, ${merchant_id}, ${customer_id}, ${payment_method_id},
         ${WITHDRAW_AMOUNT}, 'USD', 'captured', now(), 'day05 harness fixture')
       ON CONFLICT (payment_id) DO NOTHING;" >/dev/null

# Build cost is a one-off against the 10M-row table; every one of the
# three per-round scans this file runs becomes an index lookup instead
# of a sequential scan from here on. The trap fires on any exit path --
# normal completion, an explicit `exit 1` above, or an interrupt -- so a
# killed run does not leave this behind on the shared stack.
HARNESS_INDEX="day05_harness_ledger_account_idx"
echo "== harness: building a temporary index on ledger_entries(account_id) =="
in_pg "CREATE INDEX IF NOT EXISTS ${HARNESS_INDEX} ON ledger_entries (account_id);" >/dev/null
cleanup_harness_index() {
  in_pg "DROP INDEX IF EXISTS ${HARNESS_INDEX};" >/dev/null 2>&1 || true
}
trap cleanup_harness_index EXIT

# run_session executes the learner's transaction body once per attempt,
# retrying only on a serialization failure or a deadlock. Every attempt is
# preceded by the shared rendezvous barrier and bracketed by two marker
# SELECTs (DAY05_START=<epoch>, DAY05_END=<epoch>) run on the SAME
# connection, immediately before and after the body -- these give the
# caller each session's own wall-clock interval, immune to docker-exec
# startup jitter since both are read after the barrier already resolved.
# It prints every attempt's raw psql output to its own stdout, followed by
# one summary line (DAY05_SUMMARY start=<epoch> end=<epoch> duration=<s>
# retried=<0|1>) reflecting the attempt that actually decided the result.
# Its own exit status is 0 if that final attempt exited cleanly, 1
# otherwise -- callers determine TRUE success separately, by checking
# whether entry_id actually landed.
run_session() {
  local entry_id="$1" barrier_ts="$2" attempt=1 out rc retried=0 t_start t_end duration

  while :; do
    if out="$( { printf "SELECT pg_sleep(GREATEST(0, EXTRACT(epoch FROM (TIMESTAMPTZ '%s' - clock_timestamp()))));\n" "${barrier_ts}"
                 printf "SELECT 'DAY05_START=' || extract(epoch from clock_timestamp());\n"
                 cat "${WITHDRAW_SQL}"
                 printf "SELECT 'DAY05_END=' || extract(epoch from clock_timestamp());\n"
               } | docker compose -p "${COMPOSE_PROJECT}" exec -T pg \
                     psql -U dbm -d payments -v ON_ERROR_STOP=1 -tAX \
                       -v account_id="${TEST_ACCOUNT_ID}" \
                       -v payment_id="${TEST_PAYMENT_ID}" \
                       -v withdraw_amount="${WITHDRAW_AMOUNT}" \
                       -v entry_id="${entry_id}" \
                       2>&1 )"; then
      rc=0
    else
      rc=$?
    fi

    printf 'attempt %d (rc=%d):\n%s\n' "${attempt}" "${rc}" "${out}"

    if [ "${rc}" -ne 0 ] && [ "${attempt}" -lt "${MAX_RETRIES}" ] \
        && printf '%s' "${out}" | grep -qiE 'could not serialize access|deadlock detected'; then
      retried=1
      attempt=$((attempt + 1))
      continue
    fi

    t_start="$(printf '%s\n' "${out}" | grep -o 'DAY05_START=[0-9.]*' | head -1 | cut -d= -f2)"
    t_end="$(printf '%s\n' "${out}" | grep -o 'DAY05_END=[0-9.]*' | tail -1 | cut -d= -f2)"
    if [ -n "${t_start}" ] && [ -n "${t_end}" ]; then
      duration="$(awk -v a="${t_start}" -v b="${t_end}" 'BEGIN { printf "%.3f", b - a }')"
    else
      # A hard SQL error (e.g. an uncaught serialization failure past
      # MAX_RETRIES) stops ON_ERROR_STOP before the DAY05_END marker ever
      # runs -- duration/end being empty here is not "no contention," it
      # only means this attempt supplies no interval to overlap-check;
      # retried=1 already covers this case as its own independent signal.
      duration="0"
    fi
    printf 'DAY05_SUMMARY start=%s end=%s duration=%s retried=%d\n' "${t_start:-}" "${t_end:-}" "${duration}" "${retried}"

    [ "${rc}" -eq 0 ]
    return $?
  done
}

echo "== harness: racing ${WITHDRAW_SQL} for ${ROUNDS} rounds =="

pass_count=0
contention_seen=0
for round in $(seq 1 "${ROUNDS}"); do
  fund_id=$((900000000000 + round * 10))
  a_id=$((fund_id + 1))
  b_id=$((fund_id + 2))

  # Fund the account for exactly one withdrawal, and nothing else --
  # clear every prior round's rows first so each round starts clean.
  # amount_minor already carries its own sign (credits positive, debits
  # negative), so the credit here is a plain positive amount_minor and
  # every balance check below is a plain SUM(amount_minor).
  in_pg "DELETE FROM ledger_entries WHERE account_id = ${TEST_ACCOUNT_ID};" >/dev/null
  in_pg "INSERT INTO ledger_entries (entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, created_at)
         VALUES (${fund_id}, ${TEST_PAYMENT_ID}, ${TEST_ACCOUNT_ID}, 'C', ${FUND_AMOUNT}, 'USD', current_date, now());" >/dev/null

  # One shared future instant, read from Postgres's own clock so host/
  # container clock skew never enters into it -- both sessions wait for
  # this exact timestamp before touching the transaction body.
  #
  # THE TRAP: a plain ::text cast of a timestamptz under ISO DateStyle
  # produces "2026-09-08 08:14:02.881211+00" -- a SPACE between the date
  # and time, not only whitespace at the edges. `tr -d '[:space:]'` (the
  # obvious way to strip psql's tuples-only output) deletes that internal
  # space too, collapsing it to "2026-09-0808:14:02.881211+00" --
  # PostgreSQL's date/time parser then reads a single date token
  # "2026-09-0808" (day 808) and raises "date/time field value out of
  # range" on every single round. to_char with an explicit 'T' separator
  # (and no other whitespace anywhere in the format) makes stripping ALL
  # whitespace safe again, and stays valid, unambiguous ISO 8601 that
  # `TIMESTAMPTZ '...'` parses identically.
  barrier_ts="$(in_pg "SELECT to_char(clock_timestamp() + interval '${BARRIER_LEAD_SECONDS} seconds', 'YYYY-MM-DD\"T\"HH24:MI:SS.USOF');" | tr -d '[:space:]')"

  out_a="$(mktemp)"
  out_b="$(mktemp)"

  ( run_session "${a_id}" "${barrier_ts}" >"${out_a}" 2>&1 ) &
  pid_a=$!
  ( run_session "${b_id}" "${barrier_ts}" >"${out_b}" 2>&1 ) &
  pid_b=$!

  rc_a=0
  wait "${pid_a}" || rc_a=$?
  rc_b=0
  wait "${pid_b}" || rc_b=$?

  a_committed="$(in_pg "SELECT count(*) FROM ledger_entries WHERE entry_id = ${a_id};" | tr -d '[:space:]')"
  b_committed="$(in_pg "SELECT count(*) FROM ledger_entries WHERE entry_id = ${b_id};" | tr -d '[:space:]')"
  balance="$(in_pg "SELECT COALESCE(SUM(amount_minor), 0)
                     FROM ledger_entries WHERE account_id = ${TEST_ACCOUNT_ID};" | tr -d '[:space:]')"

  # Isolate the one summary line by its literal prefix first, then parse
  # each named field out of THAT line only -- avoids any chance of a
  # bare "end=" or "duration=" elsewhere in psql's own output (or the
  # learner's) being mistaken for this harness's own markers.
  summary_a="$(grep '^DAY05_SUMMARY ' "${out_a}" | tail -1)"
  start_a="$(printf '%s\n' "${summary_a}" | sed -n 's/.*start=\([^ ]*\).*/\1/p')"
  end_a="$(printf '%s\n' "${summary_a}" | sed -n 's/.*end=\([^ ]*\).*/\1/p')"
  duration_a="$(printf '%s\n' "${summary_a}" | sed -n 's/.*duration=\([^ ]*\).*/\1/p')"
  retried_a="$(printf '%s\n' "${summary_a}" | sed -n 's/.*retried=\([^ ]*\).*/\1/p')"

  summary_b="$(grep '^DAY05_SUMMARY ' "${out_b}" | tail -1)"
  start_b="$(printf '%s\n' "${summary_b}" | sed -n 's/.*start=\([^ ]*\).*/\1/p')"
  end_b="$(printf '%s\n' "${summary_b}" | sed -n 's/.*end=\([^ ]*\).*/\1/p')"
  duration_b="$(printf '%s\n' "${summary_b}" | sed -n 's/.*duration=\([^ ]*\).*/\1/p')"
  retried_b="$(printf '%s\n' "${summary_b}" | sed -n 's/.*retried=\([^ ]*\).*/\1/p')"

  # Contention evidence is either kind, independently: a retried
  # serialization failure/deadlock (direct, but only fires for that
  # technique), or the two sessions' [start, end] wall-clock intervals
  # actually intersecting -- two closed intervals [sa,ea] and [sb,eb]
  # overlap exactly when sa <= eb AND sb <= ea. A session that never
  # reached its DAY05_END marker (a raised-exception defence errors out
  # under ON_ERROR_STOP before that marker runs) has no measured end --
  # treated here as the degenerate point interval [start, start] rather
  # than excluded, since "this session entered its body at this instant"
  # is still genuine evidence, and it is the only evidence available for
  # a session that never got to finish.
  end_a_eff="${end_a:-${start_a:-}}"
  end_b_eff="${end_b:-${start_b:-}}"

  round_contended=0
  if [ "${retried_a:-0}" = "1" ] || [ "${retried_b:-0}" = "1" ]; then
    round_contended=1
  elif [ -n "${start_a:-}" ] && [ -n "${end_a_eff}" ] && [ -n "${start_b:-}" ] && [ -n "${end_b_eff}" ] \
      && awk -v sa="${start_a}" -v ea="${end_a_eff}" -v sb="${start_b}" -v eb="${end_b_eff}" \
             'BEGIN { exit !(sa <= eb && sb <= ea) }'; then
    round_contended=1
  fi
  if [ "${round_contended}" -eq 1 ]; then
    contention_seen=1
  fi

  # Exactly one of the two must actually commit. Two committed is the
  # write-skew case this whole lab is about; zero committed is the case
  # round 1 of this harness could not catch -- a body that never writes
  # anything (a bare SELECT, or an unconditional ROLLBACK) leaves the
  # balance unchanged and non-negative, and would otherwise pass having
  # tested nothing about withdrawing at all.
  committed_sum=$((a_committed + b_committed))
  round_bad=0
  reason=""
  if [ "${committed_sum}" -ne 1 ]; then
    round_bad=1
    if [ "${committed_sum}" -eq 2 ]; then
      reason="both sessions committed a debit in the same round"
    else
      reason="neither session committed a debit -- the round funded exactly one \
withdrawal and nobody took it"
    fi
  elif [ -z "${balance}" ] || [ "${balance}" -lt 0 ]; then
    round_bad=1
    reason="derived balance went negative (${balance})"
  fi

  if [ "${round_bad}" -eq 1 ]; then
    echo
    echo "== ROUND ${round}: FAIL -- ${reason} =="
    echo "session A (entry_id=${a_id}, exit=${rc_a}, committed=${a_committed}, start=${start_a:-?}, end=${end_a:-?}, duration=${duration_a:-?}, retried=${retried_a:-?}):"
    cat "${out_a}"
    echo "session B (entry_id=${b_id}, exit=${rc_b}, committed=${b_committed}, start=${start_b:-?}, end=${end_b:-?}, duration=${duration_b:-?}, retried=${retried_b:-?}):"
    cat "${out_b}"
    echo "derived balance after round: ${balance}"
    echo
    echo "${pass_count} of ${ROUNDS} rounds held the invariant before this one broke it."
    rm -f "${out_a}" "${out_b}"
    exit 1
  fi

  pass_count=$((pass_count + 1))
  echo "round ${round}/${ROUNDS}: ok (A committed=${a_committed} [${start_a:-?},${end_a:-?}], B committed=${b_committed} [${start_b:-?},${end_b:-?}], balance=${balance}, contended=${round_contended})"
  rm -f "${out_a}" "${out_b}"
done

echo

if [ "${contention_seen}" -eq 0 ]; then
  echo "FAIL: the two sessions never actually raced -- this result proves nothing about your defence."
  echo "None of the ${ROUNDS} rounds showed a retried serialization failure/deadlock, or the two sessions' \
[start,end] wall-clock intervals actually overlapping. Check that your transaction body actually reads the \
ledger-derived balance and writes within the transaction the harness runs, rather than outside it."
  exit 1
fi

echo "PASS: ${pass_count}/${ROUNDS} rounds held all three invariants (exactly one session committed, \
balance never negative), and at least one round showed real evidence the two sessions contended."
exit 0
