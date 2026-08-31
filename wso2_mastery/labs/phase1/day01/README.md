# Lab Day 1 — WSO2 IS Token Endpoint Source Walk

## Goal
Trace the path from an HTTP POST to `/oauth2/token` through the WSO2 IS Java source.
Draw it on paper. No coding today.

## Prerequisites
- WSO2 IS source at `/Users/hunghan/Downloads/wso2is-7.3.0`
- A text editor / IDE to navigate Java files

## Steps
1. Open `wso2is-7.3.0/`. Find the Maven module containing `OAuthEndpoint.java`.
   (Hint: search for `@Path("/token")` annotation.)
2. Find the method annotated `@POST`. What are its parameters?
3. Search for where `grant_type` is read from the request.
4. Find `ClientCredentialsGrantHandler` — which interface does it implement?
5. Find where the access token string is generated (look for `UUID` or `SecureRandom`).
6. Find `OAuthClientAuthnService` — what does it return on invalid credentials?
7. Find the `IDN_OAUTH2_ACCESS_TOKEN` table definition in the schema SQL files.

## Draw the call path
After completing steps 1–7, draw on paper:

```
curl POST /oauth2/token
   ↓
OAuthEndpoint#issueAccessToken   [JAX-RS entry point]
   ↓
OAuthClientAuthnService#authenticateClient   [validates Basic Auth]
   ↓
OAuthAuthzServer#issueAccessToken   [orchestrator]
   ↓
ClientCredentialsGrantHandler#issue   [grant-type dispatch]
   ↓
OAuthTokenGenerator#generateAccessToken   [token string created]
   ↓
IDN_OAUTH2_ACCESS_TOKEN   [stored in DB]
   ↓
JSON response: {"access_token":"...","token_type":"Bearer","expires_in":3600}
```

Label each box with: the class name, the key method called, and what it returns.

## Success signal
You can answer without looking at the source:

1. "When a client sends `grant_type=client_credentials`, which Java class runs the
   grant-specific logic?"
2. "What does WSO2 IS return (HTTP status + body) for an invalid `client_secret`?"
3. "Where is the issued token stored?"

## Notes
- The WSO2 IS source uses the term `consumer_key` where RFC 6749 says `client_id`.
  They are the same value.
- The `grant_type` dispatch happens in `OAuthAuthzServer`, not in `OAuthEndpoint`.
- Token generation may use `DigestUtils` (SHA256 of random bytes) rather than raw UUID
  in newer IS versions — look for both patterns.

## Teardown
Nothing to stop — no processes started.
