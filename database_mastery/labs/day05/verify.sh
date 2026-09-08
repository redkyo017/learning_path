#!/usr/bin/env bash
set -euo pipefail

# labs/day05/verify.sh
#
# Four independent checks. The first proves the learner's diagnosis named
# the actual root blocker, not the longest-waiting victim. The second
# proves the blocking chain is genuinely resolved -- no active session
# still waiting on a lock, and no idle-in-transaction session old enough
# to still be pinning the vacuum horizon. The third proves the specific
# write-skew damage was repaired, reading account 2's DERIVED balance
# from ledger_entries -- never accounts.balance_minor, which is only ever
# a cache and was never updated by break.sh's race in the first place --
# and it is scoped to that one account deliberately: under this schema's
# real sign convention, most customer accounts carry a negative ledger
# sum by construction (see the check's own comment), so "no account
# anywhere is negative" is not a property this dataset ever has. The
# fourth proves a real defence exists by actually racing it: harness.sh,
# against the learner's own labs/day05/answers/withdraw.sql, which must
# exist before this check can even attempt to run it.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "== check 1: root blocker diagnosis (/tmp/answer inside ws) =="
if answer_check /tmp/.day05-target pg; then
  pass "root_blocker= matches the session break.sh actually made the root"
else
  fail "root_blocker= in /tmp/answer (inside the ws container) does not match. \
Call pg_blocking_pids() on the longest-waiting session, then on whatever it \
names, and again, until it names an empty set -- that session is the root, \
and it is not the session that has been waiting the longest."
fi

echo
echo "== check 2: the blocking chain is genuinely resolved =="
lock_waiters="$(in_pg "SELECT count(*) FROM pg_stat_activity
                        WHERE datname = 'payments'
                          AND wait_event_type = 'Lock' AND state = 'active';" | tr -d '[:space:]')"
old_idle="$(in_pg "SELECT count(*) FROM pg_stat_activity
                    WHERE datname = 'payments'
                      AND state = 'idle in transaction'
                      AND now() - xact_start > interval '60 seconds';" | tr -d '[:space:]')"

if [ "${lock_waiters}" = "0" ] && [ "${old_idle}" = "0" ]; then
  pass "no session is actively waiting on a lock, and no idle-in-transaction \
session is older than 60 seconds"
else
  fail "the chain is not resolved: ${lock_waiters} session(s) actively waiting \
on a lock, ${old_idle} idle-in-transaction session(s) older than 60 seconds. \
Terminate the root blocker with pg_terminate_backend(pid), then re-check."
fi

echo
echo "== check 3: account 2's DERIVED balance is no longer negative =="
# Computed fresh from ledger_entries every time -- accounts.balance_minor
# is a cache seeded consistent at load time and never touched by this
# lab's injected write-skew race, so reading it here would prove nothing.
# amount_minor already carries its own sign (credits positive, debits
# negative -- labs/stack/seed/README.md's "accounts/ledger invariant"),
# so the derived balance is a plain SUM(amount_minor), never a
# direction-based CASE.
#
# This check is deliberately scoped to account 2 (merchant 2), the one
# break.sh actually drove negative -- NOT a scan across every account.
# "No account's derived balance is ever negative" is not a true property
# of this seeded ledger under the correct sign convention: customer
# accounts carry only debit legs against their payments (amount_minor
# stored negative, per the same invariant), so every customer account
# with at least one payment has a strictly negative ledger sum from the
# moment the stack is seeded -- their solvency lives entirely in
# accounts.balance_minor's seeded opening-balance constant
# (labs/stack/seed/README.md, "The accounts/ledger invariant"), which
# this lab's derived-balance instrument deliberately never reads. What
# this check actually asserts is narrower, and true: the ONE account
# this lab's incident touched has been repaired.
account_2_balance="$(in_pg "SELECT COALESCE(SUM(amount_minor), 0)
                             FROM ledger_entries WHERE account_id = 2;" | tr -d '[:space:]')"

if [ -n "${account_2_balance}" ] && [ "${account_2_balance}" -ge 0 ]; then
  pass "account 2's ledger-derived balance is no longer negative"
else
  fail "account 2's DERIVED balance (summed from ledger_entries) is still \
negative. break.sh's write-skew race left extra debit rows behind on this \
account -- find them and correct the ledger, not accounts.balance_minor."
fi

echo
echo "== check 4: harness.sh passes against answers/withdraw.sql =="
ANSWER_SQL="${LAB_DIR}/answers/withdraw.sql"
if [ ! -f "${ANSWER_SQL}" ]; then
  fail "labs/day05/answers/withdraw.sql does not exist yet -- write your \
withdrawal transaction there first (see README.md for the psql variables \
it is invoked with: :account_id, :payment_id, :withdraw_amount, :entry_id)."
else
  if bash "${LAB_DIR}/harness.sh" "${ANSWER_SQL}"; then
    pass "harness.sh: every round held all three invariants against answers/withdraw.sql"
  else
    fail "harness.sh reported a violation against answers/withdraw.sql -- see \
its per-round output above for exactly which round broke and why."
  fi
fi

echo
exit "${FAILED:-0}"
