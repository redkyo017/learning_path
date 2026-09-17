# Day 48 — Extended Tracer: Filtering and JSON Output Lab

## Goal

Extend the Day 47 parser with production-grade features:
1. Filter by activityId with `--id` flag
2. Filter by service(s) with `--service` flag (comma-separated)
3. Output JSON with `--format json`
4. Implement elapsed time calculation per service

## Quick Start

### 1. Copy Sample Log from Day 47

The sample.log from Day 47 is reused here. If you don't have it, create it:

```bash
cat > sample.log << 'EOF'
[2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Request received: POST /petstore/v1/pets
[2026-09-01 10:01:23,150] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:aaa-111] JWT validated for client demo-client-id
[2026-09-01 10:01:23,200] INFO {org.wso2.carbon.apimgt.impl.APIManagerImpl} - [activityId:aaa-111] Subscription check passed tier=Gold
[2026-09-01 10:01:23,220] INFO {org.wso2.carbon.throttle.core.ThrottleHandler} - [activityId:aaa-111] Throttle check passed
[2026-09-01 10:01:23,300] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Response sent: 200
[2026-09-01 10:02:01,400] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
[2026-09-01 10:02:01,450] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:bbb-222] JWT expired: exp claim in the past
[2026-09-01 10:02:01,460] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Response sent: 401
EOF
```

### 2. Test Basic Operation

```bash
go run main.go < sample.log
```

Should print both traces (aaa-111 and bbb-222).

### 3. Test `--id` Filter

```bash
go run main.go --id aaa-111 < sample.log
```

Expected output: Only the aaa-111 trace with 5 lines.

### 4. Test `--service` Filter

```bash
go run main.go --service GW < sample.log
```

Expected output: Both traces, but only GW lines (3 lines from aaa-111, 2 from bbb-222).

```bash
go run main.go --service GW,IS < sample.log
```

Expected output: Both traces with GW and IS lines only.

### 5. Test JSON Output

```bash
go run main.go --format json < sample.log
```

Expected output: Valid JSON with timestamp, level, service, activityId, and message for each line.

### 6. Test Combined Flags

```bash
go run main.go --id aaa-111 --service GW,IS --format json < sample.log
```

Expected output: JSON array of only GW and IS lines from trace aaa-111.

---

## Command Reference

### `--id <UUID>`

Filter to a single trace by activityId.

```bash
go run main.go --id 3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a < prod.log
```

- If the ID exists: prints only that trace
- If the ID doesn't exist: prints "no trace found for id X" to stderr, exits 0 (not an error)

### `--service <comma-separated-list>`

Filter to one or more services. Services: GW, IS, CP, TM.

```bash
go run main.go --service GW,IS < prod.log
go run main.go --service IS < prod.log
```

- Case-insensitive, whitespace-tolerant
- When combined with `--id`: filters lines within that trace
- Empty result lines are skipped (no "=== Trace ===" printed if no lines match)

### `--format text|json`

Output format. Default is `text`.

**Text format:**
```
=== Trace: aaa-111 (5 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  ...
```

**JSON format:**
```json
[
  {
    "timestamp": "2026-09-01T10:01:23Z",
    "level": "INFO",
    "service": "GW",
    "activityId": "aaa-111",
    "message": "[activityId:aaa-111] Request received: POST /petstore/v1/pets"
  }
]
```

---

## Expected Output Examples

### Example 1: Filter to One Trace

```bash
$ go run main.go --id aaa-111 < sample.log

=== Trace: aaa-111 (5 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  [10:01:23.200] CP   INFO   [activityId:aaa-111] Subscription check passed tier=Gold
  [10:01:23.220] TM   INFO   [activityId:aaa-111] Throttle check passed
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200
```

### Example 2: Filter to Services Only

```bash
$ go run main.go --service GW,IS < sample.log

=== Trace: aaa-111 (3 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200

=== Trace: bbb-222 (2 lines) ===
  [10:02:01.400] GW   INFO   [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  [10:02:01.460] GW   INFO   [activityId:bbb-222] Response sent: 401
```

### Example 3: JSON Output

```bash
$ go run main.go --id bbb-222 --format json < sample.log

[
  {
    "timestamp": "2026-09-01T10:02:01Z",
    "level": "INFO",
    "service": "GW",
    "activityId": "bbb-222",
    "message": "[activityId:bbb-222] Request received: GET /petstore/v1/pets/1"
  },
  {
    "timestamp": "2026-09-01T10:02:01Z",
    "level": "INFO",
    "service": "IS",
    "activityId": "bbb-222",
    "message": "[activityId:bbb-222] JWT expired: exp claim in the past"
  },
  {
    "timestamp": "2026-09-01T10:02:01Z",
    "level": "INFO",
    "service": "GW",
    "activityId": "bbb-222",
    "message": "[activityId:bbb-222] Response sent: 401"
  }
]
```

---

## Real-World Use Cases

### Triage: "JWT validation is timing out"

```bash
$ grep "JWT.*timeout" prod.log | head -1 | grep -oP '\[activityId:\K[^\]'
3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a

$ go run tracer.go --id 3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a --service GW,IS < prod.log
```

Output shows the exact GW → IS flow and timing breakdown.

### Debugging: "IS is slow, let me see only IS logs"

```bash
$ go run tracer.go --service IS < prod.log | less
```

Focus on Identity Server without noise from other services.

### Automation: "Export all error traces as JSON"

```bash
$ go run tracer.go --format json < prod.log | jq '.[] | select(.level == "ERROR")'
```

Pipe into jq to filter errors, feed into alerting system or dashboard.

### Incident Report: "Show me trace XYZ in JSON for the runbook"

```bash
$ go run tracer.go --id xyz-123 --format json < prod.log > incident-xyz-123.json
```

Attach to incident ticket for the on-call team.

---

## Exercises

### Exercise 1: JSON Output Mode

**Question:** The `--format json` flag outputs traces in JSON. Show how this integrates with the jq tool.

**Hint:** Use `jq` to filter and extract fields from the JSON output.

**Solution sketch:**

```bash
# Extract only ERROR lines
go run main.go --format json < prod.log | jq '.[] | select(.level == "ERROR")'

# Extract timestamps and services
go run main.go --format json < prod.log | jq '.[] | {timestamp, service}'

# Count lines per service
go run main.go --format json < prod.log | jq -r '.[] | .service' | sort | uniq -c
```

### Exercise 2: Elapsed Time Calculation

**Question:** Calculate elapsed time for each service within a trace. Modify the output to show "GW: 200ms", "IS: 50ms", etc.

**Hint:** Track the first and last timestamp per service within a trace. Use `time.Duration` and `.Milliseconds()`.

**Solution sketch:**

```go
// In main(), after filtering to matched lines and before sort:
serviceStats := make(map[string]struct {
	first time.Time
	last  time.Time
})

for _, ll := range filtered {
	stats := serviceStats[ll.Service]
	if stats.first.IsZero() {
		stats.first = ll.Timestamp
	}
	stats.last = ll.Timestamp
	serviceStats[ll.Service] = stats
}

sort.Slice(filtered, func(i, j int) bool {
	return filtered[i].Timestamp.Before(filtered[j].Timestamp)
})

if *format == "json" {
	json.NewEncoder(os.Stdout).Encode(filtered)
	continue
}

fmt.Printf("=== Trace: %s (%d lines) ===\n", id, len(filtered))
for svc, stats := range serviceStats {
	elapsed := stats.last.Sub(stats.first).Milliseconds()
	fmt.Printf("  %s: %dms\n", svc, elapsed)
}
for _, ll := range filtered {
	fmt.Printf("  [%s] %-3s %-5s %s\n", ...)
}
fmt.Println()
```

### Exercise 3: Comma-Separated Service Filter

**Question:** The `--service` flag accepts comma-separated values. Implement parsing that handles whitespace gracefully.

**Hint:** `strings.Split()` splits on comma, `strings.TrimSpace()` and `strings.ToUpper()` normalize.

**Solution sketch:**

The code already does this! In `main()`:

```go
allowed := make(map[string]bool)
if *filterSvc != "" {
    for _, s := range strings.Split(*filterSvc, ",") {
        allowed[strings.TrimSpace(strings.ToUpper(s))] = true
    }
}

// Later:
if len(allowed) > 0 && !allowed[ll.Service] {
    continue  // skip lines not matching allowed services
}
```

**Test:** 
```bash
go run main.go --service "GW, IS , CP" < sample.log
```

Should handle spaces around commas correctly.

---

## Verification Checklist

- [ ] `go run main.go < sample.log` prints both traces
- [ ] `--id aaa-111` prints only aaa-111 trace
- [ ] `--id nonexistent` exits 0 with "no trace found" message
- [ ] `--service GW` filters to GW lines only
- [ ] `--service GW,IS` filters to GW and IS lines
- [ ] `--format json` outputs valid JSON
- [ ] Combined flags work: `--id X --service Y --format json`
- [ ] Empty result (no matching lines) produces no output
- [ ] Case-insensitive service names work: `--service gw,is`

---

## Next Steps

- **Day 49:** Runbooks that use the tracer for common failure modes
- **Day 50:** Deploy tracer in Docker image with sample logs
- **Production:** Use this tool in every incident triage

---

## Troubleshooting

**Q: JSON output has `"timestamp":"0001-01-01T00:00:00Z"` — looks wrong**

A: The timestamp might not be parsing. Check that the log line matches the regex. Also note: Go's JSON marshaling converts local times to UTC; that's expected.

**Q: `--id xyz` doesn't find a trace that I know exists**

A: The UUID might not match exactly. Check:
- Spaces in the grep output (trimmed?)
- Full UUID vs. partial UUID (must be full)
- Case sensitivity (UUID is case-sensitive)

**Q: `--service gw,is` doesn't work (shows all services)**

A: Service names are converted to uppercase. Try `--service GW,IS` (capital letters).

---

## Summary

Day 48 extends Day 47's core parser with production-grade filtering and export features:
- **Focused debugging** with `--id` and `--service`
- **Tool integration** with JSON output
- **Incident automation** by piping to jq, dashboards, and alerting systems

Combined with Day 46 (source understanding) and Day 47 (parsing), you now have a complete tracing toolkit.
