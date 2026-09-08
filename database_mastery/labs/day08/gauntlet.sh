#!/usr/bin/env bash
set -euo pipefail

# labs/day08/gauntlet.sh
#
# Day 8 has no single break.sh incident -- it has a pool of EIGHT
# pathologies, each a reshaped version of a technique from Days 3-6 (never
# a verbatim repeat: a new query shape, a new join, a new root session, a
# new table). Every run selects FIVE of the eight at random, applies them
# all at once, and prints exactly five SYMPTOM lines -- numbered, with no
# layer named and no hint. Diagnosing which layer each one belongs to is
# the point: the first seven days announced their layer before you opened
# a single file, and production does not.
#
# The eight, and which earlier day each reshapes:
#   missing_index       Day 3 -- composite index, new query shape (two
#                        equality columns plus a sort, no range)
#   stale_stats          Day 4 -- stale-statistics plan flip, a different
#                        join (accounts/ledger_entries, not
#                        merchants/payments)
#   lock_chain            Day 5 -- a three-session blocking chain rooted in
#                        the session that opened FIRST, not the one that's
#                        waited longest
#   vacuum_starvation    Day 6 -- autovacuum starvation from a long-running
#                        transaction, with autovacuum left ON throughout
#   mongo_regex           Day 3/7 -- a MongoDB collection scan from an
#                        unanchored $regex on payment_events.type
#   innodb_deadlock       Day 5 -- an InnoDB deadlock from two transfer
#                        jobs that lock the same two accounts in opposite
#                        order
#   bloated_index         Day 6 -- a bloated INDEX, not a bloated table:
#                        disputes itself vacuums clean; its index doesn't
#   n_plus_one            Day 4 -- an N+1 that is invisible query-by-query
#                        (every call is fast and properly indexed) and
#                        visible only in pg_stat_statements' aggregates
#
# Answers: every selected incident's identifying value is stashed as one
# key=value line in /tmp/.day08-targets inside the `ws` container -- the
# same container the consolidated /tmp/answer lives in, since a five-line
# answer file spread across three engines has no single "relevant
# container" the way every earlier day's one-key answer did. Write all
# five key=value lines (only for the incidents you were actually handed --
# see the SYMPTOM lines and README.md) into /tmp/answer inside ws before
# running verify.sh.
#
# --reset removes every pathology this script can have applied, from all
# eight, regardless of which five a given run selected -- so a learner can
# always get back to a clean baseline before re-rolling.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

ALL_PATHOLOGIES=(missing_index stale_stats lock_chain vacuum_starvation mongo_regex innodb_deadlock bloated_index n_plus_one)

# ---------------------------------------------------------------------
# Small helpers shared by every apply_/reset_/check_ function below.
# ---------------------------------------------------------------------

stash_line() {
  # Appends one key=value line to the shared Day 8 answer stash on ws.
  printf '%s\n' "$1" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat >> /tmp/.day08-targets'
}

record_selected() {
  printf '%s\n' "$1" | docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat >> /tmp/.day08-selected'
}


# ---------------------------------------------------------------------
# 1. missing_index (PostgreSQL) -- a new query shape from Day 3's family:
#    two equality predicates and a sort, no range predicate at all.
# ---------------------------------------------------------------------

apply_missing_index() {
  local ordinal="$1" cust
  in_pg "DROP INDEX IF EXISTS idx_gauntlet_customer_status_created;" >/dev/null
  in_pg "ANALYZE payments;" >/dev/null

  cust="$(in_pg "SELECT customer_id FROM payments
                  WHERE status = 'captured'
                  ORDER BY customer_id
                  OFFSET (SELECT count(*) / 3 FROM payments WHERE status = 'captured')
                  LIMIT 1;" | tr -d '[:space:]')"

  docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/day08-missing-index.sql' <<SQL
SELECT payment_id, amount_minor, created_at
FROM payments
WHERE customer_id = ${cust}
  AND status = 'captured'
ORDER BY created_at DESC
LIMIT 20;
SQL

  stash_line "index_columns=customer_id,status,created_at"
  say_symptom "${ordinal}) a customer's recent-payments lookup, used by the support desk dozens of times an hour, takes several seconds per call."
}

reset_missing_index() {
  in_pg "DROP INDEX IF EXISTS idx_gauntlet_customer_status_created;" >/dev/null 2>&1 || true
  docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -f /tmp/day08-missing-index.sql >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 2. stale_stats (PostgreSQL) -- Day 4's technique, a different join:
#    accounts/ledger_entries instead of merchants/payments.
# ---------------------------------------------------------------------

apply_stale_stats() {
  local ordinal="$1" target plan divergent_node
  in_pg "CREATE INDEX IF NOT EXISTS ix_ledger_entries_account_id ON ledger_entries (account_id);" >/dev/null
  in_pg "ANALYZE ledger_entries;" >/dev/null

  target="$(in_pg "SELECT account_id FROM accounts
                    ORDER BY account_id
                    OFFSET (SELECT count(*) / 4 FROM accounts)
                    LIMIT 1;" | tr -d '[:space:]')"

  in_pg "ALTER TABLE ledger_entries ALTER COLUMN account_id SET (n_distinct = 1);" >/dev/null
  in_pg "ALTER TABLE ledger_entries SET (autovacuum_enabled = false);" >/dev/null

  # Before the bulk UPDATE: save the rows it's about to touch, the same
  # way Day 4's own break.sh saves payments.merchant_id before its
  # analogous bulk UPDATE, into day04_original_merchants -- Days 5-8
  # assume the seeded power-law skew is the real one, not one this lab
  # silently distorts, so the distortion must be reversible.
  # day08_original_ledger_accounts is clearly-named lab scaffolding, not
  # part of the canonical schema; reset_stale_stats restores from it and
  # drops it. IF NOT EXISTS makes a second apply (without a reset in
  # between) safe: the WHERE clause below matches zero rows on a second
  # run (they're already at the target), so the UPDATE becomes a no-op
  # and must not overwrite an already-captured original mapping.
  in_pg "CREATE TABLE IF NOT EXISTS day08_original_ledger_accounts AS
         SELECT entry_id, account_id
         FROM ledger_entries
         WHERE account_id <> ${target}
           AND entry_id % 40 = 0;" >/dev/null

  in_pg "UPDATE ledger_entries
         SET account_id = ${target}
         WHERE account_id <> ${target}
           AND entry_id % 40 = 0;" >/dev/null

  plan="$(in_pg "EXPLAIN (ANALYZE, BUFFERS)
    SELECT a.account_id, l.direction, count(*) AS n, sum(l.amount_minor) AS total_minor
    FROM accounts a
    JOIN ledger_entries l ON l.account_id = a.account_id
    WHERE a.account_id = ${target}
    GROUP BY a.account_id, l.direction;")"

  # Same deepest-divergence finder Day 4 uses: the node with the worst
  # actual/estimate ratio, ties broken toward the deeper (more indented)
  # node, because a parent's divergence is a consequence of its child's.
  read -r -d '' AWK_PROG <<'AWK' || true
{
  line = $0
  n = match(line, /[^ ]/)
  lead = n - 1
  if (lead < 0) lead = 0
  if (!match(line, /rows=[0-9]+/)) next
  est = substr(line, RSTART + 5, RLENGTH - 5) + 0
  idx = index(line, "actual")
  if (idx == 0) next
  tail = substr(line, idx)
  if (!match(tail, /rows=[0-9]+/)) next
  act = substr(tail, RSTART + 5, RLENGTH - 5) + 0
  denom = est
  if (denom == 0) denom = 1
  ratio = act / denom
  if (ratio > best_ratio + 0 || (ratio == best_ratio && lead >= best_lead)) {
    best_ratio = ratio
    best_lead = lead
    best_line = line
  }
}
END {
  node = best_line
  sub(/^ */, "", node)
  sub(/^-> */, "", node)
  sub(/ *\(.*/, "", node)
  sub(/ using .*/, "", node)
  sub(/ on .*/, "", node)
  print node
}
AWK

  divergent_node="$(printf '%s\n' "${plan}" | awk "${AWK_PROG}")"

  stash_line "divergent_node=${divergent_node}"
  say_symptom "${ordinal}) an account ledger statement that used to return in well under a second now takes over a minute, with no schema change and no query change."
}

reset_stale_stats() {
  in_pg "ALTER TABLE ledger_entries RESET (autovacuum_enabled);" >/dev/null 2>&1 || true
  in_pg "ALTER TABLE ledger_entries ALTER COLUMN account_id RESET (n_distinct);" >/dev/null 2>&1 || true
  # Restore the rows the bulk UPDATE reassigned, using the side table
  # saved before touching anything -- not optional cleanup: skipping this
  # leaves the target account's ledger activity distorted for every day
  # after this one. A no-op if the table doesn't exist (nothing to
  # restore, e.g. stale_stats was never applied this session).
  in_pg "UPDATE ledger_entries l
         SET account_id = o.account_id
         FROM day08_original_ledger_accounts o
         WHERE l.entry_id = o.entry_id;" >/dev/null 2>&1 || true
  in_pg "DROP TABLE IF EXISTS day08_original_ledger_accounts;" >/dev/null 2>&1 || true
  in_pg "DROP INDEX IF EXISTS ix_ledger_entries_account_id;" >/dev/null 2>&1 || true
  in_pg "ANALYZE ledger_entries;" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 3. lock_chain (PostgreSQL) -- three sessions, root NOT the longest
#    waiter. A locks acct_lo and holds (genuinely idle in transaction, via
#    a client-side `\! sleep`, not a server-side pg_sleep() -- the same
#    technique Day 5's break.sh uses, and for the same reason: a session
#    running pg_sleep() shows as `active`, not `idle in transaction`, and
#    the state Day 6 and STRATEGY.md's MVCC illustration both depend on
#    is the latter). B locks acct_hi, then blocks on A trying acct_lo. C
#    then blocks on B trying acct_hi. Root = A -- the session that has
#    waited on nothing at all, not the one pg_stat_activity shows as
#    having waited longest.
# ---------------------------------------------------------------------

apply_lock_chain() {
  local ordinal="$1" pair acct_lo acct_hi root_pid

  pair="$(in_pg "SELECT account_id FROM accounts ORDER BY account_id OFFSET 10 LIMIT 2;")"
  acct_lo="$(echo "$pair" | sed -n '1p' | tr -d '[:space:]')"
  acct_hi="$(echo "$pair" | sed -n '2p' | tr -d '[:space:]')"

  docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/day08-lockchain-root.sql' <<SQL
SET application_name = 'day08_gauntlet';
\o /tmp/.day08-lockchain-root-pid
SELECT pg_backend_pid();
\o
BEGIN;
UPDATE accounts SET balance_minor = balance_minor WHERE account_id = ${acct_lo};
\! sleep 900
COMMIT;
SQL
  docker compose -p "$COMPOSE_PROJECT" exec -d pg \
    psql -U dbm -d payments -tAX -f /tmp/day08-lockchain-root.sql
  sleep 2
  root_pid="$(docker compose -p "$COMPOSE_PROJECT" exec -T pg cat /tmp/.day08-lockchain-root-pid | tr -d '[:space:]')"

  docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/day08-lockchain-b.sql' <<SQL
SET application_name = 'day08_gauntlet';
BEGIN;
UPDATE accounts SET balance_minor = balance_minor WHERE account_id = ${acct_hi};
\! sleep 3
UPDATE accounts SET balance_minor = balance_minor WHERE account_id = ${acct_lo};
COMMIT;
SQL
  docker compose -p "$COMPOSE_PROJECT" exec -d pg \
    psql -U dbm -d payments -tAX -f /tmp/day08-lockchain-b.sql
  sleep 1

  docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/day08-lockchain-c.sql' <<SQL
SET application_name = 'day08_gauntlet';
BEGIN;
\! sleep 1
UPDATE accounts SET balance_minor = balance_minor WHERE account_id = ${acct_hi};
COMMIT;
SQL
  docker compose -p "$COMPOSE_PROJECT" exec -d pg \
    psql -U dbm -d payments -tAX -f /tmp/day08-lockchain-c.sql

  stash_line "root_pid=${root_pid}"
  say_symptom "${ordinal}) three application connections to the payments database have been stuck for several minutes; the newest one reports waiting on a lock, and it is not the one that's been waiting longest."
}

reset_lock_chain() {
  # Scoped to sessions THIS script started, by application_name --
  # narrower than "anything idle in transaction," which would also reach
  # Day 5's own root blocker (up to 900s, the same lifetime this
  # pathology now uses) if a learner starts the gauntlet while Day 5's
  # incident is still open. A session this script never tagged is never
  # a candidate for termination here, no matter how long it's been idle.
  in_pg "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
          WHERE application_name = 'day08_gauntlet';" >/dev/null 2>&1 || true
  docker compose -p "$COMPOSE_PROJECT" exec -T pg rm -f \
    /tmp/day08-lockchain-root.sql /tmp/day08-lockchain-b.sql /tmp/day08-lockchain-c.sql \
    /tmp/.day08-lockchain-root-pid >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 4. vacuum_starvation (PostgreSQL) -- autovacuum stays ON the whole
#    time; a long-running REPEATABLE READ transaction pins the horizon.
# ---------------------------------------------------------------------

apply_vacuum_starvation() {
  local ordinal="$1" pinning_pid i

  # Same `\o` self-stash and client-side `\! sleep` technique as
  # lock_chain above, for the same reason: this session must show
  # `idle in transaction` in pg_stat_activity, which pg_sleep() would not
  # give it. Its REPEATABLE READ snapshot is taken by the first SELECT,
  # before any of the churn below runs -- that's what pins the horizon.
  docker compose -p "$COMPOSE_PROJECT" exec -T pg sh -c 'cat > /tmp/day08-vacuum-pin.sql' <<'SQL'
SET application_name = 'day08_gauntlet';
\o /tmp/.day08-vacuum-pin-pid
SELECT pg_backend_pid();
\o
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) FROM refunds;
\! sleep 900
COMMIT;
SQL
  docker compose -p "$COMPOSE_PROJECT" exec -d pg \
    psql -U dbm -d payments -tAX -f /tmp/day08-vacuum-pin.sql
  sleep 2
  pinning_pid="$(docker compose -p "$COMPOSE_PROJECT" exec -T pg cat /tmp/.day08-vacuum-pin-pid | tr -d '[:space:]')"

  # autovacuum is never touched -- it stays on, and it will still run.
  # It cannot reclaim anything the pinned snapshot might still need
  # to see, which is exactly the churn below.
  for i in 1 2 3 4 5; do
    in_pg "UPDATE refunds SET reason = reason WHERE refund_id % 7 = 0;" >/dev/null
  done
  in_pg "VACUUM (VERBOSE) refunds;" >/dev/null 2>&1 || true

  stash_line "pinning_pid=${pinning_pid}"
  say_symptom "${ordinal}) storage used by the refunds table keeps growing week over week even though its row count barely changes, and the nightly maintenance job responsible for reclaiming that space keeps reporting success."
}

reset_vacuum_starvation() {
  # Same application_name scoping as reset_lock_chain, and for the same
  # reason -- this must never be able to reach Day 5's own long-running
  # root session on the sole basis that it's also idle in transaction.
  in_pg "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
          WHERE application_name = 'day08_gauntlet';" >/dev/null 2>&1 || true
  in_pg "VACUUM refunds;" >/dev/null 2>&1 || true
  docker compose -p "$COMPOSE_PROJECT" exec -T pg rm -f \
    /tmp/day08-vacuum-pin.sql /tmp/.day08-vacuum-pin-pid >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 5. mongo_regex (MongoDB) -- an unanchored $regex on payment_events.type.
#    Nothing to inject: the collection already carries no index beyond
#    _id_, and an unanchored pattern can't use one even once it exists.
# ---------------------------------------------------------------------

apply_mongo_regex() {
  local ordinal="$1"

  # The offending query itself, written to ws so the learner has to read
  # and repair it -- the same reason missing_index writes its SQL to ws
  # instead of only describing the shape in prose. verify.sh runs
  # whatever this file contains AT VERIFY TIME, never a hardcoded stand-in
  # -- so building an index without also fixing this file's unanchored
  # pattern (a genuinely index-unable-to-help shape, not merely an
  # unindexed one) cannot pass.
  docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/day08-mongo-regex-query.js' <<'JS'
db.payment_events.find({ type: /charge/ }).limit(20)
JS

  stash_line "regex_reason=unanchored"
  say_symptom "${ordinal}) a support tool that searches recent event records for anything matching the word \"charge\" takes several seconds per search, and the search gets slower every month as the event log grows."
}

reset_mongo_regex() {
  in_mongo '
    db.payment_events.getIndexes().forEach(function (ix) {
      if (ix.name !== "_id_") { db.payment_events.dropIndex(ix.name); }
    });
  ' >/dev/null 2>&1 || true
  docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -f /tmp/day08-mongo-regex-query.js >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 6. innodb_deadlock (MySQL) -- two transfer jobs locking the same two
#    accounts in opposite order. Reproduced once here as the reference
#    incident, then left as two editable scripts on ws. Runs against a
#    dedicated, lab-only fixture table -- not the real `accounts` table
#    -- so this pathology shares no data with the seeded dataset: a
#    deadlock's victim gets rolled back by InnoDB automatically, but the
#    SURVIVOR's balance change is real and permanent, and up to 3 apply
#    attempts plus 5 verify-time replays is not a drift Day 5's own
#    balance invariant should have to absorb.
# ---------------------------------------------------------------------

apply_innodb_deadlock() {
  local ordinal="$1" lo=1 hi=2 attempt out_a out_b pid_a pid_b

  in_my "DROP TABLE IF EXISTS day08_deadlock_accounts;" >/dev/null
  in_my "CREATE TABLE day08_deadlock_accounts (
           account_id BIGINT PRIMARY KEY,
           balance_minor BIGINT NOT NULL
         ) ENGINE=InnoDB;" >/dev/null
  in_my "INSERT INTO day08_deadlock_accounts (account_id, balance_minor)
         VALUES (${lo}, 1000000), (${hi}, 1000000);" >/dev/null

  docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/day08-transfer-a.sql' <<SQL
START TRANSACTION;
UPDATE day08_deadlock_accounts SET balance_minor = balance_minor - 100 WHERE account_id = ${lo};
SELECT SLEEP(1);
UPDATE day08_deadlock_accounts SET balance_minor = balance_minor + 100 WHERE account_id = ${hi};
COMMIT;
SQL

  docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'cat > /tmp/day08-transfer-b.sql' <<SQL
START TRANSACTION;
UPDATE day08_deadlock_accounts SET balance_minor = balance_minor - 100 WHERE account_id = ${hi};
SELECT SLEEP(1);
UPDATE day08_deadlock_accounts SET balance_minor = balance_minor + 100 WHERE account_id = ${lo};
COMMIT;
SQL

  for attempt in 1 2 3; do
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
      rm -f "$out_a" "$out_b"
      break
    fi
    rm -f "$out_a" "$out_b"
  done

  stash_line "deadlock_accounts=${lo},${hi}"
  say_symptom "${ordinal}) a nightly settlement transfer between two accounts intermittently aborts with a lock error under load; re-running it by hand right afterward always succeeds."
}

reset_innodb_deadlock() {
  in_my "DROP TABLE IF EXISTS day08_deadlock_accounts;" >/dev/null 2>&1 || true
  docker compose -p "$COMPOSE_PROJECT" exec -T ws rm -f /tmp/day08-transfer-a.sql /tmp/day08-transfer-b.sql >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 7. bloated_index (PostgreSQL) -- disputes vacuums clean; its index on
#    status, churned across all three values repeatedly, does not.
# ---------------------------------------------------------------------

apply_bloated_index() {
  local ordinal="$1" i
  in_pg "CREATE EXTENSION IF NOT EXISTS pgstattuple;" >/dev/null 2>&1 || true
  in_pg "DROP INDEX IF EXISTS idx_gauntlet_disputes_status;" >/dev/null
  in_pg "CREATE INDEX idx_gauntlet_disputes_status ON disputes (status);" >/dev/null

  for i in 1 2 3 4 5 6; do
    in_pg "UPDATE disputes SET status = CASE status
             WHEN 'open' THEN 'won' WHEN 'won' THEN 'lost' ELSE 'open' END;" >/dev/null
  done
  in_pg "VACUUM disputes;" >/dev/null

  stash_line "bloated_index=idx_gauntlet_disputes_status"
  say_symptom "${ordinal}) the disputes table is small and has very little old data sitting in it, but a query that filters on its status column has gotten steadily slower for weeks."
}

reset_bloated_index() {
  in_pg "DROP INDEX IF EXISTS idx_gauntlet_disputes_status;" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# 8. n_plus_one (PostgreSQL) -- every individual call is fast and
#    properly indexed; the problem only shows up aggregated, in
#    pg_stat_statements.
# ---------------------------------------------------------------------

apply_n_plus_one() {
  local ordinal="$1" merchant ids pid script n1_count
  in_pg "CREATE INDEX IF NOT EXISTS ix_ledger_entries_payment_id ON ledger_entries (payment_id);" >/dev/null
  in_pg "ANALYZE ledger_entries;" >/dev/null

  merchant="$(in_pg "SELECT merchant_id FROM payments
                      GROUP BY merchant_id
                      HAVING count(*) BETWEEN 100 AND 600
                      ORDER BY merchant_id
                      LIMIT 1;" | tr -d '[:space:]')"

  ids="$(in_pg "SELECT payment_id FROM payments WHERE merchant_id = ${merchant};")"

  n1_count=0
  script=""
  while IFS= read -r pid; do
    pid="$(echo "$pid" | tr -d '[:space:]')"
    [ -z "$pid" ] && continue
    script="${script}SELECT sum(amount_minor) FROM ledger_entries WHERE payment_id = ${pid};
"
    n1_count=$((n1_count + 1))
  done <<<"$ids"

  printf '%s' "$script" | docker compose -p "$COMPOSE_PROJECT" exec -T pg \
    psql -U dbm -d payments -q >/dev/null

  stash_line "n1_calls=${n1_count}"
  say_symptom "${ordinal}) a merchant capture-summary batch job for one merchant takes about 40 seconds end to end, even though every individual query in its trace completes in under 5 milliseconds."
}

reset_n_plus_one() {
  in_pg "DROP INDEX IF EXISTS ix_ledger_entries_payment_id;" >/dev/null 2>&1 || true
  in_pg "SELECT pg_stat_statements_reset();" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------

if [ "${1:-}" = "--reset" ]; then
  echo "Resetting every Day 8 pathology this script can have applied..."
  for p in "${ALL_PATHOLOGIES[@]}"; do
    "reset_${p}"
  done
  docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c \
    'rm -f /tmp/.day08-targets /tmp/.day08-selected /tmp/.day08-start /tmp/answer \
            /tmp/day08-missing-index.sql /tmp/day08-transfer-a.sql /tmp/day08-transfer-b.sql' \
    >/dev/null 2>&1 || true
  echo "Day 8 baseline restored. Re-run without --reset to roll a fresh five."
  exit 0
fi

echo "Resetting Day 8 baseline (idempotent) before rolling a fresh five..."
for p in "${ALL_PATHOLOGIES[@]}"; do
  "reset_${p}"
done
docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c \
  'rm -f /tmp/.day08-targets /tmp/.day08-selected /tmp/.day08-start /tmp/answer' \
  >/dev/null 2>&1 || true

# Fisher-Yates shuffle of the eight indices, five kept -- portable across
# the bash4+ this project already assumes (see labs/day01/verify.sh's use
# of associative arrays).
idx=(0 1 2 3 4 5 6 7)
for ((i = 7; i > 0; i--)); do
  j=$((RANDOM % (i + 1)))
  tmp=${idx[i]}; idx[i]=${idx[j]}; idx[j]=$tmp
done

echo "Applying 5 of 8 pathologies..."
for k in 0 1 2 3 4; do
  ordinal=$((k + 1))
  name="${ALL_PATHOLOGIES[${idx[k]}]}"
  record_selected "$name"
  "apply_${name}" "$ordinal"
done

docker compose -p "$COMPOSE_PROJECT" exec -T ws sh -c 'date +%s > /tmp/.day08-start' >/dev/null

echo
echo "Five incidents are live. Nothing above named a layer or an engine on"
echo "purpose -- that's the whole exercise. Diagnose each from its own"
echo "instruments, write the evidence chain in journal.md before touching a"
echo "fix, and write all five key=value answers into /tmp/answer inside ws"
echo "before running verify.sh. See README.md for the exact key names."
