# Day 5 Lab — JWT-Issuing Server

## Goal
Run a local OAuth2 server that issues RSA-signed JWTs, then decode the token manually
to see the WSO2 claim format. Also verify the JWKS endpoint returns a valid public key.

## Setup

```bash
cd labs/phase1/day05

# Initialise a Go module (do this once)
go mod init wso2lab/day05

# Fetch the JWT library
go get github.com/golang-jwt/jwt/v5

# Run the server
go run main.go
```

Expected startup log:
```
RSA-2048 dev key generated (kid=dev-key-1) — DO NOT use in production
Day 5 server listening on :9443
```

## Test 1: Issue a JWT

```bash
curl -s -u test-client:test-secret \
  -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token | python3 -m json.tool
```

Expected response:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6ImRldi1rZXktMSIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": ""
}
```

## Test 2: Decode the JWT manually

Save the token and decode it with `base64 -d`:

```bash
# Save just the access_token value
TOKEN=$(curl -s -u test-client:test-secret \
  -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo "=== Header ==="
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null; echo

echo "=== Payload ==="
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

You should see the payload includes:
- `iss`, `sub`, `iat`, `exp`, `jti` — standard RFC 7519 claims
- `http://wso2.org/claims/subscriber` — value: `test-client`
- `http://wso2.org/claims/applicationname` — value: `DefaultApp`
- `http://wso2.org/claims/applicationtier` — value: `Unlimited`
- `http://wso2.org/claims/version` — value: `v1`
- `http://wso2.org/claims/keytype` — value: `PRODUCTION`

## Test 3: Fetch the JWKS

```bash
curl -s http://localhost:9443/oauth2/jwks | python3 -m json.tool
```

Expected structure:
```json
{
  "keys": [
    {
      "alg": "RS256",
      "e": "AQAB",
      "kid": "dev-key-1",
      "kty": "RSA",
      "n": "<long base64url string — the RSA modulus>",
      "use": "sig"
    }
  ]
}
```

Note that `e` is almost always `AQAB` — this is `65537` encoded in Base64URL.
The `n` value changes on every server restart because a new RSA key is generated.

## Test 4: Verify the modulus length

A 2048-bit RSA key has a 256-byte modulus. Check:

```bash
N=$(curl -s http://localhost:9443/oauth2/jwks \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['keys'][0]['n'])")

# Count the decoded bytes — should be 256
echo $N | base64 -d 2>/dev/null | wc -c
```

## Test 5: Bad credentials

```bash
curl -s -u wrong-client:wrong-secret \
  -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token
# => {"error":"invalid_client"}
```

## Troubleshooting

**Port already in use:** Another process is on :9443. Find and stop it:
```bash
lsof -i :9443
kill <pid>
```

**base64 padding error:** Some `base64` implementations require padding. Use the padded
version from Day 4 README, or install `jq` and use:
```bash
echo $TOKEN | cut -d'.' -f2 | jq -R 'split("") | [.[] | ltrimstr("=")] | join("") | @base64d | fromjson'
```

**Module not found:** Make sure you ran `go mod init` and `go get` from the `day05/` directory.
