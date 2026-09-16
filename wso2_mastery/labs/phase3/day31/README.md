# Day 31 — Source Reading Lab: API Lifecycle State Machine

## Goal

Trace the API lifecycle state machine in the WSO2 APIM ACP source code. By the end of this lab, you will understand:
- The 4 lifecycle states and valid transitions
- What validation happens before publishing
- How WSO2 notifies downstream systems (like the Gateway) about lifecycle changes

## Prerequisites

You have the WSO2 API Manager source code downloaded at `/Users/hunghan/Downloads/wso2am-acp-4.7.0`.

## Step 1: Locate the API Provider Implementation

Find the main API provider class:

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APIProviderImpl.java" | head -3
```

**Expected output:**
```
/Users/hunghan/Downloads/wso2am-acp-4.7.0/components/apimgt/org.wso2.carbon.apimgt.core/src/main/java/org/wso2/carbon/apimgt/core/impl/APIProviderImpl.java
```

Make a note of this path. This is where all the API creation and lifecycle logic lives.

## Step 2: Trace Lifecycle Transition

In the `APIProviderImpl.java` file, search for key methods:

```bash
grep -n "changeLifeCycleStatus\|NotificationsPublisher\|validateAPI" <PATH_TO_APIProviderImpl.java> | head -20
```

**What to look for:**
- `changeLifeCycleStatus()` method: This is called when an API transitions between states
- `NotificationsPublisher` class: This fires events that the Gateway listens to
- `validateAPI()` method: This checks if an API is valid before insertion

**Hint:** You may need to scroll through the file or use your editor's "Go to Definition" feature to follow the call chain.

## Step 3: Find the State Machine Configuration

The valid transitions are defined in an XML file. Find it:

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APILifeCycle.xml"
```

**Expected output:**
```
/Users/hunghan/Downloads/wso2am-acp-4.7.0/.../APILifeCycle.xml
```

Open this file and read the state definitions.

## Step 4: Answer These Questions

Create a file called `why.md` in this directory and answer the following questions in your own words:

### Question 1: List the Lifecycle States and Transitions

**Q:** What are the 4 lifecycle states? What are the allowed transitions between them?

**Hint:** Look at the `APILifeCycle.xml` file. Each state is defined with a list of allowed "next states."

**Solution sketch:**
```
The four states are: CREATED, PUBLISHED, DEPRECATED, RETIRED

Valid transitions:
  CREATED → PUBLISHED (only transition out of CREATED)
  PUBLISHED → DEPRECATED (only transition out of PUBLISHED)
  DEPRECATED → RETIRED (only transition out of DEPRECATED)
  RETIRED → (end state, no outgoing transitions)

Invalid transitions that are rejected:
  CREATED → RETIRED (skipping PUBLISHED and DEPRECATED)
  PUBLISHED → CREATED (going backwards)
  DEPRECATED → CREATED (going backwards)
  Any transition involving RETIRED (except DEPRECATED → RETIRED)
```

### Question 2: Validation Before Publishing

**Q:** What does WSO2 validate before allowing the CREATED → PUBLISHED transition?

**Hint:** Find the `validateAPI()` method. Look at the validation checks inside it or immediately before `changeLifeCycleStatus()` is called.

**Solution sketch:**
```
Before publishing, WSO2 validates:
  1. Backend URL is not null and not empty (API must have a target)
  2. Context is not null and not empty (API must have a routing path)
  3. API name and version are provided
  4. (In full WSO2) At least one subscription tier is assigned
  5. (In full WSO2) OpenAPI/Swagger definition is syntactically valid

If any validation fails, the publish is rejected and Status stays CREATED.
```

### Question 3: Event Notification

**Q:** What event class does `changeLifeCycleStatus()` fire, and what arguments does it pass?

**Hint:** Look for `notificationsPublisher.publishNotification()` inside `changeLifeCycleStatus()`. Find the method signature to see what it takes as arguments.

**Solution sketch:**
```
changeLifeCycleStatus() calls:
  notificationsPublisher.publishNotification(
    APIEvent.class or similar,
    apiObject,
    newStatus,
    timestamp
  )

The event carries:
  - The full API object (name, context, version, backend URL, etc.)
  - The new status (PUBLISHED, DEPRECATED, or RETIRED)
  - A timestamp

The Gateway subscribes to this event stream and, when it receives
an event indicating PUBLISHED, adds the API context to its route table.
```

## Verification

Before submitting, verify your answers by:

1. Re-reading the source code section you cited
2. Checking your understanding against the theory in `content/phase3/day31.md`
3. Making sure your answers explain the "why" and "what," not just the "what"

## Why This Matters

By reading the source code directly, you learn:
- **How state machines are implemented in production systems** — with explicit allowed-transition rules
- **How database updates trigger events** — the CP doesn't just write a row; it fires a notification
- **How distributed systems stay consistent** — the GW doesn't poll the CP; it listens to events
- **Where bugs come from** — skipped validation, incomplete event publishing, or missing state checks

## Next Steps

Tomorrow (Day 32), you'll implement this exact pattern in Go. You'll build the state machine, the validation logic, and the event firing mechanism. By understanding the source first, you'll know exactly what to build.
