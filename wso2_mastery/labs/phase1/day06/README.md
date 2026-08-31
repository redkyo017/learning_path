# Day 6 Lab — Gateway Validation Middleware

## Goal
Run the server, issue a JWT from `/oauth2/token`, call the protected `/api/hello` endpoint,
and observe that it returns claims extracted from the token. Then test the rejection paths:
missing token and invalid/expired token.

## Setup

```bash
cd labs/phase1/day06

go mod init wso2lab/day06
go get github.com/golang-jwt/jwt/v5
go run main.go
```

Expected startup log:
```
RSA-2048 dev key generated (kid=dev-key-1) — DO NOT use in production
Day 6 server listening on :9443
```

## Test 1: Issue a JWT and call the protected endpoint

```bash
# Step 1: issue a token
TOKEN=$(curl -s -u test-client:test-secret \
  -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo "Token (first 60 chars): ${TOKEN:0:60}..."

# Step 2: call the protected endpoint
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:9443/api/hello | python3 -m json.tool
```

Expected response from `/api/hello`:
```json
{
  "application": "DefaultApp",
  "expires_at": "2026-01-01T01:00:00Z",
  "issuer": "https://localhost:9443/oauth2/token",
  "keytype": "PRODUCTION",
  "message": "hello from protected endpoint",
  "subject": "test-client",
  "subscriber": "test-client",
  "tier": "Unlimited",
  "version": "v1"
}
```

## Test 2: Missing Authorization header → 401

```bash
curl -s http://localhost:9443/api/hello
```

Expected:
```json
{"error":"missing_token"}
```
HTTP status: `401 Unauthorized`

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:9443/api/hello
# => 401
```

## Test 3: Invalid token → 401

```bash
curl -s -H "Authorization: Bearer not.a.real.jwt" \
  http://localhost:9443/api/hello
```

Expected:
```json
{"error":"invalid_token"}
```

The server log will show the parse error, e.g.:
```
JWT validation failed: token is malformed: ...
```

## Test 4: Tampered payload → 401

A JWT signature covers both the header and payload. Changing even one byte in the payload
invalidates the signature.

```bash
# Decode the payload, add a space, re-encode and re-assemble
HEADER=$(echo $TOKEN | cut -d'.' -f1)
PAYLOAD=$(echo $TOKEN | cut -d'.' -f2)
SIG=$(echo $TOKEN | cut -d'.' -f3)

# Append a character to the payload (tampers it)
TAMPERED="${HEADER}.${PAYLOAD}X.${SIG}"

curl -s -H "Authorization: Bearer $TAMPERED" \
  http://localhost:9443/api/hello
# => {"error":"invalid_token"}
```

## Test 5: Verify the JWKS is accessible without authentication

```bash
curl -s http://localhost:9443/oauth2/jwks | python3 -m json.tool
```

The JWKS endpoint is public — no Authorization header needed. This matches WSO2 IS
behaviour: the public key must be accessible to any API gateway for token verification.

## Teardown

See `teardown.md`.
