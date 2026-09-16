# Day 31 — API Lifecycle: The State Machine Behind Publishing

## Why This Matters

The Control Plane is the single source of truth for all API metadata. Understanding how WSO2 models the API lifecycle tells you exactly which component to debug when an API isn't reachable at the gateway. The lifecycle is not a fuzzy concept — it's a deterministic state machine, and every transition is validated before it happens. When an API gets published, the CP doesn't just update a database row; it fires an event that tells the Gateway to start routing traffic to it. If you skip this event, the Gateway ignores the API entirely.

## Core Concepts

### The API Lifecycle State Machine

WSO2 API Manager defines a strict state machine in `APILifeCycle.xml`. Every API transitions through these states:

```
CREATED → PUBLISHED → DEPRECATED → RETIRED
```

**Key properties:**
- An API starts in `CREATED` after being registered in the Publisher portal.
- Only `PUBLISHED` APIs are visible to subscribers and routed by the Gateway.
- `DEPRECATED` means "no new subscriptions," but existing ones still work.
- `RETIRED` means the API is archived — no subscriptions allowed.
- **Invalid transitions are rejected** — you cannot go directly from `CREATED` to `RETIRED`, and you cannot go backwards (e.g., `PUBLISHED` to `CREATED`).

### The Publisher Flow: End-to-End

When an API publisher creates and publishes an API, this happens in the Control Plane:

```
1. POST /apis (Publisher portal)
   ↓
2. APIProviderImpl.addAPI()
   → Validates context, backend URL, name, version (reject if validation fails)
   → Inserts row into AM_API table with Status = CREATED
   ↓
3. POST /apis/{id}/lifecycle with action="Publish"
   ↓
4. APIProviderImpl.changeLifeCycleStatus(api, "PUBLISHED")
   → Validates the transition (CREATED → PUBLISHED is allowed)
   → Updates the Status column in AM_API to PUBLISHED
   → Calls NotificationsPublisher.publishNotification()
   ↓
5. Gateway receives the notification event
   → Extracts the `context` field (e.g., "/petstore/v1")
   → Activates the route so requests to GET /petstore/v1/* are routed to the backend
```

**Critical insight:** The Gateway only learns about the publish via the event. If you bypass the event (e.g., by directly updating the database), the Gateway keeps serving the old route or no route at all.

### The `context` Field — How the Gateway Routes Traffic

The `context` is the URL path prefix that the Gateway uses for routing. For example:

- API: PetStore v1.0
- Context: `/petstore/v1`
- Gateway URL: `GET https://gateway.example.com/petstore/v1/pets`
- Backend URL: `http://backend-service:9000/pets`

The API **name** is for documentation and the Publisher portal UI. The API **context** is what the Gateway cares about. Two APIs can have the same name but different contexts and versions.

### Validation Before Publishing

WSO2 validates several things before allowing `CREATED → PUBLISHED`:

1. **Backend URL is not empty** — the API must have a target.
2. **Context is unique** — no two published APIs can share the same context.
3. **At least one subscription tier is assigned** — (Day 33 covers this in detail).
4. **API definition is syntactically valid** — the OpenAPI/Swagger spec (if provided) must parse.

If any validation fails, `changeLifeCycleStatus()` returns an error and the state stays `CREATED`.

## Exercises

### Exercise 1: Identify the Notification Publisher
**Q:** In `APIProviderImpl.java`, which method fires the notification after a publish?

**Hint:** Search for `NotificationsPublisher` inside `changeLifeCycleStatus`. Look for a method call that takes the API and a notification type as arguments.

**Solution sketch:**
```
changeLifeCycleStatus() calls notificationsPublisher.publishNotification() after updating the DB status row.
The notification includes the API object and the new status, so downstream listeners (like the Gateway)
can receive and react to the change.
```

### Exercise 2: Difference Between `addAPI()` and `changeLifeCycleStatus()`
**Q:** What is the difference between `APIProvider.addAPI()` and `changeLifeCycleStatus()`?

**Hint:** One creates a new API record. One transitions an existing record. Think about what data each one writes to the database.

**Solution sketch:**
```
addAPI() inserts a new row into AM_API with all metadata:
  - ID (generated UUID)
  - Name, Version, Context, Backend URL
  - Status = CREATED
  - Timestamp = now

changeLifeCycleStatus() updates an EXISTING row:
  - Finds the row by API ID
  - Changes only the Status column (e.g., CREATED → PUBLISHED)
  - Updates the Status timestamp
  - Publishes a notification event so listeners know the state changed
```

### Exercise 3: Endpoint Validation
**Q:** WSO2 blocks publishing an API with no backend endpoint. Where is that validation?

**Hint:** Look for a method called `validateAPI()` or similar inside `APIProviderImpl`. It should be called before or during `addAPI()`.

**Solution sketch:**
```
validateAPI() is called inside addAPI() before the row is inserted.
It checks:
  - backendUrl != null && !backendUrl.isEmpty()
  - context != null && !context.isEmpty()
  - name != null && version != null

If any check fails, validateAPI() throws an APIManagementException.
This exception bubbles up to the Publisher API, which returns 400 Bad Request.
```

## Anti-Patterns to Avoid

1. **Calling the Gateway before publishing** — If you send a request to `GET /petstore/v1/...` before the API is PUBLISHED and the event has been fired, the Gateway returns 404. The API exists in the CP database but not in the GW's route table.

2. **Assuming "deployed to GW" = "published"** — WSO2 has a separate "deployment" concept (pushing a revision to a specific Gateway). Publishing is the lifecycle transition. An API can be deployed to the GW in CREATED state, but the GW won't route traffic to it until the CP publishes and fires the event.

3. **Skipping endpoint validation** — If you try to bypass validation and insert an API with `backendUrl = null`, the Gateway will crash when it tries to route a request (or hang indefinitely waiting for the backend). Always validate before insert.

4. **Generating context duplicates** — WSO2 enforces uniqueness on the (context, version) tuple. If you try to create two PUBLISHED APIs with the same context and version, the second one is rejected.

## What You'll Learn by Reading the Source

By tracing `APIProviderImpl.java`, you'll see:
- How state machines are implemented in real systems (the `validTransitions` map concept).
- How database transactions ensure consistency (atomic updates with notifications).
- How asynchronous events decouple the CP from the GW (the GW doesn't poll; it listens).
- Why validation is critical — once data is in the database, it affects production traffic.

## Next Steps

Tomorrow (Day 32), you'll implement the CP API registry in Go, encoding every rule you learned today. You'll build the state machine, the validation logic, and the lifecycle endpoint yourself. By Day 33, you'll add the tier/policy subsystem and see how all the pieces fit together.
