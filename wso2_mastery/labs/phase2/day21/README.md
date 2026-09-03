# Lab: Day 21 — Full Gateway with JWT Validation Middleware

## Overview

This lab integrates the JWT validation middleware from Day 20 into the complete gateway from Day 18.
The resulting gateway:

1. Validates JWTs on incoming requests (except `/health`)
2. Stores validated claims in the request context
3. Exposes an `/api/info` endpoint that returns the validated claims for diagnostics
4. Routes all other requests through a reverse proxy to the mock backend
5. Handles graceful shutdown and panic recovery

This is a production-shaped gateway skeleton ready for subsequent enhancements (throttling, analytics).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Client Request                                                  │
└────────────────────────────┬──────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │ /health?         │
                    │ (no JWT needed)  │
                    └────────┬────────┘
                             │ No
           ┌─────────────────▼────────────────┐
           │ Middleware Chain:                │
           │ 1. Request ID                    │
           │ 2. Logging                       │
           │ 3. JWT Validation                │
           │ 4. Recovery                      │
           └────────┬─────────────────────────┘
                    │
           ┌────────▼─────────┐
           │ /api/info?       │
           │ (returns claims) │
           └────────┬────────┘
                    │ No
           ┌────────▼──────────────┐
           │ All other paths       │
           │ (ReverseProxy)        │
           └────────┬──────────────┘
                    │
           ┌────────▼──────────────┐
           │ Mock Backend (8080)   │
           └───────────────────────┘
```

## Prerequisites

- Go 1.21+
- Docker and Docker Compose (for running the full setup)
- Or: Phase 1 learning path for the Go KM token issuer

## Setup Option 1: Docker Compose (Recommended)

We provide a `docker-compose.yml` that starts both the Phase 1 Go Key Manager and this gateway.

### Building and Running

```bash
cd labs/phase2/day21

# Build and start both services
docker-compose up --build

# In another terminal:
# Get a token from the KM
TOKEN=$(curl -s http://localhost:8888/token?username=alice | jq -r .token)

# Test the gateway
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test
curl http://localhost:9090/health
```

### docker-compose.yml Structure

```yaml
version: '3.8'

services:
  # Phase 1 Key Manager - issues JWTs and serves JWKS
  key-manager:
    image: go-km:latest
    ports:
      - "8888:8888"
    environment:
      PORT: 8888

  # Day 21 Gateway - validates JWTs from KM
  gateway:
    image: go-gateway:latest
    ports:
      - "9090:9090"
    environment:
      JWKS_URL: http://key-manager:8888/oauth2/jwks
      PORT: 9090
    depends_on:
      - key-manager
```

## Setup Option 2: Local Go Execution

If you don't have Docker Compose, run both services directly:

```bash
# Terminal 1: Start Phase 1 KM
cd ../../phase1/day15
go run main.go

# Terminal 2: Start Day 21 Gateway
cd ../../day21
export JWKS_URL=http://localhost:8888/oauth2/jwks
go mod init gateway
go get github.com/golang-jwt/jwt/v5
go mod tidy
go run main.go

# Terminal 3: Test
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

## Testing

### Test 1: Health Check (No JWT Required)

```bash
curl http://localhost:9090/health
```

Expected response:
```json
{"status":"UP"}
```

### Test 2: Get API Info (JWT Required)

```bash
# Get a token
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)

# Send request with token
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

Expected response (JSON with validated claims):
```json
{
  "Sub": "alice@carbon.super",
  "Exp": 1693478400,
  "Iat": 1693478100,
  "http://wso2.org/claims/subscriber": "alice",
  "http://wso2.org/claims/applicationname": "default",
  "http://wso2.org/claims/applicationtier": "Unlimited",
  "http://wso2.org/claims/version": "1.0.0",
  "http://wso2.org/claims/keytype": "PRODUCTION"
}
```

### Test 3: Mock Backend Through Gateway (JWT Required)

```bash
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test
```

Expected response:
```json
{
  "message": "mock backend response",
  "path": "/mock/test",
  "method": "GET"
}
```

### Test 4: Missing JWT Token

```bash
curl http://localhost:9090/api/info
```

Expected response (401 Unauthorized):
```json
{"error":"missing_token"}
```

### Test 5: Invalid JWT Token

```bash
curl -H "Authorization: Bearer invalid.token.here" http://localhost:9090/api/info
```

Expected response (401 Unauthorized):
```json
{"error":"invalid_token"}
```

### Test 6: JWKS Endpoint Unreachable

Stop the KM, then try to validate a token:

```bash
# Terminal 1: Stop KM (Ctrl+C)

# Terminal 3: Try with an old token (cache is empty or expires)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

Expected response (401 Unauthorized):
```json
{"error":"jwks_unavailable"}
```

## Code Structure

### main.go Components

1. **JWT Types**
   - `WSO2Claims` — JWT payload structure with custom WSO2 claims
   - `claimsKey` — Typed context key for storing claims
   - `jwksCache` — Thread-safe cache of public keys

2. **JWT Validation**
   - `fetchPublicKey()` — Fetch JWKS and extract public key for a given `kid`
   - `jwtValidationMiddleware()` — Middleware that validates JWT and stores claims in context

3. **Middleware Chain**
   - `requestIDMiddleware` — Assigns X-Request-ID if missing
   - `loggingMiddleware` — Logs request method, path, and duration
   - `recoveryMiddleware` — Catches panics and returns 500 JSON
   - `Chain()` — Combines middlewares in a clean order

4. **Gateway Components**
   - `newReverseProxy()` — Creates reverse proxy to mock backend
   - `newMockBackend()` — Returns mock backend mux
   - `apiInfoHandler()` — Handles `/api/info` endpoint

5. **Lifecycle**
   - `main()` — Sets up servers, middleware chain, and graceful shutdown

### Request Flow

```
Client Request to /api/info with Bearer token
    ↓
mux routes to /api/info handler wrapped in jwtValidationMiddleware
    ↓
requestIDMiddleware (assigns X-Request-ID)
    ↓
loggingMiddleware (records start time)
    ↓
jwtValidationMiddleware (validates JWT, stores claims in context)
    ↓
recoveryMiddleware (wraps handler in defer/recover)
    ↓
apiInfoHandler (reads claims from context, returns JSON)
    ↓
Response: {"subscriber": "alice", "applicationname": "default", ...}
```

## Key Differences from Day 20

Day 20 had a standalone JWT middleware. Day 21 adds:

1. **`/api/info` endpoint** — Returns validated claims for testing
2. **Full middleware chain** — Includes request ID, logging, recovery
3. **Mock backend routing** — Routes non-JWT requests to mock backend
4. **Graceful shutdown** — Properly handles SIGTERM and drains connections

## Environment Variables

- `JWKS_URL` — JWKS endpoint URL (default: `http://localhost:8888/oauth2/jwks`)
- `PORT` — Gateway port (default: `9090`)
- `BACKEND_URL` — Mock backend URL (default: `http://localhost:8080`)
- `BACKEND_PORT` — Mock backend port (default: `8080`)

## Logs

The gateway logs all requests and key lifecycle events:

```
INFO gateway starting port=9090 backend=http://localhost:8080 jwks_url=http://localhost:8888/oauth2/jwks
INFO request method=GET path=/health duration_ms=1
INFO request method=GET path=/api/info duration_ms=45
INFO shutdown signal received
INFO shutdown complete
```

## Troubleshooting

**"error":"jwks_unavailable"**

- Check that the KM is running: `curl http://localhost:8888/oauth2/jwks`
- Verify `JWKS_URL` is set correctly
- Check network connectivity between gateway and KM

**"error":"invalid_token"**

- Token is expired: decode and check `exp` claim
- Token is signed with a different key: verify KM is running with consistent keys
- Token's `kid` doesn't match JWKS: verify KM hasn't rotated keys

**"error":"missing_token"**

- Include `Authorization: Bearer <token>` header
- Verify token variable is set: `echo $TOKEN`

**Connection refused to KM**

- KM is not running on `:8888`
- In docker-compose, use `http://key-manager:8888` (not `localhost`)
- In local mode, use `http://localhost:8888`

## Next Steps

This is the foundation for Task 3, which will add subscription throttling middleware to enforce
rate limits based on the subscription tier extracted from JWT claims.

