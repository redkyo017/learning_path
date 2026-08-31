# Lab Day 16: WSO2 Source Walk — Handler Chain

**No code to write. This is a guided source-reading exercise.**

Goal: find where in the WSO2 codebase the gateway sends a 401 (auth failure) and a 429
(throttle exceeded), and understand how each handler decides to short-circuit or continue.

---

## Setup

Clone (or browse on GitHub) the `carbon-apimgt` repository:

```bash
# Option A — clone (large; only if you have the bandwidth)
git clone --depth=1 https://github.com/wso2/carbon-apimgt.git

# Option B — browse on GitHub without cloning
# https://github.com/wso2/carbon-apimgt
```

The gateway handler classes live under:

```
components/apimgt/org.wso2.carbon.apimgt.gateway/
  src/main/java/org/wso2/carbon/apimgt/gateway/handlers/
```

---

## Task 1 — Find `APIAuthenticationHandler`

Navigate to:

```
handlers/security/APIAuthenticationHandler.java
```

1. Open the file and find the `handleRequest(MessageContext messageContext)` method.
2. Identify the `try/catch` block that catches `APISecurityException`.
3. Find the line that calls `sendFault` or `handleAuthFailure` and returns `false`.

**Question A:** What HTTP status code does this path return? Where in the code is that
status set?

---

## Task 2 — Find `ThrottleHandler`

Navigate to:

```
handlers/throttling/ThrottleHandler.java
```

1. Find the `handleRequest` method.
2. Identify the condition that triggers throttling (quota exceeded, spike arrest, etc.).
3. Find where it returns `false` after sending a fault.

**Question B:** What HTTP status code does the throttle path return?

---

## Task 3 — Trace the Chain

Look at the handler registration. In `wso2am-universal-gw-4.7.0` (or in the test XML files),
find an `<Handlers>` block in a synapse configuration that lists handlers in order.

Example pattern (from the codebase or documentation):

```xml
<Handlers>
    <Handler class="org.wso2.carbon.apimgt.gateway.handlers.security.APIAuthenticationHandler"/>
    <Handler class="org.wso2.carbon.apimgt.gateway.handlers.throttling.ThrottleHandler"/>
    <Handler class="org.wso2.carbon.apimgt.gateway.handlers.analytics.APIMgtUsageHandler"/>
</Handlers>
```

**Question C:** Which handler runs first? Which runs last before the backend call?

---

## Deliverable

Answer Questions A, B, and C. Compare your answers with `SOLUTION.md`.

---

## Teardown

Nothing to stop. Close your browser tabs or terminal.
