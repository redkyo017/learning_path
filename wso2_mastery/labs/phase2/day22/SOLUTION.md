# Day 22 Solution: Subscription Store Analysis

## Overview

This solution provides reference answers to the subscription store source-reading lab. The answers are based on the WSO2 API Manager (Universal Gateway 4.7.0) architecture and common patterns found in subscription management implementations.

**Note:** If you have access to `SubscriptionDataStore.java` from your local download or the WSO2 GitHub repository, verify these answers against the actual source code. Exact class names, method signatures, and package names may vary across versions.

---

## Question 1: Data Structure

**What data structure does the subscription store use to hold subscriptions?**

### Reference Answer

```
Data structure: ConcurrentHashMap<String, SubscriptionData>

Key type: String (composite key format: "appName::apiName" or "appId::apiId")

Value type: SubscriptionData (POJO with fields: apiId, applicationId, 
           tier, subscriptionStatus, createdTime, lastUpdatedTime)

Thread-safety mechanism: ConcurrentHashMap provides thread-safe reads via 
                         segment-level locking without explicit synchronization.
                         Allows concurrent read operations on different segments.
```

### Explanation

The subscription store uses `ConcurrentHashMap` because:
- **High-throughput reads**: API Gateway validates subscriptions on every request; concurrent reads are essential.
- **Safe writes**: When CP pushes updates, the subscription store must safely update entries without blocking concurrent reads.
- **No explicit locking required**: Developers don't need to add `synchronized` blocks; the map handles segment-level locking internally.

Key format like `"appName::apiName"` is a common pattern in WSO2 to create a unique, queryable identifier.

---

## Question 2: Subscription Lookup Method

**Find the method that checks if an application is subscribed to an API.**

### Reference Answer

```
Method name: isSubscribed() or validateSubscription()

Parameters: (String applicationId, String apiId) 
           or (String key, String subscriptionStatus)

Return type: boolean 
            or SubscriptionData (returns null if not found/not active)

Key construction: String key = applicationId + "::" + apiId;
                 (or similar delimiter-based composition)

Implementation (brief):
  1. Construct key from application ID and API ID
  2. Look up key in ConcurrentHashMap
  3. If found and subscription status is "ACTIVE", return true/SubscriptionData
  4. If not found or status is not "ACTIVE" (e.g., "BLOCKED", "REJECTED"), 
     return false/null
  5. No locking needed; ConcurrentHashMap handles thread safety
```

### Explanation

This method is called on every API request by the `APIKeyValidationService` or equivalent validator. It must be fast and thread-safe:
- Constructs a composite key to enable O(1) lookup
- Checks subscription status to ensure only active subscriptions are valid
- Returns immediately without acquiring locks (ConcurrentHashMap's strength)

Example call flow:
```
Request arrives → APIKeyValidationService checks appId + apiId
  → Calls subscriptionStore.isSubscribed(appId, apiId)
  → Returns true/false → Request allowed/blocked
```

---

## Question 3: Event-Driven Sync

**How does the gateway update the subscription store when the CP pushes a new subscription?**

### Reference Answer

```
Event trigger: JMS Topic Message from Control Plane
             (or HTTP webhook, depending on deployment)
             Topic: "SUBSCRIPTION_CREATED", "SUBSCRIPTION_UPDATED", 
                    "SUBSCRIPTION_DELETED"

Handler class: SubscriptionEventListener or JMSEventHandler
             (typically in org.wso2.apk.management.listeners or 
              com.wso2.apim.listeners package)

Event payload deserialization: 
  1. Listener receives JMS TextMessage
  2. Deserializes JSON payload into SubscriptionEvent POJO using 
     Jackson ObjectMapper (or Gson)
  3. Extracts fields: applicationId, apiId, subscriptionStatus, tier, etc.
  4. Validates event signature/timestamp (optional security check)

Update method called: 
  - addSubscription(applicationId, apiId, subscriptionData)
  - updateSubscription(applicationId, apiId, subscriptionData)
  - removeSubscription(applicationId, apiId)
```

### Explanation

The subscription store is **event-driven** because:
- CP (Control Plane) is the single source of truth for subscription state
- Gateway (Runtime) caches subscriptions for fast lookup
- When a developer creates/updates a subscription in CP, CP publishes an event
- Gateway's JMS listener consumes the event and updates the local cache

Flow:
```
Developer creates subscription in CP Console
  → CP publishes JMS event to SUBSCRIPTION_CREATED topic
  → Gateway's SubscriptionEventListener receives message
  → Deserializes JSON payload
  → Calls subscriptionStore.addSubscription(...)
  → Cache is now consistent with CP
```

---

## Question 4: Lifecycle

**How are subscriptions added to the store?**

### Reference Answer

```
Add triggers: 
  1. Startup bootstrap: Gateway reads all subscriptions from CP 
     (via REST API or database) and pre-populates the cache
  2. Event-driven update: JMS listener receives SUBSCRIPTION_CREATED 
     or SUBSCRIPTION_UPDATED events from CP and adds/updates entries

Key construction: 
  String key = applicationId + "::" + apiId;
  (or variant: "app_" + applicationId + "_api_" + apiId)

Validation checks:
  1. Verify subscription is "ACTIVE" (status check)
  2. Verify application is not "BLOCKED"
  3. Verify API is not "DELETED" or "DEPRECATED"
  4. Check subscription tier is valid and not expired
  5. Optional: Verify event signature and timestamp to prevent replay attacks
```

### Explanation

**Startup (initialization):**
- When the Gateway starts, `SubscriptionBootstrapListener` or similar loads all active subscriptions from the CP
- Prevents cache misses during warm-up period
- Example: `SELECT * FROM subscriptions WHERE status='ACTIVE'`

**Runtime (event-driven):**
- Each subscription event triggers a listener
- Listener deserializes event and validates subscription state
- Only active, non-expired subscriptions are added to cache
- Invalid or expired subscriptions are either not added or removed

**Why this design?**
- Pre-population ensures gateway doesn't reject requests due to empty cache
- Event-driven updates keep cache synchronized with CP in real-time
- Validation prevents caching of blocked/expired subscriptions

---

## Question 5: Concurrency

**Is the subscription store thread-safe? How?**

### Reference Answer

```
Thread-safe reads: YES 
  - Multiple threads can simultaneously check subscriptions 
    on different keys without blocking
  - ConcurrentHashMap uses bucket-level locking (16 default segments)
  - Each segment can be accessed by one writer OR multiple readers 
    simultaneously

Thread-safe writes: YES
  - One thread can safely update a key while others read from 
    different keys
  - Same-key updates are serialized (bucket lock)
  - Read-write operations on different keys proceed in parallel

Synchronization: 
  - Explicit: ConcurrentHashMap's built-in segment-level locks
  - No additional synchronized {} blocks needed in lookup/add/remove methods
  - Atomic operations: Entry updates are atomic (one operation, 
    no torn writes)
```

### Explanation

**Why ConcurrentHashMap and not HashMap?**

```java
// UNSAFE - HashMap is not thread-safe
HashMap<String, Sub> store = new HashMap<>();
// Concurrent reads + writes = data corruption

// SAFE - ConcurrentHashMap is thread-safe
ConcurrentHashMap<String, Sub> store = new ConcurrentHashMap<>();
// Concurrent reads + writes = consistent state
```

**Performance implication:**
- Thousands of API requests per second → thousands of concurrent `isSubscribed()` calls
- Synchronized(store) {...} would serialize all reads → bottleneck → timeout
- ConcurrentHashMap allows 16+ threads to read simultaneously from different buckets

**Worst-case scenario (handled correctly):**
- Request 1 calls `isSubscribed("app1", "api1")` → reads bucket 5
- Request 2 calls `isSubscribed("app2", "api2")` → reads bucket 12
- Event handler updates `("app1", "api1")` → writes to bucket 5
- All three proceed in parallel. Request 1's read is safe; Request 2 is unaffected.

---

## Summary

The WSO2 API Manager subscription store implements a **thread-safe, event-driven cache** using:

1. **Data structure**: ConcurrentHashMap for O(1) safe concurrent access
2. **Lookup**: Fast key-based queries (applicationId + apiId)
3. **Synchronization**: JMS event listeners update cache in real-time
4. **Lifecycle**: Bootstrap on startup + event-driven updates at runtime
5. **Concurrency**: ConcurrentHashMap handles all synchronization; no explicit locks needed

This design ensures **low-latency subscription validation** under high request load while maintaining **consistency** with the Control Plane.

---

## Verification Checklist

When you examine the actual source code, verify:

- [ ] Data structure is ConcurrentHashMap or similar concurrent collection
- [ ] Key format follows a composite pattern (appId::apiId or similar)
- [ ] `isSubscribed()` method exists and checks ACTIVE status
- [ ] Event listener class exists and deserializes JMS messages
- [ ] Subscription validation occurs before adding to cache
- [ ] No explicit `synchronized` blocks in hot-path methods
- [ ] Startup initialization loads pre-cached subscriptions
- [ ] Thread safety is provided by the collection, not manual synchronization
