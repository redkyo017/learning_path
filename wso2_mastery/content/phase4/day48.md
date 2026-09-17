# Day 48 — Extending the Tracer: Filters, JSON, and Runbooks

## Why This Matters

Yesterday you built a parser that correlates logs across all four services. Today you extend it into a production-grade debugging tool with:
- **Filtering by trace ID** — focus on one incident at a time
- **Filtering by service** — ignore noise from unrelated services
- **JSON output** — pipe into other tools (jq, dashboards, alerting systems)
- **Elapsed time calculation** — understand service latency per request

**Real incident scenario:**
```
$ go run parser.go --id 3f7e8a1b --service GW,IS < prod.log | jq '.[] | select(.level == "ERROR")'
```
This gives you only errors in GW and IS for one activityId. Pass it to your team Slack. Done in 10 seconds.

## Core Concepts

### The `--id` Filter

When you know the activityId (from a customer support ticket, a monitoring alert), you want to see only that trace:

```bash
go run main.go --id 3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a < prod.log
```

Logic:
1. Parse all traces as before
2. If `--id` flag is set, keep only `traces[id]`
3. If the id doesn't exist in the log, print "no trace found for id X" to stderr and exit 0 (not an error; maybe the ID is from a different time period)

### The `--service` Filter

Filter to specific services. Comma-separated list:

```bash
go run main.go --service GW,IS < prod.log
```

Output includes only GW and IS log lines. Useful when:
- You know the error is in the gateway layer (skip CP/TM noise)
- Debugging IS token issues (only IS lines)
- Tracking throttle behavior (only TM)

**Implementation:**
1. Parse the flag: `strings.Split(*filterSvc, ",")`
2. Build a map: `allowed[strings.ToUpper(strings.TrimSpace(s))] = true`
3. For each line, check `if len(allowed) > 0 && !allowed[ll.Service] { continue }`

### JSON Output Mode

Use `--format json` to export traces in JSON:

```bash
go run main.go --format json < prod.log
```

Output (one trace):
```json
[
  {
    "timestamp": "2026-09-01T10:01:23Z",
    "level": "INFO",
    "service": "GW",
    "activityId": "aaa-111",
    "message": "Request received: POST /petstore/v1/pets"
  },
  {
    "timestamp": "2026-09-01T10:01:23Z",
    "level": "INFO",
    "service": "IS",
    "activityId": "aaa-111",
    "message": "JWT validated for client demo-client-id"
  }
]
```

**Use cases:**
- Pipe to `jq` for filtering: `jq '.[] | select(.level == "ERROR")'`
- Ingest into ELK/Splunk for dashboards
- Store in a database for trend analysis
- Send to alerting systems

### Elapsed Time Calculation

For a given trace, what's the latency per service? Extract the first and last timestamp for each service:

```
Service: GW
  First line: 10:01:23.100
  Last line:  10:01:23.300
  Elapsed:    200ms

Service: IS
  First line: 10:01:23.150
  Last line:  10:01:23.175
  Elapsed:    25ms
```

**Why it matters:**
- If GW-to-IS latency is 3000ms, network is slow or IS is overloaded
- If CP latency is 100ms but subscription check should be <5ms, something's wrong with CP caching

**Implementation:**
1. Group lines by service
2. Sort each group by timestamp
3. Calculate `last.Timestamp - first.Timestamp` for each service
4. Report in the trace header or as a separate stats block

## Lab Structure

**Goal:** Extended parser with filters and JSON mode.

**Success signals:**
1. `go run main.go --id aaa-111 < sample.log` prints only aaa-111 trace
2. `go run main.go --service GW < sample.log` prints only GW lines from all traces
3. `go run main.go --format json < sample.log` outputs valid JSON
4. Combined: `go run main.go --id aaa-111 --service GW,IS --format text` works correctly

## Exercises

### Exercise 1: JSON Output Mode
**Question:** Add a `--format json` flag that outputs traces as JSON. Each line should include timestamp, level, service, activityId, and message.

**Hint:** Use `encoding/json` package with struct tags. Collect matching lines into a slice and call `json.NewEncoder(os.Stdout).Encode(slice)`. One array per trace, or one object per line?

**Solution sketch:**
```go
type LogLine struct {
    Timestamp  time.Time `json:"timestamp"`
    Level      string    `json:"level"`
    Service    string    `json:"service"`
    ActivityID string    `json:"activityId"`
    Message    string    `json:"message"`
}

// ... in main loop, after filtering to matched lines ...
if *format == "json" {
    json.NewEncoder(os.Stdout).Encode(filtered)  // output array of LogLines
    continue
} else {
    fmt.Printf("=== Trace: %s ===\n", id)
    // ... text output ...
}
```

### Exercise 2: Elapsed Time Calculation
**Question:** Calculate the elapsed time for each service within a trace. For example, "GW: 200ms (10:01:23.100 to 10:01:23.300)". Print this in the trace header.

**Hint:** Sort the trace lines by service, then find min/max timestamp per service. Use `time.Duration` and `.Milliseconds()` to format.

**Solution sketch:**
```go
serviceStats := make(map[string]struct{ first, last time.Time })

for _, ll := range filtered {
    stats := serviceStats[ll.Service]
    if stats.first.IsZero() {
        stats.first = ll.Timestamp
    }
    stats.last = ll.Timestamp
    serviceStats[ll.Service] = stats
}

fmt.Printf("=== Trace: %s ===\n", id)
for service, stats := range serviceStats {
    elapsed := stats.last.Sub(stats.first).Milliseconds()
    fmt.Printf("  %s: %dms\n", service, elapsed)
}
for _, ll := range filtered {
    fmt.Printf("  [%s] %-3s %-5s %s\n", ...)
}
```

### Exercise 3: Comma-Separated Service Filter
**Question:** The `--service` flag should accept a comma-separated list: `--service GW,IS,CP`. Parse it and only show lines matching those services. Handle whitespace gracefully.

**Hint:** Use `strings.Split()` to break on comma. Use `strings.TrimSpace()` and `strings.ToUpper()` to normalize. Build a map for O(1) lookup.

**Solution sketch:**
```go
filterSvc := flag.String("service", "", "comma-separated service filter")
flag.Parse()

allowed := make(map[string]bool)
if *filterSvc != "" {
    for _, s := range strings.Split(*filterSvc, ",") {
        allowed[strings.TrimSpace(strings.ToUpper(s))] = true
    }
}

// Later, when filtering lines:
if len(allowed) > 0 && !allowed[ll.Service] {
    continue  // skip this line
}
```

## Key Takeaways

1. **Filtering at the right layer** — apply filters after grouping, not before parsing (preserves complete traces for later analysis)
2. **JSON is the lingua franca** — any format that can be piped into jq, Splunk, or ELK is worth implementing
3. **Elapsed time is diagnostic gold** — 90% of production incidents are latency-related; timing breakdowns pin down the culprit
4. **Graceful "not found"** — if `--id X` doesn't match, exit 0 (success) with a message, not an error code
5. **Timestamp precision matters** — milliseconds separate a cache hit from a database query; preserve them

## Real-World Runbook Example

**Incident: JWT validation timeout**

```bash
$ grep "JWT.*timeout" prod.log | head -1
[2026-09-01 11:45:30,123] ERROR {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:xyz-456] JWT validation timeout

$ go run tracer.go --id xyz-456 --service GW,IS < prod.log
=== Trace: xyz-456 ===
  GW: 5000ms (11:45:30.100 to 11:45:35.100)
  IS: 4950ms (11:45:30.150 to 11:45:35.100)
  [11:45:30.100] GW   INFO   Request received: GET /petstore/v1/pets
  [11:45:30.150] IS   DEBUG  Token validator started
  [11:45:35.100] IS   ERROR  JWT validation timeout (socket read timeout after 5s)
  [11:45:35.100] GW   ERROR  Upstream service timeout
```

**Diagnosis:** IS took 4.95s on JWT validation. Normal is <100ms. Check IS token cache and endpoint availability.

## Anti-Patterns to Avoid

1. **Exiting with error for missing ID** — use exit 0; the trace may be in a different time period or log file
2. **Sorting before filtering** — filter within each trace, not globally; sorting the full input makes combined `--id` + `--service` slow
3. **Assuming UTC timestamps** — WSO2 logs use server local time; note this in output or docs
4. **Hardcoding service names** — use lowercase comparison (`strings.ToLower()`) to handle user input variations
5. **JSON without newlines** — if you output multiple objects, separate with `\n` or use a JSON array; streaming parsers expect it

## Next Steps

- **Lab (Day 48):** Extend Day 47 parser with `--id`, `--service`, and `--format json` flags; verify filters work
- **Day 49:** Runbook templates for common failure modes (timeout, auth failure, throttle, backend error)
- **Day 50:** Integration — ship the tracer in a Docker image with a pre-built sample log for on-call engineers

## Summary

You've now built a production-grade log correlation tool. It:
- Parses WSO2 logs across four services
- Groups by activityId
- Filters by trace ID, service, or timestamp
- Outputs text or JSON
- Calculates latency breakdowns

In an incident, this tool turns a 2-hour debugging session into a 5-minute diagnosis.
