# Day 38 — Solution: Event Bus Implementation Analysis

## Architecture Overview

The EventBus implementation uses **two categories of subscribers**:

1. **Type-specific:** `map[EventType][]chan Event` — subscribers register for specific event types
2. **All-events:** `[]chan Event` — subscribers receive all event types (for SSE, monitoring, etc.)

When an event is published, it's sent to:
- All channels in `subs[eventType]` (type-specific subscribers)
- All channels in `allSub` (all-events subscribers)

---

## Key Implementation Details

### Data Structure

```go
type EventBus struct {
    mu     sync.RWMutex                    // Protects both maps
    subs   map[EventType][]chan Event      // Type-specific subscribers
    allSub []chan Event                    // All-events subscribers
}
```

**Memory layout:**

- `mu`: 40 bytes (RWMutex)
- `subs`: One slice per event type; typically 6 types × 32 bytes per slice = ~200 bytes overhead
- `allSub`: One slice; 32 bytes overhead

**Per subscriber:** 40 bytes (channel header) + buffer memory

---

### Subscribe (Type-Specific)

```go
func (b *EventBus) Subscribe(et EventType) (<-chan Event, func()) {
    ch := make(chan Event, subBufSize)  // Buffered channel, subBufSize = 32
    b.mu.Lock()
    b.subs[et] = append(b.subs[et], ch)  // Add to type-specific list
    b.mu.Unlock()
    
    return ch, func() {  // Return unsubscribe closure
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

**Complexity:**
- Subscribe: O(1) — append to slice
- Unsubscribe: O(n_subs_for_type) — linear scan to find and remove

**Pattern:** Return an unsubscribe function (closure) that the caller can defer. This ensures cleanup even if the subscriber panics.

---

### SubscribeAll (All-Events)

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

Same pattern as Subscribe, but appends to `allSub` instead.

---

### Publish (Non-Blocking)

```go
func (b *EventBus) Publish(e Event) {
    b.mu.RLock()
    // Copy subscriber lists to avoid lock contention
    typed := make([]chan Event, len(b.subs[e.Type]))
    copy(typed, b.subs[e.Type])
    all := make([]chan Event, len(b.allSub))
    copy(all, b.allSub)
    b.mu.RUnlock()  // Release lock immediately
    
    // Send to type-specific + all-events subscribers
    for _, ch := range append(typed, all...) {
        select {
        case ch <- e:
            // Sent successfully
        default:
            // Buffer full; drop and log
            slog.Warn("event bus: buffer full, dropping event", "type", e.Type)
        }
    }
}
```

**Key insight:** Copy subscriber lists under a **read lock**, then release before sending. Why?

1. **Avoid contention:** Multiple Publish() calls can run concurrently on different event types
2. **Prevent deadlock:** If we held the write lock during send, and a Publish() tried to acquire the lock again, we'd deadlock
3. **Fast read lock:** Copying is fast; we don't hold the lock long

**Non-blocking send:**

```go
select {
case ch <- e:        // Send succeeds if buffer has space
default:             // Otherwise, execute default immediately
    slog.Warn(...)   // Drop + log
}
```

This never blocks the publisher. If a subscriber is slow (not reading from its channel), its buffer fills, and new events for that subscriber are dropped.

---

## Example Flow

### Timeline: Publishing API_PUBLISHED

```
T=0: bus.Publish(EventAPIPublished, ...)
  │
  ├─ Acquire RLock
  ├─ Copy subs[EventAPIPublished] → typed = [ch1, ch2]
  ├─ Copy allSub → all = [ch3, ch4]
  ├─ Release RLock
  │
  ├─ For each channel in [ch1, ch2, ch3, ch4]:
  │    ├─ ch1: send event → OK (buffer has space)
  │    ├─ ch2: send event → OK
  │    ├─ ch3: send event → OK
  │    └─ ch4: send event → OK (or drop if full)
  │
  └─ Return

T=1: GW subscriber (subscribed to EventAPIPublished)
  │   reads from ch1 → gets event
  │   processes it
  
T=2: SSE subscriber (subscribed to all)
     reads from ch3 → gets event
     sends to client
```

---

## What Happens When Buffers Fill?

### Scenario: Slow Subscriber

```go
// Subscriber goroutine
go func() {
    for e := range eventCh {
        time.Sleep(1 * time.Second)  // Slow!
        process(e)
    }
}()

// Publisher
for i := 0; i < 50; i++ {
    bus.Publish(Event{...})  // Publishes 50 events in ~1ms
}
```

**Timeline:**

```
T=0: Publish 50 events rapidly
  - First 32 go into buffer
  - Events 33-50: select's default triggers → "buffer full" warning
  - Publisher finishes, returns immediately

T=1000ms: Subscriber finishes processing event 1, reads event 2 from buffer

T=2000ms: Subscriber finishes event 2, reads event 3

...

T=32000ms: Subscriber finishes event 32, buffer is now empty
          (events 33-50 were never received)

Result: Subscriber missed 18 events!
```

**Recovery:** The GW (slow subscriber) should detect the problem:

```go
// In GW code
type MetricsCollector struct {
    lastEventSeq int
    currentSeq   int
}

for e := range eventStream {
    if e.Sequence != lastEventSeq+1 {
        // Gap detected! We missed events
        log.Warn("Events dropped, re-syncing from /admin/sync")
        resync()
    }
    lastEventSeq = e.Sequence
    apply(e)
}
```

---

## Performance Characteristics

### Latency (per event)

```
Publish latency breakdown:
- Acquire RLock: <1 µs
- Copy typed list: O(n_typed_subs) × 1 µs ≈ 1-10 µs
- Copy all list: O(n_all_subs) × 1 µs ≈ 1-10 µs
- Release RLock: <1 µs
- Send to each channel: O(n_total_subs) × 1 µs ≈ 1-100 µs

Total: ~10-200 µs per publish (with 100 subscribers)
```

### Throughput

```
With N subscribers, each processing events at rate R events/sec:

If Publish time is P µs and we have 1000 events/sec:

1000 publishes × 200 µs = 200 ms per second overhead
= 20% CPU for event bus alone (on one core)

Scale: 100,000 events/sec = bottleneck at 100-1000 subscribers
```

**Optimization:** For very high throughput, use a separate goroutine for publishing:

```go
eventQueue := make(chan Event, 1000)
go func() {
    for e := range eventQueue {
        bus.Publish(e)  // Batched
    }
}()

// Publisher sends to queue instead of directly
eventQueue <- event
```

---

## Memory Characteristics

### Per Event

```
Event struct:
- Type: 16 bytes (string)
- Timestamp: 24 bytes (time.Time)
- Payload: 24 bytes ([]byte header)
- Payload data: variable (usually 50-500 bytes)

Typical: 150-600 bytes per event
```

### Per Subscriber

```
Channel overhead: 40 bytes
Buffer (32 events × 200 bytes avg): 6.4 KB

Total per subscriber: ~6.5 KB
```

### With 100 Subscribers

```
EventBus overhead: ~1 KB
Subscriber buffers: 100 × 6.5 KB = 650 KB

Total: ~650 KB for a moderately loaded system
```

---

## Testing Strategies

### Test 1: Type-Specific Subscribers

```go
func TestTypeSpecificSubscriber(t *testing.T) {
    bus := NewEventBus()
    
    ch, unsub := bus.Subscribe(EventAPIPublished)
    defer unsub()
    
    bus.Publish(NewEvent(EventAPIPublished, map[string]any{"id": "1"}))
    bus.Publish(NewEvent(EventSubCreated, map[string]any{"id": "2"}))
    
    e1 := <-ch
    if e1.Type != EventAPIPublished {
        t.Fatalf("expected API_PUBLISHED, got %v", e1.Type)
    }
    
    // SubCreated should NOT be in this channel
    select {
    case <-ch:
        t.Fatal("type-specific subscriber received wrong event type")
    case <-time.After(100 * time.Millisecond):
        // Correct: channel is empty (timeout)
    }
}
```

### Test 2: All-Events Subscriber

```go
func TestAllEventsSubscriber(t *testing.T) {
    bus := NewEventBus()
    
    ch, unsub := bus.SubscribeAll()
    defer unsub()
    
    bus.Publish(NewEvent(EventAPIPublished, map[string]any{"id": "1"}))
    bus.Publish(NewEvent(EventSubCreated, map[string]any{"id": "2"}))
    
    e1 := <-ch
    e2 := <-ch
    
    if e1.Type != EventAPIPublished || e2.Type != EventSubCreated {
        t.Fatalf("all-events subscriber missed events")
    }
}
```

### Test 3: Buffer Full (Non-Blocking)

```go
func TestNonBlockingPublish(t *testing.T) {
    bus := NewEventBus()
    
    ch, unsub := bus.SubscribeAll()
    defer unsub()
    
    // Fill buffer
    for i := 0; i < subBufSize; i++ {
        bus.Publish(NewEvent(EventAPIPublished, map[string]any{"id": fmt.Sprintf("%d", i)}))
    }
    
    // This should NOT block; Publish must return immediately
    start := time.Now()
    bus.Publish(NewEvent(EventAPIPublished, map[string]any{"id": "overflow"}))
    elapsed := time.Since(start)
    
    if elapsed > 10 * time.Millisecond {
        t.Fatalf("Publish blocked for %v", elapsed)
    }
}
```

---

## Production Recommendations

1. **Monitor drop rate:** Log and alert on "buffer full" warnings
2. **Set appropriate buffer size:** 32 is good for most use cases; adjust based on load testing
3. **Use separate goroutine for publishing:** If publishing events from within HTTP handlers blocks, move to background
4. **Implement sequence IDs:** Include sequence numbers in events so consumers can detect dropped events
5. **Auto-reconnect in consumers:** If a consumer (GW) misses events, it should re-sync from `/admin/sync`

---

## Next Steps

Tomorrow (Day 39), you'll integrate this EventBus into the Control Plane server and expose it via HTTP/SSE. The GW will call `/admin/sync` to bootstrap, then stream events from `/events` to stay synchronized.

**Advanced exercise:** Implement `PublishAsync()` that sends events in a goroutine, then benchmark it against blocking Publish.
