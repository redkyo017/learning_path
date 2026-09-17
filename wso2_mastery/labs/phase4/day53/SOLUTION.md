# Exercise Solutions

## Exercise 1: Add --summary Flag

**Task:** Extend the classifier to accept a `--summary` flag that prints a count of each failure class at the end.

**Solution:**

The code already includes the `--summary` flag implementation:

```go
summary := flag.Bool("summary", false, "print counts per class at end")
flag.Parse()

counts := make(map[FailureClass]int)

// In the main loop, increment the count for each matched class:
if !matched {
  // ...
  continue
}
counts[class]++
// ...

// At the end, if --summary flag is set:
if *summary && len(counts) > 0 {
  fmt.Println("\n--- Summary ---")
  for _, r := range rules {
    if n := counts[r.Class]; n > 0 {
      fmt.Printf("  %-26s %d\n", r.Class, n)
    }
  }
}
```

**How to use:**

```bash
cat ../../day47/sample.log | go run main.go --summary
```

Expected output:
```
LINE (truncated)                CLASS                      ACTION
----------------------------------------------...
JWT expired: exp claim in t…    JWT_EXPIRED                Client re-auths; check NTP on GW/IS containers

--- Summary ---
  JWT_EXPIRED                  1
```

---

## Exercise 2: Catch a Regex False Positive

**Task:** The regex for `JWT_EXPIRED` is `(?i)jwt expired|token expired|\bexp\b claim`. A developer's custom claim called `"jwt.experience"` is in the response. Does the current regex match it? Write a test case that would expose the bug.

**Solution:**

Test case:
```bash
echo "Custom claim jwt.experience=123" | go run main.go
```

**Result:** The regex does NOT match because:
1. `\bexp\b` looks for the word `exp` surrounded by word boundaries.
2. In `"jwt.experience"`, the letter `e` before `xp` and the letter `r` after `exp` are both word characters.
3. So there is NO word boundary before `p` (it's preceded by `e`) and NO word boundary after `p` (it's followed by `e`).
4. Therefore, `\bexp\b` does NOT match `experience`.

**However**, if someone wrote the regex without the word boundary (just `(?i)jwt expired|token expired|exp claim`), it would match:
```bash
echo "Custom claim jwt.experience=123" | go run main.go
# Would incorrectly match as JWT_EXPIRED
```

**Why the word boundary matters:**
- `\b` matches the boundary between a word character and a non-word character.
- Word characters are: `[a-zA-Z0-9_]`
- Non-word characters are: everything else (space, punctuation, etc.)
- In `jwt.experience`, the `.` is a non-word character, so there IS a word boundary after `jwt` and before `experience`.
- But inside `experience`, between `exp` and `erience`, there is NO word boundary because both are word characters.

**Lesson:** Always use word boundaries (`\b`) when matching specific keywords that might appear as parts of longer words. Otherwise, you'll get false positives.

---

## Exercise 3: Add a CERTIFICATE_EXPIRED Class

**Task:** Add a new failure class that matches `"certificate.*expired"` or `"SSL handshake"`. What symptom would trigger it in production?

**Solution:**

Add to the rules array:

```go
type FailureClass string

const (
  // ... existing classes ...
  ClassCertExpired    FailureClass = "CERTIFICATE_EXPIRED"
)

var rules = []FailureRule{
  // ... existing rules ...
  {regexp.MustCompile(`(?i)certificate.*expired|ssl handshake`), ClassCertExpired, "Check IS certificate expiry; renew keystore; restart IS"},
}
```

**Production Symptom:**

When the IS certificate expires:
1. The GW→IS HTTPS connection fails with an SSL handshake error.
2. The GW can no longer call the IS JWT introspection endpoint (`/oauth2/introspect`).
3. Every incoming request with a JWT fails validation.
4. The GW returns **401 Unauthorized** with `JWT_INVALID_SIGNATURE` errors.

**Triage Steps:**

1. See `JWT_INVALID_SIGNATURE` errors in the GW log.
2. Try to manually verify the JWT: `curl -k https://is.wso2.internal:9443/oauth2/jwks` from the GW pod.
3. Get an SSL certificate error (handshake failure).
4. Check the IS certificate expiry: `openssl x509 -in /path/to/cert.pem -dates` or use `keytool` on the keystore.
5. If expired, renew the certificate and import it into the IS keystore.
6. Restart IS to load the new certificate.
7. Restart the GW (it will re-attempt the connection and succeed).

**Key Insight:** A certificate issue manifests as a JWT validation failure, not a certificate error. You need to follow the chain of symptoms to find the root cause.

---

## Testing All Patterns

Here's a quick test to verify all 7 failure classes are matched:

```bash
#!/bin/bash

# Test all 7 failure classes
echo "Testing AUTH_FAILED..."
echo "Invalid Credentials error" | go run main.go | grep AUTH_FAILED

echo "Testing SUBSCRIPTION_NOT_FOUND..."
echo "no valid subscription found" | go run main.go | grep SUBSCRIPTION_NOT_FOUND

echo "Testing THROTTLE_EXCEEDED..."
echo "Throttle limit exceeded 900800" | go run main.go | grep THROTTLE_EXCEEDED

echo "Testing BACKEND_TIMEOUT..."
echo "connection timed out to backend" | go run main.go | grep BACKEND_TIMEOUT

echo "Testing JWT_EXPIRED..."
echo "JWT expired: exp claim in the past" | go run main.go | grep JWT_EXPIRED

echo "Testing JWT_INVALID_SIGNATURE..."
echo "Signature verification failed" | go run main.go | grep JWT_INVALID_SIGNATURE

echo "Testing EVENT_SYNC_LAG..."
echo "eventHub received error from CP" | go run main.go | grep EVENT_SYNC_LAG

echo "Done!"
```

All 7 should match.

---

## Takeaway

- **Word boundaries prevent false positives.** Use `\bkeyword\b` to match whole words.
- **Case-insensitive regexes are mandatory.** WSO2 logs vary in capitalization. Always use `(?i)`.
- **Order matters.** Specific rules should come before generic ones.
- **Test edge cases.** Don't just test the happy path; test partial matches, near-misses, and false positives.
