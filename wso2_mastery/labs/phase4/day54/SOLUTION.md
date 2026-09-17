# Exercise Solutions

## Exercise 1: Add --since Filtering

**Task:** Extend the script to accept `--since "2026-09-01 10:00"` and filter lines by timestamp before running the grep patterns.

**Solution:**

```bash
#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"
ACTIVITY_ID=""
SINCE=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity-id) ACTIVITY_ID="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Usage: bash debug.sh <logfile> [--activity-id <id>] [--since 'YYYY-MM-DD HH:MM']"
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE"
  exit 2
fi

# Pre-filter by activity-id if given
INPUT="$FILE"
if [[ -n "$ACTIVITY_ID" ]]; then
  TMPFILE=$(mktemp)
  grep -F "$ACTIVITY_ID" "$FILE" > "$TMPFILE" || true
  INPUT="$TMPFILE"
fi

# Pre-filter by timestamp if given
if [[ -n "$SINCE" ]]; then
  TMPFILE2=$(mktemp)
  # WSO2 log format: [YYYY-MM-DD HH:MM:SS,mmm]
  # Extract the timestamp and compare
  awk -v s="$SINCE" '$0 ~ /^\[/ && substr($0,2,16) >= substr(s,1,16)' "$INPUT" > "$TMPFILE2"
  INPUT="$TMPFILE2"
fi

# ... rest of the script (patterns, actions, etc.)
```

**How to use:**

```bash
# Show only failures after 10:00
bash debug.sh ../../day47/sample.log --since "2026-09-01 10:00"

# Combine with activity-id
bash debug.sh ../../day47/sample.log --activity-id bbb-222 --since "2026-09-01 10:00"
```

**How it works:**
- `awk -v s="$SINCE" '$0 ~ /^\[/ && substr($0,2,16) >= substr(s,1,16)'`
- `-v s="$SINCE"` passes the `--since` value to awk
- `$0 ~ /^\[/` matches lines starting with `[` (WSO2 logs)
- `substr($0,2,16)` extracts characters 2-16 (the timestamp: `YYYY-MM-DD HH:MM`)
- `substr(s,1,16)` extracts the same from the `--since` argument
- `>=` compares them as strings (works because YYYY-MM-DD HH:MM is lexicographically sortable)

---

## Exercise 2: Accept Multiple Log Files

**Task:** Extend the script to accept multiple log files: `bash debug.sh gw.log is.log cp.log` and prefix each output line with the filename.

**Solution:**

```bash
#!/usr/bin/env bash
set -euo pipefail

FILES=()
ACTIVITY_ID=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity-id) ACTIVITY_ID="$2"; shift 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: bash debug.sh <logfile1> [<logfile2> ...] [--activity-id <id>]"
  exit 2
fi

declare -A PATTERNS
PATTERNS[AUTH_FAILED]="Invalid Credentials|900901"
PATTERNS[SUBSCRIPTION_NOT_FOUND]="no valid subscription|900908"
PATTERNS[THROTTLE_EXCEEDED]="Throttle limit exceeded|900800"
PATTERNS[BACKEND_TIMEOUT]="connection timed out|read timeout"
PATTERNS[JWT_EXPIRED]="JWT expired|token expired"
PATTERNS[JWT_INVALID_SIGNATURE]="Signature verification failed|invalid JWT"
PATTERNS[EVENT_SYNC_LAG]="eventHub.*error|sync lag"

declare -A ACTIONS
ACTIONS[AUTH_FAILED]="Check subscription in CP; verify IS token health"
ACTIONS[SUBSCRIPTION_NOT_FOUND]="Restart GW to re-sync from CP /admin/sync"
ACTIONS[THROTTLE_EXCEEDED]="Check TM health; check GW->TM SG ports 9611/9711"
ACTIONS[BACKEND_TIMEOUT]="Check backend ECS task; check SG rules"
ACTIONS[JWT_EXPIRED]="Client must re-authenticate; check NTP sync"
ACTIONS[JWT_INVALID_SIGNATURE]="curl IS /oauth2/jwks; restart GW to reload JWKS"
ACTIONS[EVENT_SYNC_LAG]="Restart GW; check CP /admin/sync endpoint"

ORDER=(AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE EVENT_SYNC_LAG)

FOUND=0
for FILE in "${FILES[@]}"; do
  if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE"
    continue
  fi

  INPUT="$FILE"
  if [[ -n "$ACTIVITY_ID" ]]; then
    TMPFILE=$(mktemp)
    grep -F "$ACTIVITY_ID" "$FILE" > "$TMPFILE" || true
    INPUT="$TMPFILE"
  fi

  echo "=== WSO2 Triage: $FILE ==="
  [[ -n "$ACTIVITY_ID" ]] && echo "=== Filtered to activityId: $ACTIVITY_ID ==="
  echo ""

  for CLASS in "${ORDER[@]}"; do
    PAT="${PATTERNS[$CLASS]}"
    COUNT=$(grep -cE "$PAT" "$INPUT" 2>/dev/null || echo 0)
    if [[ "$COUNT" -gt 0 ]]; then
      FOUND=1
      FIRST=$(grep -mE1 "$PAT" "$INPUT" | head -c 100)
      printf "  [%s] %-20s %3d hit(s)  Action: %s\n" "$FILE" "$CLASS" "$COUNT" "${ACTIONS[$CLASS]}"
      printf "      First: %s\n\n" "$FIRST"
    fi
  done

  echo ""
  [[ -n "$ACTIVITY_ID" ]] && rm -f "$TMPFILE"
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "No known failure patterns found in any files."
fi

exit $FOUND
```

**How to use:**

```bash
bash debug.sh gw.log is.log cp.log
bash debug.sh gw.log is.log cp.log --activity-id abc-123
```

**Key changes:**
- `FILES=()` is an array to hold multiple filenames
- The argument parsing loop populates `FILES` for positional args and still handles `--activity-id`
- Outer loop iterates over each file in `"${FILES[@]}"`
- Each file gets its own header and results
- Output lines are prefixed with the filename: `[gw.log]`, `[is.log]`, etc.

---

## Exercise 3: Add --service Filtering

**Task:** Add a `--service GW` flag that runs only the rules relevant to the GW (AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE) and skips EVENT_SYNC_LAG.

**Solution:**

```bash
#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"
ACTIVITY_ID=""
SERVICE=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity-id) ACTIVITY_ID="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Usage: bash debug.sh <logfile> [--activity-id <id>] [--service GW|IS|CP]"
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE"
  exit 2
fi

declare -A PATTERNS
PATTERNS[AUTH_FAILED]="Invalid Credentials|900901"
PATTERNS[SUBSCRIPTION_NOT_FOUND]="no valid subscription|900908"
PATTERNS[THROTTLE_EXCEEDED]="Throttle limit exceeded|900800"
PATTERNS[BACKEND_TIMEOUT]="connection timed out|read timeout"
PATTERNS[JWT_EXPIRED]="JWT expired|token expired"
PATTERNS[JWT_INVALID_SIGNATURE]="Signature verification failed|invalid JWT"
PATTERNS[EVENT_SYNC_LAG]="eventHub.*error|sync lag"

declare -A ACTIONS
ACTIONS[AUTH_FAILED]="Check subscription in CP; verify IS token health"
ACTIONS[SUBSCRIPTION_NOT_FOUND]="Restart GW to re-sync from CP /admin/sync"
ACTIONS[THROTTLE_EXCEEDED]="Check TM health; check GW->TM SG ports 9611/9711"
ACTIONS[BACKEND_TIMEOUT]="Check backend ECS task; check SG rules"
ACTIONS[JWT_EXPIRED]="Client must re-authenticate; check NTP sync"
ACTIONS[JWT_INVALID_SIGNATURE]="curl IS /oauth2/jwks; restart GW to reload JWKS"
ACTIONS[EVENT_SYNC_LAG]="Restart GW; check CP /admin/sync endpoint"

# Define which classes apply to each service
declare -A SERVICE_RULES
SERVICE_RULES[GW]="AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE"
SERVICE_RULES[IS]="JWT_INVALID_SIGNATURE EVENT_SYNC_LAG"
SERVICE_RULES[CP]="EVENT_SYNC_LAG"
SERVICE_RULES[TM]="THROTTLE_EXCEEDED"

# If service specified, use only those rules; else use all
CLASSES_TO_CHECK="${SERVICE_RULES[$SERVICE]:-AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE EVENT_SYNC_LAG}"

INPUT="$FILE"
if [[ -n "$ACTIVITY_ID" ]]; then
  TMPFILE=$(mktemp)
  grep -F "$ACTIVITY_ID" "$FILE" > "$TMPFILE" || true
  INPUT="$TMPFILE"
fi

FOUND=0
echo "=== WSO2 Triage: $FILE ==="
[[ -n "$ACTIVITY_ID" ]] && echo "=== Filtered to activityId: $ACTIVITY_ID ==="
[[ -n "$SERVICE" ]] && echo "=== Filtered to service: $SERVICE ==="
echo ""

for CLASS in $CLASSES_TO_CHECK; do
  PAT="${PATTERNS[$CLASS]}"
  COUNT=$(grep -cE "$PAT" "$INPUT" 2>/dev/null || echo 0)
  if [[ "$COUNT" -gt 0 ]]; then
    FOUND=1
    FIRST=$(grep -mE1 "$PAT" "$INPUT" | head -c 120)
    printf "  %-30s %3d hit(s)  Action: %s\n" "$CLASS" "$COUNT" "${ACTIONS[$CLASS]}"
    printf "  First: %s\n\n" "$FIRST"
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "  No known failure patterns found."
fi

[[ -n "$ACTIVITY_ID" ]] && rm -f "$TMPFILE"
exit $FOUND
```

**How to use:**

```bash
# Show all failure classes (default)
bash debug.sh gw.log

# Show only GW-relevant failures
bash debug.sh gw.log --service GW

# Show only IS-relevant failures
bash debug.sh is.log --service IS

# Combine filters
bash debug.sh gw.log --service GW --activity-id abc-123
```

**Key changes:**
- `SERVICE_RULES` array maps service name to the list of relevant failure classes
- `CLASSES_TO_CHECK` either uses the service-specific list (if `--service` is given) or all 7 classes (default)
- The main loop iterates only over `$CLASSES_TO_CHECK` instead of a fixed order

**Service mappings:**
- **GW:** AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE
- **IS:** JWT_INVALID_SIGNATURE, EVENT_SYNC_LAG
- **CP:** EVENT_SYNC_LAG
- **TM:** THROTTLE_EXCEEDED

This allows you to run `bash debug.sh is.log --service IS` and skip checking for GW-specific failures.

---

## Testing

Here's a script to test all three exercises:

```bash
#!/bin/bash

# Test 1: --since filtering
echo "Test 1: --since filtering"
bash debug.sh ../../day47/sample.log --since "2026-09-01 10:00"
echo "Exit code: $?"
echo ""

# Test 2: Multiple files
echo "Test 2: Multiple files (if you have multiple log files)"
# Create test files
echo "[2026-09-01 10:00:00,000] ERROR Invalid Credentials 900901" > /tmp/gw.log
echo "[2026-09-01 10:00:00,000] ERROR Signature verification failed" > /tmp/is.log
bash debug.sh /tmp/gw.log /tmp/is.log
echo "Exit code: $?"
echo ""

# Test 3: --service filtering
echo "Test 3: --service filtering"
bash debug.sh ../../day47/sample.log --service GW
echo "Exit code: $?"
echo ""

echo "Tests complete!"
```

---

## Takeaway

- **Exit codes matter.** Use them to integrate with automated monitoring.
- **Timestamps are useful.** Filter by time to reduce noise.
- **Multiple files need prefixes.** Don't lose track of which log a failure came from.
- **Service-specific rules are optional.** Not every incident spans all components.
