# Day 38 — Building the Event Bus with Go Channels

## Learning Objectives

After this day, you will:

1. Implement a non-blocking `EventBus` using Go channels
2. Understand the difference between type-specific and all-events subscribers
3. Design publish operations that **never block** (drop on full buffer)
4. Apply buffering strategies to prevent cascading failures

## Why Non-Blocking Publish Matters

### The Problem: Blocking Publish

Imagine a simple publish that blocks:

```go
func (b *EventBus) Publish(e Event) {
    for _, ch := range b.subs[e.Type] {
        ch <- e  // BLOCKS if subscriber is slow
    }
}
```

**Timeline:**

- T=0: CP handler calls `bus.Publish(EventSubCreated)`
- T=0.1: First subscriber (GW1) processes event instantly
- T=0.2: Second subscriber (GW2) is slow; blocked reading from its channel
- T=0.5: `ch <- e` on GW2's channel blocks; **the entire CP handler is stuck**
- T=1: HTTP client sees a timeout; request fails
- T=2: Requests pile up on the CP; cascading failure

**Result:** One slow GW crashes the entire CP.

### The Solution: Non-Blocking Publish

```go
func (b *EventBus) Publish(e Event) {
    for _, ch := range b.subs[e.Type] {
        select {
        case ch <- e:
            // Sent successfully
        default:
            // Buffer full; drop and warn
            slog.Warn("event bus: buffer full, dropping event", "type", e.Type)
        }
    }
}
```

**Same timeline:**

- T=0: CP handler calls `bus.Publish(EventSubCreated)`
- T=0.1: Send to GW1's channel; succeeds
- T=0.2: Send to GW2's channel; buffer is full → drop + warn
- T=0.3: Publish returns; HTTP handler continues
- T=1: HTTP response sent immediately

**Cost:** GW2 missed the event. But the CP is responsive, and GW2 can re-sync from `/admin/sync`.

This mirrors **WSO2's behavior with slow consumers** — events are dropped if the subscriber queue backs up.

---

## Part 1: The EventBus Design

### Data Structure

```go
type EventBus struct {
    mu     sync.RWMutex
    subs   map[EventType][]chan Event  // Type-specific subscribers
    allSub []chan Event                 // All-events subscribers (for SSE)
}
```

**Why two categories?**

- **Type-specific:** A GW subscribes only to `API_PUBLISHED` and `SUBSCRIPTION_CREATED`. It ignores `TOKEN_REVOCATION`. Saves CPU and channel buffer space.
- **All-events:** The SSE endpoint (streaming to browsers/GWs) receives **all** events in order. Used for monitoring dashboards and GW initial event streaming.

### Subscribe Operations

#### Type-Specific Subscription

```go
func (b *EventBus) Subscribe(et EventType) (<-chan Event, func()) {
    ch := make(chan Event, subBufSize)  // 32 events buffered
    b.mu.Lock()
    b.subs[et] = append(b.subs[et], ch)
    b.mu.Unlock()
    
    // Return read-only channel + unsubscribe func
    return ch, func() {
        b.mu.Lock()
        chs := b.subs[et]
        for i, c := range chs {
            if c == ch {
                b.subs[et] = append(chs[:i], chs[i+1:]...)
                break
            }
        }
        b.mu.Unlock()
    }
}
```

**Pattern:** `defer unsubscribe()` ensures cleanup even if the subscriber panics.

#### All-Events Subscription

```go
func (b *EventBus) SubscribeAll() (<-chan Event, func()) {
    ch := make(chan Event, subBufSize)
    b.mu.Lock()
    b.allSub = append(b.allSub, ch)
    b.mu.Unlock()
    
    return ch, func() {
        b.mu.Lock()
        for i, c := range b.allSub {
            if c == ch {
                b.allSub = append(b.allSub[:i], b.allSub[i+1:]...)
                break
            }
        }
        b.mu.Unlock()
    }
}
```

### Publish Operation (Non-Blocking)

```go
func (b *EventBus) Publish(e Event) {
    b.mu.RLock()
    // Copy subscriber lists to avoid lock contention
    typed := make([]chan Event, len(b.subs[e.Type]))
    copy(typed, b.subs[e.Type])
    all := make([]chan Event, len(b.allSub))
    copy(all, b.allSub)
    b.mu.RUnlock()
    
    // Send to type-specific subscribers
    for _, ch := range typed {
        select {
        case ch <- e:
        default:
            slog.Warn("event bus: buffer full, dropping event", "type", e.Type)
        }
    }
    
    // Send to all-events subscribers
    for _, ch := range all {
        select {
        case ch <- e:
        default:
            slog.Warn("event bus: buffer full (all-sub), dropping event")
        }
    }
}
```

**Key technique:** Copy subscriber lists **under the read lock**, then release the lock before sending. This prevents:

1. **Lock contention:** If Publish blocks on sending to one slow subscriber, we hold the lock. Other Subscribe/Unsubscribe calls are blocked.
2. **Deadlock:** If we tried to acquire the lock again during send, we'd deadlock.

---

## Part 2: Event Types and Payloads

```go
type EventType string

const (
    EventAPICreated    EventType = "API_CREATED"
    EventAPIPublished  EventType = "API_PUBLISHED"
    EventAPIDeprecated EventType = "API_DEPRECATED"
    EventAPIRetired    EventType = "API_RETIRED"
    EventSubCreated    EventType = "SUBSCRIPTION_CREATED"
    EventSubRemoved    EventType = "SUBSCRIPTION_REMOVED"
)

type Event struct {
    Type      EventType       `json:"type"`
    Timestamp time.Time       `json:"timestamp"`
    Payload   json.RawMessage `json:"payload"`
}

func NewEvent(et EventType, payload any) Event {
    raw, _ := json.Marshal(payload)
    return Event{Type: et, Timestamp: time.Now().UTC(), Payload: raw}
}
```

### Example Payloads

**API_PUBLISHED:**
```json
{
  "type": "API_PUBLISHED",
  "timestamp": "2026-09-16T14:30:45Z",
  "payload": {
    "id": "abc123",
    "name": "PetStore",
    "context": "/petstore/v1",
    "version": "1.0",
    "tiers": ["Gold", "Silver"]
  }
}
```

**SUBSCRIPTION_CREATED:**
```json
{
  "type": "SUBSCRIPTION_CREATED",
  "timestamp": "2026-09-16T14:30:46Z",
  "payload": {
    "apiId": "abc123",
    "appName": "PetApp",
    "tier": "Gold"
  }
}
```

---

## Part 3: Buffering Strategies

### Buffer Size Trade-Offs

```go
const subBufSize = 32  // How big?
```

| Size | Pros | Cons |
|------|------|------|
| **4** | Low memory, catches slow subscribers quickly | Events drop frequently; GWs re-sync often |
| **32** (default) | Balanced; absorbs traffic spikes | Higher memory |
| **256** | Very tolerant of slow subscribers | May hide problems; events stay buffered too long |

**Rule of thumb:**

- Small (<10): Strict; catches problems immediately
- Medium (32-64): Production default
- Large (128+): Lenient; useful for bursty workloads

### Memory Impact

With N subscribers:

```
Memory = N * subBufSize * sizeof(Event)
       = N * 32 * ~200 bytes
       = N * 6.4 KB
```

With 100 subscribers: 640 KB. Negligible.

---

## Part 4: Patterns and Anti-Patterns

### Pattern 1: Defer Unsubscribe for Cleanup

```go
events, unsubscribe := bus.Subscribe(EventAPIPublished)
defer unsubscribe()

for e := range events {
    handleEvent(e)
    // If panic occurs, defer ensures cleanup
}
```

### Pattern 2: Select for Graceful Shutdown

```go
events, unsubscribe := bus.SubscribeAll()
defer unsubscribe()

for {
    select {
    case e := <-events:
        handleEvent(e)
    case <-ctx.Done():
        // Context cancelled; exit gracefully
        return
    }
}
```

### Pattern 3: Non-Blocking Send with Logging

```go
select {
case ch <- event:
    // Success; event was buffered
default:
    slog.Warn("dropping event", "type", event.Type, "subscriber", i)
    // GW will re-sync from /admin/sync
}
```

### Anti-Pattern 1: Unbuffered Subscribe

```go
// WRONG
ch := make(chan Event)  // No buffer!
```

Unbuffered channels require both sender and receiver to be ready. Any publish blocks.

### Anti-Pattern 2: Publishing Inside a Mutex

```go
// WRONG
b.mu.Lock()
for _, ch := range b.subs[e.Type] {
    ch <- e  // BLOCKS; holds lock
}
b.mu.Unlock()
```

### Anti-Pattern 3: Closing Channels From Producer

```go
// WRONG
func (b *EventBus) Stop() {
    for _, chs := range b.subs {
        for _, ch := range chs {
            close(ch)  // What if someone sends?
        }
    }
}
```

**Why:** Multiple goroutines might be sending or receiving. Closing a channel with sends or receives causes a panic. Use context cancellation instead (see Pattern 2).

---

## Exercises

### Exercise 1: SubscribeAll Receives All Event Types

**Question:** Write a test that shows a `SubscribeAll` subscriber receives events for all types.

**Hint:** Subscribe to all events, publish two different event types, assert both arrive.

**Solution sketch:**

```go
bus := NewEventBus()
ch, unsub := bus.SubscribeAll()
defer unsub()

// Publish two different types
bus.Publish(NewEvent(EventAPIPublished, map[string]any{"id": "1"}))
bus.Publish(NewEvent(EventSubCreated, map[string]any{"apiId": "1"}))

// Receive both
time.Sleep(10 * time.Millisecond)  // Allow goroutines to process
e1 := <-ch
e2 := <-ch

assert.Equal(t, e1.Type, EventAPIPublished)
assert.Equal(t, e2.Type, EventSubCreated)
```

**Why it works:** `SubscribeAll()` returns a channel that receives **all** published events, regardless of type. Type-specific subscribers would miss `EventSubCreated` if they only subscribed to `EventAPIPublished`.

---

### Exercise 2: Buffer Full Means GW Has Stale Cache

**Question:** The buffer is full — `Publish` drops the event and logs a warning. In a production incident, what does "events dropped" in the log mean for the GW?

**Hint:** Think about what state the GW cache is in.

**Solution sketch:**

**The GW has a stale cache.** It missed a state change on the CP.

**Example scenario:**

1. API "PetStore" is published (event 1 sent to GW)
2. API status changes to DEPRECATED (event 2 sent — but buffer is full, dropped)
3. GW's cache: PetStore is PUBLISHED (missed the deprecation)
4. User requests: GW routes to PetStore (should return 410 GONE for deprecated APIs)
5. Result: 404 or invalid responses; traffic to retired APIs

**Recovery:** The GW should notice the dropped events (by monitoring the CP logs) and call `GET /admin/sync` to re-sync. Or set up an automatic re-sync timer (e.g., every 5 minutes).

**Production mitigation:**

```go
// In the GW event listener
select {
case e := <-events:
    cache.apply(e)
    consecutiveDrop = 0  // Reset counter
case <-time.After(5 * time.Minute):
    // Proactive re-sync every 5 minutes
    cache.resync()
}
```

---

### Exercise 3: PublishAsync Method (Extension)

**Question:** Add a `PublishAsync(Event)` method that sends the event in a goroutine instead of dropping. When would you use it?

**Hint:** Think about throughput vs. latency trade-offs.

**Solution sketch:**

```go
func (b *EventBus) PublishAsync(e Event) {
    go func() {
        b.Publish(e)
    }()
}

// OR: If subscriber buffer is full, wait asynchronously
func (b *EventBus) PublishAsync(e Event) {
    go func() {
        b.mu.RLock()
        all := make([]chan Event, len(b.allSub))
        copy(all, b.allSub)
        b.mu.RUnlock()
        
        for _, ch := range all {
            ch <- e  // BLOCKS if slow, but doesn't block caller
        }
    }()
}
```

**When to use:**

1. **Low throughput, high latency tolerance:** Event delivery is more important than response time. E.g., an admin endpoint that publishes a rare config update.

2. **Bursty workloads:** Event flood during startup. Async buffering spreads the load.

**Trade-offs:**

- **Pro:** No events are dropped
- **Con:** Goroutine leak risk if channel never drains
- **Con:** Unbounded memory if events queue up

**Example use case:**

```go
// Critical: Never drop this event
bus.PublishAsync(NewEvent(EventSecurityAlertTriggered, data))
```

**vs.**

```go
// Best effort: OK to drop if buffer full
bus.Publish(NewEvent(EventSubCreated, data))
```

---

## Deployment Considerations

### Monitoring the Event Bus

Log every drop:

```go
default:
    slog.Warn("event bus: buffer full, dropping event",
        "type", e.Type,
        "numSubscribers", len(subscribers),
        "bufferSize", subBufSize)
```

**Alerting:**

- If drops > 10 per minute: Scale down event throughput or increase buffer size
- If drops > 100 per minute: Critical; GWs are diverging from CP cache

### Load Testing

Simulate a slow subscriber:

```go
// Subscriber that deliberately processes slowly
go func() {
    for e := range events {
        time.Sleep(100 * time.Millisecond)  // Slow!
        handleEvent(e)
    }
}()
```

Measure: Do other subscribers see dropped events? (They should not; non-blocking means each buffer is independent.)

---

## Key Takeaways

1. **Non-blocking publish:** Use `select` with `default` to drop events, never block.

2. **Copy subscriber lists under lock:** Release the lock before sending to avoid contention and deadlock.

3. **Buffer size is tunable:** 32 is a good default; adjust based on traffic and tolerance for drops.

4. **Type-specific + all-events:** Subscribers opt in to types they care about; SSE needs all types.

5. **Explicit unsubscribe:** Always defer cleanup to prevent resource leaks.

6. **Monitoring:** Log every buffer-full event; alert on sustained high drop rates.

---

## Next Steps

Tomorrow (Day 39), you'll integrate the EventBus into the Control Plane and expose it over HTTP via Server-Sent Events (SSE). The GW will stream events from the CP in real-time, keeping its cache synchronized.

**Code exercise:** Implement `PublishAsync` and write a benchmark showing throughput vs. drop rate for different buffer sizes.
