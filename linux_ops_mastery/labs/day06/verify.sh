#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

in_proxy() { compose exec -T proxy sh -c "$1"; }

FAULT="$(in_proxy 'cat /tmp/.day06-fault 2>/dev/null' | tr -d '[:space:]' \
  || true)"
if [ -z "${FAULT:-}" ]; then
  echo "No fault recorded. Run: bash break.sh [1-5|random]" >&2
  exit 1
fi

fault_fixed=false
rung_name=""

case "$FAULT" in
  1)
    rung_name="rung 1 -- DNS"
    # getent, not dig or nslookup: always present, even where those two are
    # not (see content/day06.md, Read the file first).
    if in_proxy 'getent hosts app' >/dev/null 2>&1; then
      fault_fixed=true
    fi
    ;;
  2)
    rung_name="rung 2 -- route"
    # break.sh's fault 2 adds an `unreachable` route for app's address; it
    # never removes the default or connected route (see break.sh's
    # inject_2_route for why). Undone means no such route remains.
    if [ -z "$(in_proxy 'ip route show type unreachable' 2>/dev/null \
        || true)" ]
    then
      fault_fixed=true
    fi
    ;;
  3)
    rung_name="rung 3 -- firewall"
    if ! compose exec -T proxy nft list ruleset 2>/dev/null \
          | grep -Eq '8080.*drop|drop.*8080'; then
      fault_fixed=true
    fi
    ;;
  4)
    rung_name="rung 4 -- listener"
    # Strip-the-toolbox check: decode /proc/net/tcp by hand instead of
    # trusting ss, which app (Alpine) does not have anyway. Field 2 is
    # local_address, field 4 is st; 0A is LISTEN (see
    # content/primers/proc-field-reference.md, ## /proc/net/tcp).
    addr="$(compose exec -T app sh -c \
      "awk '\$2 ~ /:1F90\$/ && \$4 == \"0A\" {print \$2; exit}' /proc/net/tcp" \
      2>/dev/null | tr -d '\r' || true)"
    if [ "$addr" = "00000000:1F90" ]; then
      fault_fixed=true
    fi
    ;;
  5)
    rung_name="rung 5 -- application"
    code="$(compose exec -T app python3 -c '
import urllib.request, urllib.error
try:
    r = urllib.request.urlopen("http://127.0.0.1:8080/healthz")
    print(r.status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    pass
' 2>/dev/null | tr -d '\r' || true)"
    if [ "$code" = "200" ]; then
      fault_fixed=true
    fi
    ;;
  *)
    echo "Unrecognized fault marker on proxy: '${FAULT}'" >&2
    exit 1
    ;;
esac

e2e_code="$(in_ws \
  'curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://proxy/' \
  2>/dev/null || true)"

if [ "$fault_fixed" = "true" ] && [ "$e2e_code" = "200" ]; then
  echo "PASS: ${rung_name} was at fault, and it is fixed."
  echo "End-to-end: curl through proxy from ws -> 200."
  exit 0
fi

echo "FAIL: http://localhost:8080/ through proxy returns nothing useful." >&2
echo "  Name the rung before touching anything else." >&2
exit 1
