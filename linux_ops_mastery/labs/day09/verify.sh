#!/usr/bin/env bash
# Works with macOS /bin/bash 3.2 and Linux bash 5.x.
set -uo pipefail

PASS=0
FAIL=0
LAB=/tmp/lab09
OUT=$LAB/verify.out

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"; PASS=$((PASS+1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

stale() { find "$LAB" -maxdepth 1 -name 'work.*' -type d 2>/dev/null | wc -l | tr -d ' '; }

echo "[day09 verify] Checking fix..."

if [[ ! -f $LAB/deploy.sh ]]; then
  echo "  $LAB/deploy.sh not found — run labs/day09/break.sh first."; exit 1
fi

# 1. The cleanup must hang off EXIT, the one trap that fires on every exit.
if grep -Eq "^[[:space:]]*trap[[:space:]].*EXIT" $LAB/deploy.sh; then
  check "deploy.sh registers an EXIT trap" pass
else
  check "deploy.sh registers an EXIT trap" fail
fi

# 2. A normal run finishes, deploys every server, and leaves nothing behind.
rm -rf $LAB/work.*
bash $LAB/deploy.sh > "$OUT" 2>&1
rc=$?
deployed=$(grep -c '^Deploying to server-' "$OUT")
if [[ $rc -eq 0 && $deployed -eq 8 && $(stale) -eq 0 ]]; then
  check "normal run: exit 0, 8 servers deployed, no work.* left" pass
else
  check "normal run: exit 0, 8 servers deployed, no work.* left (got rc=$rc, deployed=$deployed, left=$(stale))" fail
fi

# 3. Killed mid-run (SIGTERM, as from kill, timeout or docker stop): it must
#    stop, clean up, and report death-by-signal. SIGTERM, not SIGINT: a
#    background job started by a non-interactive shell ignores SIGINT.
rm -rf $LAB/work.*
bash $LAB/deploy.sh > "$OUT" 2>&1 &
pid=$!
sleep 1
kill -TERM "$pid" 2>/dev/null
wait "$pid"
rc=$?
if [[ $rc -ge 128 && $(stale) -eq 0 ]] && ! grep -q 'Deployment complete' "$OUT"; then
  check "killed mid-run: stops (exit $rc), no work.* left" pass
else
  completed=$(grep -c 'Deployment complete' "$OUT")
  check "killed mid-run: stops, no work.* left (got rc=$rc, left=$(stale), kept going=$completed)" fail
fi

rm -rf $LAB/work.* "$OUT"
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
