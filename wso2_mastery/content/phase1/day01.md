# Day 1 — OAuth2 Architecture & WSO2 IS Token Endpoint

## Why this matters
Every API call your company processes goes through token issuance (WSO2 IS) and token
validation (WSO2 GW). When a 401 hits production, you need to know immediately: did IS
fail to issue the token, or did the GW fail to validate it? Day 1 draws the boundary.

Understanding this split — IS issues, GW validates — is the most important mental model
in the WSO2 stack. Every debugging session and every architecture decision comes back to it.

## WSO2 source reading
- File: `wso2is-7.3.0/repository/components/org.wso2.carbon.identity.oauth/`
  Start with `OAuthEndpoint.java` — the HTTP entry point for `/oauth2/token`.
  Key insight: every grant type funnels through a single endpoint; the `grant_type`
  parameter dispatches to a `GrantTypeHandler`.

- The endpoint is a JAX-RS resource annotated `@Path("/token")`.
- Look for `@POST` — this is the method your `curl` request hits.
- `OAuthAuthzServer` is the orchestrator; it delegates to grant handlers.
- Each grant handler implements `AuthorizationGrantHandler`.

## Core concepts

### The OAuth2 actors
- **Resource Owner** — the user (or service) that owns the data
- **Client** — the app requesting access (your API consumer)
- **Authorization Server (AS)** — WSO2 IS; issues tokens
- **Resource Server** — WSO2 API Gateway; enforces tokens

The AS and RS are separate processes in WSO2. IS runs on port 9443 by default;
the API Gateway runs on 8243 (HTTPS) and 8280 (HTTP). They share no runtime state —
the GW validates tokens either by calling IS's `/oauth2/introspect` endpoint or by
verifying a JWT signature with IS's public key.

### Grant types in your company's stack
| Grant | Used for | WSO2 IS handler class |
|---|---|---|
| `client_credentials` | Service-to-service (no user) | `ClientCredentialsGrantHandler` |
| `authorization_code` | User login flows | `AuthorizationCodeGrantHandler` |
| `refresh_token` | Extend a session | `RefreshGrantHandler` |
| `urn:ietf:params:oauth:grant-type:token-exchange` | Federated identity | `TokenExchangeGrantHandler` |

Grant selection is driven entirely by the `grant_type` POST parameter. The endpoint
itself doesn't change — only the handler invoked changes.

### What happens at `/oauth2/token` (RFC 6749 §4)
1. Client sends `POST /oauth2/token` with `grant_type` + credentials
2. IS validates client identity (Basic Auth header = `clientId:clientSecret`, base64)
3. IS dispatches to the grant handler
4. Handler validates grant-specific params, builds a token response
5. Response: `{"access_token":"...", "token_type":"Bearer", "expires_in":3600}`

The client authentication step (step 2) runs before the grant handler is called.
This means an invalid client always returns `invalid_client` regardless of grant type.

Detailed call path:
```
HTTP POST /oauth2/token
  → OAuthEndpoint#issueAccessToken (JAX-RS resource)
    → OAuthClientAuthnService#authenticateClient (validates Basic Auth)
      → OAuthAuthzServer#issueAccessToken
        → AbstractAuthorizationGrantHandler#issue (or subclass)
          → OAuthTokenGenerator#generateAccessToken
            → token stored in IDN_OAUTH2_ACCESS_TOKEN
          → token response serialized as JSON
```

### WSO2 IS token storage
Tokens are stored in the `IDN_OAUTH2_ACCESS_TOKEN` table in the WSO2 database.

| Column | Purpose |
|---|---|
| `TOKEN_ID` | UUID primary key |
| `ACCESS_TOKEN` | The token value (hashed in DB for security) |
| `CONSUMER_KEY` | client_id that requested the token |
| `AUTHZ_USER` | user or service account the token is for |
| `TOKEN_STATE` | ACTIVE, EXPIRED, REVOKED, INACTIVE |
| `TIME_CREATED` | epoch milliseconds of issuance |
| `VALIDITY_PERIOD` | token lifetime in milliseconds |
| `TOKEN_SCOPE` | space-separated scope list |

When the GW calls `/oauth2/introspect`, IS queries this table by token value. If
`TOKEN_STATE = ACTIVE` and the token is not past its validity period, introspection
returns `{"active":true,...}`. Otherwise `{"active":false}`.

### Opaque tokens vs. JWT tokens
- **Opaque tokens**: random bytes. Gateway must call IS to validate. Adds latency
  (~1–5 ms for an internal call) but allows instant revocation.
- **JWT tokens**: signed JSON. Gateway validates with IS's public key — no IS call
  needed. Fast but revocation only takes effect after token expiry.

WSO2 IS 7.x defaults to opaque tokens; JWT is configurable via
`OAuthServerConfiguration.getAccessTokenType()`.

## Lab
See `labs/phase1/day01/`. Goal: read and annotate the WSO2 IS token endpoint source.
Success signal: you can draw the call path from HTTP request to token response on paper.

## Exercises
1. Draw the sequence: client → `/oauth2/token` → which Java class handles each step.
   **Hint:** Search `OAuthEndpoint.java` for the method that reads `grant_type`.
   **Solution sketch:** `OAuthEndpoint#issueAccessToken` → `OAuthAuthzServer#issueAccessToken` → `AbstractAuthorizationGrantHandler#issue`.

2. What HTTP status code does WSO2 IS return for an invalid `client_secret`?
   **Hint:** Check `OAuthClientAuthnService` for authentication failure handling.
   **Solution sketch:** `401 Unauthorized` with body `{"error":"invalid_client","error_description":"Client Authentication failed."}`.

3. Why does RFC 6749 require the token endpoint to use TLS? What breaks without it?
   **Hint:** Think about what travels in the POST body.
   **Solution sketch:** The `client_secret` and issued `access_token` are in cleartext in the POST body and response — interceptable without TLS.

4. Which table would you query to find all ACTIVE tokens for a given `client_id`?
   **Hint:** Look at the WSO2 IS database schema files (search for `IDN_OAUTH2`).
   **Solution sketch:** `SELECT * FROM IDN_OAUTH2_ACCESS_TOKEN WHERE CONSUMER_KEY = '<client_id>' AND TOKEN_STATE = 'ACTIVE'`.

5. What is the difference between `client_id` and `consumer_key` in WSO2 terminology?
   **Hint:** Look at how the application registration creates entries in the database.
   **Solution sketch:** They are the same value — WSO2 uses `consumer_key` as its internal column name; `client_id` is the OAuth2 RFC term. WSO2 maps them 1:1 at registration.

## Anti-patterns / Common mistakes
- Confusing the *authorization endpoint* (`/oauth2/authorize`) with the *token endpoint*
  (`/oauth2/token`). Auth endpoint redirects users; token endpoint returns tokens.
- Sending `client_id`/`client_secret` as POST body params instead of Basic Auth — WSO2 IS
  accepts both, but Basic Auth is the RFC-compliant default.
- Assuming a 401 from the gateway means IS is down. A 401 usually means token validation
  failed *at the gateway* — IS may be fine. Check gateway logs first, then IS.
- Mixing up opaque token revocation (instant, DB-backed) and JWT revocation (not instant
  without a revocation list). If you need instant revocation, use opaque tokens.

## Teardown
No processes started today — source-reading only. See `labs/phase1/day01/README.md`.
