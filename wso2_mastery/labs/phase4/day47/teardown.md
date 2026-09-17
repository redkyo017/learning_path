# Day 47 — Teardown

## Clean Up

This is a stateless Go program with no running processes or services. Teardown is simple.

### Step 1: Stop the Parser (if still running)

If you left `go run main.go < sample.log` running:

```bash
Ctrl+C
```

This terminates the process immediately.

### Step 2: Verify No Process Running

```bash
ps aux | grep main.go
```

If no results (other than the grep itself), you're clean.

### Step 3: Clean Up Generated Files (Optional)

If you created test files during exploration:

```bash
# Remove test logs (keep sample.log for Day 48)
rm -f test*.log

# Remove any compiled binaries
rm -f main
```

### Step 4: Verify

```bash
ls -la
```

You should see:
- `main.go` (the source)
- `README.md`
- `SOLUTION.md`
- `teardown.md` (this file)
- `sample.log` (if you created it)

---

## What's Next?

You're ready for **Day 48: Extended Tracer with Filters**.

The Day 48 lab will build on `main.go` from this lab, adding:
- `--id` flag for filtering to a single trace
- `--service` flag for filtering to specific services
- `--format json` for JSON output
- Elapsed time calculation per service

No cleanup needed for Day 48 — it extends the same main.go structure.

---

## Summary

- **No running processes** — this was a one-off CLI tool
- **No databases or services** — the parser reads stdin and writes to stdout
- **No credentials or secrets** — sample.log is fake data
- **No file artifacts that need cleanup** — sample.log can be reused or deleted

You're clean and ready to move forward.
