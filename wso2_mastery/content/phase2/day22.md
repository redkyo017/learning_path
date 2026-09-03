# Day 22: WSO2 Subscription Validation — Source Reading and Architecture

## Why

Before Day 21's JWT validation middleware can enforce subscriptions, you must understand how
WSO2 stores and validates subscription data. Today is a source reading exercise: you'll examine
the WSO2 API Gateway's subscription store implementation to see:

- What subscription data the gateway holds (application name, API name, tier, key type).
- How the CP (Control Plane) syncs subscriptions to the GW (Gateway) at runtime.
- How the gateway checks if a request's JWT (which contains an application name) maps to a valid subscription.

---

## WSO2 Source Reading

### The Gateway Subscription Store

In WSO2 API Manager, the gateway runs a **subscription data store** — an in-memory cache of all
subscribed applications. This data is **pushed** by the Control Plane (CP) to each gateway instance
via an event system (usually JMS).

**Key data structure:**

```
SubscriptionDataStore (in-memory map)
├─ Key: applicationName + apiName (e.g., "myapp::myapi")
├─ Value: SubscriptionRecord
│   ├─ applicationName: string ("myapp")
│   ├─ apiName: string ("myapi")
│   ├─ apiVersion: string ("1.0.0")
│   ├─ subscriptionTier: string ("gold" or "silver")
│   └─ keyType: string ("PRODUCTION" or "SANDBOX")
└─ ...more entries...
```

When a request arrives with a valid JWT containing `applicationname` claim:

1. The gateway extracts `applicationname` from the JWT.
2. The gateway looks up `applicationname::apiName` in the subscription store.
3. If found → request is allowed (forward to backend).
4. If **not found** → return 403 Forbidden.

### Source References

**Main classes:**

- **`SubscriptionDataStore.java`** — Maintains the in-memory subscription map. Key method:
  - `isApplicationSubscribedForAPI(String appName, String apiName)` → checks if subscription exists.
  - `addSubscription(SubscriptionRecord)` → adds a new subscription at runtime.
  - `removeSubscription(String appName, String apiName)` → removes a subscription.

- **`APIKeyValidationService.java`** — Uses SubscriptionDataStore to validate incoming requests:
  - `validateAPIKey()` → main validation entry point (runs after JWT validation).
  - Queries the subscription store, checks throttle policies.

- **Event-based sync** — The CP publishes subscription events (via JMS or HTTP webhooks) to notify
  the gateway when subscriptions are added or removed. This happens without restarting the gateway.

### What You Need to Find

Your lab today is to **find and read `SubscriptionDataStore.java`** in the WSO2 API Manager source.
Identify:

1. The data structure used to store subscriptions (likely a `ConcurrentHashMap` or similar).
2. The method that checks if an application is subscribed for a given API.
3. How subscriptions are added/removed dynamically.
4. Thread-safety mechanisms (if any).

---

## Core Concepts

### Subscription Store as a Cache

The subscription store is a **local cache** on the gateway, not a shared database query. Why?

**Performance:** Querying a database on every request would be slow. Instead, the gateway
fetches all subscriptions once and caches them in memory.

**Consistency:** The CP pushes updates to the cache via events, so all gateways converge
on the same subscription state.

**Failover:** If the CP is temporarily unavailable, the gateway can still serve cached subscriptions.

### Event-Driven Sync (CP → GW)

```
Control Plane (CP)                      Gateway (GW)
┌─────────────────┐                   ┌──────────────┐
│ API Manager     │                   │ API Gateway  │
│ (publishes)     │                   │ (subscribes) │
│                 │  ──→ JMS Event ──→│              │
│ Event: "sub"    │                   │ Listen       │
│ {appName,       │                   │ Update cache │
│  apiName,       │                   │              │
│  tier}          │                   │              │
└─────────────────┘                   └──────────────┘
```

When a subscription is created or modified in the CP, it publishes an event.
The gateway's event listener receives it and updates the subscription store immediately.

### Why Fail-Closed on Missing Subscription

If a request contains a valid JWT (signature is valid, not expired) but the
`applicationname::apiName` is not in the subscription store, the gateway returns **403 Forbidden**.

Why? Because the application is not subscribed to that API. Even though the JWT is valid,
authorization fails.

---

## Lab

See `labs/phase2/day22/` — source reading guide. No Go code to write; instead, you'll examine
the WSO2 source and answer structured questions.

---

## Exercises

**Exercise 1:** In the WSO2 API Gateway source, find the class that implements the subscription
store. What data structure does it use (e.g., ConcurrentHashMap, TreeMap)? Why do you think that
choice was made?

**Hint:** Look for a class name containing "Subscription" and "Store" or "Cache". The data structure
should be thread-safe to support concurrent reads from multiple request threads.

**Solution sketch:**

The `SubscriptionDataStore` class (or similar) likely uses a `ConcurrentHashMap<String, SubscriptionRecord>`
(or `Map` backed by a concurrent structure). This is chosen for thread-safe concurrent reads without
locking, which is critical for high-throughput API gateways where thousands of requests per second
may query the store simultaneously.

---

**Exercise 2:** Identify the method in SubscriptionDataStore that checks if an application is
subscribed for a given API. What are its parameters and return type?

**Hint:** The method name likely contains "isSubscribed" or "isValid" and takes parameters for
application name and API name.

**Solution sketch:**

The method is typically named `isApplicationSubscribedForAPI(String applicationName, String apiName)`
and returns a boolean. It performs a key lookup in the store: `store.get(applicationName + "::" + apiName) != null`.

---

**Exercise 3:** How does the gateway update the subscription store when the CP pushes a new
subscription? What mechanism triggers the update?

**Hint:** Look for event listeners or message handlers in the gateway. The update might be triggered
by a JMS message, HTTP webhook, or in-process event.

**Solution sketch:**

The gateway typically registers a JMS message listener (or HTTP endpoint) that receives subscription
events from the CP. When a new event arrives (e.g., subscription created), the listener deserializes
the event payload and calls `subscriptionStore.addSubscription(record)` to update the cache.
This happens asynchronously without restarting the gateway.

---

## Anti-patterns

- **No expiration on cached subscriptions** — If a subscription is deleted in the CP but the GW
  cache is stale, requests may still be allowed. WSO2 mitigates this with event-driven sync
  (not time-based TTL). Your Go implementation will use a similar approach.

- **Thread-unsafe subscription store** — If the store is updated by one thread while another is
  reading it (during a request), you may get a race condition or incomplete data. Use `sync.Map`
  or similar in Go.

- **No rollback on duplicate keys** — If the store allows duplicate applications (same appName+apiName),
  later updates may silently overwrite earlier ones without logging. Always enforce uniqueness.

---

## Teardown

No containers to tear down. Complete the source reading lab by answering the structured questions in
`labs/phase2/day22/README.md`.

