# Day 12 Lab — Complete Key Manager: Docker Packaging

## What this lab builds

A production-shaped WSO2 3rd-party Key Manager that:
- Implements all seven Key Manager endpoints.
- Logs every request as structured JSON with a correlation ID.
- Reads its port from the `PORT` environment variable.
- Runs in a minimal Docker container built with a multi-stage Dockerfile.

## Setup

```bash
cd labs/phase1/day12/keymanager
go mod init keymanager
go get github.com/golang-jwt/jwt/v5
```

## Run locally (without Docker)

```bash
go run main.go
# {"time":"...","level":"INFO","msg":"server_starting","addr":":9444","day":12}
```

## Run with Docker Compose

```bash
docker compose up --build
```

Expected output:

```
keymanager-1  | {"time":"...","level":"INFO","msg":"server_starting","addr":":9444","day":12}
keymanager-1  | {"time":"...","level":"INFO","msg":"Key Manager ready","addr":":9444"}
```

## Smoke test

### 1. Health check

```bash
curl http://localhost:9444/health
# {"status":"UP"}
```

### 2. Register an application (simulates APIM subscription)

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/keymanager/application \
  -H "Content-Type: application/json" \
  -d '{"applicationName":"BillingService","grantTypes":["client_credentials"],"callbackUrl":""}' \
  | tee /tmp/km_app.json | jq .
```

### 3. Issue a token

```bash
CLIENT_ID=$(jq -r .clientId /tmp/km_app.json)
CLIENT_SECRET=$(jq -r .clientSecret /tmp/km_app.json)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  | tee /tmp/km_token.json | jq .
```

### 4. Introspect the token

```bash
TOKEN=$(jq -r .access_token /tmp/km_token.json)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/introspect \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "token=${TOKEN}" | jq .active
# true
```

### 5. JWKS

```bash
curl http://localhost:9444/api/am/keymanager/v1/jwks | jq '.keys[0].kty'
# "RSA"
```

## Observe structured logs

Each request produces a JSON log line.  View them in the Docker Compose terminal:

```json
{"time":"2026-08-31T10:00:01Z","level":"INFO","msg":"app_registered",
 "correlation_id":"aB3xQ7...","app_name":"BillingService","client_id":"dGVzdC..."}

{"time":"2026-08-31T10:00:02Z","level":"INFO","msg":"token_issued",
 "correlation_id":"zY9pK2...","client_id":"dGVzdC...","exp":1756688402}
```

Every request gets a unique `correlation_id`.  Search logs by this value to
trace a single developer subscription flow across all log lines.

## PORT override

Run on a different port without changing the Dockerfile:

```bash
PORT=8080 go run main.go
```

Or in Docker:

```bash
docker run --rm -e PORT=8080 -p 8080:8080 \
  $(docker compose images -q keymanager)
```
