# Day 9 Lab — Teardown

## Stop the server

Foreground: press `Ctrl+C`.

Background:
```bash
kill $(lsof -ti :9443)
```

## Remove module files

```bash
cd labs/phase1/day09
rm -f go.mod go.sum
```

## Clean up log capture file (if used)

```bash
rm -f /tmp/lifecycle.json
```

## Verify port is free

```bash
lsof -i :9443
# No output = port is free
```

## Notes

- All state (RSA key, `revokedTokens` map) is in memory only. Stopping the server clears everything.
- No external services are used. Nothing to stop or delete beyond the Go process.
- Requires Go 1.21+ for `log/slog`. If you see a compilation error referencing `slog`, upgrade your Go installation.
