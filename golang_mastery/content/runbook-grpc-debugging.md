# Runbook: gRPC Service Debugging

**When to use this runbook:**
- A gRPC call returns an unexpected error or status code
- Auth failures: `UNAUTHENTICATED` or `PERMISSION_DENIED` when credentials look correct
- ALB / load balancer connection issues (works locally, fails behind ALB)
- `UNIMPLEMENTED` errors when the service and method definitely exist
- gRPC works on plaintext but fails with TLS

---

## Background

gRPC errors are richer than HTTP errors. Every failed call carries a `status.Status` with a `Code` and a human-readable `Message`. The first debugging step is always: get the exact status code. The code alone narrows the problem space to 2–3 causes.

---

## Step 1: Get the exact status code

In Go, extract the status from the error:

```go
import "google.golang.org/grpc/status"
import "google.golang.org/grpc/codes"

if err != nil {
    st, ok := status.FromError(err)
    if !ok {
        // Not a gRPC status error — likely a transport/connection error
        log.Printf("non-status error: %v", err)
        return
    }
    log.Printf("gRPC error: code=%v message=%q", st.Code(), st.Message())
}
```

### The 5 most common gRPC status codes

| Code | Number | Most common causes |
|---|---|---|
| `UNAVAILABLE` | 14 | Service is down; connection refused; ALB health check failing; TLS handshake failure; HTTP/1.1 proxy between client and server |
| `DEADLINE_EXCEEDED` | 4 | Request took longer than the client's deadline; upstream slow; network latency; large payload serialization |
| `UNAUTHENTICATED` | 16 | JWT is expired; JWT signed with wrong key; `Authorization` metadata key missing or wrong format; server expects `bearer` lowercase, client sends `Bearer` |
| `PERMISSION_DENIED` | 7 | Token is valid but the user lacks the required role or permission; server-side authorization check failed |
| `UNIMPLEMENTED` | 12 | Method name mismatch between client and server; proto not regenerated after change; server reflection disabled so client guessed wrong path; service registered on wrong server |

---

## Step 2: Verify with `grpcurl`

`grpcurl` is the gRPC equivalent of `curl`. Install: `brew install grpcurl` or `go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest`

### List available services (requires server reflection)

```bash
# Plaintext (no TLS)
grpcurl -plaintext localhost:9090 list
# Expected output:
# users.UserService
# grpc.reflection.v1alpha.ServerReflection

# With TLS
grpcurl localhost:9090 list

# With TLS but skip certificate verification (dev only)
grpcurl -insecure localhost:9090 list
```

### Describe a service or method

```bash
# List methods on a service
grpcurl -plaintext localhost:9090 describe users.UserService
# Expected output:
# users.UserService is a service:
# service UserService {
#   rpc GetUser ( .users.GetUserRequest ) returns ( .users.GetUserResponse );
#   rpc CreateUser ( .users.CreateUserRequest ) returns ( .users.CreateUserResponse );
# }

# Describe the request message shape
grpcurl -plaintext localhost:9090 describe users.GetUserRequest
# Expected output:
# users.GetUserRequest is a message:
# message GetUserRequest {
#   string id = 1;
# }
```

### Call a method

```bash
# Plaintext, no auth
grpcurl -plaintext \
  -d '{"id": "u_123"}' \
  localhost:9090 users.UserService/GetUser

# With Authorization header (JWT)
grpcurl -plaintext \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"id": "u_123"}' \
  localhost:9090 users.UserService/GetUser

# Expected success output:
# {
#   "id": "u_123",
#   "name": "Alice",
#   "email": "alice@example.com"
# }

# Expected auth failure output:
# ERROR:
#   Code: Unauthenticated
#   Message: missing or invalid token
```

### Call using proto files (when reflection is disabled)

```bash
# Point grpcurl at your proto files directly
grpcurl \
  -import-path ./proto \
  -proto users/v1/users.proto \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"id": "u_123"}' \
  localhost:9090 users.UserService/GetUser
```

---

## Step 3: ALB + gRPC specific issues

gRPC over AWS ALB requires specific configuration. HTTP/1.1 ALBs will silently break gRPC because gRPC requires HTTP/2.

### Checklist for ALB + gRPC

| Check | Correct value | How to verify |
|---|---|---|
| Target group protocol | HTTP with protocol version **gRPC** or **HTTP/2** | AWS console → Target Group → Attributes |
| Listener | HTTPS (port 443) with TLS certificate | ALB listener rules |
| Target group health check | gRPC health check (`/grpc.health.v1.Health/Check`) or HTTP returning 200 | Target Group → Health check settings |
| Client connection | Must use TLS when going through ALB | `grpcurl` with `-insecure` to test |

### Symptom: `UNAVAILABLE` behind ALB but works direct

The ALB is likely using HTTP/1.1 to forward to your service. HTTP/1.1 does not support gRPC's HTTP/2 framing.

Fix: set the target group's **Protocol version** to `HTTP2` or `gRPC`.

```bash
# Check if ALB is downgrading to HTTP/1.1
# Look for this in your service's access logs:
# "protocol":"HTTP/1.1"  ← wrong, gRPC needs HTTP/2
# "protocol":"HTTP/2.0"  ← correct
```

### Symptom: `UNAVAILABLE` with "connection closed before server preface received"

The client is using TLS but the server is plaintext (or vice versa).

```bash
# Test plaintext
grpcurl -plaintext your-alb.amazonaws.com:443 list
# If this fails with TLS error, try with TLS:
grpcurl your-alb.amazonaws.com:443 list
```

---

## Step 4: Auth interceptor debugging

### Verify the token is valid before blaming the service

```bash
# Decode JWT without verifying signature (dev only)
echo $JWT_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool
# Look for:
# "exp": 1753056000  ← Unix timestamp — check if expired
# "iss": "https://auth.example.com"  ← must match server's expected issuer
# "aud": ["gateway"]  ← must match server's expected audience
# "sub": "u_123"  ← user ID
```

### Check token expiry

```bash
# Convert exp to human time
date -r 1753056000  # macOS
date -d @1753056000 # Linux
```

### Metadata key format

gRPC metadata keys are case-insensitive but the authorization header must be lowercase in the Go gRPC library:

```go
// WRONG — some clients send this and it fails
md := metadata.Pairs("Authorization", "Bearer "+token)

// CORRECT — lowercase key
md := metadata.Pairs("authorization", "Bearer "+token)
```

### Test with explicit metadata via grpcurl

```bash
# grpcurl sends -H as gRPC metadata
grpcurl -plaintext \
  -H "authorization: Bearer $JWT_TOKEN" \
  -d '{"id": "u_123"}' \
  localhost:9090 users.UserService/GetUser
```

### Common auth interceptor log messages and causes

| Log message | Cause | Fix |
|---|---|---|
| `"token is expired"` | JWT `exp` is in the past | Get a new token; check clock skew between auth service and gateway |
| `"token is not valid yet"` | JWT `nbf` (not before) is in the future | Clock skew; token generated with wrong timestamp |
| `"signature is invalid"` | Token signed with different key than what server has | Verify public key matches; check key rotation |
| `"missing metadata key: authorization"` | Client did not send Authorization metadata | Check client interceptor or middleware |
| `"unexpected signing method"` | Server enforces RS256, client sent HS256 | Regenerate token with correct algorithm |

---

## Step 5: Reflection disabled in production

Server reflection is convenient in development but is a security risk in production — it lets anyone enumerate your service methods without knowing the proto files.

When reflection is disabled:

```bash
# This will fail:
grpcurl -plaintext localhost:9090 list
# Error: Failed to list services: server does not support the reflection API

# Use proto files instead:
grpcurl \
  -import-path ./proto \
  -proto users/v1/users.proto \
  -H "authorization: Bearer $JWT_TOKEN" \
  -d '{"id": "u_123"}' \
  prod-service:9090 users.UserService/GetUser
```

Keep a copy of the production service's proto files in a known location (e.g., a `contracts/` directory or a Buf Schema Registry). This allows `grpcurl` debugging without enabling reflection.

### Check if reflection is enabled

```bash
grpcurl -plaintext localhost:9090 grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo
# If reflection is enabled: empty response (no methods listed for the reflection service itself)
# If disabled: "Failed to dial target host"
```

---

## Quick reference

```bash
# List services
grpcurl -plaintext HOST:PORT list

# Describe service
grpcurl -plaintext HOST:PORT describe SERVICE

# Call with auth
grpcurl -plaintext -H "authorization: Bearer $TOKEN" -d '{...}' HOST:PORT SERVICE/METHOD

# Call with proto files
grpcurl -import-path ./proto -proto file.proto -H "authorization: Bearer $TOKEN" -d '{...}' HOST:PORT SERVICE/METHOD

# Call with TLS, skip verify (dev)
grpcurl -insecure -H "authorization: Bearer $TOKEN" -d '{...}' HOST:PORT SERVICE/METHOD

# Decode JWT payload
echo $TOKEN | cut -d'.' -f2 | base64 -d | python3 -m json.tool

# Check token expiry
date -r $(echo $TOKEN | cut -d'.' -f2 | base64 -d | python3 -c "import sys,json; print(json.load(sys.stdin)['exp'])")
```
