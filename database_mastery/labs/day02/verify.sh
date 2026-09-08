#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Day 2 ships no break.sh -- wide_payments and the oversized
# merchant_catalog documents are deterministic seed-time artifacts, not a
# per-run injected fault, so there is no per-run stash for answer_check to
# compare against here. /tmp/answer's expected values (violated_form=3NF,
# determinant=merchant_id, or a set containing it) are fixed by the schema
# itself, not randomised per run, so they are parsed and range-checked
# directly below instead of going through answer_check.
#
# Four independent checks, reported separately: (1) the relational
# decomposition, checked structurally via information_schema rather than
# by re-deriving the anomaly declaratively -- including that the
# payment_methods UNIQUE constraint the lab asks for actually exists; (2)
# lossless-join reconstruction of wide_payments from payments_norm, on
# both cardinality and content; (3) the learner's stated diagnosis in
# /tmp/answer; (4) the MongoDB catalog restructuring, checked against
# catalog_seed_meta.

echo "== 1) relational decomposition (information_schema) =="

schema_exists="$(in_pg "SELECT count(*) FROM information_schema.schemata WHERE schema_name = 'payments_norm';" | tr -d '[:space:]')"
if [ "$schema_exists" = "1" ]; then
  pass "schema payments_norm exists"
else
  fail "schema payments_norm does not exist"
fi

for t in merchants customers payment_methods payments; do
  n="$(in_pg "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'payments_norm' AND table_name = '$t';" | tr -d '[:space:]')"
  if [ "$n" = "1" ]; then
    pass "table payments_norm.$t exists"
  else
    fail "table payments_norm.$t is missing"
  fi
done

# The structural signature of removing every transitive dependency the
# original table carried, all five of them, not only the one on
# merchant_name: each of merchant_name, merchant_country,
# merchant_risk_tier must live only in merchants, and each of
# customer_email, customer_country only in customers. Checking
# merchant_name alone would pass a decomposition that moved the name out
# but left country and risk_tier duplicated in payments_norm.payments --
# the identical unfixed transitive dependency, only partly disguised.
for pair in "merchant_name:merchants" "merchant_country:merchants" "merchant_risk_tier:merchants" \
            "customer_email:customers" "customer_country:customers"; do
  col="${pair%%:*}"
  home="${pair##*:}"
  elsewhere="$(in_pg "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'payments_norm' AND column_name = '$col' AND table_name <> '$home';" | tr -d '[:space:]')"
  present="$(in_pg "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'payments_norm' AND table_name = '$home' AND column_name = '$col';" | tr -d '[:space:]')"
  if [ "${elsewhere:-x}" = "0" ] && [ "${present:-x}" = "1" ]; then
    pass "$col lives only in payments_norm.$home"
  else
    fail "$col is missing from payments_norm.$home, or still duplicated elsewhere -- a transitive dependency has not been removed"
  fi
done

# A copy that merely renamed wide_payments to payments_norm.payments would
# also pass the checks above trivially (it is the only table, so it is
# vacuously "the merchant table"). Guard against that: merchants,
# customers, and payment_methods must be genuinely deduplicated, not
# carry one row per payment.
merchants_rows="$(in_pg "SELECT count(*) FROM payments_norm.merchants;" 2>/dev/null)" || merchants_rows=""
distinct_merchants="$(in_pg "SELECT count(DISTINCT merchant_id) FROM wide_payments;" | tr -d '[:space:]')"
if [ -n "$merchants_rows" ] && [ "$(printf '%s' "$merchants_rows" | tr -d '[:space:]')" = "$distinct_merchants" ]; then
  pass "payments_norm.merchants holds one row per distinct merchant_id"
else
  fail "payments_norm.merchants row count does not match the distinct merchant_id count in wide_payments -- this looks like a renamed copy, not a decomposition"
fi

customers_rows="$(in_pg "SELECT count(*) FROM payments_norm.customers;" 2>/dev/null)" || customers_rows=""
distinct_customers="$(in_pg "SELECT count(DISTINCT customer_id) FROM wide_payments;" | tr -d '[:space:]')"
if [ -n "$customers_rows" ] && [ "$(printf '%s' "$customers_rows" | tr -d '[:space:]')" = "$distinct_customers" ]; then
  pass "payments_norm.customers holds one row per distinct customer_id"
else
  fail "payments_norm.customers row count does not match the distinct customer_id count in wide_payments -- this looks like a renamed copy, not a decomposition"
fi

# payment_methods has no natural key in wide_payments to compare against
# directly, but the taught construction (SOLUTION.md, exercise 3) dedups
# on the distinct (customer_id, brand, last4, exp_month, exp_year)
# combination -- so that count, computed independently here, is the
# expected row count. A payment_methods table built with one row per
# payment (no dedup at all) has a row count equal to wide_payments' row
# count instead, which this catches directly.
pm_rows="$(in_pg "SELECT count(*) FROM payments_norm.payment_methods;" 2>/dev/null)" || pm_rows=""
distinct_pm="$(in_pg "SELECT count(*) FROM (SELECT DISTINCT customer_id, pm_brand, pm_last4, pm_exp_month, pm_exp_year FROM wide_payments) d;" | tr -d '[:space:]')"
if [ -n "$pm_rows" ] && [ "$(printf '%s' "$pm_rows" | tr -d '[:space:]')" = "$distinct_pm" ]; then
  pass "payments_norm.payment_methods holds one row per distinct (customer, card) combination"
else
  fail "payments_norm.payment_methods row count does not match the distinct customer/brand/last4/expiry combination in wide_payments -- this looks undeduplicated (e.g. one row per payment)"
fi

# NOT EXISTS over payments_norm's own tables is vacuously true when the
# schema itself does not exist -- missing_pk would report 0 (nothing to
# find) in that case. Harmless here only because the schema-existence and
# table-existence checks above already fail independently and set
# FAILED; do not rely on this check alone to prove payments_norm exists.
missing_pk="$(in_pg "SELECT count(*) FROM information_schema.tables t WHERE t.table_schema = 'payments_norm' AND t.table_type = 'BASE TABLE' AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints tc WHERE tc.table_schema = t.table_schema AND tc.table_name = t.table_name AND tc.constraint_type = 'PRIMARY KEY');" | tr -d '[:space:]')"
if [ "${missing_pk:-x}" = "0" ]; then
  pass "every table in payments_norm has a primary key"
else
  fail "${missing_pk:-some} table(s) in payments_norm have no primary key"
fi

fk_count="$(in_pg "SELECT count(*) FROM information_schema.table_constraints WHERE table_schema = 'payments_norm' AND table_name = 'payments' AND constraint_type = 'FOREIGN KEY';" | tr -d '[:space:]')"
if [ "${fk_count:-0}" -ge 3 ] 2>/dev/null; then
  pass "payments_norm.payments carries ${fk_count} foreign keys"
else
  fail "payments_norm.payments has only ${fk_count:-0} foreign key(s) -- expected at least 3 (merchant, customer, payment method)"
fi

# A constraint the learner is told about (README.md, SOLUTION.md) but
# never held to is not a constraint. Check the exact column set, not
# only "some UNIQUE constraint exists somewhere on this table" -- a
# UNIQUE on
# payment_method_id alone (already the primary key, and therefore always
# unique) would otherwise pass a check that only counted constraints.
pm_unique="$(in_pg "SELECT count(*) FROM (SELECT tc.constraint_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema WHERE tc.table_schema = 'payments_norm' AND tc.table_name = 'payment_methods' AND tc.constraint_type = 'UNIQUE' GROUP BY tc.constraint_name HAVING array_agg(kcu.column_name ORDER BY kcu.column_name) = ARRAY['brand','customer_id','exp_month','exp_year','last4']) u;" 2>/dev/null)" || pm_unique=""
pm_unique="$(printf '%s' "$pm_unique" | tr -d '[:space:]')"
if [ "${pm_unique:-0}" -ge 1 ] 2>/dev/null; then
  pass "payments_norm.payment_methods declares UNIQUE (customer_id, brand, last4, exp_month, exp_year)"
else
  fail "payments_norm.payment_methods has no UNIQUE constraint on exactly (customer_id, brand, last4, exp_month, exp_year) -- a card cannot be reintroduced as a duplicate on a later write without one"
fi

echo
echo "== 2) lossless join reconstruction =="

# Cardinality first: cheap, and catches gross fan-out or dropped entities
# immediately.
orig="$(in_pg "SELECT count(*) || '|' || count(DISTINCT payment_id) FROM wide_payments;" | tr -d '[:space:]')"
recon="$(in_pg "SELECT count(*) || '|' || count(DISTINCT p.payment_id) FROM payments_norm.payments p JOIN payments_norm.merchants m ON m.merchant_id = p.merchant_id JOIN payments_norm.customers c ON c.customer_id = p.customer_id JOIN payments_norm.payment_methods pm ON pm.payment_method_id = p.payment_method_id;" 2>/dev/null)" || recon=""
recon="$(printf '%s' "$recon" | tr -d '[:space:]')"
if [ -n "$recon" ] && [ "$recon" = "$orig" ]; then
  pass "reconstructed wide_payments matches the original on row count and distinct payment_id"
else
  fail "reconstructed join does not match the original wide_payments -- rows were lost or duplicated by the decomposition (or a table/join is missing)"
fi

# Cardinality matching is not lossless-join proof by itself: any
# assignment of a foreign key to a *valid* row in the referenced table --
# the right customer's second card instead of the one that payment
# actually used, say -- reproduces identical counts while every affected
# row's content is wrong. The textbook lossless-join test is the
# symmetric difference: reconstruct the same 16 substantive columns
# wide_payments carries (everything except the synthetic row_id, which
# payments_norm has no reason to reproduce) and require EXCEPT to be
# empty in both directions. At SCALE=10 (5,000,000 payments) this forces
# a real hash/sort over the full row set on each side, twice, under this
# stack's deliberately small work_mem -- expect it to spill to disk and
# take real wall-clock time, not milliseconds. That cost buys a guarantee
# cardinality alone cannot: it fails on a right-customer-wrong-card
# mistake that the row-count check above passes cleanly.
RECON_COLS="p.payment_id, p.amount_minor, p.currency, p.status, p.created_at, p.merchant_id, m.merchant_name, m.merchant_country, m.merchant_risk_tier, p.customer_id, c.customer_email, c.customer_country, pm.brand, pm.last4, pm.exp_month, pm.exp_year"
RECON_FROM="FROM payments_norm.payments p JOIN payments_norm.merchants m ON m.merchant_id = p.merchant_id JOIN payments_norm.customers c ON c.customer_id = p.customer_id JOIN payments_norm.payment_methods pm ON pm.payment_method_id = p.payment_method_id"
WIDE_COLS="payment_id, amount_minor, currency, status, created_at, merchant_id, merchant_name, merchant_country, merchant_risk_tier, customer_id, customer_email, customer_country, pm_brand, pm_last4, pm_exp_month, pm_exp_year"

recon_extra="$(in_pg "SELECT count(*) FROM ((SELECT ${RECON_COLS} ${RECON_FROM}) EXCEPT (SELECT ${WIDE_COLS} FROM wide_payments)) x;" 2>/dev/null)" || recon_extra=""
recon_extra="$(printf '%s' "$recon_extra" | tr -d '[:space:]')"
orig_extra="$(in_pg "SELECT count(*) FROM ((SELECT ${WIDE_COLS} FROM wide_payments) EXCEPT (SELECT ${RECON_COLS} ${RECON_FROM})) x;" 2>/dev/null)" || orig_extra=""
orig_extra="$(printf '%s' "$orig_extra" | tr -d '[:space:]')"

if [ "${recon_extra:-x}" = "0" ] && [ "${orig_extra:-x}" = "0" ]; then
  pass "reconstructed rows match wide_payments content exactly, both directions (symmetric EXCEPT is empty)"
else
  fail "reconstructed content diverges from wide_payments (rows only in the reconstruction: ${recon_extra:-?}; rows only in the original: ${orig_extra:-?}) -- a foreign key is pointing at a valid but wrong row somewhere"
fi

echo
echo "== 3) /tmp/answer diagnosis =="

answer_raw="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"
violated_form="$(printf '%s\n' "$answer_raw" | grep -i '^violated_form=' | head -1 | cut -d= -f2- | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
determinant="$(printf '%s\n' "$answer_raw" | grep -i '^determinant=' | head -1 | cut -d= -f2- | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"

if [ "$violated_form" = "3nf" ]; then
  pass "violated_form is 3NF"
else
  fail "violated_form must be 3NF"
fi

if [ -n "$determinant" ] && printf '%s' "$determinant" | grep -q 'merchant_id'; then
  pass "determinant names merchant_id"
else
  fail "determinant must be merchant_id, or a set containing it"
fi

echo
echo "== 4) MongoDB catalog restructuring =="

mongo_report="$(in_mongo '
  var target = db.merchant_catalog.countDocuments({}) > 0 ? "merchant_catalog" : "merchant_catalog_buckets";
  var maxN = 0;
  db.getCollection(target).find({}, {products: 1}).forEach(function(d) {
    var n = (d.products || []).length;
    if (n > maxN) maxN = n;
  });
  var totals = {};
  db.getCollection(target).aggregate([
    {$group: {_id: "$merchant_id", total: {$sum: {$size: {$ifNull: ["$products", []]}}}}}
  ]).forEach(function(d) { totals[d._id] = (totals[d._id] || 0) + d.total; });
  var checked = 0, missing = 0, mismatches = 0;
  db.catalog_seed_meta.find().forEach(function(m) {
    checked++;
    if (!(m.merchant_id in totals)) { missing++; return; }
    if (totals[m.merchant_id] !== m.product_count) mismatches++;
  });
  print("target=" + target);
  print("maxarray=" + maxN);
  print("checked=" + checked + " missing=" + missing + " mismatches=" + mismatches);
' 2>/dev/null)" || mongo_report=""

echo "$mongo_report"
maxarray="$(printf '%s\n' "$mongo_report" | grep '^maxarray=' | cut -d= -f2 | tr -d '[:space:]')"
if [ -n "$maxarray" ] && [ "$maxarray" -le 1000 ] 2>/dev/null; then
  pass "no restructured document carries more than 1000 products (max $maxarray)"
else
  fail "at least one document still carries more than 1000 products (max ${maxarray:-unknown})"
fi

missing="$(printf '%s\n' "$mongo_report" | sed -n 's/^checked=[0-9]* missing=\([0-9]*\).*/\1/p')"
mismatches="$(printf '%s\n' "$mongo_report" | sed -n 's/.*mismatches=\([0-9]*\)$/\1/p')"
if [ "${missing:-1}" = "0" ] && [ "${mismatches:-1}" = "0" ]; then
  pass "every merchant's product count is preserved against catalog_seed_meta"
else
  fail "product counts diverge from catalog_seed_meta (missing=${missing:-?}, mismatches=${mismatches:-?}) -- products were lost or duplicated while restructuring"
fi

echo
exit "${FAILED:-0}"
