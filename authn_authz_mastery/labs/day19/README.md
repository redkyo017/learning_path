# Day 19 Lab — IS 7.3 Extension Points

## Goal

Read the Custom Authenticator SPI skeleton and identify where each authentication concern is handled.
The skeleton uses comments to describe intended logic without implementing it — your task is to
understand the structure, not the Java syntax.

## Success signal

You can explain the purpose of each method without referring to IS 7.3 documentation:
- `canHandle()` — what it returns and why precision matters
- `initiateAuthenticationRequest()` — when it is called and what it does
- `processAuthenticationResponse()` — when it is called and what it does
- `getName()` — how IS 7.3 uses the return value
- `getFriendlyName()` — where the return value appears

You can also describe how IS 7.3 routes an incoming request to the correct authenticator when multiple
custom authenticators are registered.

## Steps

1. Open `config/custom_authenticator_spi.java`.
2. For each method, write a one-sentence description of its purpose in your own words before reading
   the next method.
3. Answer the routing question: how does IS 7.3 decide which authenticator handles a request when
   both `BiometricAuthenticator` and `TOTPAuthenticator` (another custom authenticator) are registered?
4. Answer the test question: how would you verify the authenticator works correctly before deploying
   to the production IS 7.3 instance?
5. Check your answers against `SOLUTION.md`.

## Stretch exercise

The biometric vendor API call in `processAuthenticationResponse()` has an average latency of 800ms
but occasionally spikes to 30 seconds during vendor incidents. IS 7.3's default auth thread pool
has 200 threads.

Without looking at `day19.md`, answer:
1. What happens to IS 7.3 authentication under a 30-second spike if `processAuthenticationResponse()`
   blocks the thread?
2. What two code-level mitigations should be applied in `processAuthenticationResponse()`?
3. Why can't you fix this by increasing the IS 7.3 thread pool size instead?

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — lab instructions |
| `diagram.md` | Bundle lifecycle and IS 7.3 discovery flow |
| `config/custom_authenticator_spi.java` | Java skeleton — method signatures with comment-described logic |
| `SOLUTION.md` | Method explanations, routing answer, test answer, stretch answers |
