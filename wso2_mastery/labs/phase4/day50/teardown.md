# Day 50 — Teardown

To stop the server:

1. In the terminal where `go run main.go` is running, press **Ctrl+C**

```
^C
```

Expected output:
```
^C
```

The server will shut down and return to the shell prompt.

## Optional: Clean up compiled binary

If you ran `go build`:

```bash
rm -f day50  # or day50.exe on Windows
```

## Next steps

- Review the exercises in SOLUTION.md
- Modify `main.go` to add the RateLimitHandler or other custom handlers
- Compare the Go chain to the WSO2 APIHandler interface you'll explore in Day 49 source reading
