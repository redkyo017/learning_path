# Day 15 Lab — Final Key Manager with Request Logging

## Goal

Run the Phase 1 capstone Key Manager, make several requests, and observe the
structured JSON logs.  Then grep by correlation_id to trace a single request
end-to-end.

---

## Setup

```bash
cd labs/phase1/day15
go mod init keymanager
go get github.com/golang-jwt/jwt/v5
```

---

## Run

In terminal 1 — start the KM and tee logs to a file:

```bash
go run main.go 2>&1 | tee /tmp/km.log
```

You should see:

```json
{"time":"...","level":"INFO","msg":"server_starting","addr":":9444","day":15,"phase":1}
{"time":"...","level":"INFO","msg":"Key Manager ready — Phase 1 complete","addr":":9444"}
```

---

## Exercise 1 — Issue a token and observe the log

In terminal 2:

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "test-client:test-secret" \
  -d "grant_type=client_credentials" | jq .
```

In `/tmp/km.log` you should see two JSON lines:
1. `"msg":"request_received"` with `method`, `path`, and `correlation_id`.
2. `"msg":"token_issued"` with `client_id` and `exp`.

---

## Exercise 2 — Grep by correlation_id

Find the correlation_id from the token_issued line:

```bash
CORR_ID=$(grep '"msg":"token_issued"' /tmp/km.log | tail -1 | jq -r .correlation_id)
echo "Correlation ID: $CORR_ID"
grep "$CORR_ID" /tmp/km.log | jq .
```

You should see all log lines for that single request.

---

## Exercise 3 — Test client auth failure

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "bad-client:wrong-secret" \
  -d "grant_type=client_credentials"
# {"error":"invalid_client"}
```

In `/tmp/km.log`, find the `token_rejected` line and note the `reason` field.

---

## Exercise 4 — Pass activityid header (APIM Gateway simulation)

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -H "activityid: my-gateway-trace-001" \
  -u "test-client:test-secret" \
  -d "grant_type=client_credentials" | jq .

grep "my-gateway-trace-001" /tmp/km.log | jq .
```

The `correlation_id` in all log lines should be `my-gateway-trace-001` —
matching the ID the APIM Gateway would have set.

---

## Teardown

See `teardown.md`.
