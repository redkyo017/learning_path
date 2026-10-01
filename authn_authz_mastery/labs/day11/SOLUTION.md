# Day 11 Lab — Solution

## What happens at each step

**Initiation**: IS 7.3 creates a server-side auth session, returns `flowId` (opaque session handle).
The PKCE `challenge` is stored in the session for verification at token exchange.

**Step 1 (Basic)**: IS 7.3 validates username/password against the LOCAL identity store. If valid,
marks Step 1 complete in the session, returns `flowStatus: INCOMPLETE` with TOTP as `nextStep`.

**Step 2 (TOTP)**: IS 7.3 verifies the 6-digit TOTP against the user's enrolled TOTP secret.
If valid, marks Step 2 complete → `flowStatus: SUCCESS_COMPLETED`, issues `authCode` (short-lived, ~60s).

**Token exchange**: IS 7.3 validates: (1) `code` matches the session, (2) `code_verifier` matches stored
`code_challenge`, (3) `redirect_uri` matches registered value. Issues `access_token` + `id_token`.

## Why `flowId` never changes
The `flowId` is the session handle. Changing it would require the client to re-correlate sessions.
IS 7.3 keeps the same `flowId` for the entire multi-step flow — the server-side session is mutable.

## What happens if TOTP fails
IS 7.3 returns `flowStatus: FAIL_INCOMPLETE` with `failureReason: "INVALID_TOKEN"`. The app
can retry Step 2 with the same `flowId` (IS 7.3 allows N retries, configurable per application).
After max retries: `FAIL_COMPLETED` — the session is terminated and a new initiation is needed.
