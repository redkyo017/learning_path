# Solution: Day 21 — Full Gateway with JWT Validation

## Docker Compose Setup

Create a `docker-compose.yml` file in `labs/phase2/day21/`:

```yaml
version: '3.8'

services:
  # Phase 1 Key Manager - issues JWTs and serves JWKS
  key-manager:
    build:
      context: ../../phase1/day15
      dockerfile: Dockerfile
    container_name: wso2-km
    ports:
      - "8888:8888"
    environment:
      PORT: 8888
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888/health"]
      interval: 5s
      timeout: 3s
      retries: 3

  # Day 21 Gateway - validates JWTs and routes requests
  gateway:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: wso2-gateway
    ports:
      - "9090:9090"
    environment:
      JWKS_URL: http://key-manager:8888/oauth2/jwks
      PORT: 9090
      BACKEND_PORT: 8080
    depends_on:
      key-manager:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090/health"]
      interval: 5s
      timeout: 3s
      retries: 3
```

## Dockerfile for Gateway

Create a `Dockerfile` in `labs/phase2/day21/`:

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o gateway main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates curl

WORKDIR /app
COPY --from=builder /build/gateway .

EXPOSE 9090

CMD ["./gateway"]
```

## Running with Docker Compose

```bash
cd labs/phase2/day21

# Build and start both services
docker-compose up --build

# In another terminal:
TOKEN=$(curl -s http://localhost:8888/token?username=alice | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

## Endpoint Behavior

### GET /health (No JWT Required)

**Request:**
```bash
curl http://localhost:9090/health
```

**Response:**
```json
{"status":"UP"}
```

**Code:**
```go
mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"UP"}`)
}))
```

This endpoint is registered directly on the mux, outside the JWT middleware chain.

### GET /api/info (JWT Required)

**Request:**
```bash
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

**Response:**
```json
{
  "Sub": "alice@carbon.super",
  "Iss": "http://localhost:8888",
  "Exp": 1234567890,
  "Iat": 1234567890,
  "http://wso2.org/claims/subscriber": "alice",
  "http://wso2.org/claims/applicationname": "default",
  "http://wso2.org/claims/applicationtier": "Unlimited",
  "http://wso2.org/claims/version": "1.0.0",
  "http://wso2.org/claims/keytype": "PRODUCTION"
}
```

**Code:**
```go
mux.Handle("/api/info", Chain(
    http.HandlerFunc(apiInfoHandler),
    jwtValidationMiddleware(jwksURL),
))

func apiInfoHandler(w http.ResponseWriter, r *http.Request) {
    claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
    if !ok {
        http.Error(w, `{"error":"claims_missing"}`, http.StatusInternalServerError)
        return
    }
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(claims)
}
```

This endpoint is wrapped in the JWT validation middleware, so:
1. The middleware validates the JWT
2. Stores claims in the request context
3. Calls the apiInfoHandler
4. Handler retrieves and returns claims

### Any Other Path (JWT Required, Proxied)

**Request:**
```bash
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test
```

**Response:**
```json
{
  "message": "mock backend response",
  "path": "/mock/test",
  "method": "GET"
}
```

**Code:**
```go
gateway := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    recoveryMiddleware,
)

mux.Handle("/", gateway)
```

All paths except `/health` and `/api/info` go through the full middleware chain:
1. Request ID is assigned
2. Request is logged
3. JWT is validated and claims stored in context
4. Panic recovery is set up
5. Request is proxied to mock backend

## Middleware Execution Order

The `Chain` function applies middlewares from right to left, so:

```go
Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    recoveryMiddleware,
)
```

Executes in this order on the way in:

```
requestIDMiddleware
    ↓
loggingMiddleware
    ↓
jwtValidationMiddleware
    ↓
recoveryMiddleware
    ↓
proxy
```

And on the way out (after the response):

```
recoveryMiddleware (defer runs)
    ↓
jwtValidationMiddleware (defer runs)
    ↓
loggingMiddleware (logs request)
    ↓
requestIDMiddleware (returns)
```

## Error Handling

All error cases return JSON responses with proper HTTP status codes:

| Case | Status | Response |
|------|--------|----------|
| Valid JWT, all checks pass | 200 | (endpoint response or proxied response) |
| Missing `Authorization` header | 401 | `{"error":"missing_token"}` |
| Malformed or invalid JWT | 401 | `{"error":"invalid_token"}` |
| `kid` not found in JWKS | 401 | `{"error":"invalid_token"}` |
| JWKS endpoint unreachable | 401 | `{"error":"jwks_unavailable"}` |
| Panic in downstream handler | 500 | `{"error":"internal_server_error"}` |

## Testing End-to-End

```bash
# Start services
docker-compose up --build

# In another terminal:

# 1. Health check (no auth)
curl http://localhost:9090/health

# 2. Get token from KM
TOKEN=$(curl -s http://localhost:8888/token?username=alice | jq -r .token)

# 3. Call /api/info (requires JWT)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info

# 4. Call mock backend through gateway (requires JWT)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test

# 5. Try without JWT (should fail)
curl http://localhost:9090/api/info

# 6. Try with invalid JWT (should fail)
curl -H "Authorization: Bearer bad.token.here" http://localhost:9090/api/info

# 7. Check logs
docker-compose logs gateway
docker-compose logs key-manager
```

## Key Insights

1. **JWT validation is middleware, not an endpoint handler** — This ensures it applies to all routes
   (except those registered outside the middleware chain like `/health`).

2. **Context carries validated claims** — Downstream handlers access claims via typed context keys,
   avoiding global state or thread-local storage.

3. **Fail-closed semantics** — If the JWKS endpoint is unreachable and the cache is empty, tokens
   are rejected (401) rather than accepted. This prioritizes security.

4. **Two-stage validation handles key rotation** — If validation fails with a cached key, the
   middleware re-fetches JWKS once, allowing new keys to be picked up without restart.

5. **Graceful shutdown drains in-flight requests** — On SIGTERM (or Ctrl+C), the server waits up
   to 5 seconds for active requests to complete before exiting.

## Debugging

To see detailed logs:

```bash
# In docker-compose, increase log verbosity
export GODEBUG=http2debug=1
docker-compose up
```

To inspect a JWT:

```bash
TOKEN=$(curl -s http://localhost:8888/token?username=alice | jq -r .token)
jq -R 'split(".")[1] | @base64d | fromjson' <<< $TOKEN
```

To check JWKS:

```bash
curl http://localhost:8888/oauth2/jwks | jq .
```

