# Day 7 — Token Introspection (RFC 7662)

## Learning Objectives

- Understand the RFC 7662 introspection endpoint contract and all response fields
- Know why opaque tokens require introspection while JWTs do not
- Recognise WSO2 IS's internal introspection pipeline (`IntrospectionDataProvider`)
- Understand why the introspection endpoint itself must be authenticated

---

## 1. What Problem Does Introspection Solve?

OAuth 2.0 tokens come in two practical forms:

- **JWTs** (self-contained): any holder of the public key can verify signature and expiry locally.
- **Opaque tokens** (reference tokens): random strings with no embedded meaning; validity is known only to the issuer.

A gateway receiving a JWT validates it offline — no network call needed. A gateway receiving an opaque token has no way to check validity locally. It must ask the authorisation server:

> "Is this token still valid, and if so, what does it represent?"

RFC 7662 defines that question as a standard protocol.

---

## 2. Endpoint Contract

```
POST /oauth2/introspect
Authorization: Basic <base64(client_id:client_secret)>
Content-Type: application/x-www-form-urlencoded

token=<token_value>&token_type_hint=access_token
```

`token_type_hint` (optional) guides the server to check `access_token` or `refresh_token` first. The server may ignore it and attempt both types.

### Active token response

```json
{
  "active": true,
  "sub": "test-client",
  "iss": "https://localhost:9443/oauth2/token",
  "iat": 1724000000,
  "exp": 1724003600,
  "nbf": 1724000000,
  "client_id": "test-client",
  "username": "test-client@carbon.super",
  "token_type": "Bearer",
  "scope": "read write",
  "aud": ["api://my-service"]
}
```

### Inactive / invalid / revoked token response

```json
{ "active": false }
```

When `active` is `false`, **no additional fields are returned**. The RFC is explicit on this: leaking the reason for invalidity (expired vs. revoked vs. never issued) would help an attacker.

---

## 3. RFC 7662 Response Fields

| Field | Type | Description |
|---|---|---|
| `active` | bool | **Required.** `true` if valid, in-scope, and not expired or revoked. |
| `sub` | string | Subject — the user or client the token was issued for. |
| `iss` | string | Issuer URL. |
| `iat` | integer | Issued-at timestamp (Unix epoch). |
| `exp` | integer | Expiry timestamp (Unix epoch). |
| `nbf` | integer | Not-before timestamp; token is invalid before this time. |
| `client_id` | string | OAuth 2.0 client ID that requested the token. |
| `username` | string | Human-readable resource owner login (ROPC / auth-code grants). |
| `token_type` | string | Token type, typically `"Bearer"`. |
| `scope` | string | Space-delimited list of granted scopes. |
| `aud` | string or array | Intended audiences. |

WSO2 IS adds non-standard extension claims:

| WSO2 claim | Description |
|---|---|
| `http://wso2.org/claims/applicationname` | Registered application name in the Developer Portal |
| `http://wso2.org/claims/keytype` | `PRODUCTION` or `SANDBOX` |
| `http://wso2.org/claims/subscriber` | Subscriber (API consumer username) |

---

## 4. JWT vs Opaque: When Do You Need Introspection?

| Token type | Validation method | Network call? | Revocation check? |
|---|---|---|---|
| **JWT** | Verify RSA/EC signature + `exp` locally | No | No — revoked JWTs remain valid until `exp` |
| **Opaque** | Call `/oauth2/introspect` on the AS | Yes (per request) | Yes — AS queries the DB each time |

**The JWT trade-off:** JWTs are fast (no round-trip) but create a **revocation gap** — once issued, a JWT cannot be cancelled until it expires naturally. Day 8 covers this in depth.

**When gateways need introspection even for JWTs:** WSO2 API Manager can be configured to call introspect for JWTs on revocation-sensitive paths, or when the gateway's own token cache has been purged. In the default configuration, the gateway validates JWTs locally and only falls back to introspect for opaque reference tokens.

---

## 5. WSO2 IS Internal Introspection Pipeline

When a resource server calls `/oauth2/introspect`, WSO2 IS processes the request through:

1. **`OAuth2TokenValidationService`** — the entry facade; accepts `OAuth2TokenValidationRequestDTO` (token string + type hint).
2. **`IntrospectionDataProvider`** — interface that builds the introspection response DTO. Two main implementations:
   - `JWTIntrospectionDataProvider` — decodes the JWT, verifies signature, returns claims.
   - `DefaultIntrospectionDataProvider` — looks up the opaque token in `IDN_OAUTH2_ACCESS_TOKEN`.
3. **`OAuth2TokenValidationMessageContext`** — the mutable validation context passed between pipeline stages (validators, claim handlers).
4. **`OAuthIntrospectionResponseDTO`** — the final response object serialised to JSON.

Relevant source packages:
```
org.wso2.carbon.identity.oauth2.validators
org.wso2.carbon.identity.oauth2.dto
org.wso2.carbon.identity.oauth.common.dto.OAuthIntrospectionResponseDTO
```

---

## 6. Securing the Introspection Endpoint

The introspection endpoint is a **token oracle**: given any string, it returns a yes/no answer on validity. Without access control, an attacker can submit arbitrary strings and learn which ones are valid tokens — a dictionary or enumeration attack.

RFC 7662 §2.1 requires the endpoint to be accessible only to **authorised resource servers or protected resource clients**.

WSO2 IS enforces this with:
- **Basic Auth** (client credentials of a registered OAuth 2.0 application)
- **Bearer token** authentication (the caller presents its own valid access token)

In the lab server, the introspect endpoint uses Basic Auth and calls `validateClient()` before processing any token. Returning `WWW-Authenticate: Basic realm="introspection"` on a 401 response signals the required auth scheme to callers.

---

## Exercises

### Exercise 1 — Decode a JWT without introspect

Obtain a token from your day06 lab server. Decode the JWT payload without calling any endpoint — use only shell tools. List which RFC 7662 fields are present and which are absent.

**Hint:** A JWT has three base64url-encoded segments separated by dots. The middle segment is the payload. Run:
```bash
echo "<payload_segment>" | base64 -d
```
Compare the decoded fields against the RFC 7662 table above. Note that `username` maps to the resource owner's human login name (not present in client_credentials grants) and `client_id` may appear as `sub` instead.

**Solution sketch:**
```bash
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret \
  -d grant_type=client_credentials | jq -r .access_token)

# Extract and decode the payload (middle segment)
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```
Present: `sub`, `iss`, `iat`, `exp`, `jti`, WSO2-specific claims.  
Absent from raw JWT (added only by introspect): `active`, `username` (ROPC-only), `token_type` as a separate field, `nbf` (unless issuer adds it).

---

### Exercise 2 — Introspect a valid token

Start the day07 lab server. Issue a token, then call `/oauth2/introspect` with valid Basic Auth. Confirm `active:true` and check all fields in the response.

**Hint:** The introspect caller must authenticate with the same credentials used to issue the token: `test-client:test-secret`. The `-u` flag in curl generates the `Authorization: Basic ...` header automatically.

**Solution sketch:**
```bash
# Start server in background: go run main.go &
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret \
  -d grant_type=client_credentials | jq -r .access_token)

curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret \
  -d "token=$TOKEN" | jq .
```
Expected: `"active": true` plus `sub`, `exp`, `iat`, `iss`, `client_id`, `token_type`, and WSO2 custom claims.

---

### Exercise 3 — Introspect without authentication

Call `/oauth2/introspect` without supplying `Authorization` header. Confirm you receive `401 Unauthorized` with `WWW-Authenticate` in the response headers.

**Hint:** Omit the `-u` flag. Use `-v` to see response headers.

**Solution sketch:**
```bash
curl -v -X POST http://localhost:9443/oauth2/introspect \
  -d "token=anything"
```
Expected: `HTTP/1.1 401 Unauthorized` and header `WWW-Authenticate: Basic realm="introspection"`. No token data is disclosed even though no valid token was submitted.
