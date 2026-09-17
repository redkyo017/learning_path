# Day 48 — Solution and Expected Output

## Expected Outputs

### Test 1: Basic Operation (No Flags)

```bash
$ go run main.go < sample.log

=== Trace: aaa-111 (5 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  [10:01:23.200] CP   INFO   [activityId:aaa-111] Subscription check passed tier=Gold
  [10:01:23.220] TM   INFO   [activityId:aaa-111] Throttle check passed
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200

=== Trace: bbb-222 (3 lines) ===
  [10:02:01.400] GW   INFO   [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  [10:02:01.450] IS   INFO   [activityId:bbb-222] JWT expired: exp claim in the past
  [10:02:01.460] GW   INFO   [activityId:bbb-222] Response sent: 401
```

### Test 2: Filter by ID

```bash
$ go run main.go --id aaa-111 < sample.log

=== Trace: aaa-111 (5 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  [10:01:23.200] CP   INFO   [activityId:aaa-111] Subscription check passed tier=Gold
  [10:01:23.220] TM   INFO   [activityId:aaa-111] Throttle check passed
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200
```

Only one trace, exact match for the requested ID.

### Test 3: Filter by Nonexistent ID

```bash
$ go run main.go --id nonexistent < sample.log
no trace found for id nonexistent

$ echo $?
0
```

Exit code is 0 (success), not 1. This is intentional — absence of a trace isn't an error; it might be in a different time period.

### Test 4: Filter by Service (Single)

```bash
$ go run main.go --service GW < sample.log

=== Trace: aaa-111 (3 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200

=== Trace: bbb-222 (2 lines) ===
  [10:02:01.400] GW   INFO   [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  [10:02:01.460] GW   INFO   [activityId:bbb-222] Response sent: 401
```

Only GW lines from both traces. IS, CP, TM lines filtered out.

### Test 5: Filter by Service (Multiple)

```bash
$ go run main.go --service GW,IS < sample.log

=== Trace: aaa-111 (3 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  [10:01:23.300] GW   INFO   [activityId:aaa-111] Response sent: 200

=== Trace: bbb-222 (2 lines) ===
  [10:02:01.400] GW   INFO   [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  [10:02:01.450] IS   INFO   [activityId:bbb-222] JWT expired: exp claim in the past
```

GW and IS lines from both traces. CP and TM filtered out. Note the line counts changed: aaa-111 went from 5 to 3 lines, bbb-222 from 3 to 2 lines.

### Test 6: JSON Output

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

Valid JSON array, one object per log line. Timestamps are in UTC (Go's JSON marshaling converts automatically).

### Test 7: Combined Flags

```bash
$ go run main.go --id aaa-111 --service IS --format json < sample.log

[
  {
    "timestamp": "2026-09-01T10:01:23Z",
    "level": "INFO",
    "service": "IS",
    "activityId": "aaa-111",
    "message": "[activityId:aaa-111] JWT validated for client demo-client-id"
  }
]
```

Only 1 line: the IS line from trace aaa-111.

---

## How the Code Works

### Flag Parsing

```go
filterID := flag.String("id", "", "filter to a single activityId")
filterSvc := flag.String("service", "", "comma-separated service filter")
format := flag.String("format", "text", "output format: text or json")
flag.Parse()
```

- `--id` (string) — if provided, filter to that trace
- `--service` (string) — comma-separated list of services (e.g., "GW,IS,CP")
- `--format` (string) — "text" (default) or "json"

### Service Filter Parsing

```go
allowed := make(map[string]bool)
if *filterSvc != "" {
    for _, s := range strings.Split(*filterSvc, ",") {
        allowed[strings.TrimSpace(strings.ToUpper(s))] = true
    }
}
```

This:
1. Splits on comma
2. Trims whitespace from each part
3. Converts to uppercase
4. Builds a lookup map

Result: `--service "gw, is, cp"` becomes `{"GW": true, "IS": true, "CP": true}`.

### ID Filtering

```go
if *filterID != "" {
    t, ok := traces[*filterID]
    if !ok {
        fmt.Fprintf(os.Stderr, "no trace found for id %s\n", *filterID)
        os.Exit(0)
    }
    order = []string{*filterID}
    _ = t
}
```

This:
1. Checks if the ID exists in traces map
2. If not, prints to stderr and exits 0 (success, but no output)
3. If yes, replaces the `order` slice with just that one ID

Result: The main loop only prints that single trace.

### Service Filtering Within Traces

```go
filtered := t.Lines
if len(allowed) > 0 {
    var keep []*LogLine
    for _, ll := range filtered {
        if allowed[ll.Service] {
            keep = append(keep, ll)
        }
    }
    filtered = keep
}
if len(filtered) == 0 {
    continue
}
```

This:
1. If a service filter was specified (len(allowed) > 0)
2. Loop through lines and keep only those matching the filter
3. If no lines remain, skip this trace (no output)

Result: Only lines from allowed services are printed.

### Format Handling

```go
if *format == "json" {
    json.NewEncoder(os.Stdout).Encode(filtered)
    continue
}
fmt.Printf("=== Trace: %s (%d lines) ===\n", id, len(filtered))
for _, ll := range filtered {
    fmt.Printf("  [%s] %-3s %-5s %s\n", ...)
}
fmt.Println()
```

This:
- If JSON format: use `json.NewEncoder` to write the LogLine array as JSON
- If text format: print the trace header and formatted lines

JSON encoding is automatic because LogLine has struct tags:
```go
type LogLine struct {
    Timestamp  time.Time `json:"timestamp"`
    Level      string    `json:"level"`
    Service    string    `json:"service"`
    ActivityID string    `json:"activityId"`
    Message    string    `json:"message"`
}
```

---

## Exercise Solutions

### Exercise 1: JSON Output with jq

**Commands:**

```bash
# Extract only ERROR lines
go run main.go --format json < prod.log | jq '.[] | select(.level == "ERROR")'

# Extract timestamps and services  
go run main.go --format json < prod.log | jq '.[] | {timestamp, service}'

# Count lines per service
go run main.go --format json < prod.log | jq -r '.[] | .service' | sort | uniq -c

# Get the first and last timestamp in each trace
go run main.go --format json < prod.log | jq '[.[0].timestamp, .[-1].timestamp]'

# Filter to errors in GW only
go run main.go --service GW --format json < prod.log | jq '.[] | select(.level == "ERROR")'
```

**Why this matters:** JSON output lets you feed traces into any tool that understands JSON — dashboards, alerting systems, databases, or even Excel imports.

### Exercise 2: Elapsed Time Calculation

**Enhancement to main.go:**

```go
// After filtering and sorting lines, before output:
type ServiceStats struct {
    first time.Time
    last  time.Time
}
serviceStats := make(map[string]ServiceStats)

for _, ll := range filtered {
    stats := serviceStats[ll.Service]
    if stats.first.IsZero() {
        stats.first = ll.Timestamp
    }
    stats.last = ll.Timestamp
    serviceStats[ll.Service] = stats
}

// In text output, after the trace header:
if *format != "json" {
    fmt.Printf("=== Trace: %s (%d lines) ===\n", id, len(filtered))
    
    // Print service elapsed times
    for svc, stats := range serviceStats {
        elapsed := stats.last.Sub(stats.first).Milliseconds()
        fmt.Printf("  %s: %dms\n", svc, elapsed)
    }
    
    // Print lines
    for _, ll := range filtered {
        fmt.Printf("  [%s] %-3s %-5s %s\n", ...)
    }
}
```

**Output example:**
```
=== Trace: aaa-111 (5 lines) ===
  GW: 200ms
  IS: 25ms
  CP: 0ms
  TM: 0ms
  [10:01:23.100] GW   INFO   ...
```

**Why it matters:** Service latency breakdowns pin down which service is slow. A 3000ms GW latency suggests network issues or overload.

### Exercise 3: Comma-Separated Service Filter

**The code already implements this!**

```go
allowed := make(map[string]bool)
if *filterSvc != "" {
    for _, s := range strings.Split(*filterSvc, ",") {
        allowed[strings.TrimSpace(strings.ToUpper(s))] = true
    }
}
```

**Test cases:**

```bash
# Exact
go run main.go --service GW,IS < sample.log
# Result: only GW and IS lines

# With spaces
go run main.go --service "GW, IS, CP" < sample.log
# Result: same as above (spaces trimmed)

# Case variation
go run main.go --service gw,is < sample.log
# Result: same as above (converted to uppercase)

# All services (redundant but valid)
go run main.go --service GW,IS,CP,TM < sample.log
# Result: all lines (all services allowed)

# Single service
go run main.go --service CP < sample.log
# Result: only CP lines
```

---

## Real-World Integration Examples

### Pipeline 1: Find Errors in Specific Trace

```bash
activityId=$(grep "ERROR" prod.log | head -1 | grep -oP '\[activityId:\K[^\]')
go run tracer.go --id "$activityId" --format json < prod.log | \
  jq '.[] | select(.level == "ERROR")'
```

This:
1. Extracts an activityId from an ERROR line
2. Pulls the full trace for that ID
3. Filters JSON to show only ERROR lines within the trace

### Pipeline 2: Service Performance Dashboard

```bash
go run tracer.go --format json < prod.log | \
  jq -r '.[] | "\(.service) \(.timestamp)"' | \
  awk '{print $1, $2}' | \
  sort | uniq | \
  uniq -c
```

Counts occurrences per service per timestamp to detect bottlenecks.

### Pipeline 3: Alert Integration

```bash
go run tracer.go --format json < prod.log | \
  jq '.[] | select(.level == "ERROR" or .level == "WARN")' > errors.json
  
# Send to alerting system
curl -X POST https://alerts.example.com/api/events \
  -d @errors.json
```

Exports errors and warnings to an alerting system.

---

## Debugging Tips

### Empty Result When Filtering

If `--id X` or `--service Y` produces no output:

1. **Check that the ID exists:**
   ```bash
   grep "X" sample.log
   ```

2. **Check service name:**
   ```bash
   go run main.go < sample.log | grep "service"
   ```
   Services are: GW, IS, CP, TM (uppercase).

3. **Check format:**
   - Text format shows `=== Trace: === line count ===`
   - JSON format shows `[{...}]`

### Timestamp Parsing Issues

If timestamps look wrong in JSON output (e.g., year 1, invalid time):

1. Check the regex matches:
   ```bash
   go run main.go < sample.log
   ```
   If no traces print, the regex doesn't match your log format.

2. Verify the timestamp format in sample.log:
   - `✓` Correct: `10:01:23,100` (comma for milliseconds)
   - `✗` Wrong: `10:01:23.100` (period)

### JSON Not Valid

If jq fails with "parse error":

1. Run without jq to see the raw output:
   ```bash
   go run main.go --format json < sample.log | head -c 200
   ```

2. Check that all traces are complete (look for `]` at the end)

3. If combining multiple traces, remember each trace is a separate JSON array

---

## Summary

Day 48 adds production-grade filtering and integration:
- **`--id`**: Focus on one request
- **`--service`**: Filter noise, see only relevant components
- **`--format json`**: Integrate with dashboards, alerting, automation

Combined with Day 46 (source understanding) and Day 47 (parsing), you now have a complete toolkit for production tracing and incident response.

Next: Day 49 will use this tool to build runbooks for common failure modes.
