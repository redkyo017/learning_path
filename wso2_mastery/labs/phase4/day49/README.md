# Day 49 — Source Reading Lab

## Goal
Locate the WSO2 APIHandler and OAuthGrantHandler interfaces in the source code. Understand their methods, signatures, and how they're loaded and dispatched by WSO2.

## Preparation
Make sure you have the WSO2 source trees checked out at:
- `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0` (API Manager Gateway)
- `/Users/hunghan/Downloads/wso2is-7.3.0` (Identity Server)

If not, see the WSO2 Phase 4 setup instructions.

---

## Step 1: Find the APIHandler Interface

**Grep for APIHandler.java in the Gateway source:**

```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "APIHandler.java" 2>/dev/null | head -3
```

Expected output (path may vary):
```
/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0/...apimgt-gateway.../org/wso2/carbon/apimgt/gateway/handlers/APIHandler.java
```

**View the interface:**

```bash
grep -n "handleRequest\|handleResponse\|getName\|priority" <path-from-above> | head -20
```

This shows the method signatures and any priority-related code.

**Questions to answer:**

1. What is the return type of `handleRequest()`? What does `false` mean?
2. Are `handleRequest` and `handleResponse` called for all APIs, or only for specific ones?
3. Does the interface have a `getName()` method? Why?

**Expected findings:**

```
APIHandler.java:
  - handleRequest(MessageContext msgCtx): boolean
    Returns `true` to continue the chain, `false` to short-circuit
  - handleResponse(MessageContext msgCtx): void
    Called after backend responds (in reverse order)
  - getName(): String
    Returns the handler name for logging and config
```

---

## Step 2: Find api-handlers.xml Configuration

**Grep for api-handlers.xml in the Gateway distribution:**

```bash
find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "api-handlers.xml" | head -3
```

Expected output:
```
/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0/.../conf/api-handlers.xml
```

**View the configuration file:**

```bash
cat <path-from-above> | head -40
```

**Questions to answer:**

1. How are handlers registered? (Find a `<handler>` element)
2. What is the `priority` attribute? (Lower number = earlier in chain)
3. Where is APIKeyValidationHandler defined, and what is its priority?
4. Can you add a new handler without modifying the source code?

**Expected findings:**

```xml
<api-handlers>
  <handler class="org.wso2.carbon.apimgt.gateway.handlers.APIKeyValidationHandler" priority="100">
    <property name="keyManagerServerUrl">https://...</property>
  </handler>
  <handler class="org.wso2.carbon.apimgt.gateway.handlers.SomeOtherHandler" priority="200">
    ...
  </handler>
</api-handlers>
```

**Key insight:**
- Handlers are loaded from OSGi bundles (classes on the classpath)
- Priority determines chain order: lower priority = earlier
- Handler chain is built at startup and reused for every request
- Sharing handler instances across requests means handlers must be thread-safe

---

## Step 3: Find the OAuthGrantHandler Interface

**Grep for AbstractAuthorizationGrantHandler.java in the Identity Server:**

```bash
find /Users/hunghan/Downloads/wso2is-7.3.0 -name "AbstractAuthorizationGrantHandler.java" 2>/dev/null | head -3
```

Expected output:
```
/Users/hunghan/Downloads/wso2is-7.3.0/...oauth2-token-validation.../org/wso2/carbon/identity/oauth2/grant/AbstractAuthorizationGrantHandler.java
```

**View the grant handler interface/class:**

```bash
grep -n "validateGrant\|issueAccessToken\|canHandleGrant\|GrantType" <path-from-above> | head -20
```

**Questions to answer:**

1. What method name is used instead of `CanHandle`? (hint: it's in the class name or a method starting with `can`)
2. What exception is thrown on validation failure?
3. What does `issueAccessToken()` return?

**Expected findings:**

```
AbstractAuthorizationGrantHandler.java:
  - canHandle(String grantType): boolean
    Returns `true` if this handler processes the grant type
  - validateGrant(OAuthTokenReqMessageContext tokReqMsgCtx): void
    Throws IdentityOAuth2Exception on validation failure
  - issueAccessToken(OAuthTokenReqMessageContext tokReqMsgCtx): OAuthAuthzRespDTO
    Mints and returns the access token
```

**Key insight:**
- The grant type string (e.g., `client_credentials`, `password`) routes to the handler
- Validation happens before token issuance
- WSO2 stores grant handlers in a registry indexed by grant type
- The token endpoint dispatches to the first matching handler (like the Go version)

---

## Step 4: Compare Patterns

**In your "why" log, answer:**

1. **Handler chain model:**
   - In WSO2 APIHandler, how does short-circuiting work? What method returns `false`?
   - In Go (Day 50), how do we implement the same pattern?

2. **Configuration vs. Code:**
   - In WSO2, handler order is configured in `api-handlers.xml` (priority attribute)
   - In Go (Day 50), handler order is configured in code (`chain.Add()`)
   - Which is more flexible? Which is more discoverable?

3. **Grant type dispatch:**
   - In WSO2, how many grant type handlers can handle the same `grant_type`?
   - In Go (Day 51), what happens if two handlers both return `true` from `CanHandle()`?

4. **Concurrency:**
   - WSO2 APIHandler instances are shared across all requests on a GW node
   - In Go (Day 50), the handler chain is shared across all requests (via `http.ListenAndServe`)
   - What does "shared" mean for handler state? Must we use locks?

5. **Error handling:**
   - In WSO2, an APIHandler can throw an exception. What happens?
   - In Go (Day 50), an APIHandler returns `false` and writes the response itself
   - Which model is cleaner? Why?

---

## Notes for Exploration

- **File sizes:** Source files are often 200-500 lines; focus on method signatures and comments
- **Package names:** Gateway handlers are in `org.wso2.carbon.apimgt.gateway.handlers.*`; grant handlers are in `org.wso2.carbon.identity.oauth2.grant.*`
- **Built-in handlers:** Look for `APIKeyValidationHandler`, `JWTValidationHandler`, and `TransportHeaderHandler` in the Gateway
- **Built-in grant handlers:** Look for `ClientCredentialsGrantHandler`, `PasswordGrantHandler`, and `AuthorizationCodeGrantHandler` in IS
