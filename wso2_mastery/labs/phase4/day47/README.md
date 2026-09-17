# Day 47 — Log Correlation Parser Lab

## Goal

Build a Go program that:
1. Reads WSO2-style log lines from stdin
2. Extracts timestamp, log level, logger class, and message
3. Infers the service (GW/IS/CP/TM) from the logger class
4. Extracts the activityId from log messages
5. Groups lines by activityId
6. Prints correlated traces in chronological order

## Success Signal

Run `go run main.go < sample.log` and see:
- Two `=== Trace: ===` blocks
- Each trace contains lines from **multiple services** (at least GW and IS, or GW and CP)
- Lines within each trace are sorted by timestamp
- Output is readable and well-formatted

## Quick Start

### 1. Prepare Sample Log

Save the following content to `sample.log` in this directory:

```
[2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Request received: POST /petstore/v1/pets
[2026-09-01 10:01:23,150] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:aaa-111] JWT validated for client demo-client-id
[2026-09-01 10:01:23,200] INFO {org.wso2.carbon.apimgt.impl.APIManagerImpl} - [activityId:aaa-111] Subscription check passed tier=Gold
[2026-09-01 10:01:23,220] INFO {org.wso2.carbon.throttle.core.ThrottleHandler} - [activityId:aaa-111] Throttle check passed
[2026-09-01 10:01:23,300] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Response sent: 200
[2026-09-01 10:02:01,400] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
[2026-09-01 10:02:01,450] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:bbb-222] JWT expired: exp claim in the past
[2026-09-01 10:02:01,460] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Response sent: 401
```

### 2. Run the Parser

```bash
go run main.go < sample.log
```

### 3. Expected Output

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

---

## How It Works

### Regex Parsing

The log line pattern is:
```
[YYYY-MM-DD HH:MM:SS,mmm] LEVEL {loggerClass} - message
```

The regex `logLineRE` captures:
1. Timestamp
2. Log level
3. Logger class (to infer service)
4. Message

### Service Inference

Check the logger class for keywords:
- Contains "gateway" or "apimgt.gateway" → **GW**
- Contains "identity" → **IS**
- Contains "throttle" → **TM**
- Otherwise → **CP**

### ActivityId Extraction

Search the message for the pattern `[activityId:xxx]` using the regex:
```
\[activityId:([^\]]+)\]
```

### Grouping

- Parse all lines
- Skip lines with no activityId
- Group by activityId into a map
- Track first-seen order in a slice

### Output

- Sort lines within each trace by timestamp
- Print traces in first-seen order

---

## Code Structure

**Key Functions:**

- `parseLines()` — read from stdin, extract fields, build LogLine structs and ordering slice
- `inferService()` — classify service from logger class name
- `correlate()` — group LogLines by activityId
- `printTrace()` — sort and pretty-print one trace

**Key Data Structures:**

```go
type LogLine struct {
    Timestamp  time.Time  // parsed from [YYYY-MM-DD HH:MM:SS,mmm]
    Level      string     // INFO, ERROR, WARN, etc.
    Service    string     // GW, IS, CP, TM (inferred from logger class)
    ActivityID string     // UUID from [activityId:...]
    Message    string     // the log message
    Raw        string     // original line (for debugging)
}

type Trace struct {
    ActivityID string
    Lines      []*LogLine
}
```

---

## Exercises

### Exercise 1: Add `--show-unmatched` Flag

**Question:** Lines with no activityId are skipped (background threads, monitoring, etc.). Add a `--show-unmatched` flag that prints them prefixed with `[NO-ID]`.

**Hint:** Import the `flag` package. Add a bool flag. Keep a separate slice for unmatched lines. After printing traces, print unmatched lines with a `[NO-ID]` prefix.

**Solution sketch:**
```go
import "flag"

func main() {
    showUnmatched := flag.Bool("show-unmatched", false, "print lines without activityId")
    flag.Parse()
    
    lines, order := parseLines(bufio.NewScanner(os.Stdin))
    
    var unmatched []*LogLine
    for _, ll := range lines {
        if ll.ActivityID == "" {
            unmatched = append(unmatched, ll)
        }
    }
    
    // ... print traces ...
    
    if *showUnmatched {
        fmt.Println("\n=== Unmatched Lines ===")
        for _, ll := range unmatched {
            fmt.Printf("  [NO-ID] [%s] %s %s\n", 
                ll.Timestamp.Format("15:04:05.000"), ll.Level, ll.Message)
        }
    }
}
```

**Test:** `go run main.go --show-unmatched < sample.log`

### Exercise 2: Fix Random Trace Order

**Question:** When you run the parser multiple times on the same input, traces print in different order (Go maps randomize). Fix it to always print traces in first-seen order.

**Hint:** The `parseLines()` function already returns an `order []string` slice. Use that instead of iterating the map.

**Solution sketch:**
The code already does this! The `order` slice tracks first-seen activityIds, and `main()` already prints traces in `order` instead of iterating the map.

**Verify:** Run `go run main.go < sample.log` three times. Output should be identical (both traces in same order).

### Exercise 3: Handle Multiline Stack Traces

**Question:** Java stack traces don't match the log line regex. Test what happens when stack traces are present.

**Hint:** Stack trace lines start with `\t` (tab) or `at `. Add a check in `parseLines()` to skip them before applying the regex.

**Solution sketch:**
The code already does this! In `parseLines()`, the loop skips lines starting with `\t` or `at ` before attempting the regex.

**Test:** Create a log file with a stack trace and run it through the parser. Verify the stack trace lines don't break parsing.

Example test log:
```
[2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:ccc-333] Request received
[2026-09-01 10:01:23,110] ERROR {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:ccc-333] Null pointer exception
	at java.lang.NullPointerException.getMessage(NullPointerException.java:65)
	at org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator.validate(DefaultOAuth2TokenValidator.java:123)
[2026-09-01 10:01:23,120] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:ccc-333] Response sent: 500
```

---

## Verification Checklist

- [ ] `go run main.go < sample.log` runs without errors
- [ ] Two traces print with correct activityIds (aaa-111, bbb-222)
- [ ] Each trace has lines from multiple services
- [ ] Lines are sorted by timestamp within each trace
- [ ] Traces are printed in first-seen order (aaa-111 first)
- [ ] Service inference is correct (GW for gateway, IS for identity, etc.)
- [ ] No junk output or parse errors

---

## Next Steps

- **Day 48:** Extend the parser with `--id`, `--service`, and `--format json` flags
- **Day 49:** Use the parser in production incident runbooks

---

## Troubleshooting

**Q: Parser exits with error "no correlated traces found"**

A: The sample.log doesn't contain any lines matching the regex. Check:
- Log lines have the exact format `[YYYY-MM-DD HH:MM:SS,mmm]`
- All timestamps use commas (`,`) not periods (`.`) for milliseconds
- Message contains `[activityId:...]` pattern

**Q: Service inference shows wrong service**

A: The logger class must contain keywords: "gateway", "identity", or "throttle". Check the sample log format. If using custom logger names, modify `inferService()`.

**Q: Timestamp parsing fails**

A: The time.Parse format must match exactly: `"2006-01-02 15:04:05,000"`. Note the comma before milliseconds.

---

## Summary

You've built the core log tracing tool. It reads mixed logs from all four services, groups them by correlation ID, and outputs clean chronological traces. This is the foundation for Day 48 (filtering) and Day 49 (runbooks).
