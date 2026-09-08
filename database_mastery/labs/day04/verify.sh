#!/usr/bin/env bash
set -euo pipefail

# labs/day04/verify.sh
#
# Five independent checks. The first two prove the pathology is genuinely
# resolved (query speed, and the specific catalog artifact break.sh left
# behind). The third proves nobody forced the plan instead of fixing the
# cause -- that path is rejected explicitly, not silently allowed to pass.
# The fourth and fifth prove the SECOND stage of the fix actually happened
# (extended statistics), not only the first. None of this substitutes for
# the learner's own diagnosis, which is what the answer_check below is for.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

FAILED=0
THRESHOLD_MS=3000

echo "== check 1: learner's diagnosis (/tmp/answer on ws) =="
if answer_check /tmp/.day04-target pg; then
  pass "divergent_node= matches the deepest node break.sh's reference run found"
else
  fail "divergent_node= in /tmp/answer does not match. Read the plan bottom-up: \
find the deepest node where estimate and actual diverge, not the top-level node."
fi

echo
echo "== check 2: the target query itself is fast again =="
# Recompute the same target merchant break.sh used -- it is a fixed row
# (the id-order midpoint of `merchants`), not something break.sh needed to
# stash, so verify.sh derives it the identical way.
target="$(in_pg "SELECT merchant_id FROM merchants
                  ORDER BY merchant_id
                  OFFSET (SELECT count(*)/2 FROM merchants)
                  LIMIT 1;" | tr -d '[:space:]')"

exec_line="$(in_pg "EXPLAIN (ANALYZE)
  SELECT m.name, count(*) AS n_captured, sum(p.amount_minor) AS total_minor
  FROM merchants m
  JOIN payments p ON p.merchant_id = m.merchant_id
  WHERE p.merchant_id = ${target}
    AND p.status = 'captured'
  GROUP BY m.name;" | grep -i 'Execution Time' || true)"

elapsed_ms="$(printf '%s' "${exec_line}" | grep -oE '[0-9]+\.[0-9]+' | head -n1)"

if [ -z "${elapsed_ms}" ]; then
  fail "could not read an Execution Time from EXPLAIN ANALYZE output for the target query"
elif awk -v a="${elapsed_ms}" -v b="${THRESHOLD_MS}" 'BEGIN{exit !(a<b)}'; then
  pass "merchant capture-totals report completed in ${elapsed_ms} ms (under ${THRESHOLD_MS} ms)"
else
  fail "merchant capture-totals report took ${elapsed_ms} ms -- still above the ${THRESHOLD_MS} ms \
threshold. The row-estimate fix (n_distinct override removed, ANALYZE re-run) is not fully applied yet."
fi

echo
echo "== check 3: the hack fix is rejected =="
# enable_nestloop / enable_hashjoin / enable_seqscan must be 'on' everywhere
# this session can see them: as the effective setting for THIS session
# (which already reflects any database- or role-level ALTER ... SET that
# applies to user dbm on database payments), and, independently, across
# every persisted override in pg_db_role_setting -- including one aimed at
# a different role or a different database, which this session's own
# pg_settings would never surface.
off_settings="$(in_pg "SELECT name || '=' || setting
                        FROM pg_settings
                        WHERE name IN ('enable_nestloop','enable_hashjoin','enable_seqscan')
                          AND setting <> 'on';")"

off_overrides="$(in_pg "SELECT cfg
                         FROM (SELECT unnest(setconfig) AS cfg FROM pg_db_role_setting) s
                         WHERE cfg ~ '^(enable_nestloop|enable_hashjoin|enable_seqscan)=off\$';")"

if [ -n "${off_settings}" ] || [ -n "${off_overrides}" ]; then
  fail "enable_nestloop / enable_hashjoin / enable_seqscan is disabled somewhere \
(session, database, or role). Forcing a plan node off hides the row-estimate error \
instead of fixing it, and it stops working the moment the data shifts again -- turn \
these back on and fix the statistics instead."
else
  pass "enable_nestloop, enable_hashjoin and enable_seqscan are on everywhere checked"
fi

echo
echo "== check 4: the false n_distinct override is gone =="
attopts="$(in_pg "SELECT coalesce(attoptions::text, '')
                   FROM pg_attribute
                   WHERE attrelid = 'payments'::regclass
                     AND attname = 'merchant_id';")"

if printf '%s' "${attopts}" | grep -qi 'n_distinct'; then
  fail "pg_attribute.attoptions for payments.merchant_id still carries an n_distinct \
override. Remove it with ALTER TABLE payments ALTER COLUMN merchant_id RESET (n_distinct);"
else
  pass "payments.merchant_id carries no n_distinct override"
fi

echo
echo "== check 5: extended statistics on the correlated pair exist and are analysed =="
ext_name="$(in_pg "SELECT stxname
                    FROM pg_statistic_ext es
                    WHERE es.stxrelid = 'wide_payments'::regclass
                      AND (SELECT array_agg(a.attname ORDER BY a.attname)
                           FROM pg_attribute a
                           WHERE a.attrelid = es.stxrelid
                             AND a.attnum = ANY (es.stxkeys::int2[]))
                          = ARRAY['currency','merchant_country']::name[]
                    LIMIT 1;")"

if [ -z "${ext_name}" ]; then
  fail "no extended statistics object on wide_payments(currency, merchant_country) found \
in pg_statistic_ext. This is the second stage of the fix -- ANALYZE alone does not \
close the independence-assumption error on a correlated pair; CREATE STATISTICS does."
else
  analysed="$(in_pg "SELECT 1
                      FROM pg_stats_ext
                      WHERE tablename = 'wide_payments'
                        AND attnames @> ARRAY['currency','merchant_country']::name[]
                        AND (n_distinct IS NOT NULL OR dependencies IS NOT NULL)
                      LIMIT 1;")"
  if [ -z "${analysed}" ]; then
    fail "extended statistics object '${ext_name}' exists but pg_stats_ext shows no \
n_distinct/dependencies payload yet -- run ANALYZE wide_payments; after creating it."
  else
    pass "extended statistics object '${ext_name}' exists and has been analysed"
  fi
fi

echo
exit "${FAILED:-0}"
