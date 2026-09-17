# Day 46 — Source Reading Lab: ActivityId Stamping Mechanism

## Goal

Explore WSO2's source code to understand:
1. Which class generates the `activityId` UUID and when it runs
2. How log4j2 writes the `activityId` into every log line
3. How the Gateway propagates `activityId` to downstream services via HTTP headers

You'll trace the correlation mechanism from request entry to log output.

## Prerequisites

- WSO2 universal gateway source at `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0`
- Basic grep and find command familiarity
- Optional: IDE with Java file search (IntelliJ, VSCode)

## Success Signal

You can answer all three questions below by finding and examining the relevant source files. You'll create a personal "why" log (see end of exercise) documenting your findings.

---

## Step 1: Find ActivityIDHandler in the Gateway

The `ActivityIDHandler` is the component responsible for generating the `activityId` UUID and putting it into the thread-local MDC (Mapped Diagnostic Context).

### Commands

```bash
# Find the ActivityIDHandler class
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "ActivityIDHandler.java" 2>/dev/null

# Once found, examine it for MDC.put and UUID logic
grep -n "activityId\|MDC.put\|UUID" <path-to-ActivityIDHandler.java> | head -30
```

### What to Look For

- Where is `MDC.put("activityId", ...)` called?
- What generates the UUID? (Look for `UUID.randomUUID()` or similar)
- Is there a comment explaining the handler's position in the request pipeline?
- What is the handler's package and class name?

### Expected Finding

The handler should:
- Run **early** in the request processing chain, before security/validation handlers
- Generate a UUID for each request
- Place it into MDC so all downstream handlers in the same thread can access it
- Ensure all log lines in that thread include the activityId

### Your Notes

Write your findings in a personal "why" log file. Example:
```
## ActivityIDHandler Source Review

**File:** org/wso2/carbon/apimgt/gateway/handlers/common/ActivityIDHandler.java

**Key Lines:**
- Line 42: `String activityId = UUID.randomUUID().toString();`
- Line 45: `MDC.put("activityId", activityId);`

**Why It Works:**
The handler runs before APIKeyValidationHandler (based on handler ordering in the config).
This ensures every request gets a unique ID before any security checks. 
The MDC makes it available to every log4j2 logger in that thread.

**When Executed:** On every inbound request, before authentication/validation.
```

---

## Step 2: Find the Log4j2 Pattern and `%X{activityId}` Token

The log4j2 configuration file contains a PatternLayout that tells log4j2 how to format each log line. The `%X{activityId}` token extracts the activityId from MDC and includes it in the output.

### Commands

```bash
# Find log4j2.properties in the universal gateway
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "log4j2.properties"

# Examine the layout pattern
grep -n "activityId\|%X{\|appenders.console\|PatternLayout" <path> | head -30
```

### What to Look For

- The `appender.console.layout.pattern` or similar configuration line
- The presence of `%X{activityId}` or similar placeholder
- Other placeholders to understand the full format (e.g., `%d`, `%p`, `%c`, `%m`)

### Expected Finding

A line like:
```properties
appender.console.layout.pattern = [%d{ISO8601}] %-5p {%c} - %X{activityId} %m%n
```

Where:
- `%d{ISO8601}` = timestamp
- `%-5p` = log level (padded)
- `%c` = logger class name
- `%X{activityId}` = extract activityId from MDC
- `%m` = message
- `%n` = newline

### Your Notes

```
## Log4j2 Pattern Token

**File:** <path-to-log4j2.properties>

**Pattern Line:**
[exact line from the file]

**Token Breakdown:**
- %d{ISO8601}: Timestamp in ISO 8601 format
- %-5p: Log level, left-aligned, 5 chars
- %c: Logger class name
- %X{activityId}: Pull activityId from MDC (our key trace element)
- %m: Message
- %n: Newline

**How It Works:**
When log4j2 formats a line, it calls MDC.get("activityId").
If the value exists, it includes [activityId:xxx] in the output.
If the key doesn't exist (background thread), it prints empty/nothing.
```

---

## Step 3: Find X-Activity-Id Header Propagation

When the Gateway calls downstream services (IS, CP, TM), it must pass the `activityId` in an HTTP header. This is typically done when making outbound HTTP requests (e.g., to IS for token validation, to CP for subscription checks).

### Commands

```bash
# Search for outbound HTTP header setup mentioning activityId
grep -rn "X-Activity-Id\|ActivityId.*header\|setHeader.*activityId" \
  /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 --include="*.java" | head -20

# Alternative: look for the HTTP client code that calls IS/CP
grep -rn "HttpClient\|CloseableHttpClient\|setHeader" \
  /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 --include="*.java" | \
  grep -i "activity\|correlat" | head -20
```

### What to Look For

- The HTTP header name (usually `X-Activity-Id`)
- Which class/handler adds this header to outbound requests
- How the downstream service is expected to read and use this header

### Expected Finding

Code similar to:
```java
HttpGet request = new HttpGet(endpoint);
String activityId = MDC.get("activityId");
if (activityId != null) {
    request.setHeader("X-Activity-Id", activityId);
}
```

### Your Notes

```
## X-Activity-Id Header Propagation

**Search Pattern:** [describe what you searched]

**Files That Reference It:** [list any files found]

**Mechanism:**
The Gateway retrieves the activityId from MDC using MDC.get("activityId").
It adds it as an HTTP header in outbound requests to IS/CP/TM.
These downstream services read this header and put it into their own MDC.
Result: The same activityId appears in logs across all four services.

**Header Name:** X-Activity-Id
**Inbound:** HTTP request arrives (Gateway generates UUID)
**Outbound:** Gateway → IS/CP/TM (propagates via header)
**Downstream:** IS/CP/TM receives header, stamps their own logs
```

---

## Step 4: Create Your "Why" Log

Write a markdown file `why_log.md` in this directory documenting your findings. Use the template below:

### Template

```markdown
# Day 46 — Source Reading "Why" Log

## Question 1: ActivityIDHandler

**Where I looked:**
- File: [path]
- Grep commands: [what I ran]

**What I found:**
- Class name: ...
- UUID generation: [code snippet or line number]
- MDC.put() call: [line number]
- Handler ordering: [description]

**Why it matters:**
[Your explanation of why this design works]

---

## Question 2: Log4j2 Pattern Token

**Where I looked:**
- File: [path]
- Pattern line: [exact line]

**Key tokens:**
- %X{activityId}: [what it does]
- Other tokens: [brief explanation]

**Why it matters:**
[Your explanation of how this connects to the logs you see in production]

---

## Question 3: X-Activity-Id Header

**Where I looked:**
- Grep command: [what you ran]
- Files found: [list them]

**Mechanism:**
[Flow from GW → IS, explaining how the header is used]

**Why it matters:**
[How this enables cross-service correlation]

---

## Key Insights

[3-5 sentences summarizing what you learned about tracing and logging in distributed systems]
```

---

## Hints

### Stuck on Step 1?

Try:
```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "*Activity*.java" 2>/dev/null
```

Look for files with "Activity" in the name. The class is likely in a `handlers/common/` directory.

### Stuck on Step 2?

Try:
```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -path "*/conf/*" -name "*.properties" 2>/dev/null
```

Log4j2 properties are typically in a `conf/` directory. Look for filenames like `log4j2.properties` or `log4j2-*.properties`.

### Stuck on Step 3?

Try:
```bash
grep -rn "setHeader\|addHeader" /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 --include="*.java" | grep -i "activity" 
```

HTTP client code sets headers on request objects. Search for both the header name and the method that adds it.

---

## Success Checklist

- [ ] Found ActivityIDHandler and identified MDC.put() call
- [ ] Located log4j2.properties and found %X{activityId} token
- [ ] Found X-Activity-Id header propagation mechanism
- [ ] Created why_log.md with answers to all three questions
- [ ] Can explain the flow: generation → MDC → log pattern → HTTP propagation

---

## What's Next?

Day 47: Build the Go parser that reads these logs and extracts correlated traces by activityId.
