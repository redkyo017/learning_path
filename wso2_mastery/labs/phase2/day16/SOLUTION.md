# Solution — Lab Day 16

## Question A: Which class/method sends HTTP 401?

**Class:** `APIAuthenticationHandler`
**Method:** `handleRequest(MessageContext messageContext)`

When token validation fails, the handler catches `APISecurityException`. Inside the catch
block it calls a fault-sending utility (varies slightly by version — look for
`sendFault`, `handleAuthFailure`, or `Util.sendFault`). The HTTP status is set to `401`.
The method then returns `false`, which stops the handler chain — no throttle check, no
analytics event, no backend call.

Relevant excerpt (simplified; actual line numbers vary by tag):

```java
} catch (APISecurityException e) {
    if (log.isDebugEnabled()) { ... }
    // Sets HTTP 401 on the Axis2 message context
    Util.sendFault(messageContext, e.getErrorCode());
    return false;  // ← chain stops here
}
```

`APISecurityConstants.API_AUTH_INVALID_CREDENTIALS` is one of the error codes that maps
to status 401 in the fault-sending utility.

---

## Question B: Which class/method sends HTTP 429?

**Class:** `ThrottleHandler`
**Method:** `handleRequest(MessageContext messageContext)`

When a request exceeds a throttle policy (subscription throttle, application throttle, or
spike arrest), `ThrottleHandler` calls its fault-sending path with HTTP status `429`
(Too Many Requests). It returns `false`, stopping the chain.

Look for a block like:

```java
if (isThrottled) {
    Util.sendFault(messageContext, 429, "Message throttled out");
    return false;
}
```

---

## Question C: Handler order

From the `<Handlers>` XML configuration the order is:

1. `APIAuthenticationHandler` — first; validates the token
2. `ThrottleHandler` — second; checks rate limits
3. `APIMgtUsageHandler` (analytics) — third; records the event
4. Backend call — last (performed by the Axis2 transport layer)

A request that fails auth never reaches throttle check or analytics. A request that passes
auth but is throttled never reaches analytics or the backend. Only a fully valid, in-quota
request reaches the backend and gets recorded in analytics.

This ordering is intentional: cheap security check first (fail fast), then quota check, then
the (relatively expensive) analytics write.
