#!/usr/bin/env bash
# Hit the router N times through Traefik and tally which version served each
# request (v1 vs v2) plus any 5xx errors. This is how you SEE the canary split.
#
#   ./count-versions.sh          # 200 requests
#   ./count-versions.sh 500      # 500 requests
#   BASE=http://localhost:8080 ./count-versions.sh
set -euo pipefail
BASE="${BASE:-http://localhost:8080}"
N="${1:-200}"

v1=0; v2=0; err=0
for ((i = 0; i < N; i++)); do
  code=$(curl -s -o /tmp/orders_body -w '%{http_code}' "$BASE/orders" || echo 000)
  body=$(cat /tmp/orders_body 2>/dev/null || true)
  if [[ "$code" != "200" ]]; then
    err=$((err + 1))
  elif [[ "$body" == *v2* ]]; then
    v2=$((v2 + 1))
  elif [[ "$body" == *v1* ]]; then
    v1=$((v1 + 1))
  else
    err=$((err + 1))
  fi
done

pct() { awk "BEGIN{ if($2==0){print 0}else{printf \"%.1f\", 100*$1/$2} }"; }
echo "requests=$N  v1=$v1 ($(pct $v1 $N)%)  v2=$v2 ($(pct $v2 $N)%)  errors=$err ($(pct $err $N)%)"
