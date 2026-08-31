# Day 6 — Gateway-Side JWT Validation and Auth Middleware

## Why this matters
The API gateway is the last line of defence before a request reaches your backend service.
In WSO2 API Manager, the gateway validates the JWT locally — it checks the signature,
the expiry, the issuer, and the subscription claims — before forwarding the request.
Understanding this validation logic lets you: replicate it in your own gateway layer,
write integration tests that issue real JWTs and assert they are accepted or rejected,
and diagnose `401 Invalid token` errors in production.

## WSO2 source reading
- **File:** `components/org.wso2.carbon.apimgt.gateway/src/main/java/org/wso2/carbon/apimgt/gateway/handlers/security/jwt/JWTValidator.java`
  - Look for `validateJWTToken` — the entry point
  - It calls `getSignatureAlgorithm`, then `verifyTokenSignature` (public key lookup by `kid`)
  - Then it calls `validatePayload` — checks `exp`, `iss`, and `aud` claims
  - Then it extracts `keytype`, `subscriber`, `applicationname`, `applicationtier` for
    throttling and analytics
- **File:** `identity.xml` → `OAuthConfiguration` → `TokenPersistenceProcessor`
  - Value `org.wso2.carbon.identity.oauth2.token.JWTTokenIssuer` → issues JWTs
  - Value `org.wso2.carbon.identity.oauth2.token.OauthTokenIssuer` → issues opaque tokens
  - This is the single config switch that determines whether your IS issues JWTs or opaque tokens

## Core concepts

### Opaque vs JWT token validation

| Aspect | Opaque token | JWT |
|--------|-------------|-----|
| Gateway validation | Must call IS `/introspect` per request | Verify signature locally using public key |
| Latency | +1 network hop to IS | Zero extra hops (after JWKS cache warm) |
| Revocation | Immediate — IS can mark token inactive | Delayed — must wait for `exp` to pass |
| IS load | Every request → introspect call | Only JWKS fetch (cached; rarely refreshed) |
| Token size | ~43 bytes (random opaque string) | ~500–2000 bytes (header.payload.sig) |

**Revocation gap:** JWTs cannot be immediately revoked. If a user logs out or an application
key is deleted, any JWT that was issued before the deletion remains valid until its `exp`.
WSO2 APIM 4.x partially addresses this with a token revocation event sent to gateways, but
the window still exists until gateways process the event. For high-security APIs (banking,
health), consider shorter token lifetimes (5–15 minutes) or using opaque tokens with
introspection.

### Time-related claims: `iat`, `nbf`, `exp`

| Claim | Meaning | Validation rule |
|-------|---------|-----------------|
| `iat` (issued-at) | When the token was created (Unix epoch seconds) | Informational; can detect very old tokens |
| `nbf` (not-before) | Token is not valid before this time | Reject if `now < nbf` |
| `exp` (expires-at) | Token is not valid after this time | Reject if `now >= exp` (or with small clock skew) |

WSO2 IS sets `iat` to the current time, does not usually set `nbf`, and sets `exp` based
on the access token validity period configured per application/API.

The `golang-jwt/jwt/v5` library checks `exp` and `nbf` automatically when you use
`jwt.ParseWithClaims` — you do not need to compare times manually.

### Gateway-side validation flow

```
1. Extract Bearer token from Authorization header
2. Base64URL-decode the JWT header to get "kid"
3. Look up kid in the cached JWKS to get the RSA public key
4. Verify RSA-SHA256 signature
5. Check exp > now (reject if expired)
6. Check iss == expected issuer URL
7. Check aud contains this gateway's resource identifier (optional)
8. Extract sub, keytype, applicationname, applicationtier for throttling
9. Forward request to backend with claims attached (e.g. as X-JWT-Claims header)
```

Steps 2–7 are handled by `jwt.ParseWithClaims` in Go if you implement the key function
correctly. Steps 8–9 are your application logic.

### Context key type pattern

In Go, using a plain `string` as a context key causes collisions if multiple packages use
the same string. The idiomatic fix is a private unexported type:

```go
// Define a package-private type for the context key
type contextKey string
const claimsKey contextKey = "wso2claims"

// Set:
ctx := context.WithValue(r.Context(), claimsKey, claims)

// Get (in a downstream handler):
claims, ok := r.Context().Value(claimsKey).(*WSO2Claims)
```

Because `contextKey` is a distinct type, `context.Value(claimsKey)` will not match
`context.Value("wso2claims")` — even though the underlying string is the same.

### validateJWT pattern

```go
func validateJWT(tokenStr string) (*WSO2Claims, error) {
    token, err := jwt.ParseWithClaims(
        tokenStr,
        &WSO2Claims{},
        func(t *jwt.Token) (any, error) {
            // Reject non-RSA tokens — prevents algorithm confusion attacks
            if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
                return nil, fmt.Errorf("unexpected alg: %v", t.Header["alg"])
            }
            return &signingKey.PublicKey, nil
        },
    )
    if err != nil {
        return nil, err
    }
    claims, ok := token.Claims.(*WSO2Claims)
    if !ok || !token.Valid {
        return nil, fmt.Errorf("invalid token claims")
    }
    return claims, nil
}
```

The algorithm check (`t.Method.(*jwt.SigningMethodRSA)`) prevents the "none" algorithm
attack and the HMAC/RSA confusion attack (where an attacker signs with the *public key*
using HS256, tricking a naive validator that accepts both algorithms).

## Lab
See `labs/phase1/day06/` — full JWT-issuing server with validation middleware and protected
endpoint. Tests token acceptance, rejection, and claims extraction.

## Exercises

**Exercise 1: Validate a self-issued JWT**

Using the Day 6 server, issue a token with curl, then call `/api/hello` with the Bearer
token. Examine the JSON response and locate each WSO2 claim. Then call `/api/hello` without
the Authorization header — confirm you get a 401.

**Hint:** The `/api/hello` handler reads claims from the request context. The middleware
puts them there only if the JWT is valid.

**Solution sketch:**
```bash
# Issue a token
TOKEN=$(curl -s -u test-client:test-secret \
  -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Call protected endpoint
curl -H "Authorization: Bearer $TOKEN" http://localhost:9443/api/hello
# => {"subject":"test-client","application":"DefaultApp","keytype":"PRODUCTION",...}

# No token
curl http://localhost:9443/api/hello
# => 401 {"error":"missing_token"}
```

**Exercise 2: Force an expired token**

Modify `issueJWT` in day06/main.go to issue a token with a 1-second lifetime. Call
`/oauth2/token`, wait 2 seconds, then call `/api/hello`. What error do you get?

**Hint:** `jwt.ParseWithClaims` returns an error wrapping `jwt.ErrTokenExpired` when `exp`
has passed. The `errors.Is` function can check for this.

**Solution sketch:**
```go
// Change in issueJWT:
ExpiresAt: jwt.NewNumericDate(now.Add(1 * time.Second)),
```
```bash
TOKEN=$(curl -s -u test-client:test-secret -d "grant_type=client_credentials" \
  http://localhost:9443/oauth2/token | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
sleep 2
curl -H "Authorization: Bearer $TOKEN" http://localhost:9443/api/hello
# => 401 {"error":"invalid_token"}
```
On the server log you would see: `token is expired by 1s`.

**Exercise 3: Algorithm confusion defence**

Explain the RS256/HS256 confusion attack. Why does checking `t.Method.(*jwt.SigningMethodRSA)`
prevent it?

**Hint:** In the attack, an adversary takes the *public key* (which is public) and uses it
as an HMAC secret to forge a token with `alg: HS256`.

**Solution sketch:**
The attack exploits a naive validator that accepts both `RS256` and `HS256`. The attacker
takes your public key (from JWKS), signs `header.payload` with HMAC-SHA256 using the public
key bytes as the HMAC secret, sets `alg: HS256` in the header, and submits the forged JWT.
A naive validator switches to HMAC mode, calls `hmac.verify(pubKeyBytes, ...)`, and accepts
the signature because it matches. The type assertion `t.Method.(*jwt.SigningMethodRSA)` fails
for `*jwt.SigningMethodHMAC`, so the key function returns an error before any signature check,
blocking the attack.

## Anti-patterns
- **Using a plain `string` as a context key** — collides with other packages; use a typed
  private type instead (see Core concepts above).
- **Not checking the signing method in the key function** — leaves the server open to
  algorithm confusion attacks. Always assert the expected type.
- **Returning the private key instead of the public key in the key function** —
  `validateJWT` should return `&signingKey.PublicKey`, not `signingKey`. Returning the
  private key would work for signature verification (RSA can verify with either), but it
  exposes the private key material to the jwt library unnecessarily.
- **Ignoring `token.Valid`** — `jwt.ParseWithClaims` can return a partially-parsed token
  even on error. Always check both `err == nil` AND `token.Valid` before trusting claims.
- **Issuing long-lived JWTs without a revocation strategy** — for high-privilege operations,
  keep token lifetimes short (5–15 minutes) or maintain a server-side revocation list.

## Teardown
The lab server runs on `:9443`. Stop it with `Ctrl+C`.
No external resources are used — everything runs in a single Go process with in-memory state.
