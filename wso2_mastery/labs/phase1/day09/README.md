# Day 9 Lab — End-to-End Lifecycle + Structured Logging

## What this lab adds

- **`log/slog` JSON output**: all log lines are machine-readable JSON objects.
- **Correlation ID middleware**: every HTTP request gets a unique 22-character ID stored in context; every handler includes it in its slog calls.
- **Typed context key**: `correlationKey{}` (unexported empty struct) prevents key collisions with any imported package.
- **Named log events**: `token_issued`, `token_validated`, `token_invalid`, `token_revoked`, `introspect_called`, `revoke_called`.

## Setup

```bash
cd labs/phase1/day09
go mod init wso2lab/day09
go get github.com/golang-jwt/jwt/v5
```

Requires Go 1.21+ (for `log/slog`).

---

## Exercise 1 — Run the server and observe JSON logs

Run the server and pipe stdout through `jq` to view formatted structured logs:

```bash
go run main.go | jq .
```

The startup line looks like:
```json
{"time":"2026-08-31T10:00:00Z","level":"INFO","msg":"server_starting","addr":":9443","day":9}
```

---

## Exercise 2 — Full lifecycle, structured log capture

In one terminal, capture logs to a file:
```bash
go run main.go > /tmp/lifecycle.json
```

In another terminal, run the complete lifecycle:
```bash
#!/usr/bin/env bash
BASE="http://localhost:9443"
CREDS="test-client:test-secret"

TOKEN=$(curl -s -X POST "$BASE/oauth2/token" \
  -u "$CREDS" -d grant_type=client_credentials | jq -r .access_token)
echo "Issued"

curl -s -X POST "$BASE/oauth2/introspect" \
  -u "$CREDS" -d "token=$TOKEN" | jq .active
echo "Introspected (expect true)"

curl -s -o /dev/null -X POST "$BASE/oauth2/revoke" \
  -u "$CREDS" -d "token=$TOKEN"
echo "Revoked"

curl -s -X POST "$BASE/oauth2/introspect" \
  -u "$CREDS" -d "token=$TOKEN" | jq .active
echo "Introspected again (expect false)"
```

Stop the server (`Ctrl+C`), then inspect the log file:

```bash
# List all event types in order
jq -r .msg /tmp/lifecycle.json

# Find all log lines for a specific token (by token_prefix)
PREFIX=$(jq -r 'select(.msg=="token_issued") | .correlation_id' /tmp/lifecycle.json | head -1)
jq "select(.correlation_id == \"$PREFIX\")" /tmp/lifecycle.json

# Show the introspect_called lines with their active field
jq 'select(.msg == "introspect_called") | {correlation_id, active, reason}' /tmp/lifecycle.json
```

---

## Exercise 3 — Search logs by correlation ID

Each HTTP request gets its own correlation ID. Identify the correlation ID from the `token_revoked` event, then find all log lines sharing it:

```bash
REVOKE_CORR=$(jq -r 'select(.msg=="token_revoked") | .correlation_id' /tmp/lifecycle.json)
echo "Revoke correlation_id: $REVOKE_CORR"
jq "select(.correlation_id == \"$REVOKE_CORR\")" /tmp/lifecycle.json
```

Expected: 2 lines for the revoke request — `token_revoked` and `revoke_called` — both sharing the same `correlation_id`.

---

## Teardown

See `teardown.md`.
