# Day 47 — Solution and Expected Output

## Expected Output

Running `go run main.go < sample.log` should produce:

```
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

**Key observations:**
1. Two traces printed separately
2. Each has an activityId and line count
3. Lines are chronologically sorted within each trace
4. Service column correctly inferred for each service
5. Traces print in first-seen order (aaa-111 before bbb-222)

---

## How the Code Works

### Regex Captures

The `logLineRE` regex has 4 capture groups:

```
^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\]\s+(\w+)\s+\{([^}]+)\}\s+-\s+(.+)$
 Group 1: Timestamp          Group 2: Level   Group 3: LoggerClass    Group 4: Message
```

For the first line in sample.log:
```
[2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Request received: POST /petstore/v1/pets
```

The regex captures:
- Group 1: `2026-09-01 10:01:23,100`
- Group 2: `INFO`
- Group 3: `org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler`
- Group 4: `[activityId:aaa-111] Request received: POST /petstore/v1/pets`

### Service Inference

The logger class contains "gateway":
```go
cls := strings.ToLower("org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler")
// cls = "org.wso2.carbon.apimgt.gateway..."
// strings.Contains(cls, "gateway") == true
// return "GW"
```

For the IS line:
```go
cls := strings.ToLower("org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator")
// strings.Contains(cls, "identity") == true
// return "IS"
```

For the CP line (APIManagerImpl is a Control Plane component):
```go
cls := strings.ToLower("org.wso2.carbon.apimgt.impl.APIManagerImpl")
// No "gateway", "identity", or "throttle"
// Default case: return "CP"
```

For the TM line:
```go
cls := strings.ToLower("org.wso2.carbon.throttle.core.ThrottleHandler")
// strings.Contains(cls, "throttle") == true
// return "TM"
```

### ActivityId Extraction

The `activityRE` regex searches within the message:

```
\[activityId:([^\]]+)\]
```

For message `[activityId:aaa-111] Request received: POST /petstore/v1/pets`:
- Matches: `[activityId:aaa-111]`
- Capture group 1: `aaa-111`

### Grouping and Ordering

The `parseLines()` function maintains:
1. A `result []*LogLine` slice — all parsed lines
2. A `seen map[string]bool` — whether we've encountered each activityId
3. An `order []string` slice — the order of first-seen activityids

When parsing line 1 (activityId: aaa-111):
```go
if !seen["aaa-111"] {
    seen["aaa-111"] = true
    order = append(order, "aaa-111")  // order = ["aaa-111"]
}
```

When parsing line 2 (also aaa-111):
```go
if !seen["aaa-111"] {
    // false, already seen, skip
}
```

When parsing line 6 (activityId: bbb-222):
```go
if !seen["bbb-222"] {
    seen["bbb-222"] = true
    order = append(order, "bbb-222")  // order = ["aaa-111", "bbb-222"]
}
```

Result: `order = ["aaa-111", "bbb-222"]` — the exact order they appeared in the file.

### Timestamp Parsing

The format string is critical:
```go
ts, _ := time.Parse("2006-01-02 15:04:05,000", m[1])
```

For input `2026-09-01 10:01:23,100`:
- `2006` → year (2026)
- `01` → month (09)
- `02` → day (01)
- `15:04:05` → time (10:01:23)
- `,000` → milliseconds (,100)

The result is a `time.Time` object that can be compared and formatted.

### Sorting Within Traces

The `printTrace()` function sorts lines by timestamp:

```go
sort.Slice(t.Lines, func(i, j int) bool {
    return t.Lines[i].Timestamp.Before(t.Lines[j].Timestamp)
})
```

For the aaa-111 trace, before sorting:
```
Line 1: 10:01:23.100
Line 2: 10:01:23.150
Line 3: 10:01:23.200
Line 4: 10:01:23.220
Line 5: 10:01:23.300
```

Already in order, so no change. But if they arrived out of sequence (e.g., due to concurrent processing in the real log), sorting puts them back in order.

### First-Seen Order Preservation

In `main()`:

```go
for _, id := range order {
    printTrace(traces[id])
}
```

Instead of:

```go
for id, trace := range traces {  // map iteration is randomized
    printTrace(trace)
}
```

This ensures traces always print in the order they first appeared in the input.

---

## Exercise Solutions

### Exercise 1: `--show-unmatched` Flag

**Full solution:**

```go
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

// ... (type definitions remain the same) ...

func main() {
	showUnmatched := flag.Bool("show-unmatched", false, "print lines without activityId")
	flag.Parse()

	lines, order := parseLines(bufio.NewScanner(os.Stdin))
	traces := correlate(lines)
	if len(traces) == 0 {
		fmt.Fprintln(os.Stderr, "no correlated traces found — check that logs contain [activityId:...] patterns")
		os.Exit(1)
	}
	for _, id := range order {
		printTrace(traces[id])
	}

	if *showUnmatched {
		var unmatched []*LogLine
		for _, ll := range lines {
			if ll.ActivityID == "" {
				unmatched = append(unmatched, ll)
			}
		}
		if len(unmatched) > 0 {
			fmt.Println("=== Unmatched Lines ===")
			sort.Slice(unmatched, func(i, j int) bool {
				return unmatched[i].Timestamp.Before(unmatched[j].Timestamp)
			})
			for _, ll := range unmatched {
				fmt.Printf("  [NO-ID] [%s] %-3s %-5s %s\n",
					ll.Timestamp.Format("15:04:05.000"), ll.Service, ll.Level, ll.Message)
			}
		}
	}
}
```

**Test:**
```bash
go run main.go --show-unmatched < sample.log
```

**Expected addition to output:**
Since all sample.log lines have activityId, no unmatched lines will print. But if you add a line without `[activityId:...]`:

```
[2026-09-01 10:01:00,050] INFO {org.wso2.carbon.utils.monitoring.HealthChecker} - Health check completed
```

Running with `--show-unmatched` would add:
```
=== Unmatched Lines ===
  [NO-ID] [10:01:00.050] CP   INFO   Health check completed
```

### Exercise 2: First-Seen Ordering

**The code already implements this!** The key is:

```go
func parseLines(scanner *bufio.Scanner) ([]*LogLine, []string) {
	// ...
	var order []string
	seen := make(map[string]bool)
	
	// When first encountering an activityId:
	if !seen[ll.ActivityID] {
		seen[ll.ActivityID] = true
		order = append(order, ll.ActivityID)
	}
	
	return result, order
}

func main() {
	lines, order := parseLines(...)
	// ...
	
	// Print in first-seen order, not random map order:
	for _, id := range order {
		printTrace(traces[id])
	}
}
```

**Verify:** Run `go run main.go < sample.log` five times. Output is identical each time.

### Exercise 3: Multiline Stack Trace Handling

**The code already handles this!** In `parseLines()`:

```go
for scanner.Scan() {
	raw := scanner.Text()
	// skip Java stack trace continuation lines
	if strings.HasPrefix(raw, "\t") || strings.HasPrefix(raw, "at ") {
		continue
	}
	m := logLineRE.FindStringSubmatch(raw)
	// ... rest of parsing ...
}
```

**Test with a stack trace:**

Create `sample-with-stack.log`:
```
[2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:ccc-333] Request received
[2026-09-01 10:01:23,110] ERROR {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:ccc-333] Null pointer exception
	at java.lang.NullPointerException.getMessage(NullPointerException.java:65)
	at org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator.validate(DefaultOAuth2TokenValidator.java:123)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
[2026-09-01 10:01:23,120] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:ccc-333] Response sent: 500
```

Run:
```bash
go run main.go < sample-with-stack.log
```

**Expected output:**
```
=== Trace: ccc-333 (3 lines) ===
  [10:01:23.100] GW   INFO   [activityId:ccc-333] Request received
  [10:01:23.110] IS   ERROR  [activityId:ccc-333] Null pointer exception
  [10:01:23.120] GW   INFO   [activityId:ccc-333] Response sent: 500
```

The stack trace lines are skipped, and the trace is clean.

---

## Debugging Tips

If output looks wrong, check:

1. **Timestamp format:** Does your sample.log use `,` (comma) for milliseconds, not `.` (period)?
   - ✓ Correct: `10:01:23,100`
   - ✗ Wrong: `10:01:23.100`

2. **ActivityId pattern:** Does the message contain `[activityId:...]` exactly?
   - ✓ Correct: `[activityId:aaa-111]`
   - ✗ Wrong: `[activity-id:aaa-111]` or `activity-id: aaa-111`

3. **Logger class:** Does the logger class match one of the service keywords?
   - ✓ GW: `org.wso2.carbon.apimgt.gateway.*`
   - ✓ IS: `org.wso2.carbon.identity.*`
   - ✓ TM: `org.wso2.carbon.throttle.*`
   - ✓ CP: anything else

4. **Regex escaping:** In Go strings, `\t` is the tab character. If you need a literal backslash, use `\\t`.

---

## Summary

The parser demonstrates:
- Regular expression pattern matching for log line format
- Service inference from component names
- Time parsing and sorting
- Map + slice pattern for preserving insertion order
- Clean separation of parsing, grouping, and output

The core insight: **structured parsing (regex) + grouping (map) + ordering (slice) = readable tracing.**

Tomorrow (Day 48), you'll extend this with filters and JSON output to create a production-ready tool.
