# Lab Day 3 — Authorization Code Grant + PKCE

## Goal
Implement the two-step authorization code flow in Go. Test the full round-trip with `curl`:
1. GET `/oauth2/authorize` → server redirects with a `code`
2. POST `/oauth2/token` with the code → server returns an access token
3. POST `/oauth2/token` with the same code again → server returns `invalid_grant`

## Prerequisites
- Go 1.22+
- `curl`

## Run
```bash
go run main.go
```

Server listens on `http://localhost:9443`.

## Test

### Step 1: Get an authorization code

```bash
# The -L flag follows the redirect; -v shows headers
# We do NOT want to follow the redirect here — we want to capture the code
curl -v "http://localhost:9443/oauth2/authorize?response_type=code&client_id=test-client&redirect_uri=http://localhost:8080/callback&state=xyz123" 2>&1 | grep -i location
```

Expected: the server returns HTTP 302 with a `Location` header like:
```
Location: http://localhost:8080/callback?code=<code>&state=xyz123
```

Extract the code from the Location header. Set it as a shell variable:
```bash
CODE="<paste the code value here>"
```

### Step 2: Exchange the code for a token

```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${CODE}&redirect_uri=http://localhost:8080/callback"
```

Expected response (HTTP 200):
```json
{"access_token":"<random>","token_type":"Bearer","expires_in":3600,"scope":""}
```

### Step 3: Second exchange — should fail

```bash
# Reuse the same code — single-use enforcement
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${CODE}&redirect_uri=http://localhost:8080/callback"
```

Expected response (HTTP 400):
```json
{"error":"invalid_grant"}
```

### Test PKCE flow

Generate a code verifier and challenge (requires `openssl` or Python):
```bash
# Generate a random verifier
VERIFIER=$(openssl rand -base64 32 | tr -d '=+/' | head -c 43)
echo "verifier: $VERIFIER"

# Compute the challenge: SHA256 then base64url-encode (no padding)
CHALLENGE=$(echo -n "$VERIFIER" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
echo "challenge: $CHALLENGE"
```

Authorization request with PKCE:
```bash
curl -v "http://localhost:9443/oauth2/authorize?response_type=code&client_id=test-client&redirect_uri=http://localhost:8080/callback&code_challenge=${CHALLENGE}&code_challenge_method=S256&state=pkce123" 2>&1 | grep -i location
```

Extract the code and exchange with the verifier:
```bash
CODE_PKCE="<paste the code value>"

curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${CODE_PKCE}&redirect_uri=http://localhost:8080/callback&code_verifier=${VERIFIER}"
```

Expected: token issued. Exchange with wrong verifier returns `invalid_grant`.

### Test wrong response_type

```bash
curl -v "http://localhost:9443/oauth2/authorize?response_type=token&client_id=test-client&redirect_uri=http://localhost:8080/callback" 2>&1 | grep -i location
```

Expected: redirect to `http://localhost:8080/callback?error=unsupported_response_type`.

## Exercises
See `content/phase1/day03.md` §Exercises.

## Teardown
See `teardown.md`.
