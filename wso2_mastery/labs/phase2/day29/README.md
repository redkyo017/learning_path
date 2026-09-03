# Lab: Day 29 — GW Log Analysis (Synthetic Log File)

## Overview

In this lab, you'll analyze a synthetic GW log file and answer diagnostic questions about request flows.
The log file contains realistic gateway debug output with multiple requests, including successes and failures
(401, 403, 429 scenarios).

## Objective

Read `log_samples/gw_failure.log` and answer the following questions based on log patterns from Day 29:

## Files

```
log_samples/gw_failure.log      ← Synthetic GW debug logs (20+ lines)
```

## Instructions

### Step 1: Read the Log File

```bash
cat log_samples/gw_failure.log
```

Observe the sequence of requests, timestamps, and log messages.

### Step 2: Identify Request Outcomes

The log file contains multiple requests (identified by `req-00X` IDs). For each request, determine:
- Did it succeed or fail?
- If failed, what was the failure reason?
- What HTTP status code would have been returned?

### Step 3: Answer These Questions

**Question 1:** Which request succeeded and returned 200 OK to the client?

**Hint:** Look for log lines showing successful JWT validation, subscription found, and throttle allows.

---

**Question 2:** What was the failure reason for req-002, and what HTTP status code would it return?

**Hint:** Look for WARN or ERROR level logs with a failure message.

---

**Question 3:** Which application hit the subscription wall (403 Forbidden), and what API was it trying to access?

**Hint:** Search for "API subscription not found" and extract the app name and API name.

---

**Question 4:** Which tier was throttled (429 Too Many Requests), and what was the bucket state at failure?

**Hint:** Look for "Request throttled" and find the tier name. Then look for the bucket count just before throttle.

---

## Expected Output

Your answers should reference specific log lines and include:

1. Request ID and timestamp
2. The relevant log line that indicates success/failure
3. The extracted data (app name, API name, tier, etc.)

Example:
```
Q1: req-001 succeeded (200 OK)
    Log: "JWT token validated successfully for application: app1"
    Log: "Subscription found: tier=gold, keytype=PRODUCTION"
    Log: "Bucket allows request, count=1"
```

## Verification

You'll know you've analyzed correctly when:
- [ ] You can identify which request IDs succeeded
- [ ] You can explain the failure reason for each failed request
- [ ] You can match HTTP status codes to log patterns
- [ ] You can reference specific log lines to support your answers

## Hints

- Successful requests have no WARN or ERROR logs
- 401 failures mention "Token expired" or "Signature verification failed"
- 403 failures mention "API subscription not found"
- 429 failures mention "Request throttled"
- Timestamps can help you correlate requests across the log file

## Teardown

No cleanup needed — this is a log analysis exercise with no running services.

