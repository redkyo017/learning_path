# Day 18 — Gin at the Edge + REST-to-gRPC Transcoding

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Layer Gin middleware on top of a stdlib `httputil.ReverseProxy` handler
- Explain the REST-to-gRPC translation problem: what must be converted and at what cost
- Forward context across the protocol boundary: HTTP headers → gRPC metadata → HTTP headers
- Understand what `grpc-gateway` automates versus what you must handle manually
- Inject and propagate request IDs at the gateway edge

---

## Core mental model

**Transcoding is protocol translation — your gateway speaks both languages and translates between them.**

A REST-to-gRPC gateway is a bilingual interpreter. The REST client speaks HTTP/1.1 with JSON bodies. The upstream speaks HTTP/2 with length-prefixed protobuf frames. The gateway must translate:

- URL path + method → gRPC service + method name
- JSON request body → serialized protobuf bytes
- HTTP request headers → gRPC metadata entries
- Protobuf response bytes → JSON response body
- gRPC status code → HTTP status code

Every one of these conversions can fail. Most production incidents in transcoders are either marshaling failures (type mismatch, unknown field) or metadata loss (auth token not forwarded).

---

## Request flow diagram

```
REST Client
    │
    │  POST /v1/users  (HTTP/1.1, Content-Type: application/json)
    │  Body: {"name": "alice", "email": "alice@example.com"}
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                 Gateway (Gin + Transcoder)            │
│                                                      │
│  1. Gin middleware chain runs (auth, rate-limit, log) │
│  2. Route matched: POST /v1/users                    │
│  3. JSON body unmarshaled into CreateUserRequest{}   │
│  4. gRPC metadata built from HTTP headers            │
│  5. gRPC call made: UserService.CreateUser(ctx, req) │
│                                                      │
└──────────────────────────────────────────────────────┘
    │
    │  /users.UserService/CreateUser (HTTP/2, application/grpc)
    │  Body: <5-byte length prefix><protobuf bytes>
    │
    ▼
gRPC Upstream
    │
    │  CreateUserResponse{id: "u_123", name: "alice"}
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                 Gateway (reverse path)               │
│                                                      │
│  6. Protobuf response → JSON marshaling              │
│  7. gRPC status → HTTP status mapping                │
│  8. Response headers set                             │
│                                                      │
└──────────────────────────────────────────────────────┘
    │
    │  HTTP/1.1 200 OK, Content-Type: application/json
    │  Body: {"id": "u_123", "name": "alice"}
    │
    ▼
REST Client
```

---

## gRPC over the wire: what the protocol actually looks like

Understanding the wire format helps you debug transcoding failures.

**HTTP/2 + gRPC framing:**
- A gRPC call is a standard HTTP/2 request
- Method is always `POST`
- Path is `/package.ServiceName/MethodName` (e.g., `/users.UserService/CreateUser`)
- `Content-Type` is `application/grpc` (or `application/grpc+proto`)
- The body is a stream of length-prefixed messages:
  - 1 byte: compression flag (0 = uncompressed)
  - 4 bytes: message length (big-endian uint32)
  - N bytes: protobuf-encoded message

**gRPC status codes travel in HTTP/2 trailers** — the `grpc-status` and `grpc-message` headers arrive after the response body, not in the initial headers. This is why HTTP/1.1 intermediaries (ALBs, older proxies) can fail with gRPC.

---

## Layering Gin on top of `httputil.ReverseProxy`

Gin and `net/http` are fully compatible — a Gin engine implements `http.Handler`. You can wrap any `http.Handler` (including a `ReverseProxy`) to be used as a Gin endpoint.

```go
func mountProxyRoute(router *gin.Engine, path string, proxy http.Handler) {
    // Any method, any sub-path
    router.Any(path+"/*proxyPath", func(c *gin.Context) {
        // Rewrite the URL so the full path is preserved for the proxy
        c.Request.URL.Path = c.Param("proxyPath")
        proxy.ServeHTTP(c.Writer, c.Request)
    })
}
```

For transcoding endpoints (REST → gRPC), you do not use a `ReverseProxy` at all. Instead, Gin handles the HTTP side and your code makes a direct gRPC call:

```go
router.POST("/v1/users", func(c *gin.Context) {
    var req pb.CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    ctx := metadataFromGinContext(c)
    resp, err := userClient.CreateUser(ctx, &req)
    if err != nil {
        c.JSON(grpcStatusToHTTP(err), gin.H{"error": grpcErrMessage(err)})
        return
    }

    c.JSON(http.StatusOK, resp)
})
```

### Gin middleware chain

Order matters. Every middleware in the chain runs before the handler, and deferred cleanup runs after:

```
Request
  │
  ▼
Recovery         ← catches panics, returns 500
  │
  ▼
RequestID        ← injects/extracts X-Request-ID
  │
  ▼
Logger           ← logs method, path, latency, status
  │
  ▼
Auth             ← validates JWT, injects claims into context
  │
  ▼
RateLimit        ← per-client token bucket check
  │
  ▼
Handler          ← transcodes and calls gRPC upstream
```

```go
r := gin.New()
r.Use(
    gin.Recovery(),
    RequestIDMiddleware(),
    StructuredLoggerMiddleware(),
    JWTMiddleware(jwtSecret),
    RateLimitMiddleware(limiter),
)
```

---

## The translation problem: HTTP → gRPC

### Path and method mapping

REST URLs are semantically rich: `GET /users/{id}` means "retrieve user by ID". gRPC paths are just `ServiceName/MethodName`. You must define this mapping explicitly — either in proto annotations (grpc-gateway style) or in your router.

```
GET  /v1/users/{id}  →  UserService.GetUser(GetUserRequest{id: id})
POST /v1/users       →  UserService.CreateUser(CreateUserRequest{...})
PUT  /v1/users/{id}  →  UserService.UpdateUser(UpdateUserRequest{id: id, ...})
```

### JSON to protobuf marshaling

Use `google.golang.org/protobuf/encoding/protojson` for canonical JSON ↔ protobuf conversion. It handles field name mapping (camelCase JSON ↔ snake_case proto), enum values, and well-known types (`google.protobuf.Timestamp`).

```go
import "google.golang.org/protobuf/encoding/protojson"

// JSON → protobuf
var req pb.CreateUserRequest
if err := protojson.Unmarshal(body, &req); err != nil {
    // handle
}

// protobuf → JSON
jsonBytes, err := protojson.Marshal(resp)
```

`c.ShouldBindJSON` also works if the protobuf struct uses standard JSON tags — but `protojson` handles edge cases (unknown fields, enum names) more correctly.

### gRPC status code → HTTP status code mapping

gRPC has its own status codes. You must map them to HTTP:

| gRPC Code | HTTP Status | Meaning |
|---|---|---|
| OK (0) | 200 | Success |
| NOT_FOUND (5) | 404 | Resource does not exist |
| INVALID_ARGUMENT (3) | 400 | Bad request / validation failure |
| ALREADY_EXISTS (6) | 409 | Conflict |
| PERMISSION_DENIED (7) | 403 | Insufficient permissions |
| UNAUTHENTICATED (16) | 401 | Missing or invalid credentials |
| RESOURCE_EXHAUSTED (8) | 429 | Rate limited |
| INTERNAL (13) | 500 | Server error |
| UNAVAILABLE (14) | 503 | Service temporarily down |
| DEADLINE_EXCEEDED (4) | 504 | Timeout |

```go
import "google.golang.org/grpc/codes"
import "google.golang.org/grpc/status"

func grpcStatusToHTTP(err error) int {
    st, ok := status.FromError(err)
    if !ok {
        return http.StatusInternalServerError
    }
    switch st.Code() {
    case codes.NotFound:
        return http.StatusNotFound
    case codes.InvalidArgument:
        return http.StatusBadRequest
    case codes.Unauthenticated:
        return http.StatusUnauthorized
    case codes.PermissionDenied:
        return http.StatusForbidden
    case codes.AlreadyExists:
        return http.StatusConflict
    case codes.ResourceExhausted:
        return http.StatusTooManyRequests
    case codes.Unavailable:
        return http.StatusServiceUnavailable
    case codes.DeadlineExceeded:
        return http.StatusGatewayTimeout
    default:
        return http.StatusInternalServerError
    }
}
```

---

## Metadata forwarding: HTTP headers ↔ gRPC metadata

gRPC metadata is logically equivalent to HTTP headers: it is a `map[string][]string` sent with the request. The gateway must explicitly forward relevant headers as metadata, and extract metadata from responses as response headers.

```go
import "google.golang.org/grpc/metadata"

// HTTP request → gRPC outgoing metadata
func metadataFromGinContext(c *gin.Context) context.Context {
    ctx := c.Request.Context()
    md := metadata.MD{}

    // Forward request ID
    if id := c.GetString("request_id"); id != "" {
        md["x-request-id"] = []string{id}
    }

    // Forward authorization (JWT already validated — forward as-is or forward claims)
    if auth := c.GetHeader("Authorization"); auth != "" {
        md["authorization"] = []string{auth}
    }

    // Forward trace context
    if traceparent := c.GetHeader("traceparent"); traceparent != "" {
        md["traceparent"] = []string{traceparent}
    }

    return metadata.NewOutgoingContext(ctx, md)
}
```

### The gRPC metadata naming convention

gRPC metadata keys that end in `-bin` are binary (base64-encoded). All other keys are treated as ASCII. The conventional header prefix for forwarding HTTP headers to gRPC is `Grpc-Metadata-*` (used by grpc-gateway), but your own gateway can use any key names your upstreams understand.

---

## What `grpc-gateway` automates vs. building it manually

`grpc-gateway` generates a complete transcoding reverse proxy from proto annotations. Understanding the line between automated and manual helps you decide whether to use it.

| Concern | grpc-gateway | Manual |
|---|---|---|
| Path/method mapping | From proto `google.api.http` annotations | Your router |
| JSON ↔ protobuf | `protojson` — generated | `protojson` — you call it |
| gRPC status → HTTP status | Built-in | You implement it |
| Streaming (server-side) | Supported via chunked encoding | You implement it |
| OpenAPI spec generation | From proto (with `protoc-gen-openapiv2`) | Manual or separate tool |
| Custom middleware | Limited (use interceptors) | Full Gin middleware chain |
| Custom error formats | Requires custom error handler | Your code |

**Use grpc-gateway when:**
- You have a proto-first service and want standard REST semantics with minimal code
- You need OpenAPI docs generated from the same source of truth as the proto

**Build manually when:**
- Your gateway is the product (you own the routing logic, not the upstream proto)
- You need non-standard HTTP semantics (custom error shapes, non-REST URLs)
- Your Gin middleware chain must run before transcoding (auth, custom rate limiting)

---

## Request ID injection

Every request entering the gateway should carry a unique ID. This ID must be the same in:
- The gateway's access log
- The gRPC metadata forwarded to the upstream
- The upstream's logs
- The response header returned to the client

```go
func RequestIDMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        id := c.GetHeader("X-Request-ID")
        if id == "" {
            id = newRequestID() // uuid.New().String() or similar
        }
        // Store in Gin context for later middleware
        c.Set("request_id", id)
        // Echo back to client
        c.Header("X-Request-ID", id)
        c.Next()
    }
}
```

If the upstream returns its own `X-Request-ID` in the response (forwarded from gRPC metadata), `ModifyResponse` in the proxy can merge them.

---

## Returning engineer: what changed since 1.16–1.18

| Area | Change | Version |
|---|---|---|
| gRPC | `google.golang.org/grpc/status` — `FromError` always returns a status (was less reliable pre-1.x API stabilization) | grpc-go v1.40+ |
| protobuf | `google.golang.org/protobuf` (v2 API) replaced `github.com/golang/protobuf` — use `protojson`, `proto.Marshal` from the new module | 2020 onwards |
| Gin | Gin v1.9 added `c.ShouldBindBodyWith` for reading body multiple times | Gin 1.9 |
| gRPC | `grpc.NewClient` replaces deprecated `grpc.Dial` for connection creation | grpc-go v1.64 |
| Go stdlib | `net/http/httputil.ProxyRequest` and `ReverseProxy.Rewrite` field | Go 1.20 |

The `github.com/golang/protobuf` → `google.golang.org/protobuf` migration is the most common source of confusion for returning engineers. If you see `proto.Marshal` imports from the old path, the code predates the v2 API. Both are compatible at the Go module level but have different package paths.

---

## Key concepts to memorize

- Gin implements `http.Handler` — it wraps or delegates to any stdlib handler
- gRPC bodies are length-prefixed protobuf, not raw JSON — never return raw JSON on a gRPC endpoint
- gRPC status codes travel in HTTP/2 **trailers**, not initial headers
- gRPC metadata is the equivalent of HTTP headers — explicit forwarding is required
- `protojson` handles the JSON ↔ protobuf canonical mapping; `encoding/json` works but misses proto-specific edge cases
- `grpc-gateway` eliminates boilerplate at the cost of inflexibility; manual transcoding is more work but more controllable

---

## Common mistakes

1. **Using `encoding/json` instead of `protojson`.** Standard JSON marshaling ignores proto-specific semantics: `google.protobuf.Timestamp` becomes an object literal instead of an RFC3339 string, enum values become integers instead of names, and `oneof` fields may serialize incorrectly.

2. **Forgetting to forward the Authorization header as gRPC metadata.** The JWT is validated at the gateway but the upstream still needs the user's identity. Forward either the raw token or the validated claims as metadata — document which one your upstreams expect.

3. **Not handling gRPC trailer-only responses.** When a gRPC call fails immediately (before sending any response bytes), the status is sent as a trailer-only response. Libraries handle this transparently, but if you are parsing the wire format manually you must handle the `trailers-only` case.

4. **Mounting Gin at the root and also mounting a `ReverseProxy` at the root.** Gin and `ReverseProxy` both try to own the root. Use distinct path prefixes, or mount the proxy as a Gin `NoRoute` handler.

5. **Creating a new gRPC client connection per request.** A `grpc.ClientConn` is expensive — it manages connection pooling and health checking. Create one connection per upstream at startup and reuse it.

---

## Check your understanding

1. A REST client sends `POST /v1/orders` with a JSON body containing a `created_at` field as a Unix timestamp integer. Your protobuf definition uses `google.protobuf.Timestamp`. What marshaling library do you use, and what format should `created_at` be in for `protojson` to parse it correctly?

2. Your gateway validates JWTs in a Gin middleware and stores the user ID in the Gin context. The gRPC upstream needs the user ID to authorize the request. Describe the two approaches for passing it to the upstream, and which you prefer for a production gateway.

3. The grpc-gateway generated code handles the `/v1/users/{id}` → `UserService.GetUser` mapping automatically. What capability do you lose compared to writing the handler manually with Gin, and in what kind of production scenario would that matter?
