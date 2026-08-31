# Teardown

1. Stop the server: `Ctrl+C` in the terminal running `go run main.go`.
2. No Docker containers to stop.
3. No cloud resources created.
4. Check: `lsof -i :9443` returns empty.

If port 9443 is still in use after `Ctrl+C`:

```bash
# Find the process holding port 9443
lsof -i :9443

# Kill by PID (replace <pid> with the actual PID from lsof output)
kill <pid>
```

## State cleanup note
The Go server uses in-memory `sync.Map` for both `tokenStore` and `codeStore`.
All state is lost when the process stops — no external cleanup required.
Any authorization codes in flight (issued but not yet exchanged) expire with the process.
