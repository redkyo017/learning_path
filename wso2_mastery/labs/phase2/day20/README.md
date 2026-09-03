# Lab: Day 20 — JWKS-Backed JWT Validator Middleware

## Overview

This lab implements a JWT validation middleware that:
1. Fetches public keys from a JWKS endpoint
2. Caches keys in a `sync.Map` keyed by `kid`
3. Handles key rotation by re-fetching on validation failure
4. Stores validated claims in the request context

The middleware is standalone and ready to be integrated into the full gateway (Day 21).

## What You'll Build

A gateway with two key parts:

```go
// 1. Fetch and cache public keys from JWKS endpoint
func fetchPublicKey(jwksURL, kid string) (*rsa.PublicKey, error)

// 2. Middleware that validates JWT tokens
func jwtValidationMiddleware(jwksURL string) func(http.Handler) http.Handler
```

## Prerequisites

- Go 1.21+
- A working JWT issuer (the Phase 1 Go Key Manager, or any other JWKS-compatible server)
- `curl` or similar HTTP client for testing

## Setup

### Option 1: Using Phase 1 Go Key Manager

If you have Phase 1 of the learning path, you can use its Go Key Manager as a token issuer:

```bash
# Terminal 1: Start the Phase 1 KM (token issuer)
cd ../../phase1/day15  # Assuming day15 is the KM lab
go run main.go
# KM runs on :8888 and exposes /oauth2/jwks endpoint
```

### Option 2: Using a Local Mock JWKS Endpoint

If you don't have Phase 1, you can start a mock key server. We provide a helper script:

```bash
# Mock server will run on :8888 and serve fake JWTs
# See SOLUTION.md for details
```

### Option 3: Using an External Key Server

Point `JWKS_URL` to any JWKS-compatible endpoint (e.g., a real WSO2 KM, Keycloak, Auth0):

```bash
export JWKS_URL=https://your-key-server/oauth2/jwks
```

## Running the Lab

### Step 1: Start the Token Issuer

```bash
# Terminal 1: Start Phase 1 KM (if available)
cd ../../phase1/day15
go run main.go
# Listens on :8888
# Exposes: GET /oauth2/jwks (JWKS endpoint)
#          GET /token?username=alice (issue token)
```

If you don't have Phase 1 available, skip this step and use the mock server from Option 2.

### Step 2: Run the Gateway

```bash
# Terminal 2: In labs/phase2/day20/
export JWKS_URL=http://localhost:8888/oauth2/jwks
go run main.go
# Gateway listens on :9090
```

### Step 3: Get a Token

```bash
# Terminal 3: Get a token from the KM
curl -s "http://localhost:8888/token?username=alice" | jq .
# Response: {"token": "<JWT>"}

# Or with jq:
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
echo $TOKEN
```

### Step 4: Test JWT Validation

```bash
# Call the gateway with a valid token
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/

# You should see a response. If validation failed, you'd see:
# {"error":"invalid_token"}
```

## Expected Behavior

### Successful JWT Validation

Request:
```bash
curl -H "Authorization: Bearer <valid-token>" http://localhost:9090/health
```

Response:
```
HTTP/1.1 200 OK
{"status":"UP"}
```

The token was validated successfully. The claims are now in the request context.

### Missing Token

Request:
```bash
curl http://localhost:9090/health
```

Response:
```
HTTP/1.1 401 Unauthorized
{"error":"missing_token"}
```

### Invalid Token

Request:
```bash
curl -H "Authorization: Bearer invalid.token.here" http://localhost:9090/
```

Response:
```
HTTP/1.1 401 Unauthorized
{"error":"invalid_token"}
```

### JWKS Endpoint Unreachable

If the JWKS endpoint is down and the cache is empty:

Request:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:9090/
```

Response:
```
HTTP/1.1 401 Unauthorized
{"error":"jwks_unavailable"}
```

## Key Rotation Handling

To test key rotation:

1. Start the gateway with a token signed by key `kid1`
2. Let the token validate successfully (key cached)
3. Simulate key rotation: have the KM rotate keys (remove `kid1`, add `kid2`)
4. Send a new token signed by `kid2` to the gateway
5. First validation attempt fails with cached key
6. Middleware re-fetches JWKS, finds `kid2`, validates successfully

This demonstrates the two-stage validation approach.

## Code Structure

`main.go` contains:

- **`WSO2Claims`** — Custom JWT claims structure with WSO2 namespaced fields
- **`claimsKey`** — Typed context key for storing claims
- **`jwksCache`** — Thread-safe cache of public keys by `kid`
- **`fetchPublicKey`** — Fetch JWKS and extract public key for a given `kid`
- **`jwtValidationMiddleware`** — Middleware that validates JWT and stores claims in context

## What You Learn

- How to parse JWK (JSON Web Key) format into Go's `rsa.PublicKey`
- Using `sync.Map` for thread-safe caching without locks
- Extracting the `kid` from a JWT header without full verification
- Two-stage validation: cache + re-fetch on miss
- Storing validated claims in `context.Context` for downstream handlers
- Handling key rotation gracefully

## Dependencies

This lab uses only the standard library plus one external package:

```go
import (
    "github.com/golang-jwt/jwt/v5"  // JWT parsing and verification
)
```

To install:

```bash
go mod init gateway
go get github.com/golang-jwt/jwt/v5
go mod tidy
```

## Troubleshooting

**"error":"jwks_unavailable"**

- Check that `JWKS_URL` environment variable is set correctly
- Verify the JWKS endpoint is reachable: `curl <JWKS_URL>`
- If using Phase 1 KM, ensure it's running on `:8888`

**"error":"invalid_token"**

- Verify the token is correctly signed by the key server
- Check that the token is not expired: `jq -R 'split(".")[1] | @base64d | fromjson' <<< $TOKEN`
- Ensure the `kid` in the token header matches a key in the JWKS response

**"error":"missing_token"**

- Include the `Authorization: Bearer <token>` header in your request
- Use `curl -H "Authorization: Bearer $TOKEN" ...`

## Next Steps

Proceed to Day 21 to integrate this JWT validation middleware into the complete gateway from Day 18.

