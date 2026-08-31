# Day 11 Teardown

The Day 11 lab runs a plain `go run` process — no containers, no background services.

## Stop the server

In the terminal running `go run main.go`, press `Ctrl+C`.

## Clean up temporary files

```bash
rm -f /tmp/km_app.json /tmp/km_token.json
```

## Clean up Go module files (optional)

If you want to reset the module to a clean state:

```bash
cd labs/phase1/day11/keymanager
rm -f go.mod go.sum
```

Re-run `go mod init keymanager && go get github.com/golang-jwt/jwt/v5` to restore.

## Nothing persists

The client registry (`sync.Map`) and revoked-token set live entirely in
process memory.  All state is lost when the server stops.  No database,
no files, no Docker volumes to remove.
