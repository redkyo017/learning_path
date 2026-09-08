#!/usr/bin/env bash
set -euo pipefail

# labs/day05/break.sh
#
# Two independent incidents, bundled into one script because a learner
# would see them arrive together in production too.
#
# Incident 1 -- a five-session blocking chain on accounts.account_id = 1
# (merchant 1's account, guaranteed to exist at any SCALE). One root
# session takes a row lock and then sits genuinely idle in transaction --
# a client-side `sleep`, not a server-side pg_sleep(), so pg_stat_activity
# shows the real "idle in transaction" state Day 6 depends on -- for a
# bounded lifetime, so a forgotten lab self-heals instead of wedging the
# stack. Four more sessions queue up behind it, one at a time, against the
# SAME row. The chain that results is genuinely transitive, but not
# because pg_blocking_pids() pre-walks it for you: only the FIRST queued
# session (S1) actually collides with the root's transaction (wait_event
# = transactionid, pg_blocking_pids = {root}); S1 itself then holds a
# heavyweight tuple lock marking "I am next in line," and the remaining
# three queue on THAT lock in arrival order (wait_event = tuple), so each
# one's pg_blocking_pids names a growing prefix of the waiters ahead of
# it -- never the root directly (see content/day05.md's "Read the
# instrument first" section for the full mechanism, and
# content/primers/catalog-field-reference.md, #pg_locks-and-pg_blocking_pids).
# S1 -- the FIRST queued session -- ends up the longest-waiting row in
# pg_stat_activity, and it is a victim of the root, not the root itself.
# Killing it frees nothing the root still holds; the next session in line
# becomes the new longest waiter instead, now itself waiting directly on
# the root. The root's own backend PID is stashed at /tmp/.day05-target
# inside `pg`, written by the root's own session so no second connection
# is ever needed to observe it.
#
# Incident 2 -- write skew, already committed by the time this script
# returns. Two genuinely concurrent withdrawal transactions against a
# second account (merchant 2's -- power-law skew favors low merchant ids,
# so this one is guaranteed to be busy enough to carry a real positive
# balance and real ledger_entries rows to borrow a payment_id from) each
# read the same pre-race derived balance, each insert a NEW debit row the
# other transaction cannot see, and both commit. Neither INSERT conflicts
# with anything at the row level -- the account they jointly overdraw is
# not itself written by either statement. This is exactly the anomaly
# `content/primers/isolation-anomaly-ladder.md#write-skew` describes, and
# it is why the CHECK (balance_minor >= 0) commented into 00-schema.sql
# would not have helped even if it were live.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

LOCK_ACCOUNT=1        # merchant 1's account -- exists at any SCALE >= 1
SKEW_ACCOUNT=2         # merchant 2's account -- see comment above
ROOT_LIFETIME=900      # seconds; bounded so a forgotten lab self-heals,
                       # but sized to comfortably outlast a real
                       # evidence-chain write-up, not to race against it
QUEUE_STAGGER=1        # seconds between each queued session's launch
SKEW_ENTRY_A=9000000000001
SKEW_ENTRY_B=9000000000002

# Idempotency: a learner who lets the root blocker expire mid-diagnosis,
# or who wants to start over for any reason, re-runs this script. Without this,
# the second run's two race() INSERTs would fail outright on the primary
# key (the sentinel entry ids already exist from the first run), the
# bare `wait` below would still return 0 regardless, and break.sh would
# assert a symptom the second run never actually created. Clear both
# incidents' prior residue before building anything new.
echo "== day05: clearing any stale state from a previous run =="
in_pg "DELETE FROM ledger_entries WHERE entry_id IN (${SKEW_ENTRY_A}, ${SKEW_ENTRY_B});" >/dev/null
docker compose -p "${COMPOSE_PROJECT}" exec -T pg sh -c 'rm -f /tmp/.day05-target' >/dev/null 2>&1 || true
# Also clear any still-alive root from an earlier, un-terminated run --
# otherwise a re-run's new root queues up behind the stale one instead of
# acquiring the lock itself, and the confirmation loop below would see
# the STALE session's idle-in-transaction state and wrongly conclude the
# NEW root had landed. This terminates EVERY idle-in-transaction session
# on the payments database, not only ones this script itself started --
# deliberate, not an oversight: this is a single-purpose lab stack with
# one learner and one database, so any idle-in-transaction session found
# here is either this lab's own leftover (the case this exists to handle)
# or a different problem the learner would want surfaced anyway, not
# silently left running underneath a fresh incident.
in_pg "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
       WHERE state = 'idle in transaction' AND datname = 'payments';" >/dev/null

echo "== day05: building the five-session blocking chain on account ${LOCK_ACCOUNT} =="

# Root session. Written to a file first (docker compose exec cannot pipe a
# heredoc into a *detached* exec), then launched detached so break.sh does
# not block on it. \o redirects the query output that follows straight to
# the stash file, from inside this same connection -- the value written is
# this session's own pg_backend_pid(), never printed to the terminal and
# never computed by a second, different connection.
docker compose -p "${COMPOSE_PROJECT}" exec -T pg sh -c 'cat > /tmp/day05-root.sql' <<SQL
\o /tmp/.day05-target
SELECT 'root_blocker=' || pg_backend_pid();
\o
BEGIN;
UPDATE accounts SET created_at = created_at WHERE account_id = ${LOCK_ACCOUNT};
\! sleep ${ROOT_LIFETIME}
COMMIT;
SQL

docker compose -p "${COMPOSE_PROJECT}" exec -d pg \
  psql -U dbm -d payments -tAX -f /tmp/day05-root.sql

# Confirm the root actually landed before queueing anything behind it --
# both that its own connection wrote the stash (proof its SELECT ran),
# and that a genuine idle-in-transaction session now exists (proof its
# UPDATE acquired the row lock and it is sitting in the client-side
# `sleep`, not still connecting). A blind fixed sleep here would let a
# slow-starting root silently produce a chain with no real root to find.
root_confirmed=0
for _ in $(seq 1 20); do
  stash_nonempty="$(docker compose -p "${COMPOSE_PROJECT}" exec -T pg \
    sh -c '[ -s /tmp/.day05-target ] && echo yes || echo no' 2>/dev/null | tr -d '[:space:]')"
  idle_count="$(in_pg "SELECT count(*) FROM pg_stat_activity
                        WHERE state = 'idle in transaction' AND datname = 'payments';" | tr -d '[:space:]')"
  if [ "${stash_nonempty}" = "yes" ] && [ "${idle_count}" -ge 1 ] 2>/dev/null; then
    root_confirmed=1
    break
  fi
  sleep 0.5
done

if [ "${root_confirmed}" -ne 1 ]; then
  echo "day05 break.sh: the root session never confirmed (stash file empty or no \
idle-in-transaction session appeared) -- aborting before queueing anything behind it" >&2
  exit 1
fi

for i in 1 2 3 4; do
  docker compose -p "${COMPOSE_PROJECT}" exec -T pg sh -c "cat > /tmp/day05-s${i}.sql" <<SQL
BEGIN;
UPDATE accounts SET created_at = created_at WHERE account_id = ${LOCK_ACCOUNT};
COMMIT;
SQL
  docker compose -p "${COMPOSE_PROJECT}" exec -d pg \
    psql -U dbm -d payments -tAX -f "/tmp/day05-s${i}.sql"
  sleep "${QUEUE_STAGGER}"
done

echo "== day05: committing a write-skew violation on account ${SKEW_ACCOUNT} =="

# amount_minor already carries its own sign (credits positive, debits
# negative -- labs/stack/seed/README.md's "accounts/ledger invariant"),
# so every balance below is a plain SUM(amount_minor), never a
# direction-based CASE.
currency="$(in_pg "SELECT currency FROM accounts WHERE account_id = ${SKEW_ACCOUNT};" | tr -d '[:space:]')"
payment_id="$(in_pg "SELECT payment_id FROM ledger_entries WHERE account_id = ${SKEW_ACCOUNT} ORDER BY entry_id LIMIT 1;" | tr -d '[:space:]')"
balance="$(in_pg "SELECT COALESCE(SUM(amount_minor), 0)
                   FROM ledger_entries WHERE account_id = ${SKEW_ACCOUNT};" | tr -d '[:space:]')"

if [ -z "${payment_id}" ] || [ -z "${balance}" ] || [ "${balance}" -le 0 ]; then
  echo "day05 break.sh: account ${SKEW_ACCOUNT} has no usable balance or payment_id to race against" >&2
  exit 1
fi

# 70% of the current balance, withdrawn twice, overdraws by 40% -- large
# enough to be unmistakable in the derived-balance check, small enough
# that either withdrawal alone is clearly covered.
withdraw="$(awk -v b="${balance}" 'BEGIN { printf "%d", b * 0.7 }')"

# Two real, separately-connected sessions launched as background shell
# jobs (not detached in the container -- this script waits for both to
# actually commit before it prints the symptom line, because the whole
# point is that the violation is already committed, not a race the
# learner is meant to watch happen). Each reads the balance, then pauses
# for two full seconds before writing -- long enough that ordinary docker
# exec startup jitter cannot prevent both reads from landing before either
# write, so the interleaving below is not a matter of luck.
race() {
  local entry_id="$1"
  docker compose -p "${COMPOSE_PROJECT}" exec -T pg \
    psql -U dbm -d payments -tAX <<SQL
BEGIN;
SELECT COALESCE(SUM(amount_minor), 0)
  FROM ledger_entries WHERE account_id = ${SKEW_ACCOUNT};
SELECT pg_sleep(2);
INSERT INTO ledger_entries (entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, created_at)
  VALUES (${entry_id}, ${payment_id}, ${SKEW_ACCOUNT}, 'D', -${withdraw}, '${currency}', current_date, now());
COMMIT;
SQL
}

race "${SKEW_ENTRY_A}" &
pid_race_a=$!
race "${SKEW_ENTRY_B}" &
pid_race_b=$!

wait "${pid_race_a}"
wait "${pid_race_b}"

# Confirm the violation actually landed -- a bare, argument-less `wait`
# above would return 0 unconditionally regardless of whether either race
# actually committed, so this is a real, independent confirmation rather
# than trusting the exit status of a `wait` that could not have failed
# meaningfully in the first place.
final_balance="$(in_pg "SELECT COALESCE(SUM(amount_minor), 0)
                         FROM ledger_entries WHERE account_id = ${SKEW_ACCOUNT};" | tr -d '[:space:]')"

if [ -z "${final_balance}" ] || [ "${final_balance}" -ge 0 ]; then
  echo "day05 break.sh: the write-skew race did not leave account ${SKEW_ACCOUNT} \
negative (derived balance: ${final_balance:-unknown}) -- both withdrawals may not \
have overlapped; re-run this script" >&2
  exit 1
fi

say_symptom "settlement writes are timing out, and one account's derived balance has gone negative."
