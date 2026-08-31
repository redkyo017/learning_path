# Day 5 Lab Teardown

## Stop the server

The server runs as a foreground process. Stop it with:

```
Ctrl+C
```

## What gets cleaned up automatically

- The RSA key pair — generated in memory at startup, discarded on exit
- Any issued JWTs — they exist only as strings returned to curl; not stored server-side
- No database, no files, no Docker containers were created

## Remove the Go module cache (optional)

If you want to remove the downloaded dependencies:

```bash
cd labs/phase1/day05
rm go.mod go.sum
rm -rf $(go env GOPATH)/pkg/mod/github.com/golang-jwt
```

Or to clean only the module files for this lab:

```bash
rm -f labs/phase1/day05/go.mod labs/phase1/day05/go.sum
```

## Port check

If `:9443` is still in use after stopping (e.g. the process was backgrounded):

```bash
lsof -i :9443
kill <pid>
```

## Nothing persists between runs

Every restart of `go run main.go` generates a fresh RSA key with the same `kid` value
(`dev-key-1`). Any JWTs issued in a previous run will fail signature verification after
restart because the public key changes. This is expected lab behaviour — it illustrates why
production systems must persist their signing keys.
