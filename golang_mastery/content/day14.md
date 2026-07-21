# Day 14 — gRPC Streaming

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Choose the correct streaming pattern for a given use case using the decision tree
- Implement stream lifecycle management including clean shutdown from both sides
- Detect client disconnect inside a streaming handler using `ctx.Done()`
- Explain backpressure in gRPC streams and why `Send` can block
- Identify the goroutine leak pattern in streaming handlers and prevent it

---

## Core mental model

**Streaming is just an RPC that doesn't return until the stream closes — context cancellation is how both sides agree to stop.**

A gRPC server streaming handler is a function that returns `error`. It stays alive as long as it keeps calling `stream.Send()`. When it returns `nil`, the stream closes cleanly (EOF to the client). When it returns an error, the stream closes with that status code.

The client can cancel at any time by cancelling its context. That cancellation propagates into the server as `ctx.Done()` being closed and subsequent `stream.Send()` calls returning an error. Neither side can force the other to keep going — the contract is cooperative, mediated by the context.

```
Client                          Server
  |                               |
  |-- StreamLogs(req) ----------->|  handler starts
  |<-- Log{...} ------------------|  stream.Send()
  |<-- Log{...} ------------------|  stream.Send()
  |                               |
  | (client cancels context)      |
  |-- RST_STREAM ---------------->|  ctx.Done() fires
  |                               |  stream.Send() returns error
  |                               |  handler returns error
  |<-- status: CANCELLED ---------|
```

---

## When to use each streaming pattern

### Decision tree

```
Is the total response data known upfront and small enough to fit in a single message?
├── Yes → UNARY  (default choice)
└── No →
    Does the server need to send data back before the client finishes sending?
    ├── No, client sends everything first → CLIENT STREAMING
    │     (file upload, bulk insert, sensor batch)
    └── Yes →
        Does the client send a single request to kick things off?
        ├── Yes → SERVER STREAMING
        │     (live feed subscription, report generation, large result paginator)
        └── No, both sides send independently → BIDIRECTIONAL STREAMING
              (chat, collaborative editing, duplex sensor + commands)
```

### Real use-case mapping

| Use case | Pattern | Reason |
|----------|---------|--------|
| Get a single user by ID | Unary | Small, discrete query |
| Process a payment | Unary | Single request-response with strong ordering |
| Subscribe to live price ticks | Server streaming | Server pushes events as they occur |
| Stream a large CSV export | Server streaming | Response too large for single message |
| Upload a multi-part file | Client streaming | Client sends chunks; server returns summary |
| Batch-insert 10k records | Client streaming | Amortises per-RPC overhead |
| Bidirectional chat | Bidi streaming | Both sides send independently |
| Remote shell (stdin/stdout) | Bidi streaming | Interactive, decoupled streams |

**Default to unary** unless your data is inherently a stream. The operational complexity of streaming (goroutine management, backpressure, disconnect detection) is real. Pagination with unary RPCs is often simpler and more debuggable than server streaming.

---

## Stream lifecycle

### Server streaming: complete lifecycle

```go
func (s *server) StreamEvents(req *pb.EventRequest, stream pb.EventService_StreamEventsServer) error {
    // 1. Validate request
    if req.TopicId == "" {
        return status.Error(codes.InvalidArgument, "topic_id required")
    }

    // 2. Set up resources
    sub, err := s.pubsub.Subscribe(req.TopicId)
    if err != nil {
        return status.Errorf(codes.Internal, "subscribe failed: %v", err)
    }
    defer sub.Close()  // ALWAYS clean up on return

    // 3. Stream loop
    for {
        select {
        case <-stream.Context().Done():
            // client cancelled or deadline exceeded
            return stream.Context().Err()

        case event, ok := <-sub.Events():
            if !ok {
                return nil  // subscription closed — clean EOF to client
            }
            if err := stream.Send(event); err != nil {
                // Send failed — client gone
                return err
            }
        }
    }
}
```

Key points:
- `stream.Context()` is the request context — it is cancelled when the client disconnects or the deadline fires.
- `defer sub.Close()` ensures cleanup regardless of which exit path fires.
- Returning `nil` sends a clean EOF. Returning a non-nil error sends the corresponding gRPC status.

### Client streaming: complete lifecycle

```go
func (s *server) UploadFile(stream pb.FileService_UploadFileServer) error {
    var buf []byte
    for {
        chunk, err := stream.Recv()
        if err == io.EOF {
            // client finished sending — send the single response
            return stream.SendAndClose(&pb.UploadResult{
                Size: int64(len(buf)),
            })
        }
        if err != nil {
            return status.Errorf(codes.Internal, "recv error: %v", err)
        }
        buf = append(buf, chunk.Data...)
    }
}
```

The `io.EOF` sentinel means "client closed the send side cleanly." Any other error is a transport or cancellation problem.

### Bidirectional streaming: decoupled send/receive

```go
func (s *server) Negotiate(stream pb.NegotiateService_NegotiateServer) error {
    // Use a goroutine for receiving because Recv blocks
    errCh := make(chan error, 1)
    go func() {
        for {
            msg, err := stream.Recv()
            if err != nil {
                errCh <- err
                return
            }
            s.process(msg)
        }
    }()

    // Send loop in the main goroutine
    ticker := time.NewTicker(time.Second)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            if err := stream.Send(s.heartbeat()); err != nil {
                return err
            }
        case err := <-errCh:
            if err == io.EOF {
                return nil  // client closed send side cleanly
            }
            return err
        case <-stream.Context().Done():
            return stream.Context().Err()
        }
    }
}
```

---

## Detecting client disconnect

Inside a streaming handler, the client can disconnect at any time. There are two signals:

**Signal 1: `stream.Context().Done()` is closed**

Use this in a `select` loop to detect cancellation *between* sends:

```go
select {
case <-stream.Context().Done():
    return stream.Context().Err()
case event := <-eventCh:
    stream.Send(event)
}
```

**Signal 2: `stream.Send()` returns a non-nil error**

When the client disconnects, the next `Send` call returns an error (typically the `context.Canceled` wrapped in a gRPC status). This is the synchronous signal — you don't need a separate goroutine to check for it.

**Which to use?**

Use `stream.Context().Done()` in a select when you have other work to interleave (e.g., reading from a channel). Use the error return from `Send` or `Recv` when you have a simple sequential loop.

---

## Backpressure

gRPC streams are not fire-and-forget. The send path applies backpressure:

- `stream.Send()` blocks when the receiver's flow-control window is full.
- HTTP/2 has per-stream flow-control windows (default 65535 bytes). When the client isn't reading fast enough, the window fills and `Send` blocks on the server.

What this means in practice:
- A slow consumer can cause the server's `Send` to block indefinitely.
- Always run your stream send loop with a context-aware select so you can detect deadline exceeded while blocked.
- Do not call `stream.Send()` from multiple goroutines on the same stream — it is not safe for concurrent use.

```go
// CORRECT — send in one goroutine, respect context
for {
    select {
    case <-stream.Context().Done():
        return stream.Context().Err()
    case item := <-workCh:
        if err := stream.Send(item); err != nil {
            return err  // client went away or backpressure caused timeout
        }
    }
}
```

---

## Goroutine leak risk in streaming handlers

This is the most common production bug with gRPC streaming.

### The leak pattern

```go
// BROKEN — goroutine leak
func (s *server) StreamEvents(req *pb.Req, stream pb.Svc_StreamEventsServer) error {
    go func() {
        for event := range s.globalEventCh {   // reads from a shared channel
            stream.Send(event)                  // what happens when client disconnects?
        }
    }()
    // handler returns immediately — goroutine keeps running forever
    return nil
}
```

The handler returns `nil` (closing the stream), but the goroutine launched inside continues trying to `Send` on a closed stream. The goroutine blocks on the channel read and never exits.

### The fix

1. Never return from a streaming handler while a goroutine it owns is still running.
2. Pass the stream context to all goroutines so they can exit when the client disconnects.
3. Use `errgroup.WithContext` for multi-goroutine stream handlers.

```go
// CORRECT
func (s *server) StreamEvents(req *pb.Req, stream pb.Svc_StreamEventsServer) error {
    ctx := stream.Context()
    g, ctx := errgroup.WithContext(ctx)

    eventCh := make(chan *pb.Event, 64)

    // producer goroutine
    g.Go(func() error {
        defer close(eventCh)
        return s.produce(ctx, req.TopicId, eventCh)  // exits when ctx is cancelled
    })

    // consumer (send) — runs in calling goroutine
    g.Go(func() error {
        for event := range eventCh {
            if err := stream.Send(event); err != nil {
                return err
            }
        }
        return nil
    })

    return g.Wait()  // handler blocks until both goroutines exit
}
```

---

## Returning engineer: what changed since 1.16–1.18

- **`errgroup` is now the idiomatic concurrency harness.** In the 1.16 era, multi-goroutine streaming handlers were often written with raw channels and WaitGroups. `golang.org/x/sync/errgroup` with `errgroup.WithContext` is the modern idiom — it cancels the context when any goroutine returns an error, which is exactly the semantics streaming handlers need.
- **Flow control and buffer sizes are configurable.** `grpc.WithInitialWindowSize` and `grpc.WithInitialConnWindowSize` let you tune the HTTP/2 flow-control window. In high-throughput streaming, the default 64KB window is a common bottleneck. This was not prominently documented pre-1.20.
- **gRPC-Go added `grpc.MaxCallRecvMsgSize` / `grpc.MaxCallSendMsgSize` with better defaults.** The default max message size is 4MB receive. If you're streaming large payloads per message (not per stream), you may hit this. Prefer smaller messages and more of them for streaming.
- **Context propagation and `grpc.SetHeader` / `grpc.SendHeader`** are stable but the timing rules are stricter in newer versions — metadata headers must be sent before the first message. If you send headers after `Send()`, you'll see a logged warning.

---

## Key concepts to memorize

- Returning `nil` from a stream handler = clean EOF; returning error = gRPC status to client
- `io.EOF` from `stream.Recv()` = client closed send side cleanly (not an error condition)
- `stream.Context().Done()` = client cancelled or deadline exceeded
- `stream.Send()` is not goroutine-safe — only one goroutine sends at a time
- `stream.Send()` blocks when the HTTP/2 flow-control window is full (backpressure)
- Always `defer cleanup()` inside streaming handlers — there are multiple exit paths
- Never launch a goroutine in a handler that can outlive the handler's return

---

## Common mistakes

**1. Treating `io.EOF` from `Recv()` as an error**

*Why it matters:* `io.EOF` from `stream.Recv()` is the normal signal that the client finished sending. If you return it as an error, you send an `UNKNOWN` or `INTERNAL` status to the client instead of the expected response.

*How to avoid:* Always check `err == io.EOF` explicitly and handle it as the success branch in client-streaming and bidi handlers.

**2. Not closing resources on all exit paths**

*Why it matters:* A streaming handler can exit via: normal EOF, client cancel, deadline, Send error, or a bug panic. If you close a subscription or file handle only in the "happy path", resource leaks accumulate.

*How to avoid:* Use `defer` for all cleanup. The `defer` runs on every exit path including panics.

**3. Sending on a closed stream after returning**

*Why it matters:* After a streaming handler returns, the stream is closed. Any goroutine still holding a reference to `stream` and calling `Send` will get an error, but the goroutine itself keeps running — consuming memory and goroutine stack until the process restarts.

*How to avoid:* The handler must not return until all goroutines it spawned have exited. Use `errgroup.Wait()` as the last statement.

**4. Using a server-side timeout that doesn't cancel the stream context**

*Why it matters:* A `time.AfterFunc` or `time.Sleep` in a handler does not cancel the stream context. The client remains connected and the handler runs past the intended timeout.

*How to avoid:* Use `context.WithTimeout(stream.Context(), duration)` to derive a child context with a deadline. Pass this child context to all downstream operations.

**5. Choosing bidi streaming when server streaming suffices**

*Why it matters:* Bidi streaming requires coordinating two concurrent goroutines on each side, careful EOF handling for each direction, and more complex error propagation. It is significantly harder to test and debug.

*How to avoid:* Use the decision tree. If the client sends exactly one request to start the stream, use server streaming. Reserve bidi for genuinely interactive, decoupled message flows.

---

## Check your understanding

1. A server streaming handler reads from a database cursor and calls `stream.Send()` in a loop. The client cancels after receiving 50 of a possible 1000 rows. Describe the exact sequence of events: what signal does the server see first, what does the next `stream.Send()` return, and what status code does the client receive?

2. You have a bidi streaming handler that launches a goroutine to read from `stream.Recv()` and uses the main goroutine to send periodic heartbeats. The client sends EOF (closes its send side) while the server's heartbeat goroutine is mid-sleep. Write the select statement in the send loop that handles this cleanly without leaking the receive goroutine.

3. Your server streaming handler processes events and must stop sending if no event arrives within 5 seconds (producer timeout), but must also stop if the client disconnects. Write the select statement that implements both conditions without a goroutine leak.
