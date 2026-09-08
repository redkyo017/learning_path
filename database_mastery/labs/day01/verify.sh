#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_stack

# Day 1 ships no break.sh -- nothing here was broken on purpose, so there
# is no stashed per-run value for answer_check to compare against. Instead,
# every one of the three deliverables is recomputed live from the catalogs
# right here, and the learner's /tmp/answer (inside the `ws` container) is
# checked against that live computation. Never echo the computed truth,
# on a pass or a fail -- only which of the three deliverables is wrong.

# ---------------------------------------------------------------------
# Read and parse /tmp/answer from the ws container.
# ---------------------------------------------------------------------
raw_answer="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"

if [[ -z "${raw_answer//[[:space:]]/}" ]]; then
  fail "no /tmp/answer found in ws, or it is empty -- see README.md for the required format"
fi

declare -A ans
while IFS= read -r line; do
  line="${line%$'\r'}"
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^([a-z_]+)=(.*)$ ]]; then
    ans["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  else
    fail "malformed line in /tmp/answer: '$line' -- expected key=value, lowercase key, no spaces around ="
  fi
done <<<"$raw_answer"

for key in bloat_ratio toast_column fattest_pk; do
  if [[ -z "${ans[$key]:-}" ]]; then
    fail "missing key '$key' in /tmp/answer"
  fi
done

# ---------------------------------------------------------------------
# Deliverable 1: bloat_ratio -- pg_total_relation_size('payments') versus
# the summed per-row average pg_column_size of payments' own columns,
# accepted within +/-0.15 since summation method legitimately varies.
# ---------------------------------------------------------------------
if [[ -n "${ans[bloat_ratio]:-}" ]]; then
  learner_ratio="${ans[bloat_ratio]}"

  if ! [[ "$learner_ratio" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    fail "bloat_ratio is not a plain non-negative number"
  else
    total_bytes="$(in_pg "SELECT pg_total_relation_size('payments');" | tr -d '[:space:]')"
    avg_row_bytes="$(in_pg "SELECT avg(
        pg_column_size(payment_id) + pg_column_size(merchant_id) +
        pg_column_size(customer_id) + pg_column_size(payment_method_id) +
        pg_column_size(amount_minor) + pg_column_size(currency) +
        pg_column_size(status) + pg_column_size(created_at) +
        pg_column_size(captured_at) + pg_column_size(description)
      ) FROM payments;" | tr -d '[:space:]')"
    reltuples="$(in_pg "SELECT reltuples::bigint FROM pg_class WHERE relname = 'payments';" | tr -d '[:space:]')"

    if [[ -z "$total_bytes" || -z "$avg_row_bytes" || -z "$reltuples" || "$reltuples" == "0" ]]; then
      fail "could not compute bloat_ratio from the catalog (unexpected empty/zero reading)"
    else
      within="$(awk -v t="$total_bytes" -v a="$avg_row_bytes" -v n="$reltuples" -v y="$learner_ratio" '
        BEGIN {
          truth = t / (a * n);
          d = truth - y;
          if (d < 0) d = -d;
          print (d <= 0.15) ? "yes" : "no";
        }')"
      if [[ "$within" == "yes" ]]; then
        pass "bloat_ratio is within tolerance of the catalog-computed value"
      else
        fail "bloat_ratio does not match pg_total_relation_size('payments') versus summed column bytes (±0.15)"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------
# Deliverable 2: toast_column -- the payments column that is ACTUALLY
# stored out of line, not merely eligible to be. attstorage <> 'p' only
# says a column's type *can* be compressed/external (varlena) -- in this
# schema that is true of `currency`, `status`, AND the real answer, so
# eligibility alone can't distinguish them. Instead, measure genuine
# out-of-line storage directly: for every varlena column, count rows
# whose pg_column_size() crosses the ~2 KB threshold TOAST acts on, in
# one scan, and take whichever column has a nonzero count. This adapts
# on its own if a future seed change alters which columns are varlena.
# ---------------------------------------------------------------------
if [[ -n "${ans[toast_column]:-}" ]]; then
  learner_toast_col="$(printf '%s' "${ans[toast_column]}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  candidates_raw="$(in_pg "SELECT attname FROM pg_attribute
      WHERE attrelid = 'payments'::regclass
        AND attnum > 0 AND NOT attisdropped
        AND attstorage <> 'p'
      ORDER BY attnum;")"

  candidates=()
  while IFS= read -r c; do
    c="$(printf '%s' "$c" | tr -d '[:space:]')"
    [[ -n "$c" ]] && candidates+=("$c")
  done <<<"$candidates_raw"

  toast_relid="$(in_pg "SELECT reltoastrelid FROM pg_class WHERE relname = 'payments';" | tr -d '[:space:]')"

  if [[ "${#candidates[@]}" -eq 0 || -z "$toast_relid" || "$toast_relid" == "0" ]]; then
    fail "could not determine any TOAST-eligible column for payments from the catalog"
  else
    filter_sql=""
    for c in "${candidates[@]}"; do
      [[ -n "$filter_sql" ]] && filter_sql+=", "
      filter_sql+="count(*) FILTER (WHERE pg_column_size(${c}) > 2000)"
    done
    counts_raw="$(in_pg "SELECT ${filter_sql} FROM payments;")"

    IFS='|' read -r -a counts_arr <<<"$counts_raw"

    nonzero_count=0
    true_toast_col=""
    for i in "${!candidates[@]}"; do
      val="$(printf '%s' "${counts_arr[$i]:-}" | tr -d '[:space:]')"
      if [[ -n "$val" && "$val" != "0" ]]; then
        nonzero_count=$((nonzero_count + 1))
        true_toast_col="${candidates[$i]}"
      fi
    done

    if [[ "$nonzero_count" -ne 1 ]]; then
      fail "could not uniquely determine, from actual row measurements, which column is stored out of line"
    elif [[ "$learner_toast_col" == "$true_toast_col" ]]; then
      pass "toast_column matches the column the catalog shows is genuinely stored out of line"
    else
      fail "toast_column does not match the column the catalog shows is genuinely stored out of line"
    fi
  fi
fi

# ---------------------------------------------------------------------
# Deliverable 3: fattest_pk -- which of the three MySQL PK-variant tables
# carries the largest total secondary-index footprint, read from
# information_schema.tables.INDEX_LENGTH (InnoDB: everything that is not
# the clustered primary-key data).
# ---------------------------------------------------------------------
if [[ -n "${ans[fattest_pk]:-}" ]]; then
  learner_pk="$(printf '%s' "${ans[fattest_pk]}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  case "$learner_pk" in
    pk_variant_bigint|pk_variant_uuid|pk_variant_natural) ;;
    *) fail "fattest_pk is not one of pk_variant_bigint, pk_variant_uuid, pk_variant_natural" ;;
  esac

  sizes_raw="$(in_my "SELECT table_name, index_length FROM information_schema.tables
      WHERE table_schema = 'payments'
        AND table_name IN ('pk_variant_bigint','pk_variant_uuid','pk_variant_natural');")"

  declare -A sizes
  while IFS=$'\t' read -r tbl sz; do
    [[ -z "$tbl" ]] && continue
    sizes["$tbl"]="$sz"
  done <<<"$sizes_raw"

  if [[ "${#sizes[@]}" -ne 3 ]]; then
    fail "could not read secondary-index sizes for all three pk_variant tables from information_schema.tables"
  else
    true_max_tbl=""
    true_max_val=-1
    for tbl in "${!sizes[@]}"; do
      if (( sizes[$tbl] > true_max_val )); then
        true_max_val="${sizes[$tbl]}"
        true_max_tbl="$tbl"
      fi
    done

    if [[ "$learner_pk" == "$true_max_tbl" ]]; then
      pass "fattest_pk matches the table with the largest secondary-index footprint"
    else
      fail "fattest_pk does not match the table with the largest secondary-index footprint"
    fi
  fi
fi

exit "${FAILED:-0}"
