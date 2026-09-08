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

echo "[day09 verify] Checking fix..."

if grep -q 'trap ' /tmp/lab09/deploy.sh 2>/dev/null; then
  check "deploy.sh registers a trap" pass
else
  check "deploy.sh registers a trap" fail
fi

rm -rf /tmp/lab09/work.*
bash /tmp/lab09/deploy.sh &
DEPLOY_PID=$!
sleep 0.8
kill -INT "$DEPLOY_PID" 2>/dev/null || true
sleep 0.5

stale_count=$(find /tmp/lab09 -maxdepth 1 -name 'work.*' -type d 2>/dev/null | wc -l)
if [[ "$stale_count" -eq 0 ]]; then
  check "no stale work directories after Ctrl-C interrupt" pass
else
  check "no stale work directories after Ctrl-C interrupt" fail
fi

rm -rf /tmp/lab09/work.*
if bash /tmp/lab09/deploy.sh > /dev/null 2>&1; then
  check "second run completes without stale-directory failure" pass
else
  check "second run completes without stale-directory failure" fail
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
