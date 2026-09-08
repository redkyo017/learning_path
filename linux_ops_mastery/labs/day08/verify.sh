#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"; ((PASS++))
  else
    echo "  FAIL: $desc"; ((FAIL++))
  fi
}

echo "[day08 verify] Checking fix..."

if grep -qE 'pipefail' /tmp/lab08/backup.sh 2>/dev/null; then
  check "backup.sh contains pipefail" pass
else
  check "backup.sh contains pipefail" fail
fi

if bash /tmp/lab08/backup.sh > /dev/null 2>&1; then
  check "fixed backup.sh exits non-zero on permission-denied find" fail
else
  check "fixed backup.sh exits non-zero on permission-denied find" pass
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
