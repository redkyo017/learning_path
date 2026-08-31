# Day 7 Lab — Token Introspection (RFC 7662)

## What this lab does

Adds a `/oauth2/introspect` endpoint to the Day 6 JWT server. The endpoint:

- Requires Basic Auth on the **caller** (prevents token oracle attacks)
- Validates the submitted token via JWT signature + expiry check
- Checks the `revokedTokens` map (populated by Day 8's revoke endpoint)
- Returns full RFC 7662 response with WSO2-specific extension claims when active

## Setup

```bash
cd labs/phase1/day07
go mod init wso2lab/day07
go get github.com/golang-jwt/jwt/v5
go run main.go
```

Server starts on `http://localhost:9443`.

---

## Exercise 1 — Issue a token

```bash
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret \
  -d grant_type=client_credentials | jq -r .access_token)
echo "Token: ${TOKEN:0:60}..."
```

---

## Exercise 2 — Introspect a valid token (expect active:true)

```bash
curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret \
  -d "token=$TOKEN" | jq .
```

Expected response:
```json
{
  "active": true,
  "sub": "test-client",
  "iss": "https://localhost:9443/oauth2/token",
  "exp": 1724003600,
  "iat": 1724000000,
  "client_id": "test-client",
  "token_type": "Bearer",
  "http://wso2.org/claims/applicationname": "DefaultApp",
  "http://wso2.org/claims/keytype": "PRODUCTION"
}
```

---

## Exercise 3 — Introspect an invalid / fabricated token (expect active:false)

```bash
curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret \
  -d "token=this.is.not.a.valid.jwt" | jq .
```

Expected response:
```json
{ "active": false }
```

Note: No reason is disclosed. RFC 7662 §2.2 — the response must not reveal whether the token was malformed, expired, or unknown.

---

## Exercise 4 — Call introspect without authentication (expect 401)

```bash
curl -v -X POST http://localhost:9443/oauth2/introspect \
  -d "token=$TOKEN" 2>&1 | grep -E "< HTTP|WWW-Authenticate"
```

Expected:
```
< HTTP/1.1 401 Unauthorized
< WWW-Authenticate: Basic realm="introspection"
```

---

## Teardown

See `teardown.md`.
