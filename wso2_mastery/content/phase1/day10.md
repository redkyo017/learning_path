# Day 10 — WSO2 Key Manager REST API: The Contract

## Why a Key Manager Interface Exists

WSO2 API Manager (APIM) separates two concerns:

- **Gateway** — enforces API access; validates every incoming token.
- **Key Manager** — the OAuth 2.0 authority; issues, introspects, and revokes tokens.

By default, WSO2 Identity Server (IS) plays both roles.  The Key Manager REST
interface lets you swap in *any* OAuth 2.0 server — an external IS cluster, a
cloud IAM provider, or (after Day 12) your own Go service — without changing
the gateway code.

### Built-in vs External Key Manager

| Type | Description | When to use |
|------|-------------|-------------|
| **Built-in (Resident)** | IS bundled inside APIM; same JVM, same database | Developer/test topologies |
| **External IS** | Separate IS cluster; APIM calls IS REST API | Production; HA; federation |
| **Custom (3rd-party)** | Any service that implements `KeyManagerInterface` | Your Go service, Keycloak, Okta with an adapter |

The critical insight: APIM does **not** call IS directly at the protocol level.
It calls a well-known REST contract.  Implement that contract and APIM treats
your service as a first-class Key Manager.

---

## The Seven Key Manager Endpoints

These map directly to the methods declared in
`KeyManagerInterface.java` inside the `wso2am-acp` source tree
(`org.wso2.carbon.apimgt.api.model.KeyManager`).

| # | Method | Path | Purpose |
|---|--------|------|---------|
| 1 | `POST`   | `/api/am/keymanager/v1/oauth2/token`              | Issue an access token (client_credentials, password, …) |
| 2 | `POST`   | `/api/am/keymanager/v1/oauth2/introspect`          | RFC 7662 — validate a token, return claims |
| 3 | `POST`   | `/api/am/keymanager/v1/oauth2/revoke`              | RFC 7009 — revoke a token |
| 4 | `GET`    | `/api/am/keymanager/v1/oauth2/userinfo`            | Return user profile claims (OIDC) |
| 5 | `GET`    | `/api/am/keymanager/v1/jwks`                       | Publish RSA/EC public keys as JWK Set |
| 6 | `POST`   | `/api/am/keymanager/v1/keymanager/application`     | Register an OAuth client (APIM calls this when a developer subscribes) |
| 7 | `DELETE` | `/api/am/keymanager/v1/keymanager/application/{id}` | Delete an OAuth client (APIM calls this when a subscription is removed) |

Endpoints 1–5 are the standard OAuth 2.0 / OIDC surface.
Endpoints 6–7 are WSO2-specific — they let APIM manage OAuth clients
*on behalf of* developers who never talk to the Key Manager directly.

---

## How APIM Registers a 3rd-Party Key Manager

When you add a Key Manager in the APIM admin console, the Control Plane
makes the following sequence of REST calls to *your* service:

```
1.  GET  /health
    → APIM checks the service is reachable.
    → Expected: 200 {"status":"UP"}

2.  GET  /api/am/keymanager/v1/jwks
    → APIM fetches your public keys to cache them for local JWT validation.
    → Expected: 200 {"keys":[{"kty":"RSA","kid":"...","n":"...","e":"..."}]}

3.  POST /api/am/keymanager/v1/keymanager/application
    → APIM registers its own internal service accounts (e.g. "admin_store").
    → Body: {"applicationName":"admin_store","grantTypes":["client_credentials"]}
    → Expected: 201 {"clientId":"<generated>","clientSecret":"<generated>","clientName":"admin_store"}
```

After registration, every developer subscription triggers step 3 again for
that developer's application, and every un-subscription triggers DELETE.

---

## Client Application Registration Flow

The sequence below shows what happens when a developer subscribes an app to
an API in the Developer Portal:

```
Developer Portal  ──POST /subscribe──►  APIM Control Plane
                                              │
                              POST /keymanager/application
                                              │
                                              ▼
                                     Key Manager Service
                                     (your Go service / IS)
                                              │
                                    201 {clientId, clientSecret}
                                              │
                                              ▼
                              APIM stores mapping in
                              AM_APPLICATION_KEY_MAPPING
                                              │
                              Returns keys to Developer Portal
                                              ▼
Developer receives clientId + clientSecret
```

The `AM_APPLICATION_KEY_MAPPING` table links:

```
APIM Application ID  ←→  OAuth Client ID  ←→  Key Manager Name
```

This mapping is what lets the gateway know *which* Key Manager to call when
it sees a token it wants to introspect.

---

## Practical Checkpoint

Before Day 11, make sure you can answer:

1. Name the two WSO2-specific endpoints (6 & 7) and explain when APIM calls each.
2. What does APIM store in `AM_APPLICATION_KEY_MAPPING` and why?
3. What is the difference between a *built-in* and a *custom* Key Manager?

---

## Lab (Day 10)

See `labs/phase1/day10/README.md` — source-reading exercise: locate
`KeyManagerInterface.java` in the wso2am-acp checkout and map its methods
to the endpoint table above.

---

## Exercises

**Exercise 1 — Endpoint mapping**

Draw a table with three columns: `KeyManagerInterface method name`,
`HTTP method`, `path`.  Fill in all seven rows from the table above without
looking at it.

**Hint:** The JWKS endpoint is a GET because keys are public and read-only;
token operations are POSTs because they mutate state or carry a secret body.

**Solution sketch:**
```
registerApplication → POST  /keymanager/application
deleteApplication   → DELETE /keymanager/application/{id}
generateAccessToken → POST  /oauth2/token
getNewApplicationAccessToken → POST /oauth2/token (same endpoint, different grant)
getTokenMetaData    → POST  /oauth2/introspect
revokeAccessToken   → POST  /oauth2/revoke
getJWKS             → GET   /jwks
```

**Exercise 2 — Registration sequence**

Write the three HTTP calls (method + path + expected status) that APIM makes
to your service immediately after you click "Add Key Manager" in the admin console.

**Hint:** APIM first confirms liveness, then fetches keys, then registers its
own internal applications.

**Solution sketch:**
```
GET  /health                              → 200
GET  /api/am/keymanager/v1/jwks           → 200
POST /api/am/keymanager/v1/keymanager/application  → 201
```
