# Day 32 — Lab: Building the CP API Registry

## Goal

Build a working API registry that implements the WSO2 API lifecycle state machine. This is a standalone HTTP server that handles all CRUD operations and lifecycle transitions.

## Prerequisites

- Go 1.19 or later
- `curl` (for testing)

## Running the Lab

### Step 1: Start the Server

Navigate to this directory and run:

```bash
go run main.go
```

You should see:
```
WSO2 CP — API Registry listening on :8082
```

The server is now listening on `http://localhost:8082`.

### Step 2: Test the Endpoints

Open a new terminal and run these commands:

#### Test 1: Health Check

```bash
curl -s http://localhost:8082/health | jq .
```

**Expected output:**
```json
{"status":"UP"}
```

#### Test 2: Create an API

```bash
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"PetStore",
    "context":"/petstore/v1",
    "version":"1.0",
    "backendUrl":"http://backend:9000",
    "allowedTiers":["Gold","Silver"]
  }' | jq .
```

**Expected output:**
```json
{
  "id":"3f8c2a1b",
  "name":"PetStore",
  "context":"/petstore/v1",
  "version":"1.0",
  "backendUrl":"http://backend:9000",
  "status":"CREATED",
  "allowedTiers":["Gold","Silver"],
  "createdAt":"2026-09-16T10:30:00Z"
}
```

**Copy the `id` value** — you'll need it for the next steps. Let's call it `{id}`.

#### Test 3: List All APIs

```bash
curl -s http://localhost:8082/apis | jq .
```

**Expected output:**
```json
[
  {
    "id":"3f8c2a1b",
    "name":"PetStore",
    ...
  }
]
```

#### Test 4: Get a Specific API

```bash
curl -s http://localhost:8082/apis/{id} | jq .
```

Replace `{id}` with the actual ID from Test 2.

#### Test 5: Publish the API

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}' | jq .
```

**Expected output:**
```json
{
  "id":"3f8c2a1b",
  ...
  "status":"PUBLISHED",
  ...
}
```

Notice the status changed from `CREATED` to `PUBLISHED`.

#### Test 6: Try an Invalid Transition

Try to go from PUBLISHED back to CREATED (this should fail):

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}' | jq .
```

**Expected output (error):**
```json
{"error":"invalid transition: PUBLISHED → PUBLISHED"}
```

The status code should be `400 Bad Request`.

#### Test 7: Deprecate the API

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Deprecate"}' | jq .
```

**Expected output:**
```json
{
  "id":"3f8c2a1b",
  ...
  "status":"DEPRECATED",
  ...
}
```

#### Test 8: Retire the API

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Retire"}' | jq .
```

**Expected output:**
```json
{
  "id":"3f8c2a1b",
  ...
  "status":"RETIRED",
  ...
}
```

#### Test 9: Try to Publish Without Tiers

Create a new API with no allowed tiers and try to publish:

```bash
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"BadAPI",
    "context":"/bad/v1",
    "version":"1.0",
    "backendUrl":"http://backend:9000",
    "allowedTiers":[]
  }' | jq .
```

Copy the `id` from the response, then try to publish:

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}' | jq .
```

**Expected output (error):**
```json
{"error":"cannot publish API with no allowed tiers"}
```

Status code: `400 Bad Request`.

#### Test 10: Delete an API

```bash
curl -s -X DELETE http://localhost:8082/apis/{id}
```

**Expected output:** No body, status code `204 No Content`.

Verify it's deleted:

```bash
curl -s http://localhost:8082/apis/{id}
```

**Expected output (error):** `not found`, status code `404`.

## Exercises (Answer in a File Called `answers.md`)

### Exercise 1: Partial Update
**Q:** Add a `PUT /apis/{id}` endpoint that updates the Name and BackendURL fields but not Status or Context. Test it with a curl request.

**Hint:** Add a new method to the Registry type. Inside the mux handler, detect `PUT` method on `/apis/` paths with no sub-resource.

**Solution sketch:**
See `SOLUTION.md` for a complete implementation.

### Exercise 2: HTTP Status for Invalid Transitions
**Q:** What HTTP status code does the registry return when you try an invalid transition (like PUBLISHED → CREATED)? Why is that code appropriate?

**Hint:** Run Test 6 above. Look at the `transitionLifecycle` function in `main.go`.

**Solution sketch:**
```
The registry returns 400 Bad Request.

This is appropriate because:
  - It's not a server error (500) — the server is working correctly
  - It's not a "not found" error (404) — the API exists
  - It's a client error: the client is asking for an invalid operation
  
The HTTP spec defines 400 for "The request could not be understood by
the server due to malformed syntax or violates business rules."
```

### Exercise 3: Concurrency and Mutexes
**Q:** In the `transitionLifecycle` method, why is the `defer r.mu.Unlock()` placed inside the method but the lock is acquired at the start? What would happen if a panic occurred during the state transition?

**Hint:** Try adding a `panic()` statement inside `transitionLifecycle` and run the test. What happens?

**Solution sketch:**
```
The defer statement ensures that Unlock() is called even if the
handler panics or returns early.

If we did NOT use defer and a panic occurred:
  1. The lock would stay held
  2. All other goroutines (HTTP handlers) would block forever
  3. The server would become unresponsive

By using defer, we guarantee that the lock is released no matter what.
This is a common Go pattern for resource cleanup.
```

## What You Learned

- How to implement a state machine in Go with a `validTransitions` map
- How to use `sync.RWMutex` for safe concurrent access to shared data
- How to parse JSON request bodies and write JSON responses
- How to route HTTP requests based on method and path
- Why business rule validation is critical in production systems
- The importance of proper error handling and status codes

## Next Steps

Tomorrow (Day 33), you'll extend this registry with tier and policy management. You'll add endpoints to query and update the subscription tiers allowed for each API, and you'll learn why you can't change tiers while an API is PUBLISHED.
