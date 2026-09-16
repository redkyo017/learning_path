# Day 38 — Lab: The Event Bus with Go Channels

## Goal

Build and test the EventBus: a non-blocking, in-process event pub-sub system using Go channels. Observe:

- Type-specific subscribers receive only their event types
- All-events subscribers receive all events
- Non-blocking publish drops events if a buffer is full

## Prerequisites

- Go 1.18+ installed
- Day 38 content reading completed
- `go run`, `curl`, and basic shell commands available

## Running the Demo

Start the EventBus demo:

```bash
go run main.go
```

**Expected output:**

```
{...} INFO GW received API_PUBLISHED context=/petstore/v1 version=1.0
{...} INFO SSE stream type=API_PUBLISHED
{...} INFO SSE stream type=SUBSCRIPTION_CREATED
Event bus demo complete.
```

### What's Happening?

1. **Main goroutine:**
   - Creates the EventBus
   - Starts a type-specific subscriber (EventAPIPublished only)
   - Starts an all-events subscriber (all event types)

2. **Type-specific subscriber (GW simulation):**
   - Subscribes to `EventAPIPublished`
   - Receives and logs only API_PUBLISHED events
   - Ignores SUBSCRIPTION_CREATED (not subscribed)

3. **All-events subscriber (SSE simulation):**
   - Subscribes via `SubscribeAll()`
   - Receives and logs all event types

4. **Publishing:**
   - Publishes EventAPIPublished → both subscribers receive
   - Publishes EventSubCreated → only all-events subscriber receives

## Observations

### Observation 1: Type-Specific Filtering

The GW subscriber logs:

```
{...} INFO GW received API_PUBLISHED context=/petstore/v1 version=1.0
```

**Not:**

```
{...} INFO GW received SUBSCRIPTION_CREATED appId=abc123 appName=PetApp
```

**Why?** The GW only subscribed to `EventAPIPublished` via `bus.Subscribe(EventAPIPublished)`. The SUBSCRIPTION_CREATED event is not in its type-specific list.

### Observation 2: All-Events Receives Everything

The SSE subscriber logs both:

```
{...} INFO SSE stream type=API_PUBLISHED
{...} INFO SSE stream type=SUBSCRIPTION_CREATED
```

**Why?** The SSE subscriber used `SubscribeAll()`, which receives all event types from both the type-specific map and the all-events list.

### Observation 3: Buffering

The EventBus creates buffered channels (`make(chan Event, subBufSize)` with subBufSize=32). This means:

- Each subscriber can hold up to 32 events in its channel buffer
- If the buffer is full and a new event arrives, the publisher uses `select` with `default` to avoid blocking
- The event is dropped and logged as "buffer full"

**In this demo:** The buffers never fill because events are processed quickly. Run the demo multiple times to see consistent output.

---

## Performance Testing

### Test 1: Buffer Exhaustion

To see "buffer full" warnings, modify `main.go` to publish many events quickly:

```go
func main() {
    bus := NewEventBus()
    
    // Slow subscriber (deliberately slow)
    allCh, unsubAll := bus.SubscribeAll()
    defer unsubAll()
    
    go func() {
        for e := range allCh {
            time.Sleep(100 * time.Millisecond)  // Very slow!
            slog.Info("processed", "type", e.Type)
        }
    }()
    
    // Publish many events rapidly
    for i := 0; i < 50; i++ {
        bus.Publish(NewEvent(EventAPIPublished, map[string]any{
            "id": fmt.Sprintf("api%d", i),
        }))
    }
    
    time.Sleep(10 * time.Second)
}
```

**Expected output:**

```
{...} WARN event bus: buffer full, dropping event type=API_PUBLISHED
{...} WARN event bus: buffer full, dropping event type=API_PUBLISHED
...
```

**Why?** The subscriber processes 1 event per 100ms (10 per second). We publish 50 events in a few milliseconds. After 32 events fill the buffer, the rest are dropped.

---

## Design Patterns Demonstrated

### Pattern 1: Resource Cleanup with Defer

```go
events, unsubscribe := bus.Subscribe(EventAPIPublished)
defer unsubscribe()

// If this goroutine panics, defer ensures cleanup
for e := range events {
    handleEvent(e)
}
```

### Pattern 2: Non-Blocking Send

```go
select {
case ch <- event:
    // Sent
default:
    // Buffer full; drop and log
    slog.Warn("dropped")
}
```

### Pattern 3: RWMutex for Lock Reduction

```go
b.mu.RLock()  // Multiple readers allowed simultaneously
typed := make([]chan Event, len(b.subs[e.Type]))
copy(typed, b.subs[e.Type])
all := make([]chan Event, len(b.allSub))
copy(all, b.allSub)
b.mu.RUnlock()

// Now send without holding the lock
for _, ch := range append(typed, all...) {
    select {
    case ch <- e:
    default:
        // No contention; other publishes can proceed
    }
}
```

---

## Verification Checklist

- [ ] `go run main.go` completes without errors
- [ ] GW subscriber logs only API_PUBLISHED events
- [ ] SSE subscriber logs both event types
- [ ] No "buffer full" warnings in normal execution
- [ ] Cleanup via defer works (no goroutine leaks)
- [ ] Event timestamps are present in output
- [ ] Event payloads are correctly formatted JSON

---

## Key Takeaways

1. **Non-blocking publish:** The EventBus never blocks the publisher, ensuring the Control Plane remains responsive.

2. **Type-specific subscribers:** Clients can opt into only the events they care about (less memory, less CPU).

3. **All-events subscribers:** The SSE endpoint uses `SubscribeAll()` to stream all events to monitoring dashboards and GW instances.

4. **Buffering strategy:** 32-event buffer is a sweet spot; it absorbs traffic spikes while quickly detecting slow subscribers.

5. **Lock reduction:** Copy subscriber lists under a read lock, then release before sending. Prevents contention and deadlock.

---

## Next Steps

Move to the SOLUTION.md to see implementation details and performance analysis.

Then (Day 39), you'll integrate this EventBus into the Control Plane server and expose it via SSE.
