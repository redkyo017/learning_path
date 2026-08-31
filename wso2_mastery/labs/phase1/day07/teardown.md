# Day 7 Lab — Teardown

## Stop the server

If you ran it in the foreground, press `Ctrl+C`.

If you ran it in the background:
```bash
# Find the process
lsof -ti :9443

# Kill it
kill $(lsof -ti :9443)
```

## Remove module files

```bash
cd labs/phase1/day07
rm -f go.mod go.sum
```

## Verify port is free

```bash
lsof -i :9443
# No output = port is free
```

## Notes

- The server holds all state in memory (RSA key, `revokedTokens` map). Nothing is written to disk.
- Stopping the server clears all issued tokens and revocations — the next run starts with a fresh key pair.
- No database, no container, no external dependencies to clean up.
