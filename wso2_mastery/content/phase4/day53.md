# Day 53: Building a Log Failure Classifier in Go

## Why This Matters

Writing the log classifier forces you to **encode every failure class as a regex**. This regex is exactly what you'll use later in:
- CloudWatch Metrics Filters (to trigger alarms)
- Datadog pipeline rules (to tag incidents)
- Splunk saved searches

If your regex doesn't match the real error message in production, your monitoring will miss the incident.

**Time value:** Spending 30 minutes to get the regex right in the lab saves you 2 hours debugging a missed incident in production.

---

## Core Concepts

### Failure Rules

A `FailureRule` struct has:
- `Pattern *regexp.Regexp` — the compiled regex to match against log lines
- `Class FailureClass` — the name of the failure class (e.g., `AUTH_FAILED`)
- `Action string` — the immediate action to take

The classifier reads log lines from stdin, applies each rule in order (first match wins), and prints only the matched lines with their class and action.

### Case Sensitivity

WSO2 error messages vary in capitalization across versions:
- Some logs say `"JWT expired"` (lowercase)
- Others say `"JWT Expired"` (title case)
- Still others say `"jwt expired"` (all lowercase)

Always use `(?i)` in your regex to make it case-insensitive. Example: `regexp.MustCompile(`(?i)jwt expired`)` matches "JWT expired", "jwt expired", "JWT Expired", etc.

### Word Boundaries

The regex `JWT expired` will match:
- `"JWT expired"` ✓
- `"token was JWT expired"` ✓
- `"jwt_expired_at"` ✗ (good, not what we want)

But `exp` without a word boundary will match:
- `"exp claim"` ✓
- `"exp_time"` ✓
- `"jwt.experience"` ✗ (BAD! This is a custom claim, not an expiration)

Use `\bexp\b` (word boundary before and after) to match only the word `exp` as a whole word.

### First Match Wins

The rules are applied in order. If two rules could match the same line, whichever rule is first in the array wins. Put the most specific rules first. Example:
```go
// WRONG: generic rule first blocks specific rule
{regexp.MustCompile(`(?i)jwt`), ClassJWTGeneric, "..."},
{regexp.MustCompile(`(?i)jwt expired`), ClassJWTExpired, "..."},
```

```go
// RIGHT: specific rules first
{regexp.MustCompile(`(?i)jwt expired`), ClassJWTExpired, "..."},
{regexp.MustCompile(`(?i)jwt`), ClassJWTGeneric, "..."},
```

---

## The Classifier Tool

The `labs/phase4/day53/main.go` program:
1. Reads log lines from stdin (one per line)
2. For each line, iterates the `FailureRule` array
3. On first match, increments a counter, prints the line with class and action
4. On no match, skips the line (or prints with `[OK]` if `--verbose`)
5. If `--summary`, prints a count of each class at the end

### Usage

```bash
# Pipe a log file through the classifier
cat sample.log | go run main.go

# Print only failures (default)
cat sample.log | go run main.go | grep -v "[OK]"

# Print all lines (matched and unmatched)
cat sample.log | go run main.go --verbose

# Print counts by class at the end
cat sample.log | go run main.go --summary
```

---

## Anti-Patterns to Avoid

1. **Case-sensitive regex.** Always use `(?i)` for error messages. WSO2 logs vary in capitalization.

2. **Printing all lines including unmatched.** When you pipe a 500MB log file, a noisy output defeats the purpose. Print only matched failures.

3. **Hardcoding log line format assumptions.** Don't assume the error message is always at position 10. Use `strings.Contains()` or regex matching on the whole line.

4. **Not testing edge cases.** A regex that matches `"JWT expired"` might also match `"jwt_experience"` if you use `.` instead of `\b`. Test with a word boundary.

---

## Exercises

### Exercise 1: Add a --summary Flag (Hint: map[FailureClass]int)

**Scenario:** You want to know how many of each failure class appeared in a large log file, for your incident report. Extend the classifier to accept a `--summary` flag that prints counts at the end.

**Hint:** Use `map[FailureClass]int` to track counts. After processing all lines, iterate the rules and print one line per class showing the count.

**Solution Sketch:**
```go
// In main()
counts := make(map[FailureClass]int)

// In the matching loop
if class, action, matched := classify(line); matched {
  counts[class]++
}

// At the end, if --summary flag is set:
if *summary {
  fmt.Println("\n--- Summary ---")
  for _, r := range rules {
    fmt.Printf("%-30s %d\n", r.Class, counts[r.Class])
  }
}
```

---

### Exercise 2: Catch a Regex False Positive (Hint: Word Boundary)

**Scenario:** The regex for `JWT_EXPIRED` is `(?i)jwt expired|token expired|\bexp\b claim`. A developer's custom claim called `"jwt.experience"` is in the response. Does the current regex match it? Write a test case that exposes the bug.

**Hint:** Look at the `\bexp\b` part. Word boundaries protect you from matching `exp` inside `experience`. But what about `experience` in a claim name like `"jwt.experience"`?

**Solution Sketch:**
- Line: `"Custom claim jwt.experience=123"`
- The regex `\bexp\b claim` looks for `exp` as a whole word followed by space and the word `claim`.
- The line does NOT match because `exp` is inside `experience` (no word boundary after `p`).
- But if you wrote `\bexp\b` without the `claim` part, it would match `jwt.experience` incorrectly.
- Fix: Use `\bexp\b claim` (word boundary and specific context) or `(?i)jwt expired|token expired|expired.*claim`.

---

### Exercise 3: Add a CERTIFICATE_EXPIRED Class (Hint: TLS Handshake Error)

**Scenario:** IS's keystore certificate is about to expire. When it does, the GW→IS HTTPS connection will fail with an SSL handshake error. Add a `CERTIFICATE_EXPIRED` failure class to the classifier that matches `"certificate.*expired"` or `"SSL handshake"`.

**Hint:** What symptom would this cause? If the GW can't connect to IS over HTTPS, what endpoint would fail?

**Solution Sketch:**
- Add a new constant: `ClassCertExpired FailureClass = "CERTIFICATE_EXPIRED"`
- Add a new rule: `{regexp.MustCompile(`(?i)certificate.*expired|ssl handshake`), ClassCertExpired, "Check IS certificate expiry; renew keystore"}`
- Symptom: The GW's JWT introspection calls to IS fail. Every request gets 401 with `JWT_INVALID_SIGNATURE` because the GW can't validate the JWT signature (can't reach IS).
- Action: Check IS certificate expiry (`openssl x509 -in keystore.jks -text` or keytool); renew the keystore; restart IS.

---

## Key Takeaway

The regex you write here is not just for learning. It's a pattern you'll use in production monitoring forever. Get it right in the lab, and it scales to production automatically. Get it wrong, and you'll miss incidents.

Test your regex against real log lines from production, not just the happy path.
