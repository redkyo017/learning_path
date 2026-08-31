# Day 8 Lab — Teardown

## Stop the server

Foreground: press `Ctrl+C`.

Background:
```bash
kill $(lsof -ti :9443)
```

## Remove module files

```bash
cd labs/phase1/day08
rm -f go.mod go.sum
```

## Verify port is free

```bash
lsof -i :9443
# No output = port is free
```

## Notes

- All state (RSA key, `revokedTokens` map) is in memory only.
- Stopping the server clears all revocations. Every restart begins with a fresh, empty revocation map.
- No external services (no database, broker, or container) are used.
