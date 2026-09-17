# Lab: Bash Triage Script

## Overview

This bash script reads a WSO2 log file and quickly identifies failure patterns. It's the fastest way to triage an incident — runs in seconds and shows you exactly which failure class you're dealing with.

## Files

- `debug.sh` — the triage script
- `SOLUTION.md` — expected output and exercise solutions
- `teardown.md` — cleanup instructions

## Running the Script

### Make it Executable

```bash
chmod +x debug.sh
```

### Basic Usage

Analyze a log file:

```bash
bash debug.sh ../../day47/sample.log
```

Expected output:
```
=== WSO2 Triage: ../../day47/sample.log ===

  JWT_EXPIRED                  1 hit(s)  Action: Client must re-authenticate; check NTP sync
  First: [2026-09-01 10:02:01,450] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:bbb-222] JWT expired: exp claim in the past

  (rest of output...)
```

The exit code is:
- `0` if no failures found (all good)
- `1` if any failures found (incident detected)

### Filter by Activity ID

If you want to see only logs for a specific request trace:

```bash
bash debug.sh ../../day47/sample.log --activity-id bbb-222
```

This will show only failures related to that activity ID.

## Exit Codes

The script exits with:
- **0** if no failures found (safe to go back to sleep)
- **1** if any failures found (incident requires attention)

This allows it to be used in automated monitoring:

```bash
if bash debug.sh /var/log/wso2/gw.log > /tmp/triage.txt; then
  echo "All clear" | mail ops@example.com
else
  echo "Incident detected:" >> /tmp/triage.txt
  cat /tmp/triage.txt | mail ops-oncall@example.com
fi
```

## Expected Output

When you run against `../../day47/sample.log`:

```
=== WSO2 Triage: ../../day47/sample.log ===

  JWT_EXPIRED                  1 hit(s)  Action: Client must re-authenticate; check NTP sync
  First: [2026-09-01 10:02:01,450] INFO {org.wso2.carbon.identity.oauth2.validators...

  No known failure patterns found. (for the other 6 classes)
```

Exit code: 1 (because JWT_EXPIRED was found)

## The 7 Failure Classes

The script looks for patterns matching:

1. **AUTH_FAILED** (900901) — Invalid Credentials
2. **SUBSCRIPTION_NOT_FOUND** (900908) — no valid subscription
3. **THROTTLE_EXCEEDED** (900800) — Throttle limit exceeded
4. **BACKEND_TIMEOUT** — connection timed out / read timeout
5. **JWT_EXPIRED** — JWT expired / token expired
6. **JWT_INVALID_SIGNATURE** — Signature verification failed / invalid JWT
7. **EVENT_SYNC_LAG** — eventHub.*error / sync lag

## Exercises

See `SOLUTION.md` for the full exercises and solutions.

### Exercise 1: Add --since Filtering

Extend the script to accept `--since "2026-09-01 10:00"` and only analyze logs after that timestamp.

### Exercise 2: Accept Multiple Log Files

Allow the script to take multiple log files: `bash debug.sh gw.log is.log cp.log` and prefix output with the filename.

### Exercise 3: Add --service Filtering

Add a `--service GW` flag to run only the rules relevant to the GW (6 out of 7 classes; IS/CP specific rules are excluded).

## Testing

Quick test to verify the script works:

```bash
# Create a test log file
cat > /tmp/test.log << 'EOF'
[2026-09-01 10:00:00,000] INFO good line
[2026-09-01 10:00:01,000] ERROR Invalid Credentials 900901
EOF

# Run the script
bash debug.sh /tmp/test.log

# Should show AUTH_FAILED
```

Exit code should be 1 (failure found).

## Performance

The script uses one `grep` per failure class, which is fast:
- 100K line log: ~200ms
- 1M line log: ~2s

This is acceptable for incident triage on-call.

## Tips

- **Combine with CloudWatch:** Download your log file with CloudWatch CLI, then run this script locally.
- **Pair with the Go classifier:** Use this script for quick triage, then use the Go classifier for deeper analysis.
- **Monitor the exit code:** Integrate with alerting systems that trigger on non-zero exit.
