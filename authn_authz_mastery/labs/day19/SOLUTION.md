# Day 19 Lab — SOLUTION

## Method-by-method explanations

### `canHandle(HttpServletRequest request)`

**Purpose:** determines whether this authenticator should handle the current incoming request.

IS 7.3 calls `canHandle()` on every registered authenticator in priority order for every authentication
request. The first authenticator that returns `true` gets routed to `processAuthenticationResponse()`.
If no authenticator returns `true`, IS 7.3 calls `initiateAuthenticationRequest()` on the authenticator
configured for the current step.

Precision is critical because: a `canHandle()` that returns `true` unconditionally intercepts every
request — including TOTP callbacks, FIDO2 assertion responses, and basic auth submissions — and routes
them all to `processAuthenticationResponse()`, which is designed only for biometric callbacks. Every
other authenticator's callbacks fail. A `canHandle()` that always returns `false` means
`processAuthenticationResponse()` is never called for this authenticator — the biometric callback goes
unhandled, the authentication step never completes.

The correct implementation: return `true` only for a request parameter that uniquely identifies a
callback from this authenticator — something no other authenticator would set (e.g., `biometric_token`
in this skeleton).

### `initiateAuthenticationRequest(request, response, context)`

**Purpose:** starts the authentication step by redirecting the user to the biometric vendor page.

IS 7.3 calls this when the authentication step for `BiometricAuthenticator` is reached and no existing
callback is present (i.e., `canHandle()` returned `false`). It builds the vendor redirect URL using
`context.getContextIdentifier()` as a state parameter and sends an HTTP redirect. After this call,
IS 7.3 suspends the authentication session until the vendor page calls back.

### `processAuthenticationResponse(request, response, context)`

**Purpose:** completes the authentication step by validating the vendor token and identifying the user.

IS 7.3 calls this when `canHandle()` returns `true` — the biometric vendor page has redirected back
with `biometric_token` in the request. This method reads the token, calls the vendor API to validate
it (with timeout + circuit-breaker), resolves the user identity, and calls `context.setSubject()` on
success or throws `AuthenticationFailedException` on failure. IS 7.3 uses the return state to
decide whether to advance to the next step or fail the flow.

### `getName()`

**Purpose:** returns the stable internal identifier for this authenticator.

IS 7.3 uses this string as the key for per-application configuration, audit log entries, and the flow
builder configuration file. It must be unique across all registered authenticators and must not change
once deployed — changing it breaks stored application configurations that reference the old name.

### `getFriendlyName()`

**Purpose:** returns the human-readable display name shown in IS 7.3 Console.

This appears in the Console flow builder under "Add Authenticator" — it is what the admin sees and
selects. Unlike `getName()`, it can be changed between versions without breaking stored configurations.

## Routing question: multiple registered authenticators

When both `BiometricAuthenticator` and a `TOTPAuthenticator` are registered, IS 7.3 routes as follows:

1. An authentication request arrives (e.g., the biometric vendor callback with `biometric_token=...`)
2. IS 7.3 iterates over registered authenticators in priority order
3. `BiometricAuthenticator.canHandle()` — checks `request.getParameter("biometric_token") != null` → `true`
4. IS 7.3 routes to `BiometricAuthenticator.processAuthenticationResponse()` — evaluation stops
5. `TOTPAuthenticator.canHandle()` is not called for this request

For a TOTP callback (request has `totp_token` param, not `biometric_token`):
1. `BiometricAuthenticator.canHandle()` → `false` (biometric_token absent)
2. `TOTPAuthenticator.canHandle()` → `true` (totp_token present)
3. IS 7.3 routes to `TOTPAuthenticator.processAuthenticationResponse()`

This is why each `canHandle()` must check for a parameter unique to that authenticator.

## Test answer

To verify the authenticator before production deployment:
1. **Deploy to a dev/staging IS 7.3 instance** — never test custom bundles on production IS 7.3 first.
   A broken `canHandle()` that returns `true` unconditionally will break all authentication for all users.
2. **Use IS 7.3 DEBUG logging** — enable `org.wso2.carbon.identity.application.authentication.framework`
   at DEBUG level; IS 7.3 logs which authenticator's `canHandle()` was called and what it returned.
3. **Test `canHandle()` independently**: write a JUnit test that passes a mock `HttpServletRequest`
   with and without `biometric_token` set, and verify the return value.
4. **Mock the vendor API** in `processAuthenticationResponse()` tests — don't call the real vendor
   in tests; use a test double that returns success/failure on demand to verify both paths.
5. **Test timeout behaviour**: use a slow mock vendor that delays 3+ seconds and verify the authenticator
   throws `AuthenticationFailedException` (not a raw timeout exception) within the configured limit.

## Stretch exercise answers

**1. What happens under a 30-second spike?**
Each request that reaches `processAuthenticationResponse()` blocks its IS 7.3 auth thread for 30
seconds (waiting on the vendor API). With 200 threads in the pool, 200 simultaneous biometric
authentications would exhaust the pool within seconds. New authentication requests (FIDO2, TOTP,
basic auth — all authenticator types) queue waiting for a thread. IS 7.3's authentication endpoint
becomes unresponsive. Bank customers cannot log in.

**2. Two code-level mitigations:**
- **Bounded HTTP client timeout**: set `connectTimeout = 2000ms` and `readTimeout = 2000ms` on the
  vendor API HTTP client. If the vendor does not respond within 2 seconds, the method throws
  `AuthenticationFailedException("Vendor API timeout")` immediately, freeing the thread.
- **Circuit-breaker** (e.g., Resilience4j): after N consecutive failures/timeouts, the circuit opens
  and subsequent calls to `processAuthenticationResponse()` fail immediately (no HTTP call made) until
  the vendor API recovers. This prevents the thread pool from being filled with in-flight requests
  during a vendor outage.

**3. Why increasing the thread pool doesn't fix it?**
A larger thread pool delays exhaustion but does not prevent it. If the vendor spike lasts 30 seconds
and each blocked thread holds for 30 seconds, doubling the pool to 400 threads doubles the time to
exhaustion — it does not prevent it. The fundamental issue is unbounded blocking: every thread that
calls the vendor waits for the full socket timeout. The fix must be at the call site — a bounded
timeout means threads are released in 2 seconds regardless of vendor behaviour. Thread pool size is
a capacity parameter, not a resilience parameter.
