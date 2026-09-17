# Teardown

## Status

No running processes. The classifier is a CLI tool that reads stdin and exits immediately.

## Cleanup

If you compiled the classifier to a binary:

```bash
rm -f classifier
```

Otherwise, there's nothing to clean up. The `go run main.go` command doesn't leave any processes running.

## Verification

Verify there are no lingering processes:

```bash
ps aux | grep -i classifier
ps aux | grep -i main.go
```

Should return no results (or just the grep command itself).

## Next Steps

Move on to Day 54, where you'll build the bash triage script that uses similar patterns to classify logs even faster.
