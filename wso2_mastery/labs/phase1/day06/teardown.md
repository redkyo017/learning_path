# Day 6 Lab Teardown

## Stop the server

```
Ctrl+C
```

## What gets cleaned up automatically

- RSA key pair — generated in memory at startup, gone on exit
- All issued JWTs — exist only as strings returned to curl clients; not stored server-side
- No files, no database, no Docker containers were created

## Port check

If `:9443` is still in use:

```bash
lsof -i :9443
kill <pid>
```

## Remove Go module files (optional)

```bash
cd labs/phase1/day06
rm -f go.mod go.sum
```

## Note on key persistence between days

Days 5 and 6 both generate a fresh RSA key on startup with `kid=dev-key-1`.
A JWT issued by the Day 5 server will fail validation against the Day 6 server (different
private keys, same `kid`). This is intentional lab behaviour — in production, the signing
key is loaded from persistent storage so tokens survive restarts.

When you start Day 7 work (introspection), the same teardown applies: stop the process,
no external state to clean.
