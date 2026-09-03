# Lab: Day 22 — Subscription Store Source Reading

## Objective

Find and analyze the WSO2 API Gateway's subscription store implementation in the source code.
Understand the data structure, threading model, and how subscriptions are validated.

## What You'll Find

This is a **source-reading lab**. You will not write code. Instead, you'll examine the WSO2
API Manager source code (Universal Gateway 4.7.0 or API Manager source) and answer the
questions below.

### Location

The WSO2 API Manager Universal Gateway source is available at:
- Official WSO2 GitHub: https://github.com/wso2/apk (newer universal gateway)
- Or from your downloaded distribution: `/path/to/wso2am-universal-gw-4.7.0/`

### Key Files to Find

1. **`SubscriptionDataStore.java`** (or similar)
   - Main class managing the subscription cache
   - Location varies by version; look in packages like:
     - `com.wso2.apim.datastore`
     - `org.wso2.apk.management.datastore`
     - `com.wso2.api.gateway`

2. **`APIKeyValidationService.java`** (or similar)
   - Uses the subscription store to validate incoming requests
   - Location varies; look in:
     - `com.wso2.apim.service`
     - `org.wso2.apk.api.service`

3. **Event handlers** — classes that listen for subscription events from the CP
   - Look for files with "Event", "Listener", "Handler" in the name
   - Often in a `listeners` or `events` package

## Structured Questions

Answer each question by examining the source code. Cite the class name, method name, and
a brief code snippet where relevant.

### Question 1: Data Structure

**What data structure does the subscription store use to hold subscriptions?**

- Is it a `ConcurrentHashMap`, `TreeMap`, `Map` with locks, or something else?
- What is the key? (e.g., "appName::apiName")
- What is the value? (a POJO class name, or a primitive type?)

**Your answer:**

```
[Examine SubscriptionDataStore.java]

Data structure: _______________________________
Key type: _________________________________
Value type: __________________________________
Thread-safety mechanism: _______________________
```

---

### Question 2: Subscription Lookup Method

**Find the method that checks if an application is subscribed to an API.**

- What is the method name?
- What are the parameters?
- What does it return?
- How does it construct the key to look up?

**Your answer:**

```
[Examine SubscriptionDataStore.java or APIKeyValidationService.java]

Method name: ______________________________
Parameters: ________________________________
Return type: __________________________________
Key construction: ____________________________
Implementation (brief): ____________________________
```

---

### Question 3: Event-Driven Sync

**How does the gateway update the subscription store when the CP pushes a new subscription?**

- What event triggers the update? (JMS message, HTTP webhook, in-process event?)
- What class handles the event?
- Does the event listener deserialize the subscription data? How?

**Your answer:**

```
[Search for event listeners, JMS handlers, HTTP endpoints]

Event trigger: _______________________________
Handler class: _______________________________
Event payload deserialization: _____________________
Update method called: ______________________________
```

---

### Question 4: Lifecycle

**How are subscriptions added to the store?**

- When is `addSubscription()` called? (startup bootstrap, event handler, both?)
- How is the key constructed?
- Is there any validation before adding?

**Your answer:**

```
[Examine initialization code and event handlers]

Add triggers: _________________________________
Key construction: ____________________________
Validation checks: ____________________________
```

---

### Question 5: Concurrency

**Is the subscription store thread-safe? How?**

- Can multiple threads read simultaneously? (should be yes for high throughput)
- Can one thread write while another reads? (should be safe)
- What synchronization mechanism is used?

**Your answer:**

```
[Review the data structure and locking strategy]

Thread-safe reads: _____________________________
Thread-safe writes: _____________________________
Synchronization: _________________________________
```

---

## Submission

Write your answers in a file named `ANSWERS.md` in this directory. Format:

```markdown
# Day 22 Submission: Subscription Store Analysis

## Question 1: Data Structure
[Your answer]

## Question 2: Subscription Lookup Method
[Your answer]

## Question 3: Event-Driven Sync
[Your answer]

## Question 4: Lifecycle
[Your answer]

## Question 5: Concurrency
[Your answer]
```

## Hints

- If the distribution doesn't have source, check the official GitHub: https://github.com/wso2/apk
- The newer APK (API Platform for Kubernetes) uses a similar architecture but may have different class names.
- Look for TODOs or comments like "subscription cache" or "subscription validation" — they often lead to key code.
- If you find the code in a JAR, extract it with `jar xf myjar.jar com/wso2/...` or use a decompiler like CFR.

## Further Reading

- WSO2 API Manager Admin Guide: https://apim.docs.wso2.com/
- APK (Universal Gateway) GitHub: https://github.com/wso2/apk
- API Key Validation Flow: Refer to the API Manager architecture documentation.

## Teardown

No containers or resources to tear down.

