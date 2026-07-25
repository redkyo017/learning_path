#!/usr/bin/env bash
# loadgen.sh — send traffic for many tenants through the cell router and tally
# success/failure PER CELL. Run it once with both cells healthy, then again after
# you kill cell-a, and compare: cell-a tenants should fail while cell-b tenants
# stay at 100% — that is blast-radius containment made visible.
#
# Usage:  ./loadgen.sh [ROUTER_URL] [N_TENANTS]
set -euo pipefail

ROUTER="${1:-http://localhost:8090}"
N="${2:-40}"

declare -A ok fail cell
for i in $(seq 1 "$N"); do
  tenant="tenant-$i"
  # Capture the HTTP status and the X-Cell header the router stamped on.
  resp=$(curl -s -o /dev/null -D - -H "X-Tenant: $tenant" \
    "$ROUTER/work?ms=5" -w "%{http_code}") || resp="000"
  code=$(printf '%s' "$resp" | tail -n1)
  which=$(printf '%s' "$resp" | awk -F': ' 'tolower($1)=="x-cell"{print $2}' | tr -d '\r')
  which="${which:-unknown}"
  cell["$tenant"]="$which"
  if [[ "$code" == "200" ]]; then
    ok["$which"]=$(( ${ok["$which"]:-0} + 1 ))
  else
    fail["$which"]=$(( ${fail["$which"]:-0} + 1 ))
  fi
done

echo "=== per-cell tally ($N tenants through $ROUTER) ==="
for c in $(printf '%s\n' "${cell[@]}" | sort -u); do
  printf '  %-28s ok=%-4s fail=%-4s\n' "$c" "${ok[$c]:-0}" "${fail[$c]:-0}"
done
echo "Interpretation: after killing one cell, only THAT cell's row shows failures."
