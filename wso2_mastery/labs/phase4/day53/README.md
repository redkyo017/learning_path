# Lab: Go Log Failure Classifier

## Overview

This Go program reads WSO2 log lines from stdin and classifies each line into one of 7 failure classes. It's a practical exercise in encoding real-world error patterns as regexes.

## Files

- `main.go` — the classifier source code
- `SOLUTION.md` — expected output and exercise solutions
- `teardown.md` — cleanup instructions

## Running the Classifier

### Basic Usage

Pipe a log file through the classifier:

```bash
cat ../../day47/sample.log | go run main.go
```

Expected output: each matched line is printed with its class and recommended action. Unmatched lines are skipped.

### Show Unmatched Lines

Use `--verbose` to also print lines with no match (marked `[OK]`):

```bash
cat ../../day47/sample.log | go run main.go --verbose
```

### Print Summary

Use `--summary` to print a count of each failure class at the end:

```bash
cat ../../day47/sample.log | go run main.go --summary
```

## Expected Output

When you run the classifier against `../../day47/sample.log`, you should see:

```
LINE (truncated)                CLASS                      ACTION
----------------------------------------------...
JWT expired: exp claim in t…    JWT_EXPIRED                Client re-auths; check NTP on GW/IS containers
```

The sample.log has one JWT_EXPIRED entry (line 7).

## Exercises

See `SOLUTION.md` for the full exercises and solutions.

### Exercise 1: Add --summary Flag

Extend the classifier to accept a `--summary` flag that prints a count of each failure class at the end. See `SOLUTION.md` for the solution.

### Exercise 2: Catch a Regex False Positive

The regex for `JWT_EXPIRED` uses `\bexp\b` (word boundary) to avoid matching `jwt.experience`. Write a test case that would catch this bug if the word boundary were missing. See `SOLUTION.md`.

### Exercise 3: Add a CERTIFICATE_EXPIRED Class

Add a new failure class that matches `"certificate.*expired"` or `"SSL handshake"`. What symptom would trigger it in production? See `SOLUTION.md`.

## Testing

To verify the classifier works:

```bash
# Should find JWT_EXPIRED
echo "JWT expired: exp claim in the past" | go run main.go

# Should find nothing (unmatched)
echo "Everything is fine" | go run main.go

# Should find AUTH_FAILED
echo "Invalid Credentials error 900901" | go run main.go
```

## Compiling to Binary

To compile the classifier as a standalone binary (no Go runtime needed):

```bash
go build -o classifier main.go
./classifier < ../../day47/sample.log
```

Then you can copy it to any machine and use it without Go installed.
