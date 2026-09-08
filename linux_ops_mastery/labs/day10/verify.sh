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

echo "[day10 verify] Checking fix..."

if bash /tmp/lab10/inspect.sh > /dev/null 2>&1; then
  check "inspect.sh exits non-zero with no arguments" fail
else
  check "inspect.sh exits non-zero with no arguments" pass
fi

if bash /tmp/lab10/inspect.sh notapid > /dev/null 2>&1; then
  check "inspect.sh exits non-zero with non-numeric argument" fail
else
  check "inspect.sh exits non-zero with non-numeric argument" pass
fi

if bash /tmp/lab10/inspect.sh 1 > /dev/null 2>&1; then
  check "inspect.sh exits 0 with valid PID (1)" pass
else
  check "inspect.sh exits 0 with valid PID (1)" fail
fi

stderr_out=$(bash /tmp/lab10/inspect.sh 2>&1 1>/dev/null || true)
if [[ -n "$stderr_out" ]]; then
  check "inspect.sh prints error/usage to stderr on invalid call" pass
else
  check "inspect.sh prints error/usage to stderr on invalid call" fail
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
