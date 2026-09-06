#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Day 5 is the only day that needs the sysd overlay. compose_sysd/in_sysd are
# defined here, not in ../lib/common.sh, so the other six days never see the
# extra -f and never depend on the sysd container being up.
compose_sysd() {
  docker compose -p linuxops \
    -f "${LABS_DIR}/fleet/docker-compose.yml" \
    -f "${LABS_DIR}/fleet/docker-compose.sysd.yml" "$@"
}
in_sysd() { compose_sysd exec -T sysd bash -c "$1"; }

require_sysd() {
  if [ -z "$(compose_sysd ps --status running --quiet sysd 2>/dev/null)" ]; then
    echo "sysd is not running. Bring up the Day 5 overlay first:" >&2
    echo "  cd ${LABS_DIR}/fleet" >&2
    echo "  docker compose -p linuxops -f docker-compose.yml \\" >&2
    echo "    -f docker-compose.sysd.yml up -d --build sysd" >&2
    echo "If it exits immediately, read the fleet README's Colima fallback." >&2
    exit 1
  fi
}
require_sysd

pass=0
fail=0

# Check 1: appuser can now read the file. Prefer sudo; fall back to su
# belt-and-braces in case sudo is ever absent — either way this proves the
# fix at the permission boundary, not just that root can read the file.
check1='if command -v sudo >/dev/null 2>&1; then
  sudo -u appuser cat /srv/reports/q3.txt
else
  su -s /bin/sh -c "cat /srv/reports/q3.txt" appuser
fi'
if in_sysd "$check1" >/dev/null 2>&1; then
  echo "PASS: appuser can read /srv/reports/q3.txt"
  pass=$((pass + 1))
else
  echo "FAIL: appuser still cannot read /srv/reports/q3.txt"
  fail=$((fail + 1))
fi

# Check 2: the unit is actually running, not merely "fixed on paper".
status="$(in_sysd 'systemctl is-active labs-api.service' 2>/dev/null || true)"
if [ "$status" = "active" ]; then
  echo "PASS: labs-api.service is active"
  pass=$((pass + 1))
else
  echo "FAIL: labs-api.service is not active (systemctl is-active: '${status}')"
  fail=$((fail + 1))
fi

# Check 3: the repaired unit file names After=labs-db.service. This is the
# check that stops "fixing" the ordering bug by deleting Requires= instead
# of adding the missing After= line next to it.
if in_sysd "grep -qE '^After=.*labs-db\\.service' /etc/systemd/system/labs-api.service" \
    >/dev/null 2>&1; then
  echo "PASS: labs-api.service declares After=labs-db.service"
  pass=$((pass + 1))
else
  echo "FAIL: labs-api.service has no After=labs-db.service line"
  fail=$((fail + 1))
fi

echo "---"
echo "${pass}/3 checks passed"
[ "$fail" -eq 0 ]
