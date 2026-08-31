# Day 8 Lab — Token Revocation (RFC 7009)

## What this lab does

Adds a `/oauth2/revoke` endpoint to the Day 7 server. Key RFC 7009 behaviours demonstrated:

- Requires Basic Auth on the revoking client
- Stores revoked tokens in `revokedTokens sync.Map`
- **Always returns HTTP 200** — even for unknown or already-revoked tokens
- After revocation, introspect returns `{"active": false}`

## Setup

```bash
cd labs/phase1/day08
go mod init wso2lab/day08
go get github.com/golang-jwt/jwt/v5
go run main.go
```

Server starts on `http://localhost:9443`.

---

## Full lifecycle round-trip script

Copy and run this script in one pass to see all four stages:

```bash
#!/usr/bin/env bash
set -e

BASE="http://localhost:9443"
CREDS="test-client:test-secret"

echo "=== 1. Issue token ==="
TOKEN=$(curl -s -X POST "$BASE/oauth2/token" \
  -u "$CREDS" -d grant_type=client_credentials | jq -r .access_token)
echo "Token prefix: ${TOKEN:0:40}..."

echo ""
echo "=== 2. Introspect — expect active:true ==="
curl -s -X POST "$BASE/oauth2/introspect" \
  -u "$CREDS" -d "token=$TOKEN" | jq '{active, sub, exp}'

echo ""
echo "=== 3. Revoke — expect HTTP 200 ==="
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE/oauth2/revoke" \
  -u "$CREDS" -d "token=$TOKEN")
echo "HTTP status: $HTTP_STATUS"

echo ""
echo "=== 4. Introspect again — expect active:false ==="
curl -s -X POST "$BASE/oauth2/introspect" \
  -u "$CREDS" -d "token=$TOKEN" | jq .
```

---

## Exercise — Revoke an unknown token

```bash
curl -v -X POST http://localhost:9443/oauth2/revoke \
  -u test-client:test-secret \
  -d "token=this-was-never-issued"
```

Expected: `HTTP/1.1 200 OK` with empty body. This is correct per RFC 7009 §2.2 — a uniform 200 prevents token fishing attacks.

---

## Exercise — Revoke without credentials (expect 401)

```bash
curl -v -X POST http://localhost:9443/oauth2/revoke \
  -d "token=anything"
```

Expected: `HTTP/1.1 401 Unauthorized` with `{"error":"invalid_client"}`.

---

## Teardown

See `teardown.md`.
