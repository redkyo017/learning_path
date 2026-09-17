# Day 49 — Understanding WSO2 Extension Points

## Why This Matters

WSO2 is designed to be extended at three critical junctures without forking the codebase:

1. **APIHandler** — Intercept and modify every request/response flowing through the API Gateway
2. **OAuthGrantHandler** — Add custom OAuth2 grant types to the Identity Server token endpoint
3. **AbstractMediator** — Add custom routing and transformation logic to the Synapse mediation engine

Your company uses IS as a 3rd-party key manager for your API platform. Without knowing these extension points, you're forced to customize WSO2 via:
- Hard-coding logic in XML config (unmaintainable, not version-controlled)
- Forking and recompiling WSO2 (support nightmare, upgrade hell)
- Running sidecar services and patching requests at the network layer (latency, operational complexity)

Understanding extension points means you can:
- **Extend gracefully:** Add custom grant types, claim transformations, or validation rules by implementing one interface
- **Stay on the upgrade path:** WSO2 releases new versions without requiring custom code merge conflicts
- **Version control your extensions:** Store handler implementations in your company's code repo; deploy alongside WSO2
- **Debug from first principles:** Read the WSO2 source; understand where your extension runs in the request lifecycle

This day is a source-reading lab. You'll locate the interfaces in the WSO2 source and extract the mental model. Days 50–51 build Go blueprints of those same patterns — so you can test ideas without WSO2 running.

---

## Core Concept: The Handler Chain

### The APIHandler Interface

WSO2's API Gateway executes every request through a **handler chain**:

```
Client Request
    ↓
APIHandler 1 (priority 10)
    ↓
APIHandler 2 (priority 20)
    ↓
APIHandler 3 (priority 100)
    ↓
Backend Service
    ↓
APIHandler 3 (response)
    ↓
APIHandler 2 (response)
    ↓
APIHandler 1 (response)
    ↓
Client Response
```

Each handler implements:

```java
interface APIHandler {
    boolean handleRequest(MessageContext msgCtx);
    void handleResponse(MessageContext msgCtx);
    String getName();
}
```

**Semantics:**

- `handleRequest()` receives the request context before it reaches the backend
  - Returns `true` → continue chain to next handler
  - Returns `false` → short-circuit (stop chain, response already written by this handler)
  - Can read/modify headers, set properties for downstream handlers
  - Used for: API key validation, rate limiting, JWT validation, request logging

- `handleResponse()` is called **after** the backend responds, in **reverse chain order**
  - Receives the same `MessageContext` that was passed to `handleRequest`
  - Can read response body, add headers, log metrics
  - Used for: latency tracking, response transformation, cache population

- `getName()` returns a unique identifier (e.g., `APIKeyValidator`, `JWTValidator`)
  - Used for logging, debugging, and config references

### MessageContext

The context object is a map of properties and the request/response objects:

```java
class MessageContext {
    Map<String, Object> properties;  // Handler ↔ handler communication
    HttpRequest request;
    HttpResponse response;
    // ... plus axis2-specific internals
}
```

Each handler can write to `properties` and read from prior handlers:

```java
// Handler 1
msgCtx.setProperty("tier", "Gold");

// Handler 2 (reads tier from Handler 1)
String tier = (String) msgCtx.getProperty("tier");
```

This is how handlers coordinate without coupling to each other.

### Handler Chain Configuration

Handlers are declared in `api-handlers.xml`:

```xml
<api-handlers>
  <handler class="org.wso2.carbon.apimgt.gateway.handlers.APIKeyValidationHandler" priority="100">
    <property name="keyManagerServerUrl">https://is-server:9443</property>
  </handler>
  <handler class="org.wso2.carbon.apimgt.gateway.handlers.JWTValidationHandler" priority="110">
    <property name="issuer">https://is-server/oauth2</property>
  </handler>
  <handler class="com.example.CustomMetricsHandler" priority="200">
    <property name="metricsEndpoint">http://prometheus:9090</property>
  </handler>
</api-handlers>
```

**Loading:**
- WSO2 reads `api-handlers.xml` on startup
- For each handler, it:
  1. Loads the class (must be on classpath, usually in a bundle/jar)
  2. Instantiates once (one handler instance per GW node)
  3. Sorts by priority (ascending)
  4. Builds the chain slice
- That chain instance is reused for every request

**Key implications:**
- Handler instances are **shared** across all requests → must be thread-safe
- Handler initialization happens once, not per-request
- Configuration changes require GW restart

---

## Core Concept: Grant Handler Dispatch

### The OAuthGrantHandler Interface

The Identity Server's token endpoint (`/oauth2/token`) can issue tokens for different OAuth2 grant types. Each grant type has different validation and token generation logic:

```
POST /oauth2/token
  - grant_type=client_credentials     → ClientCredentialsGrantHandler
  - grant_type=password                → PasswordGrantHandler (ROPC)
  - grant_type=authorization_code      → AuthorizationCodeGrantHandler
  - grant_type=urn:custom:my_grant     → Your CustomGrantHandler
```

Each handler implements:

```java
interface OAuthGrantHandler {
    boolean canHandle(String grantType);
    void validateGrant(OAuthTokenReqMessageContext tokReqMsgCtx) throws IdentityOAuth2Exception;
    OAuthAuthzRespDTO issueAccessToken(OAuthTokenReqMessageContext tokReqMsgCtx);
    String getGrantType();
}
```

**Semantics:**

- `canHandle(grantType)` returns `true` if this handler processes that grant type
  - Token endpoint calls this on each handler in order; first match wins
  - Multiple handlers can support the same grant (but only first is used)

- `validateGrant(tokReqMsgCtx)` validates the request
  - Throws `IdentityOAuth2Exception` on failure (e.g., invalid credentials, missing scope)
  - Has access to: client ID/secret, username, password, scope, custom parameters

- `issueAccessToken()` mints and returns the token
  - Receives the validated context
  - Returns a DTO with: `access_token`, `token_type`, `expires_in`, `scope`

- `getGrantType()` returns the grant type string (e.g., `client_credentials`)

### Dispatch Pattern

```
1. Client POST /oauth2/token with grant_type=urn:custom:device_code

2. TokenEndpoint iterates registered handlers:
   for (OAuthGrantHandler h : handlers) {
       if (!h.canHandle("urn:custom:device_code")) continue;
       h.validateGrant(reqCtx);      // Throws exception on failure
       return h.issueAccessToken();   // Returns token DTO
   }

3. If no handler canHandle() the grant type → 400 unsupported_grant_type

4. If validateGrant() throws → 401 or 400 (depending on error code)

5. If issueAccessToken() succeeds → 200 with token JSON
```

### Grant Type Registration

Custom grant handlers are registered in `identity.xml`:

```xml
<OAuth>
  <SupportedGrantTypes>
    <SupportedGrantType>
      <GrantTypeHandler>org.wso2.carbon.identity.oauth2.grant.clientcredentials.ClientCredentialsGrantHandler</GrantTypeHandler>
      <GrantType>client_credentials</GrantType>
      <ValidAfter>0</ValidAfter>
    </SupportedGrantType>
    <SupportedGrantType>
      <GrantTypeHandler>com.mycompany.CustomDeviceCodeGrantHandler</GrantTypeHandler>
      <GrantType>urn:ietf:params:oauth:grant-type:device_code</GrantType>
      <ValidAfter>0</ValidAfter>
    </SupportedGrantType>
  </SupportedGrantTypes>
</OAuth>
```

---

## Comparison to Your Go Blueprints

Days 50 and 51 implement the same patterns in Go:

| Concept | WSO2 (Java) | Go Blueprint (Day 50/51) |
|---------|-------------|--------------------------|
| **Request interception** | `APIHandler.handleRequest()` returns `boolean` | `APIHandler.HandleRequest(ctx)` returns `bool` |
| **Short-circuiting** | `return false` stops chain | `return false` stops chain |
| **Context sharing** | `MessageContext.properties` map | `MessageContext.Properties` map |
| **Response processing** | `handleResponse()` in reverse order | `HandleResponse()` in reverse order |
| **Grant dispatch** | `canHandle()` iterates handlers | `CanHandle()` iterates handlers |
| **First match wins** | Yes, loop breaks after first match | Yes, loop returns after first match |
| **Thread-safety** | Handler instances shared → must synchronize | HTTP request goroutines shared → use sync.Mutex if needed |

The Go versions are **standalone labs**, not integration with WSO2. They let you:
- Understand the pattern without WSO2's OSGi/Axis2 complexity
- Experiment with extending the chain
- Test error handling and edge cases
- Deploy to the cloud easily (Go binary vs. Java app server)

---

## Anti-Patterns to Avoid

### 1. Throwing Unchecked Exceptions from Handlers

**Wrong:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    String key = msgCtx.getRequest().getHeader("X-API-Key");
    if (key == null) {
        throw new RuntimeException("API key required");  // Crash!
    }
    return true;
}
```

**Problem:** The exception escapes the handler chain. The entire Gateway thread crashes. Client gets 500 Internal Server Error with no proper error body.

**Right:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    String key = msgCtx.getRequest().getHeader("X-API-Key");
    if (key == null) {
        Utils.setFaultPayload(msgCtx, buildErrorResponse("API key required"));
        return false;  // Stop chain, error response already set
    }
    return true;
}
```

### 2. Modifying Shared State Without Synchronization

**Wrong (in WSO2, where handler is shared):**

```java
public class MyHandler implements APIHandler {
    private int requestCount = 0;  // Shared across all requests!
    
    public boolean handleRequest(MessageContext msgCtx) {
        requestCount++;  // Race condition — multiple threads access this
        return true;
    }
}
```

**Problem:** Multiple request threads access `requestCount` concurrently. Counter gets corrupted.

**Right:**

```java
public class MyHandler implements APIHandler {
    private final AtomicInteger requestCount = new AtomicInteger(0);
    
    public boolean handleRequest(MessageContext msgCtx) {
        requestCount.incrementAndGet();  // Thread-safe
        return true;
    }
}
```

Or use `synchronized`, locks, or move state to thread-local storage.

### 3. Forgetting to Return `true` in Handler Chain

**Wrong:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    logger.info("Request received");
    // No return statement — implicitly returns null → crash!
}
```

**Problem:** Returning `null` instead of `boolean` causes NPE.

**Right:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    logger.info("Request received");
    return true;  // Explicitly continue chain
}
```

### 4. Writing Response in HandleRequest But Modifying in HandleResponse

**Wrong:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    msgCtx.getResponse().addHeader("X-Rate-Limit", "100");
    msgCtx.getResponse().setStatus(429);
    return false;  // Stop chain, response sent
}

public void handleResponse(MessageContext msgCtx) {
    msgCtx.getResponse().setStatus(200);  // Too late! Response already sent
}
```

**Problem:** In `handleResponse`, the response is already written to the client. Modifying it has no effect.

**Right:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    // ... validation ...
    if (rateLimited) {
        msgCtx.getResponse().addHeader("X-Rate-Limit", "100");
        msgCtx.getResponse().setStatus(429);
        return false;  // Response sent here
    }
    return true;
}

public void handleResponse(MessageContext msgCtx) {
    // Log metrics, set cache headers, etc. — modify response BEFORE client sees it
    long elapsed = (long) msgCtx.getProperty("requestTime");
    msgCtx.getResponse().addHeader("X-Response-Time", elapsed + "ms");
}
```

---

## Exercises

### Exercise 1: APIHandler Priority

**Question:**
Where is the `priority` of WSO2's built-in `APIKeyValidationHandler` set? How would you lower the priority to make it run first in the chain?

**Hint:**
Look at `api-handlers.xml` in the Gateway checkout. The priority is an XML attribute on the `<handler>` element.

**Solution sketch:**

1. Find the config:
   ```bash
   find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "api-handlers.xml" | head -1
   cat <path> | grep -A2 "APIKeyValidationHandler"
   ```

2. Look for the `<handler>` element:
   ```xml
   <handler class="...APIKeyValidationHandler" priority="100">
       ...
   </handler>
   ```

3. To make it run first, lower the priority value:
   ```xml
   <handler class="...APIKeyValidationHandler" priority="1">  <!-- Lower = earlier -->
       ...
   </handler>
   ```

4. Restart the Gateway for changes to take effect.

**Why:** This would make API key validation happen before JWT validation, which might be desired if API key is your preferred method.

---

### Exercise 2: Short-Circuiting a Request

**Question:**
How does an `APIHandler` return a 403 Forbidden response and stop the chain?

**Hint:**
You need to:
1. Set the response status code (403)
2. Write the response body (error JSON)
3. Return `false` to stop the chain

Look at how `Utils` is used in other handlers to set error responses.

**Solution sketch:**

```java
public boolean handleRequest(MessageContext msgCtx) {
    if (!isAuthorized(msgCtx)) {
        // Set HTTP status
        Axis2MessageContext ax2MsgCtx = (Axis2MessageContext) msgCtx;
        ax2MsgCtx.getAxis2MessageContext().setProperty(
            SynapseConstants.HTTP_SC, 403
        );
        
        // Set response body
        OMFactory omFactory = OMAbstractFactory.getOMFactory();
        OMElement errorPayload = omFactory.createOMElement("error", null);
        errorPayload.setText("Forbidden");
        
        msgCtx.setEnvelope(
            MessageUtils.cloneSOAPEnvelope(msgCtx.getEnvelope())
        );
        msgCtx.getEnvelope().getBody().addChild(errorPayload);
        
        return false;  // Stop chain, response written
    }
    return true;
}
```

Modern WSO2 provides `Utils.setFaultPayload()` helper:

```java
public boolean handleRequest(MessageContext msgCtx) {
    if (!isAuthorized(msgCtx)) {
        Utils.setFaultPayload(msgCtx, createErrorResponse("Forbidden", 403));
        return false;
    }
    return true;
}
```

**Key:** Once you `return false`, no further handlers run and the response is sent to the client.

---

### Exercise 3: Understanding Grant Handler Inheritance

**Question:**
A custom `OAuthGrantHandler` must call `super.validateGrant(tokReqMsgCtx)` before doing custom validation. What does the super method check?

**Hint:**
Look at `AbstractAuthorizationGrantHandler.validateGrant()` in the IS source. Search for the grant type validation, client lookup, and scope checks.

**Solution sketch:**

The super method validates:

1. **Grant type string matches:** The incoming `grant_type` parameter matches what this handler claims to support (`super.getGrantType()`)
2. **Client exists and is active:** Looks up the client by `client_id`, checks it's not disabled/revoked
3. **Client credentials are valid:** For grant types that use `client_secret` (not all do), validates it matches
4. **Scopes are authorized:** For the requested scopes, checks the client is authorized to request them

Example:

```java
public void validateGrant(OAuthTokenReqMessageContext tokReqMsgCtx) 
        throws IdentityOAuth2Exception {
    
    // SUPER method does:
    super.validateGrant(tokReqMsgCtx);  // Checks 1-4 above
    
    // CUSTOM method does:
    // ... additional custom validation, e.g., check IP whitelist, MFA status, etc.
}
```

**Why it matters:** Skipping `super.validateGrant()` bypasses all standard OAuth2 checks. Your custom handler could issue tokens to revoked clients or for unauthorized scopes, creating a security hole.

---

## Next Steps

1. **Today (Day 49):** Complete the source-reading lab in `labs/phase4/day49/`
   - Find the two interfaces in WSO2 source
   - Answer the comprehension questions
   - Compare to Go blueprints

2. **Tomorrow (Day 50):** Implement the Go APIHandler chain in `labs/phase4/day50/`
   - Run the handler chain locally
   - Test short-circuiting
   - Implement RateLimitHandler

3. **Day 51:** Implement the Go OAuthGrantHandler dispatch in `labs/phase4/day51/`
   - Run the token endpoint
   - Test all three grant types
   - Implement JWTBearerGrant

4. **Day 52+:** Capstone project (Task 5 of Phase 4)
   - Design a custom handler for your platform's specific needs
   - Integrate it with WSO2 (on a test instance)
   - Write the extension in Go, then translate to Java for WSO2 deployment
