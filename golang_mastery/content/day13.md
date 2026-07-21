# Day 13 — gRPC Server + Interceptors

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Explain the HTTP/2 advantages that make gRPC different from REST
- Implement all four gRPC RPC patterns and pick the right one for a scenario
- Map gRPC status codes to HTTP equivalents without looking them up — and explain where the mapping breaks down
- Write a `UnaryServerInterceptor` for logging, auth, or metrics
- Chain multiple interceptors with `grpc.ChainUnaryInterceptor`
- Enable gRPC reflection for debugging with `grpcurl`

---

## Core mental model

**gRPC interceptors are identical in concept to Gin middleware — same stack pattern, different type signature.**

In Gin you write:

```go
func Logger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        log.Printf("took %v", time.Since(start))
    }
}
```

In gRPC you write:

```go
func LoggingInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    log.Printf("%s took %v", info.FullMethod, time.Since(start))
    return resp, err
}
```

The shape is different, but the mental model is identical: a function wraps the real handler, does work before, calls through, does work after. Chains of interceptors form a stack — the first registered executes outermost.

---

## gRPC over HTTP/2

gRPC uses HTTP/2 as its transport. Understanding three HTTP/2 features explains why gRPC is preferred over REST for internal services:

### Multiplexing

HTTP/1.1 has head-of-line blocking: one request per connection slot. If a slow response is in flight, faster ones queue behind it. HTTP/2 multiplexes many logical streams over a single TCP connection concurrently — a 100ms slow RPC does not block a 1ms fast RPC on the same connection.

For a service making 20 concurrent RPCs to a downstream, HTTP/1.1 requires a connection pool of ≥20. HTTP/2 needs one connection.

### Binary framing

HTTP/1.1 is text-based. HTTP/2 frames are binary with a fixed header format. This means:
- Less CPU spent parsing text headers.
- Length-prefixed frames make message boundaries unambiguous — no chunked encoding heuristics.
- gRPC's length-prefixed message framing sits directly on top of HTTP/2 data frames.

### Header compression (HPACK)

HTTP/2 compresses headers using HPACK, a static + dynamic table. For gRPC, this means repeated metadata (`:authority`, `content-type: application/grpc`, authorization headers) are transmitted as small integer references after the first request, not as full strings.

---

## The four gRPC patterns

| Pattern | Request | Response | Signature |
|---------|---------|----------|-----------|
| Unary | Single | Single | `rpc Foo(Req) returns (Resp)` |
| Server streaming | Single | Stream | `rpc Foo(Req) returns (stream Resp)` |
| Client streaming | Stream | Single | `rpc Foo(stream Req) returns (Resp)` |
| Bidirectional streaming | Stream | Stream | `rpc Foo(stream Req) returns (stream Resp)` |

### Unary

The simplest and most common. Behaves like a typed HTTP POST. Use it as the default unless you have a clear reason for streaming.

```go
func (s *server) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    u, err := s.repo.Find(ctx, req.Id)
    if err != nil {
        return nil, status.Errorf(codes.NotFound, "user %s not found", req.Id)
    }
    return u, nil
}
```

### Server streaming

The server sends many messages; the client reads until EOF. The RPC doesn't complete until the server closes the stream or an error occurs.

```go
func (s *server) StreamLogs(req *pb.LogRequest, stream pb.LogService_StreamLogsServer) error {
    for event := range s.events {
        if err := stream.Send(event); err != nil {
            return err   // client disconnected
        }
    }
    return nil  // stream closed cleanly
}
```

### Client streaming

The client sends many messages; the server reads until EOF, then returns a single response.

```go
func (s *server) UploadChunks(stream pb.FileService_UploadChunksServer) error {
    var total int
    for {
        chunk, err := stream.Recv()
        if err == io.EOF {
            return stream.SendAndClose(&pb.UploadSummary{BytesReceived: int64(total)})
        }
        if err != nil {
            return err
        }
        total += len(chunk.Data)
    }
}
```

### Bidirectional streaming

Both sides send independently; each side closes when done. The two streams are decoupled — the server can send before it finishes receiving.

```go
func (s *server) Chat(stream pb.ChatService_ChatServer) error {
    for {
        msg, err := stream.Recv()
        if err == io.EOF {
            return nil
        }
        if err != nil {
            return err
        }
        if err := stream.Send(&pb.Message{Text: "echo: " + msg.Text}); err != nil {
            return err
        }
    }
}
```

---

## gRPC status codes vs HTTP status codes

The most dangerous mistake returning engineers make: assuming gRPC status codes map cleanly to HTTP. **They do not map 1:1 and the mapping direction matters.**

| gRPC Status Code | HTTP Equivalent | Notes on the trap |
|------------------|-----------------|-------------------|
| `OK` (0) | 200 | Direct |
| `CANCELLED` (1) | 499 (nginx) | HTTP has no standard 499; gateway proxies vary |
| `UNKNOWN` (2) | 500 | Catch-all; don't use if a better code exists |
| `INVALID_ARGUMENT` (3) | 400 | Client sent bad data; do NOT use for missing auth |
| `DEADLINE_EXCEEDED` (4) | 504 | Deadline set by *caller* expired; 408 is wrong here |
| `NOT_FOUND` (5) | 404 | Direct |
| `ALREADY_EXISTS` (6) | 409 | Closer to 409 than 422 |
| `PERMISSION_DENIED` (7) | 403 | Authenticated but not authorised |
| `UNAUTHENTICATED` (16) | 401 | Missing or invalid credentials — NOT 403 |
| `RESOURCE_EXHAUSTED` (8) | 429 | Rate limit or quota; add `Retry-After` in metadata |
| `INTERNAL` (13) | 500 | Server-side bug; always log the cause |

**The UNAUTHENTICATED vs PERMISSION_DENIED distinction** is the one most developers get backwards. UNAUTHENTICATED means "I don't know who you are." PERMISSION_DENIED means "I know who you are, but you can't do this." This maps to 401 vs 403 in HTTP — the same distinction HTTP gets wrong in practice.

Return status codes from handlers using the `status` package:

```go
import "google.golang.org/grpc/status"
import "google.golang.org/grpc/codes"

return nil, status.Errorf(codes.NotFound, "order %s not found", req.OrderId)

// with structured details:
st, _ := status.New(codes.InvalidArgument, "validation failed").
    WithDetails(&errdetails.BadRequest{...})
return nil, st.Err()
```

---

## Interceptors

### UnaryServerInterceptor type

```go
type UnaryServerInterceptor func(
    ctx     context.Context,
    req     any,
    info    *grpc.UnaryServerInfo,   // .FullMethod = "/pkg.Service/Method"
    handler grpc.UnaryHandler,
) (any, error)
```

### Authentication interceptor example

```go
func AuthInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "missing metadata")
    }
    tokens := md.Get("authorization")
    if len(tokens) == 0 || !isValid(tokens[0]) {
        return nil, status.Error(codes.Unauthenticated, "invalid token")
    }
    return handler(ctx, req)
}
```

### Chaining interceptors

```go
grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        RecoveryInterceptor,   // outermost — catches panics from all others
        LoggingInterceptor,
        AuthInterceptor,
        MetricsInterceptor,    // innermost before handler
    ),
)
```

Execution order: RecoveryInterceptor → LoggingInterceptor → AuthInterceptor → MetricsInterceptor → handler → MetricsInterceptor → AuthInterceptor → LoggingInterceptor → RecoveryInterceptor.

`ChainUnaryInterceptor` is the preferred API (added in gRPC-Go v1.25). The older pattern of nesting multiple `grpc.UnaryInterceptor` options is deprecated.

There are parallel types for client-side and for streaming:
- `grpc.UnaryClientInterceptor` — for the gRPC *client*
- `grpc.StreamServerInterceptor` — for streaming RPCs on the server

### Passing values through interceptors with context

Use typed context keys, never string keys:

```go
type ctxKey string
const userIDKey ctxKey = "userID"

// in interceptor:
ctx = context.WithValue(ctx, userIDKey, extractedUserID)

// in handler:
uid := ctx.Value(userIDKey).(string)
```

---

## gRPC reflection for debugging

Register reflection in your server so `grpcurl` can inspect and call it without a `.proto` file:

```go
import "google.golang.org/grpc/reflection"

s := grpc.NewServer()
pb.RegisterPaymentServiceServer(s, &server{})
reflection.Register(s)   // adds the reflection service
```

Then from any terminal:

```bash
# list services
grpcurl -plaintext localhost:50051 list

# describe a service
grpcurl -plaintext localhost:50051 describe payments.v1.PaymentService

# call a unary RPC
grpcurl -plaintext -d '{"id":"pay_123"}' localhost:50051 payments.v1.PaymentService/GetPayment
```

Disable reflection in production or gate it behind a build tag — it exposes your full API schema.

---

## Returning engineer: what changed since 1.16–1.18

- **`grpc.UnaryInterceptor` (single) vs `grpc.ChainUnaryInterceptor` (multiple).** In the 1.16 era, chaining multiple interceptors required third-party libraries (`go-grpc-middleware`). `grpc.ChainUnaryInterceptor` is now in the standard gRPC-Go library. Use it.
- **`UnimplementedXxxServer` embedding is now required by default.** Generated server interfaces include an `UnimplementedXxxServer` struct. Embed it in your server struct to ensure forward-compatible behaviour when new RPCs are added. `protoc-gen-go-grpc` enforces this with `require_unimplemented_servers=true` (the default).
- **`grpc.WithInsecure()` is deprecated.** Replace with `grpc.WithTransportCredentials(insecure.NewCredentials())`. The old form still compiles but emits a deprecation warning.
- **gRPC module path changed.** It is `google.golang.org/grpc` (was the same since early days, but version drift is significant — v1.50+ has meaningful API changes over v1.20).
- **`buf` generates separate `_grpc.pb.go` files.** The old `protoc-gen-go` bundled gRPC code in the same file. With modern tooling, `*.pb.go` has messages and `*_grpc.pb.go` has service interfaces — don't be confused by the split.

---

## Key concepts to memorize

- HTTP/2 multiplexing eliminates head-of-line blocking at the connection layer
- Four patterns: unary, server-stream, client-stream, bidi — unary is the default choice
- `UNAUTHENTICATED` (16) = 401 (don't know who you are); `PERMISSION_DENIED` (7) = 403 (know you, no access)
- `DEADLINE_EXCEEDED` (4) = deadline the *caller* set expired, maps to 504 not 408
- `UnaryServerInterceptor` signature: `(ctx, req, info, handler) → (resp, err)`
- `grpc.ChainUnaryInterceptor` — first argument is outermost in the call stack
- Register `reflection.Register(s)` for `grpcurl` debugging; disable in production

---

## Common mistakes

**1. Returning `INTERNAL` for all errors**

*Why it matters:* `INTERNAL` tells the client "something went wrong on the server — retry might not help." If the error is `NOT_FOUND` or `INVALID_ARGUMENT`, returning `INTERNAL` prevents clients from handling the error correctly and makes dashboards meaningless.

*How to avoid:* Map every error path explicitly. Create a helper that wraps repository errors into appropriate gRPC codes. Reserve `INTERNAL` for genuine unexpected failures.

**2. Calling `grpc.UnaryInterceptor` multiple times**

*Why it matters:* Only the last `grpc.UnaryInterceptor` option takes effect. Silently dropping interceptors causes auth or logging to disappear.

*How to avoid:* Always use `grpc.ChainUnaryInterceptor(a, b, c)` as a single server option. Never stack multiple `grpc.UnaryInterceptor` calls.

**3. Not recovering from panics in interceptors**

*Why it matters:* A panic in a handler crashes the goroutine but in gRPC-Go (before v1.57) it could take down the entire server process depending on recover settings. Even with recovery, an unhandled panic returns `UNKNOWN` to the client, which is unhelpful.

*How to avoid:* Register a recovery interceptor as the outermost layer that catches panics, logs the stack trace, and returns `INTERNAL`. The `go-grpc-middleware/recovery` package provides this.

**4. Leaking context values with string keys**

*Why it matters:* Using `ctx.WithValue(ctx, "user_id", uid)` collides with any other package that uses the same string key. This causes silent overwrites or security bugs where interceptors read the wrong value.

*How to avoid:* Always define a private unexported type for context keys: `type ctxKey string`. Two packages with `type ctxKey string` have different types even though the underlying type is the same.

**5. Forgetting that interceptors do not fire for streaming RPCs**

*Why it matters:* `ChainUnaryInterceptor` only applies to unary RPCs. A logging interceptor registered as unary will silently skip all streaming RPC calls.

*How to avoid:* For streaming RPCs, also register `grpc.ChainStreamInterceptor` with `StreamServerInterceptor` implementations.

---

## Check your understanding

1. You register three unary interceptors: Recovery, Logging, Auth — in that order via `ChainUnaryInterceptor`. The Auth interceptor returns `UNAUTHENTICATED`. Write out which interceptors execute and in what order before the response reaches the client.

2. A client sends a request that arrives after the client's deadline. The server handler is mid-execution when the deadline fires. Which gRPC status code does the client receive, and which status code should the server use if it detects the cancellation and returns early?

3. Your team is debating whether to add `reflection.Register(s)` to the production binary for on-call debugging convenience. List two security risks this introduces and one mitigation short of disabling it entirely.
