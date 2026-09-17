#!/usr/bin/env bash
# WSO2 Production Triage Script
# Usage: bash debug.sh <logfile> [--activity-id <id>]
# Exits 0 if no failures found, 1 if any found.

set -euo pipefail

FILE="${1:-}"
ACTIVITY_ID=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity-id) ACTIVITY_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Usage: bash debug.sh <logfile> [--activity-id <id>]"
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE"
  exit 2
fi

# If activity-id given, pre-filter
INPUT="$FILE"
TMPFILE=""
if [[ -n "$ACTIVITY_ID" ]]; then
  TMPFILE=$(mktemp)
  grep -F "$ACTIVITY_ID" "$FILE" > "$TMPFILE" || true
  INPUT="$TMPFILE"
fi

# Count matches using grep
count_matches() {
  CLASS="$1"
  case "$CLASS" in
    AUTH_FAILED)
      grep -c "Invalid Credentials\|900901" "$INPUT" 2>/dev/null || echo "0"
      ;;
    SUBSCRIPTION_NOT_FOUND)
      grep -c "no valid subscription\|900908" "$INPUT" 2>/dev/null || echo "0"
      ;;
    THROTTLE_EXCEEDED)
      grep -c "Throttle limit exceeded\|900800" "$INPUT" 2>/dev/null || echo "0"
      ;;
    BACKEND_TIMEOUT)
      grep -c "connection timed out\|read timeout" "$INPUT" 2>/dev/null || echo "0"
      ;;
    JWT_EXPIRED)
      grep -c "JWT expired\|token expired\|\bexp\b claim" "$INPUT" 2>/dev/null || echo "0"
      ;;
    JWT_INVALID_SIGNATURE)
      grep -c "Signature verification failed\|invalid JWT" "$INPUT" 2>/dev/null || echo "0"
      ;;
    EVENT_SYNC_LAG)
      grep -c "eventHub.*error\|sync lag\|event sync.*fail" "$INPUT" 2>/dev/null || echo "0"
      ;;
  esac
}

get_first_match() {
  CLASS="$1"
  case "$CLASS" in
    AUTH_FAILED)
      grep "Invalid Credentials\|900901" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    SUBSCRIPTION_NOT_FOUND)
      grep "no valid subscription\|900908" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    THROTTLE_EXCEEDED)
      grep "Throttle limit exceeded\|900800" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    BACKEND_TIMEOUT)
      grep "connection timed out\|read timeout" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    JWT_EXPIRED)
      grep "JWT expired\|token expired\|\bexp\b claim" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    JWT_INVALID_SIGNATURE)
      grep "Signature verification failed\|invalid JWT" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
    EVENT_SYNC_LAG)
      grep "eventHub.*error\|sync lag\|event sync.*fail" "$INPUT" 2>/dev/null | head -1 | head -c 120
      ;;
  esac
}

get_action() {
  case "$1" in
    AUTH_FAILED) echo "Check subscription in CP; verify IS /oauth2/token health" ;;
    SUBSCRIPTION_NOT_FOUND) echo "Restart GW to re-sync from CP /admin/sync" ;;
    THROTTLE_EXCEEDED) echo "Check TM health; check GW->TM SG ports 9611/9711" ;;
    BACKEND_TIMEOUT) echo "Check backend ECS task; check SG rules" ;;
    JWT_EXPIRED) echo "Client must re-authenticate; check NTP sync" ;;
    JWT_INVALID_SIGNATURE) echo "curl IS /oauth2/jwks; restart GW to reload JWKS" ;;
    EVENT_SYNC_LAG) echo "Restart GW; check CP /admin/sync endpoint" ;;
  esac
}

FOUND=0
echo "=== WSO2 Triage: $FILE ==="
if [[ -n "$ACTIVITY_ID" ]]; then
  echo "=== Filtered to activityId: $ACTIVITY_ID ==="
fi
echo ""

for CLASS in AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE EVENT_SYNC_LAG; do
  COUNT=$(count_matches "$CLASS")
  COUNT=$(echo "$COUNT" | tr -d ' \n')
  if [ "$COUNT" -gt 0 ] 2>/dev/null; then
    FOUND=1
    FIRST=$(get_first_match "$CLASS")
    ACTION=$(get_action "$CLASS")
    printf "  %-30s %3d hit(s)  Action: %s\n" "$CLASS" "$COUNT" "$ACTION"
    printf "  First: %s\n\n" "$FIRST"
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "  No known failure patterns found."
fi

if [[ -n "$TMPFILE" ]]; then
  rm -f "$TMPFILE"
fi
exit $FOUND
