# Day 47 — Building the Log Correlation Parser

## Why This Matters

On Day 46 you learned that `activityId` ties all four services' logs together. Today you build the tool you'll use in every production incident.

**The problem:** You have a 2 GB log file with 100,000+ lines from all four services mixed together. You need to extract a single correlated trace for activityId `3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a`. Manual grep and sort? 5 minutes. A good parser? 2 seconds.

**The tool:** A Go program that:
1. Reads log lines from stdin (or a file pipe)
2. Extracts timestamp, log level, logger class, and message via regex
3. Infers the service (GW/IS/CP/TM) from the logger class
4. Extracts the activityId from the message
5. Groups all lines by activityId
6. Sorts each group by timestamp
7. Prints correlated traces

**Success signal:** Two activityId traces printed, each containing lines from 2+ services, in chronological order within each trace.

## Core Concepts

### Log Parsing Pipeline

```
Input: raw log line
  ↓
Parse: extract (timestamp, level, loggerClass, message)
  ↓
Infer: service = classify(loggerClass)
  ↓
Extract: activityId = regex match in message
  ↓
Group: traces[activityId] = append(logLine)
  ↓
Sort: each trace sorted by timestamp
  ↓
Output: "=== Trace: 3f7e8a1b ===" followed by lines
```

### The Core Regex

WSO2 log4j2 default layout:
```
[2006-01-02 15:04:05,000] LEVEL {loggerClass} - message
```

Regex to capture this:
```
^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\]\s+(\w+)\s+\{([^}]+)\}\s+-\s+(.+)$
```

Breaking it down:
- `^\[` — start of line, literal `[`
- `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)` — capture group 1: timestamp (YYYY-MM-DD HH:MM:SS,mmm)
- `\]\s+` — `]` followed by whitespace
- `(\w+)` — capture group 2: log level (INFO, WARN, ERROR, DEBUG, etc.)
- `\s+\{` — whitespace then literal `{`
- `([^}]+)` — capture group 3: logger class name (everything except `}`)
- `\}\s+-\s+` — `}` whitespace `-` whitespace
- `(.+)$` — capture group 4: message (rest of line)

### ActivityId Extraction

Within the message, activityId appears as `[activityId:uuid-here]`. Regex:
```
\[activityId:([^\]]+)\]
```

This captures the UUID between `[activityId:` and `]`.

### Service Inference

Given a logger class like `org.wso2.carbon.apimgt.gateway.handlers.security.APIKeyValidationHandler`:

```
if contains "gateway" or "apimgt.gateway" → "GW"
if contains "identity" → "IS"
if contains "throttle" → "TM"
else → "CP"
```

Make the check case-insensitive (`strings.ToLower`).

### Handling Multiline Log Entries

Java stack traces don't match the regex. They appear as continuation lines starting with `\t` (tab) or `at `:

```
[2026-09-01 10:01:23,100] ERROR {foo.bar.Handler} - Null pointer exception
	at foo.bar.Handler.process(Handler.java:42)
	at foo.bar.Executor.run(Executor.java:10)
```

**Solution:** Skip any line starting with `\t` or `at ` before applying the regex. This keeps the main trace clean.

### Grouping and Ordering

Two challenges:
1. **Grouping:** Many traces in one log file; you need to print them separately
2. **Ordering:** Go maps iterate in random order; you need to print traces in the order they first appear in the log

**Solution for ordering:**
- Maintain a `seen map[string]bool` to track which activityIds you've encountered
- Maintain an `order []string` slice
- When you first see an activityId, add it to `order`
- At the end, iterate `order` (not the map) to print traces

### The Data Structure

```go
type LogLine struct {
    Timestamp  time.Time
    Level      string
    Service    string
    ActivityID string
    Message    string
    Raw        string
}

type Trace struct {
    ActivityID string
    Lines      []*LogLine
}
```

## Lab Structure

**Goal:** Parse the sample log, print two correlated traces.

**Success signal:** Run `go run main.go < sample.log` and see:
```
=== Trace: aaa-111 (5 lines) ===
  [10:01:23.100] GW   INFO   [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [10:01:23.150] IS   INFO   [activityId:aaa-111] JWT validated for client demo-client-id
  ...

=== Trace: bbb-222 (3 lines) ===
  [10:02:01.400] GW   INFO   [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  ...
```

## Exercises

### Exercise 1: Show Unmatched Lines
**Question:** The parser skips lines with no activityId. These are background threads, monitoring tasks, etc. Add a `--show-unmatched` flag that prints them prefixed with `[NO-ID]`.

**Hint:** Add a `bool` flag using the `flag` package. Keep a separate slice for unmatched lines. After printing all traces, loop through unmatched and print each with `[NO-ID]` prefix.

**Solution sketch:**
```go
showUnmatched := flag.Bool("show-unmatched", false, "print lines without activityId")
flag.Parse()

var unmatched []*LogLine
for _, ll := range lines {
    if ll.ActivityID == "" {
        unmatched = append(unmatched, ll)
    }
}

if *showUnmatched {
    fmt.Println("\n=== Unmatched Lines ===")
    for _, ll := range unmatched {
        fmt.Printf("  [NO-ID] [%s] %s %s\n", 
            ll.Timestamp.Format("15:04:05.000"), ll.Level, ll.Message)
    }
}
```

### Exercise 2: First-Seen Ordering
**Question:** When you run the parser multiple times on the same log, traces appear in different order (maps are randomized in Go). Fix it so traces always print in the order they first appear in the input.

**Hint:** Track first-seen order in a slice alongside the map. Iterate the slice instead of the map.

**Solution sketch:**
```go
seen := make(map[string]bool)
var order []string

for _, ll := range lines {
    if ll.ActivityID != "" && !seen[ll.ActivityID] {
        seen[ll.ActivityID] = true
        order = append(order, ll.ActivityID)
    }
}

// Later, print traces:
for _, id := range order {
    printTrace(traces[id])
}
```

### Exercise 3: Skip Multiline Stack Traces
**Question:** The log line regex fails on Java stack trace continuation lines like `at foo.bar.Handler.process()`. What simple heuristic skips them without breaking normal log lines?

**Hint:** Stack trace lines always start with `\t` (tab indentation) or `at ` (the word "at" followed by space). Test for this before running the regex.

**Solution sketch:**
```go
for scanner.Scan() {
    raw := scanner.Text()
    
    // Skip Java stack trace lines
    if strings.HasPrefix(raw, "\t") || strings.HasPrefix(raw, "at ") {
        continue
    }
    
    // Now safe to apply regex
    m := logLineRE.FindStringSubmatch(raw)
    if m == nil {
        continue
    }
    // ... parse normally
}
```

## Key Takeaways

1. **Regex is the foundation** — good regex = clean log parsing; bad regex = false positives/negatives
2. **Service inference from class name** — logger classes follow a pattern; exploit it
3. **Time parsing** — WSO2 timestamps are local time, not UTC; parse carefully with the right format string
4. **Ordered maps** — Go maps are unordered; maintain a slice for ordering
5. **Stack traces are noise** — skip them with a prefix check; they'll appear in the message if you need them later

## Anti-Patterns to Avoid

1. **Using `strings.Split()` instead of regex** — logger class names contain `.`, spaces, and special chars; split breaks
2. **Printing traces as they're found** — interleaved output is unreadable; group first, print later
3. **Hardcoding service names** — pass the map of service keywords as a config or read from a file
4. **Parsing timestamps incorrectly** — WSO2 uses `,` not `.` for milliseconds; the Go time format is `2006-01-02 15:04:05,000`
5. **Ignoring the stack trace problem** — multiline exceptions blow up your output; handle them

## Next Steps

- **Lab (Day 47):** Run the parser on sample.log; verify two traces print with multiple services
- **Day 48:** Extend with `--id` and `--service` filters, JSON output, and elapsed time calculation
- **Day 49:** Use the parser in incident runbooks

## Summary

You've built the core tracing tool. It reads 100,000 log lines, groups them by activityId, and outputs clean correlated traces. Tomorrow you'll add filtering and formatting modes to make it production-ready.
