#!/usr/bin/env bash
# dvwa_setup.sh -- initialize DVWA's database, log in as admin, and set
# the security level, entirely via curl from inside the attacker
# container (no host browser, no published port needed).
#
# Usage:  bash dvwa_setup.sh [low|medium|high|impossible]   (default: low)
#
# Prints diagnostic lines to stderr and, on success, ONE final line to
# stdout of the form:
#
#   Cookie: PHPSESSID=<value>; security=<level>
#
# Reuse that exact string with curl's -H "Cookie: ..." or sqlmap's
# --cookie="..." to act as the logged-in, security-level-set session.
#
# NOTE: this script is idempotent -- safe to re-run any time you want to
# switch security level (e.g. "low" for the Attack Lab, "impossible" for
# the Defense Lab) or refresh an expired session.
set -euo pipefail

LEVEL="${1:-low}"
HOST="http://dvwa"
JAR="$(mktemp)"
TMP="$(mktemp -d)"
trap 'rm -f "$JAR"; rm -rf "$TMP"' EXIT

log() { echo "[dvwa_setup] $*" >&2; }

# --- 1. Create / reset the database (idempotent). ---------------------
log "creating/resetting the DVWA database..."
curl -s -c "$JAR" -b "$JAR" "$HOST/setup.php" -o "$TMP/setup1.html"
curl -s -c "$JAR" -b "$JAR" -X POST "$HOST/setup.php" \
  --data-urlencode "create_db=Create / Reset Database" \
  -o "$TMP/setup2.html" || true

# --- 2. Log in as admin/password, extracting the CSRF user_token first. ---
log "logging in as admin..."
curl -s -c "$JAR" -b "$JAR" "$HOST/login.php" -o "$TMP/login1.html"
TOKEN="$(grep -oE "user_token['\"] value=['\"][a-f0-9]+" "$TMP/login1.html" \
  | grep -oE '[a-f0-9]{20,}' | head -1 || true)"
curl -s -c "$JAR" -b "$JAR" -X POST "$HOST/login.php" \
  --data-urlencode "username=admin" \
  --data-urlencode "password=password" \
  --data-urlencode "user_token=${TOKEN:-}" \
  --data-urlencode "Login=Login" \
  -o "$TMP/login2.html"

if ! grep -qi "logout" "$TMP/login2.html" 2>/dev/null; then
  log "WARNING: login response didn't obviously contain a logout link --"
  log "  check $TMP/login2.html's page source if this script's field names"
  log "  (username/password/user_token/Login) have drifted from what this"
  log "  DVWA image actually ships. See SOLUTION.md for a captured example."
fi

# --- 3. Set the security level. ----------------------------------------
log "setting security level to '$LEVEL'..."
curl -s -c "$JAR" -b "$JAR" "$HOST/security.php" -o "$TMP/sec1.html"
TOKEN2="$(grep -oE "user_token['\"] value=['\"][a-f0-9]+" "$TMP/sec1.html" \
  | grep -oE '[a-f0-9]{20,}' | head -1 || true)"
if [ -n "${TOKEN2:-}" ]; then
  curl -s -c "$JAR" -b "$JAR" -X POST "$HOST/security.php" \
    --data-urlencode "security=$LEVEL" \
    --data-urlencode "seclev_submit=Submit" \
    --data-urlencode "user_token=$TOKEN2" \
    -o "$TMP/sec2.html"
else
  curl -s -c "$JAR" -b "$JAR" -X POST "$HOST/security.php" \
    --data-urlencode "security=$LEVEL" \
    --data-urlencode "seclev_submit=Submit" \
    -o "$TMP/sec2.html"
fi

# --- 4. Build and print the reusable Cookie header. ---------------------
PHPSESSID="$(awk -F'\t' '$6=="PHPSESSID"{print $7}' "$JAR" | tail -1)"
if [ -z "$PHPSESSID" ]; then
  log "ERROR: could not extract PHPSESSID from the cookie jar -- setup"
  log "  likely failed upstream. Inspect $TMP/*.html before it's cleaned up"
  log "  (this script's trap will remove it on exit)."
  exit 1
fi
echo "Cookie: PHPSESSID=${PHPSESSID}; security=${LEVEL}"
