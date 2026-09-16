# Day 37 — Lab: Source Reading - The Event Hub

## Goal

Trace the WSO2 event hub architecture by reading source code. Understand:

1. The 4 JMS topics and their payloads
2. How the CP publishes events
3. How the GW subscribes and syncs on startup

## Prerequisites

- WSO2 AM distribution downloaded: `/Users/hunghan/Downloads/wso2am-acp-4.7.0` and `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0`
- Access to file system and grep
- 30-45 minutes

## Steps

### Step 1: Find EventHub.java

Run:

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "EventHub.java" -o -name "*EventHub*" | head -10
```

**Expected output (or similar):**

```
/Users/hunghan/Downloads/wso2am-acp-4.7.0/repository/components/plugins/.../EventHub.java
```

Open one of these files. Look for:

- **Class definition:** Is it a singleton? Does it use dependency injection?
- **Topic constants:** Look for `public static final String NOTIFICATION_TOPIC`, etc.

**Question 1:** What are the 4 JMS topic names?

---

### Step 2: Search for Topic Names in Configuration

Run:

```bash
grep -rn "notification\|keymanager\|throttle-data\|token-revocation" \
  /Users/hunghan/Downloads/wso2am-acp-4.7.0 \
  --include="*.java" \
  --include="*.xml" | grep -iE "(topic|topic_name|queue)" | head -20
```

Look for:

- Topic names as string constants
- Configuration files that define topics
- Code that publishes to topics

**Question 2:** Find one place where the CP publishes to the `notification` topic. What method is called?

---

### Step 3: Find JMS Publisher Implementation

Run:

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "JMSMessagePublisher.java" -o -name "*Publisher*.java" | head -5
```

Open one of these files. Look for:

- **publish method signature:** Does it block or return immediately?
- **Exception handling:** What happens if the broker is unavailable?
- **Threading model:** Is publishing async or sync?

**Question 3:** Is the JMS publish operation blocking or non-blocking? How does it handle a slow broker?

---

### Step 4: Trace the GW Sync Process

Run:

```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 \
  -name "*.java" | \
  xargs grep -l "getSyncData\|fullSync\|syncData" 2>/dev/null | head -5
```

Open one of these files (e.g., `SyncManager.java`). Look for:

- **initialization sequence:** Does the GW call `getSyncData()` before subscribing?
- **subscription setup:** Where does the GW subscribe to JMS topics?
- **cache loading:** How is the cache populated from the sync response?

**Question 4:** Draw a timeline of the GW startup sequence (what happens first: sync or subscribe?).

---

### Step 5: Examine Event Payload Structure

Run:

```bash
grep -rn "EventProperties\|EventPayload\|APIPublishedEvent" \
  /Users/hunghan/Downloads/wso2am-acp-4.7.0 \
  --include="*.java" | head -10
```

Look for:

- Classes that represent event payloads
- Fields in the event (apiId, apiName, context, etc.)
- How the event is serialized to JSON/XML

**Question 5:** What fields are in an `API_PUBLISHED` event?

---

## Answers (Log Format)

In your `why.log` file (or a text file), write:

```
Day 37 — Source Reading Log
============================

1. The 4 JMS topics are:
   - notification: <what it carries>
   - keymanager: <what it carries>
   - throttle-data: <what it carries>
   - token-revocation: <what it carries>

2. The CP publishes to the notification topic when:
   - <specific scenario>
   - Source: <file path>:<line number>

3. The JMS publish operation is:
   - Blocking / Non-blocking (circle one)
   - Reasoning: <why>

4. GW startup sequence (first → last):
   - Step 1: ...
   - Step 2: ...
   - Step 3: ...
   - Source: <file path>:<line number>

5. API_PUBLISHED event fields:
   - apiId, apiName, context, ...
   - Source: <file path>:<line number>

6. Reflection:
   - One thing that surprised me: ...
   - One question I still have: ...
```

---

## Key Observations to Look For

### The Sync/Subscribe Ordering

**Correct order:**

```
GW startup:
  1. Full sync: GET /cp/admin/sync → local cache loaded
  2. Connect: Subscribe to JMS topics
  3. Loop: For each event, apply to cache
```

**Why:** If reversed, events published during the gap are lost.

### Topic vs. Queue

- **Topic:** Broadcast to all subscribers (publish-subscribe)
- **Queue:** Deliver to one subscriber (point-to-point)

WSO2 uses **topics** so all GW instances receive all events.

### Durability and Persistence

- **Durable topic subscription:** If a GW is offline, messages are persisted in the broker. When the GW comes back, it receives missed messages.
- **Non-durable:** If a GW is offline, messages are lost.

WSO2 uses durable subscriptions (high availability).

---

## Verification Checklist

- [ ] Found EventHub.java or equivalent event manager class
- [ ] Identified 4 topic names
- [ ] Found the JMS publisher implementation
- [ ] Understand whether publishing is blocking or async
- [ ] Traced the GW startup sequence (sync → subscribe)
- [ ] Located at least one event payload class
- [ ] Noted how events are published (synchronously or asynchronously)
- [ ] Documented the ordering: sync first, then subscribe

---

## Optional Exploration

1. **Cluster resilience:** Search for "cluster" or "node" in EventHub code. How does WSO2 handle multiple GW nodes? Do all nodes subscribe independently?

2. **Sequence IDs:** Search for "sequence" in event-related files. Do events include sequence numbers to detect dropped messages?

3. **Compression:** Search for event serialization code. Are events compressed? Encrypted?

---

## Reflection

Write a short reflection (100-200 words):

**"Why does WSO2 use a separate event hub instead of asking GWs to poll the CP?"**

Consider:

- Latency vs. load
- Scalability (1000 GW instances polling)
- Network usage
- Consistency guarantees

---

## Next Steps

Tomorrow (Day 38), you'll implement the Go equivalent: `EventBus` with channels. Compare your implementation with what you learned from WSO2 source code:

- Does your EventBus use buffered channels (mirroring WSO2's queue)?
- Do you have type-specific subscribers (API_PUBLISHED vs. SUBSCRIPTION_CREATED)?
- How do you handle slow subscribers?

**Hint:** Your Go version will be simpler (no broker, no durability) but follow the same architectural patterns.
