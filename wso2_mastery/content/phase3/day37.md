# Day 37 — Source Reading: The Event Hub

## Learning Objectives

After this day, you will:

1. Understand how WSO2's event hub keeps the Gateway in sync with the Control Plane
2. Identify the 4 JMS topics and their payloads in WSO2 architecture
3. Recognize why event ordering and durability matter in a distributed system
4. Trace the startup sequence: `getSyncData()` → subscribe to events

## Why This Matters

The event hub is the **nervous system** of the WSO2 API platform.

**Scenario:** An API is published on the Control Plane. The Gateway must know about it immediately so new requests route correctly. Without the event hub:

- The GW would poll the CP every N seconds (high latency, high load)
- Or the GW would serve stale data (routing errors, 503s)

**With the event hub:** The CP publishes an event; every GW subscribes and receives it in milliseconds.

**Production failure modes specific to event hubs:**

1. **JMS broker outage:** All event delivery stops. GWs continue routing on stale cache until manually restarted.
2. **Slow consumer:** One GW instance is slow to consume events → events queue up in the broker → memory pressure → message loss.
3. **Network partition:** A GW loses connectivity to the broker → misses events → diverges from CP state.

We eliminate these with **in-process Go channels** and **explicit reconnection + re-sync**.

---

## Part 1: WSO2's Event Hub Architecture

### The Four JMS Topics

WSO2 uses Apache ActiveMQ as the event broker. The CP publishes to 4 topics; each GW subscribes to all 4:

| Topic | Payload | Example |
|-------|---------|---------|
| `notification` | API lifecycle changes, subscription events | `{"type":"API_PUBLISHED","apiId":"123","apiName":"PetStore","apiStatus":"Published"}` |
| `keymanager` | Key manager configuration updates | `{"type":"KEYMANAGER_CONFIG_UPDATED","kmName":"default"}` |
| `throttle-data` | Throttle policy updates | `{"type":"THROTTLE_POLICY_UPDATED","policyName":"Gold","requestCount":5000}` |
| `token-revocation` | Token revocation events | `{"type":"TOKEN_REVOKED","token":"jwt...","revokedAt":"2026-09-16T..."}` |

### The CP-to-GW Data Flow

```
┌─────────────────────────────────────────────────────────┐
│           Control Plane                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │ API Registry / Subscription Store                 │  │
│  └───────────────────────────────────────────────────┘  │
│                         │                                │
│                         ├─ on API publish                │
│                         ├─ on subscription create        │
│                         └─ on lifecycle change           │
│                                 ↓                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │ EventHub (JMS Publisher)                          │  │
│  │  - publishes to: notification, keymanager, ...   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                             ↓
              JMS Broker (Apache ActiveMQ)
                    4 durable topics
                             ↓
    ┌────────────────────────┼────────────────────────┐
    ↓                        ↓                        ↓
  ┌──────────┐           ┌──────────┐           ┌──────────┐
  │  Gateway │           │  Gateway │           │  Gateway │
  │   Node 1 │           │   Node 2 │           │   Node 3 │
  └──────────┘           └──────────┘           └──────────┘
```

### The GW Startup Sequence

When a Gateway starts:

1. **Full sync:** Call `GET /cp/admin/sync`
   - Response: All published APIs, all active subscriptions, all key manager configs
   - Load into local cache

2. **Connect to event stream:** Subscribe to 4 JMS topics
   - Listen for incremental updates
   - Apply each event to the local cache (API_PUBLISHED → add to cache; API_RETIRED → remove)

3. **Serve requests:** Route using the synced + continuously updated cache

**Why this two-step approach?**

- **Events during startup gap:** If the GW crashes between syncing and subscribing, it might miss events. Full sync ensures correctness regardless.
- **Event ordering:** Events are numbered (sequence ID). The GW can detect out-of-order delivery and re-sync if needed.

---

## Part 2: Source Walk — WSO2 EventHub

### Step 1: Locate EventHub.java

Run this in your shell:

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "EventHub.java" | head -3
```

**Expected output:**
```
/Users/hunghan/Downloads/wso2am-acp-4.7.0/repository/components/plugins/org.wso2.carbon.apimgt.impl-11.0.0.jar/org/wso2/carbon/apimgt/impl/event/EventHub.java
```

### Step 2: Inspect EventHub.java

Open the file and look for:

- **Constructor:** How is it initialized? Is it a singleton?
- **Topic definitions:** Constants like `NOTIFICATION_TOPIC`, `KEYMANAGER_TOPIC`, etc.
- **publish methods:** How does it send events? Is publishing synchronous or async?

**Key snippet to find:**

```java
public static final String NOTIFICATION_TOPIC = "notification";
public static final String KEYMANAGER_TOPIC = "keymanager";
public static final String THROTTLE_DATA_TOPIC = "throttle-data";
public static final String TOKEN_REVOCATION_TOPIC = "token-revocation";
```

### Step 3: Find JMS Publisher Configuration

Run:

```bash
grep -rn "JMSMessagePublisher\|notification\|keymanager" \
  /Users/hunghan/Downloads/wso2am-acp-4.7.0 \
  --include="*.java" | grep -E "(topic|Topic)" | head -15
```

Look for:

- **Topic names** as string constants
- **Durability settings** (is the broker durable? Do messages persist?)
- **Connection pooling** (how many publisher threads?)

### Step 4: Trace the GW Startup Sequence

Run:

```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 \
  -name "*.java" | \
  xargs grep -l "getSyncData\|fullSync\|syncData" 2>/dev/null | head -5
```

Expected files:

- `SyncManager.java` — coordinates the full sync
- `SubscriptionDataRetrievalUtil.java` — fetches API list from CP
- `EventListener.java` — subscribes to JMS topics

Open one of these and answer:

1. What does `getSyncData()` return?
2. Is the JMS subscription established **before** or **after** calling `getSyncData()`?
3. What happens if the GW loses the JMS connection?

---

## Part 3: Key Insights

### Event Ordering and Sequence IDs

WSO2 event payloads include a **sequence ID**:

```json
{
  "type": "API_PUBLISHED",
  "sequence": 42,
  "apiId": "123",
  "apiName": "PetStore"
}
```

The GW tracks the last sequence ID it processed. If it receives sequence 43 but expected 42, it knows:

- Events were dropped (broker issue or network lag)
- Action: Call `getSyncData()` to resync

This **explicit recovery** avoids silent data loss.

### Durability vs. In-Process Channels

| Aspect | JMS (WSO2) | Go Channels (Our System) |
|--------|-----------|-------------------------|
| Durability | Messages persist on broker if subscriber offline | In-memory buffer; loss on process crash |
| Broker availability | Depends on broker uptime | No broker; always available |
| Throughput | Limited by network + broker | Very high (in-process) |
| Reconnection | Manual in GW code | Explicit HTTP reconnect |
| Message size | Small (JSON) | Small (JSON) |

**Trade-off:** We accept no durability (bounded buffer, drop on full) for **simplicity** and **always-available** event delivery.

### Non-Blocking Publish

In WSO2, the JMS publisher is asynchronous:

```java
publisher.publish(event); // Returns immediately; actual send is async
```

If the broker is slow, messages queue up in the publisher's thread pool. If the queue fills, messages are dropped with a warning in the log.

We replicate this with **non-blocking channel send**:

```go
select {
case ch <- event:
    // Sent
default:
    log.Warn("event bus: buffer full, dropping event")
}
```

---

## Part 4: Anti-Patterns to Avoid

### Anti-Pattern 1: Subscribing Without Initial Sync

```go
// WRONG: Subscribe first, then sync
go func() {
    for e := range eventStream {
        cache.apply(e)
    }
}()
time.Sleep(1 * time.Second) // Hope events start flowing
resp := getSyncData()
cache.load(resp) // Too late; events were missed during the gap
```

**Why it fails:** Events published during the gap are lost. The cache ends up inconsistent.

**Fix:**

```go
// CORRECT: Sync first, then subscribe
cache.load(getSyncData())
for e := range eventStream {
    cache.apply(e)
}
```

### Anti-Pattern 2: Unbuffered Channels

```go
// WRONG: Unbuffered
ch := make(chan Event) // No buffer

select {
case ch <- event:
    // Sent
default:
    // Buffer is always full (capacity 0)
    log.Warn("dropped")
}
```

**Why it fails:** Unbuffered channels block the sender until the receiver is ready. One slow consumer blocks all others.

**Fix:** Always use buffered channels with a size matching expected throughput.

### Anti-Pattern 3: Blocking Publish in an HTTP Handler

```go
// WRONG: Blocking
func handleCreate(w http.ResponseWriter, r *http.Request) {
    sub := createSubscription(r)
    bus.publish(Event{...}) // BLOCKS if subscriber is slow!
    writeJSON(w, http.StatusCreated, sub)
}
```

**Why it fails:** An HTTP handler blocks; requests pile up; cascading failures.

**Fix:** Use non-blocking send (drop on full).

---

## Exercises

### Exercise 1: JMS Topics and Failure Modes

**Question:** WSO2 uses JMS for event sync. Name two production failure modes specific to JMS that Go channels avoid.

**Hint:** Think about broker availability and message queuing.

**Solution sketch:**

1. **JMS broker outage:** If ActiveMQ goes down, all event delivery stops. The GW continues routing on cached data until the broker is restored and the GW manually re-syncs. Go channels are in-process; no broker, no outage.

2. **Slow consumer queue backup:** If a GW is slow, events queue up in the broker. If the queue fills, messages are dropped (with no notification to other subscribers). Go channels are bounded and drop immediately with a warning, allowing the GW to re-sync.

**Additional insight:** JMS also requires connection pooling, heartbeats, and failover configuration — all sources of operational complexity. Go channels eliminate this.

---

### Exercise 2: The Startup Sequence Gap

**Question:** The GW calls `getSyncData()` at startup before subscribing to events. Why is this ordering critical?

**Hint:** Think about what happens if an API is published between the GW starting and the subscription establishing.

**Solution sketch:**

Events published **during the startup gap** (before the GW subscribes) will never reach the GW.

**Example timeline:**
- T=0: GW starts
- T=1: GW calls `getSyncData()` → gets API list (doesn't include API created at T=1.5)
- T=1.5: Operator publishes a new API on the CP → API_PUBLISHED event fired
- T=2: GW subscribes to events
- T=3: GW is now listening, but the T=1.5 event is gone

**Result:** The new API is missing from the GW's cache.

**Fix:**
1. Call `getSyncData()` first (get all current state)
2. Then subscribe to events
3. Any API_PUBLISHED event arriving after subscription is applied immediately

This is called the **"initial sync + stream"** pattern.

---

### Exercise 3: The 4 JMS Topics and Their Payloads

**Question:** List the 4 JMS topic names WSO2 uses for event sync and what each carries.

**Hint:** Check `EventHub.java` constants.

**Solution sketch:**

1. **`notification`** — API lifecycle changes (create, publish, deprecate, retire) and subscription events (create, update, block, delete). Payload: `{type, apiId, apiName, subscriptionId, ...}`

2. **`keymanager`** — Key manager configuration updates (new KM instance, KM endpoint changed). Payload: `{type, keyManagerName, configuration}`

3. **`throttle-data`** — Throttle policy updates (new policy, policy rate changed). Payload: `{type, policyName, requestCount, resetTime, ...}`

4. **`token-revocation`** — Revoked JWT tokens and OAuth tokens. Payload: `{type, token, revokedAt, reason}`

**Why this separation?** Each GW subscribes to all 4, but the CP can publish events to just the topics relevant to a change (reduces broker load).

---

## Key Takeaways

1. **Event hub architecture:** Decouples the CP from GWs using a pub-sub broker (JMS/ActiveMQ).

2. **Two-step startup:** Full sync → subscribe to events. Ensures consistency even if events are missed during the gap.

3. **Non-blocking publish:** Prevents slow subscribers from blocking the CP. Drop events if buffer is full.

4. **Durability trade-off:** WSO2 uses durable JMS for persistence. We use in-process Go channels (simpler) and accept the risk (mitigated by explicit reconnection + re-sync).

5. **Event ordering:** Include sequence IDs in event payloads to detect and recover from event loss.

---

## Next Steps

Tomorrow (Day 38), you'll build the EventBus in Go using channels, then integrate it into the CP. For now, focus on understanding the **why** of event-driven architecture and the specific patterns WSO2 uses.

**Go deeper:** Read the WSO2 EventHub documentation at https://apim.docs.wso2.com/en/latest/administer/managing-distributed-deployments/managing-the-product-instances/
