#!/usr/bin/env bash
set -euo pipefail

# labs/day04/break.sh
#
# Applies a statistics pathology to `payments.merchant_id`, then runs a
# bulk UPDATE that shifts the real distribution of that column with no
# follow-up ANALYZE. The result: a report query that joins merchants to
# payments for one specific merchant goes from a clean, well-estimated
# plan to a catastrophically slow one, with no schema change and no query
# change -- only the statistics the planner is trusting are wrong.
#
# IMPORTANT -- what this script deliberately does NOT do: it never touches
# enable_nestloop, enable_hashjoin or enable_seqscan, at any level (session,
# database, or role). Disabling one of those settings would force the
# planner away from the bad plan without fixing why it chose it, and the
# fix would stop working the next time the data shifts again. verify.sh
# checks pg_settings AND pg_db_role_setting for all three and FAILS the
# lab if any of them is off anywhere -- that hack is not a valid solution
# here, on purpose.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

echo "== day04: setting up a clean baseline =="

# Day 3's teardown drops its indexes -- do not assume one survives. This
# lab needs an index on payments.merchant_id to exist at all (a plain
# sequential scan wouldn't show a plan-shape divergence worth reading), so
# create it here, then ANALYZE while the statistics are still honest. This
# ANALYZE is the "before" snapshot everything below silently invalidates.
in_pg "CREATE INDEX IF NOT EXISTS payments_merchant_id_idx ON payments (merchant_id);" >/dev/null
in_pg "ANALYZE payments;" >/dev/null

# The target merchant is not random and not hidden: it is the merchant
# sitting at the midpoint of the id range. merchant_id is assigned
# 1..N by generate_series at seed time (see labs/stack/seed/10-generate.sql),
# so this is a fixed, reproducible row -- not something break.sh invents
# and verify.sh has to remember on its behalf. Because the power-law draw
# that assigns payments to merchants favors LOW merchant_ids, a merchant
# at the midpoint of the id range starts out well below average activity:
# an unremarkable, forgettable merchant, which is exactly the profile a
# stale-statistics incident needs to be surprising.
target="$(in_pg "SELECT merchant_id FROM merchants
                  ORDER BY merchant_id
                  OFFSET (SELECT count(*)/2 FROM merchants)
                  LIMIT 1;" | tr -d '[:space:]')"

echo "target merchant resolved (deterministic, not a secret): merchant_id=${target}"

echo "== day04: applying the statistics pathology =="

# 1. A false n_distinct override. This tells the planner "trust me, this
#    column effectively has one distinct value" -- a hand-applied hack,
#    the kind someone leaves behind after "fixing" an unrelated estimate
#    problem and never removes. It corrupts every ANALYZE run against this
#    column from here on, including ones the learner runs later, until it
#    is explicitly reset.
in_pg "ALTER TABLE payments ALTER COLUMN merchant_id SET (n_distinct = 1);" >/dev/null

# 2. Autovacuum off for payments. Nothing will refresh this table's
#    statistics on its own from this point forward, no matter how much
#    the data underneath changes.
in_pg "ALTER TABLE payments SET (autovacuum_enabled = false);" >/dev/null

# 3. Before the bulk UPDATE: save the rows it is about to touch. The
#    UPDATE below turns the target merchant from unremarkable into one of
#    the dataset's highest-volume merchants -- an UPDATE, not an INSERT,
#    so a plain `DELETE` can't undo it, and Days 5-8 depend on the seeded
#    power-law skew being the real skew, not one this lab silently
#    distorted. `day04_original_merchants` is clearly-named lab
#    scaffolding, not part of the canonical schema: teardown.md restores
#    the moved rows from it and drops it, so the distortion is reversible,
#    not permanent -- as long as teardown.md is actually run.
#    `IF NOT EXISTS` makes re-running break.sh without teardown in between
#    safe -- a second run's bulk UPDATE below would match zero rows
#    (they're already at the target), so it must not overwrite an
#    already-captured original mapping with an empty one.
in_pg "CREATE TABLE IF NOT EXISTS day04_original_merchants AS
       SELECT payment_id, merchant_id
       FROM payments
       WHERE merchant_id <> ${target}
         AND status = 'captured'
         AND payment_id % 40 = 0;" >/dev/null

# 4. The bulk UPDATE itself: reassigns that exact slice of captured
#    payments -- currently spread across many other merchants -- onto the
#    target merchant. This is the actual distribution shift: the target
#    merchant, previously unremarkable, now owns a large, disproportionate
#    slice of captured payments. No ANALYZE follows. The planner's picture
#    of this column is now stale in exactly the place that matters for the
#    query below.
in_pg "UPDATE payments
       SET merchant_id = ${target}
       WHERE merchant_id <> ${target}
         AND status = 'captured'
         AND payment_id % 40 = 0;" >/dev/null

echo "== day04: reference run (this is what a learner's own run will look like) =="

# The target query: a merchant capture-totals report, the kind of thing a
# settlement dashboard runs once per merchant per day. It is exactly the
# query whose plan the learner is asked to read.
read -r -d '' Q1 <<SQL || true
SELECT m.name,
       count(*)            AS n_captured,
       sum(p.amount_minor) AS total_minor
FROM merchants m
JOIN payments p ON p.merchant_id = m.merchant_id
WHERE p.merchant_id = ${target}
  AND p.status = 'captured'
GROUP BY m.name;
SQL

plan="$(in_pg "EXPLAIN (ANALYZE, BUFFERS) ${Q1}")"

# Find the deepest plan node where the estimate and the actual diverge.
# This is not guesswork dressed up as a formula: for every line that
# carries both an estimate ("rows=N" in the cost parenthetical) and a
# measured value ("rows=N" inside the "(actual ... )" parenthetical), it
# computes actual/estimate and tracks the node with the worst ratio,
# breaking ties toward the MORE indented (deeper) node -- because a parent
# node's own divergence is a consequence of its child's, never the other
# way around, and the lesson is to stop at the cause, not the first symptom
# you see at the top of the plan.
#
# Known blind spot, harmless for this lab's fixed pathology but worth
# flagging for any future reuse: the metric is actual/estimate, which can
# only ever flag an UNDERestimate. A node where the planner drastically
# OVERestimates rows (actual/estimate << 1) would never win this
# comparison no matter how wrong it is. If a future day's break.sh needs
# to catch an overestimate instead, this ratio needs to become
# max(actual/estimate, estimate/actual) or the two directions need to be
# tracked separately.
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

if [ -z "${divergent_node}" ]; then
  echo "day04 break.sh: could not identify a divergent plan node from a reference run" >&2
  echo "${plan}" >&2
  exit 1
fi

# Stash exactly the line the learner is asked to write into /tmp/answer,
# never anything more -- answer_check compares the two files' full content,
# not a substring. Deliberately no echo of ${divergent_node} above this
# line or below it: this value IS the answer the learner is being asked
# to find, and printing it here would hand them the lesson instead of
# letting them earn it (the exact failure mode common.sh's answer_check
# and the day-author-context conventions both exist to prevent -- see
# Day 3's break.sh for the same discipline applied to its own stash).
docker compose -p "${COMPOSE_PROJECT}" exec -T pg sh -c \
  "printf 'divergent_node=%s\n' '${divergent_node}' > /tmp/.day04-target"

say_symptom "the merchant capture-totals report ran in about 400 ms last week; same schema, same query, same index -- it now takes upward of 90 seconds."
