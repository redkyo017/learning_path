# Day 16: Synapse Mediation Engine — WSO2's Handler Chain

## Why

Every API request hitting WSO2 API Manager passes through a sequence of handlers before it
reaches the backend. Understanding this sequence tells you exactly where auth failures,
throttle rejections, and analytics records originate — knowledge you need when debugging
production issues or building a Go gateway that behaves the same way.

---

## WSO2 Source Reading

Three files explain the handler model:

| File | Package | What it tells you |
|------|---------|-------------------|
| `org.apache.synapse.MessageContext` (interface) | `synapse-core` | The envelope that carries a message through the chain — properties, headers, axis2 context |
| `org.apache.synapse.mediators.AbstractMediator` | `synapse-core` | Base class for every mediator; defines `mediate(MessageContext ctx)` which each handler overrides |
| `org.wso2.carbon.apimgt.gateway.handlers.security.APIAuthenticationHandler` | `universal-gw` | The first handler in the GW chain; calls `super.handleRequest()` and can short-circuit by sending a 401 fault |

Clone or browse the source:

```
https://github.com/wso2/wso2-synapse          (SynapseMessageContext, AbstractMediator)
https://github.com/wso2/carbon-apimgt         (APIAuthenticationHandler)
```

Key method in `APIAuthenticationHandler`:

```java
@Override
public boolean handleRequest(MessageContext messageContext) {
    // ... validates the token via key manager
    // On failure: Util.sendFault(messageContext, HttpStatus.SC_UNAUTHORIZED, ...);
    //             return false;   ← short-circuits the chain
    return true;  // passes to next handler
}
```

Returning `false` from `handleRequest` stops the chain. The framework (`SynapseMessageContext`
dispatches handlers in order and stops at the first `false`).

---

## Core Concepts

### What Synapse Is

Apache Synapse is WSO2's mediation engine. It is **not** a plain HTTP reverse proxy. Instead
of forwarding raw HTTP bytes, it:

1. Parses the message into a `MessageContext` object (headers, body, properties, axis2 envelope).
2. Passes that context through a sequence of **mediators** (handlers).
3. Constructs the outbound call to the backend from the mutated context.

This model lets WSO2 mutate, validate, transform, or reject a message at any stage without
touching the transport layer directly.

### Handler Chain Order

In `wso2am-universal-gw-4.7.0` the in-flow handler sequence is:

```
Request arrives
      │
      ▼
APIAuthenticationHandler   ← validates JWT / API key; 401 on failure
      │
      ▼
ThrottleHandler            ← rate-limit check; 429 on quota exceeded
      │
      ▼
AnalyticsHandler           ← records the event to the analytics stream
      │
      ▼
Backend call via Axis2 transport
```

Each handler can either:
- Return `false` (and send an HTTP fault) → chain stops, no backend call.
- Return `true` → next handler runs.

### Why WSO2 Uses a Handler Chain Rather Than Middleware

In a Node.js or Go codebase you bolt middleware together with function composition.
WSO2 cannot do that because each handler lives in a **separate OSGi bundle**. OSGi is
Java's module system: each bundle has its own classloader and lifecycle (install, start, stop,
uninstall). The API Manager composes the chain at runtime by reading handler configuration
from `api-manager.xml`; bundles can be swapped or disabled without recompiling the whole
server. This is why the chain is data-driven and handler classes implement an interface rather
than being closures nested around each other.

### Go Equivalent: `http.Handler`

Go's standard library uses a single interface:

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}
```

A **middleware** is a function that wraps one `Handler` with another:

```go
type Middleware func(http.Handler) http.Handler
```

This is functionally equivalent to WSO2's handler chain: each middleware can short-circuit
(write a response and return, never calling `next.ServeHTTP`) or pass control forward.

The Go equivalent of `MessageContext` is `*http.Request` combined with `context.Context`
(stored in `r.Context()`). You attach per-request values — correlation IDs, authenticated
subject, throttle quota — with `context.WithValue` and read them downstream with
`r.Context().Value(key)`.

---

## Lab

See `labs/phase2/day16/` — source-reading exercise (no code to write).

Walk the WSO2 source to answer three questions about where 401 and 429 originate.

---

## Exercises

**Exercise 1:** In the WSO2 source, which class and method sends the HTTP 401 when token
validation fails?

**Hint:** Look at `APIAuthenticationHandler.handleRequest`. Find the branch that calls
`Util.sendFault` and returns `false`.

**Solution sketch:** `APIAuthenticationHandler.handleRequest` — when the authenticator
throws `APISecurityException` with code `API_AUTH_INVALID_CREDENTIALS`, it calls
`sendFault(messageContext, 401, ...)` and returns `false`, stopping the chain.

---

**Exercise 2:** What is the Go equivalent of WSO2's `MessageContext` and how do you pass
per-request data through a middleware chain?

**Hint:** `*http.Request` carries headers and body; `context.Context` (via `r.Context()`)
carries typed values.

**Solution sketch:** Use `context.WithValue(r.Context(), myKey, myValue)` to attach data,
then propagate with `r = r.WithContext(newCtx)`. Downstream middleware or the handler reads
it with `r.Context().Value(myKey)`. This is the idiomatic replacement for WSO2's
`messageContext.setProperty("key", value)`.

---

**Exercise 3:** Draw (as text) the handler chain for a valid API call in WSO2, then write
the equivalent Go middleware chain call using `Chain(proxy, m1, m2, m3)` where m1=auth,
m2=throttle, m3=analytics.

**Hint:** Auth runs first, then throttle, then analytics, then the backend. In Go, `Chain`
applies right-to-left so the first argument to `Chain` runs outermost.

**Solution sketch:**

WSO2 chain (in-flow):
```
APIAuthenticationHandler → ThrottleHandler → AnalyticsHandler → backend
```

Go equivalent:
```go
// Chain(h, m1, m2, m3) = m1(m2(m3(h)))
// m1 runs first (outermost), m3 runs last (closest to proxy)
handler := Chain(proxy, authMiddleware, throttleMiddleware, analyticsMiddleware)
```

---

## Anti-patterns

- **Skipping the auth handler in testing** — If you bypass `APIAuthenticationHandler` in a
  dev environment by setting a passthrough policy, remember to re-enable it before staging.
  Leaving the gateway handler chain incomplete is a common misconfiguration.

- **Mutating `MessageContext` properties across threads** — `MessageContext` is not
  thread-safe. In Go, never share a `*http.Request` pointer between goroutines; always clone
  with `r.Clone(ctx)` before handing off.

- **Treating handler order as implicit** — WSO2 reads handler order from XML configuration.
  In Go, the order of arguments to `Chain` is your configuration. Document it explicitly.

---

## Teardown

This day has no running processes. Close any browser tabs used for source browsing.
