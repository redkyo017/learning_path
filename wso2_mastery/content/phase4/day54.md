# Day 54: Building a Bash Triage Script

## Why This Matters

A bash triage script runs in **seconds** against live CloudWatch log downloads and produces a report before you've opened a second terminal tab. It's the first thing you run when an incident is reported.

**Time value:** Manual grepping takes 2 minutes. A triage script takes 5 seconds and prints the exact summary you need.

---

## Core Concepts

### The debug.sh Script

The `labs/phase4/day54/debug.sh` program:
1. Takes a log file path as the first argument
2. Optionally takes `--activity-id <id>` to filter to a specific request trace
3. Runs 7 grep patterns (one per failure class)
4. For each pattern that matches:
   - Counts the number of hits
   - Prints the first matching line
   - Suggests the immediate action
5. Exits 0 if no failures found, 1 if any found (so it can be used in alerts)

### Exit Codes Matter

```bash
exit 0  # No failures found (green light)
exit 1  # Failures found (red light, alert should fire)
```

This allows the script to be used in automated monitoring:
```bash
if bash debug.sh gw.log; then
  echo "All clear"
else
  echo "Incident detected, paging SRE"
fi
```

### Associative Arrays

Bash arrays let you define patterns and actions:
```bash
declare -A PATTERNS
PATTERNS[AUTH_FAILED]="Invalid Credentials|900901"
PATTERNS[SUBSCRIPTION_NOT_FOUND]="no valid subscription|900908"
```

Then loop over them:
```bash
for CLASS in "${!PATTERNS[@]}"; do
  PAT="${PATTERNS[$CLASS]}"
  grep -E "$PAT" "$FILE"
done
```

### One Grep Per Class

Running `grep "pattern1|pattern2|...|pattern7"` in one pass loses which class matched. Always run one grep per class so you know which action to take.

---

## The Triage Workflow

1. **Incident reported:** "API is returning 401"
2. **You run:** `bash debug.sh gw.log`
3. **You see:** 
   ```
   JWT_EXPIRED             3 hit(s)  Action: Client re-auth; check NTP
   JWT_INVALID_SIGNATURE   1 hit(s)  Action: Restart GW to reload JWKS
   ```
4. **You know:** Either the token is expired (client re-auth) or the signature check failed (restart GW).
5. **You check:** Client token expiry, then restart GW if needed.

Without the script, you'd be grepping manually, scrolling through logs, trying to count matches.

---

## Anti-Patterns to Avoid

1. **Running all 7 patterns in one grep.** Example: `grep -E "pattern1|pattern2|...|pattern7"` loses which class matched. Instead, run one grep per class.

2. **Not quoting the FILE variable.** If the log file path has spaces, the script breaks:
   ```bash
   # WRONG
   grep "$PAT" $FILE
   
   # RIGHT
   grep "$PAT" "$FILE"
   ```

3. **Printing only the count without the first matching line.** The count tells you "it broke". The first line tells you "why and where". Always print both.

4. **Hardcoding the failure class order.** Use an array to define the order, so you can easily move classes around or add new ones.

---

## Exercises

### Exercise 1: Add --since Filtering (Hint: awk '$1 >= since')

**Scenario:** The log file has 100K lines spanning a week. You only care about the last hour because that's when the incident started. Extend `debug.sh` to accept `--since "2026-09-01 10:00"` and filter lines before running grep.

**Hint:** Timestamps in WSO2 logs are in the format `[YYYY-MM-DD HH:MM:SS,mmm]`. Use `awk` to filter lines with timestamps >= the `--since` value.

**Solution Sketch:**
```bash
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [[ -n "$SINCE" ]]; then
  # Pre-filter lines with awk by timestamp
  awk -v s="$SINCE" '$0 ~ /^\[/ && substr($0,2,19) >= s' "$FILE" > /tmp/filtered.log
  FILE=/tmp/filtered.log
fi

# Then run grep patterns on the filtered file
```

---

### Exercise 2: Accept Multiple Log Files (Hint: Loop Over "$@")

**Scenario:** An incident spans GW, IS, and CP logs. You want to run: `bash debug.sh gw.log is.log cp.log`. How would you modify the script to handle multiple files?

**Hint:** Use a for loop over `"$@"` to iterate all arguments. Prefix output with the filename so you know which log the failure came from.

**Solution Sketch:**
```bash
for FILE in "$@"; do
  echo "=== Processing $FILE ==="
  for CLASS in "${ORDER[@]}"; do
    PAT="${PATTERNS[$CLASS]}"
    COUNT=$(grep -cE "$PAT" "$FILE" 2>/dev/null || echo 0)
    if [[ "$COUNT" -gt 0 ]]; then
      FIRST=$(grep -mE1 "$PAT" "$FILE" | head -c 120)
      printf "[%s] %-30s %3d hit(s)  Action: %s\n" "$FILE" "$CLASS" "$COUNT" "${ACTIONS[$CLASS]}"
    fi
  done
done
```

---

### Exercise 3: Add --service Filtering (Hint: Associative Arrays Per Service)

**Scenario:** You have rules for all 7 failure classes, but some only apply to the GW, and others only to the IS. Add a `--service GW` flag that runs only the GW-relevant rules.

**Hint:** GW failures: AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE. IS failures: JWT_INVALID_SIGNATURE, EVENT_SYNC_LAG (and CP failures are different). Define a map of service → rules.

**Solution Sketch:**
```bash
SERVICE=""
declare -A SERVICE_RULES
SERVICE_RULES[GW]="AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE"
SERVICE_RULES[IS]="JWT_INVALID_SIGNATURE EVENT_SYNC_LAG"
SERVICE_RULES[CP]="EVENT_SYNC_LAG"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [[ -n "$SERVICE" ]]; then
  CLASSES_TO_CHECK="${SERVICE_RULES[$SERVICE]}"
else
  CLASSES_TO_CHECK="${!PATTERNS[@]}"
fi

for CLASS in ${CLASSES_TO_CHECK}; do
  PAT="${PATTERNS[$CLASS]}"
  # ... run grep
done
```

---

## Key Takeaway

The bash script is your first responder. It runs on any machine with bash (no Go, no dependencies). Use it to triage the incident in seconds, then dig deeper if needed.

When you see multiple failure classes in the output, look for **cascading failures**: if JWT_INVALID_SIGNATURE and BACKEND_TIMEOUT both appear, maybe the JWT check failed (EVENT_SYNC_LAG), so the GW fell back to a permissive auth, but then couldn't reach the backend (BACKEND_TIMEOUT).

The failure classes are connected. Reading the catalog (day52/failure_catalog.md) will help you spot the root cause.
