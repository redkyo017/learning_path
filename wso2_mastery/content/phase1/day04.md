# Day 4 — JWT Structure, WSO2 Claim Namespace, and JWKS

## Why this matters
When a client calls an API through WSO2 API Manager, the gateway needs to decide: is this
token valid? With opaque tokens, the gateway must call WSO2 IS to introspect every request.
With JWTs, the gateway can validate the token locally using the public key from the JWKS
endpoint — no network hop to IS required. Understanding the JWT structure and the WSO2-specific
claim namespace is the foundation for building and validating tokens correctly.

## WSO2 source reading
- **File:** `components/org.wso2.carbon.identity.oauth/src/main/java/org/wso2/carbon/identity/oauth2/token/handlers/grant/saml/SAML2BearerGrantHandler.java` — skip this for now
- **File:** `components/org.wso2.carbon.identity.oauth/src/main/java/org/wso2/carbon/identity/oauth2/util/OAuth2Util.java`
  - Search for `buildJWTClaimSet` — this is where WSO2 assembles the JWT payload
  - Notice how it adds claims under the `http://wso2.org/claims/` namespace
- **File:** `components/org.wso2.carbon.identity.oauth/src/main/java/org/wso2/carbon/identity/oauth2/token/JWTTokenGenerator.java`
  - The `buildJWTClaimSet` method constructs a `JWTClaimsSet` (Nimbus library)
  - Standard claims: `iss`, `sub`, `aud`, `iat`, `exp`, `jti`
  - Custom claims are added via `claimsSet.claim(claimName, claimValue)`
  - Look for the `keyId` being set — this maps to the `kid` in the JWT header

Key insight: WSO2 API Manager (the gateway) fetches the JWKS from IS at startup and caches
it. When a request arrives with a JWT, the gateway looks up the `kid` in the cached JWKS,
retrieves the public key, and validates the signature. No call to IS is made per-request.

## Core concepts

### JWT structure

A JWT is three Base64URL-encoded JSON objects joined by dots:

```
eyJhbGciOiJSUzI1NiIsImtpZCI6ImRldi1rZXktMSJ9   <- header
.
eyJpc3MiOiJodHRwczovL2xvY2FsaG9zdDo5NDQzL29hdXRoMi90b2tlbiIsInN1YiI6InRlc3QtY2xpZW50In0
                                                  <- payload
.
<signature bytes>                                 <- signature
```

**Header** fields:
| Field | Meaning |
|-------|---------|
| `alg` | Signing algorithm — WSO2 uses `RS256` (RSA + SHA-256) |
| `kid` | Key ID — identifies which public key in the JWKS to use for verification |

**Standard payload claims** (RFC 7519):
| Claim | Type | Meaning |
|-------|------|---------|
| `iss` | string | Issuer — typically `https://<is-host>/oauth2/token` |
| `sub` | string | Subject — the `client_id` for client_credentials, or the user's username |
| `aud` | string/array | Audience — the API or resource the token is intended for |
| `iat` | NumericDate | Issued-at — Unix epoch seconds |
| `exp` | NumericDate | Expiry — Unix epoch seconds |
| `jti` | string | JWT ID — unique identifier, prevents replay |

### WSO2 claim namespace

WSO2 adds application and API subscription metadata as custom claims:

| Claim URI | Example value | Meaning |
|-----------|---------------|---------|
| `http://wso2.org/claims/subscriber` | `admin` | The WSO2 IS user who created the application |
| `http://wso2.org/claims/applicationname` | `MyApp` | The application name in the Dev Portal |
| `http://wso2.org/claims/applicationtier` | `Unlimited` | The application-level throttling tier |
| `http://wso2.org/claims/version` | `v1` | The API version the subscription is for |
| `http://wso2.org/claims/keytype` | `PRODUCTION` | `PRODUCTION` or `SANDBOX` — determines which endpoint the API GW routes to |

The gateway uses `keytype` to route to production vs sandbox backend URLs. If a token was
issued for `SANDBOX` and it hits a gateway configured for `PRODUCTION` routing only, the
request is rejected.

### The `kid` and JWKS relationship

WSO2 IS signs JWTs with an RSA private key. The corresponding public key is exposed at:

```
GET https://<is-host>:9443/oauth2/jwks
```

Response:
```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "dev-key-1",
      "use": "sig",
      "alg": "RS256",
      "n": "<base64url-encoded modulus>",
      "e": "AQAB"
    }
  ]
}
```

The `kid` in the JWT header matches a key entry in this JWKS. When you rotate keys (replace
the signing key), you add the new key to the JWKS *first* with a new `kid`, then switch
signing to the new key. Old JWTs still validate because the old public key remains in the
JWKS until they expire. This is **zero-downtime key rotation** — gateways never reject
valid in-flight tokens during the rotation window.

### Decoding a JWT manually

```bash
# Given a JWT token in $TOKEN, split on '.' and decode the payload (part 2):
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool

# Or with jq:
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .

# Decode the header (part 1):
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null | jq .
```

Note: Base64URL padding — `base64 -d` may complain about missing `=` padding. Add padding:
```bash
PAYLOAD=$(echo $TOKEN | cut -d'.' -f2)
# Pad to multiple of 4 characters
PADDED="${PAYLOAD}$(printf '=%.0s' $(seq $((4 - ${#PAYLOAD} % 4))))"
echo $PADDED | base64 -d | jq .
```

## Lab
See `labs/phase1/day04/` — source reading guide, no new Go code.

## Exercises

**Exercise 1: Manual JWT decode**

Take a sample WSO2 JWT (from lab README or Day 5 output) and decode it manually using
`base64 -d`. List every claim you find and classify each as: standard RFC 7519, WSO2 custom,
or unknown.

**Hint:** Split the token on `.` to get header and payload separately. The header is part 1,
payload is part 2. Ignore the signature (part 3) — you can't decode it without the public key.

**Solution sketch:**
```bash
TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6ImRldi1rZXktMSJ9.eyJpc3MiOiJodHRwczovL2xvY2FsaG9zdDo5NDQzL29hdXRoMi90b2tlbiIsInN1YiI6InRlc3QtY2xpZW50IiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE2MDAwMDM2MDB9.<sig>"
# Header
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null
# => {"alg":"RS256","kid":"dev-key-1"}
# Payload
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null
# => {"iss":"https://localhost:9443/oauth2/token","sub":"test-client","iat":1600000000,"exp":1600003600}
# iss, sub, iat, exp = RFC 7519 standard
```

**Exercise 2: Identify WSO2 claims**

After running the Day 5 server and issuing a token, decode the JWT and list each WSO2 custom
claim. For each one, explain what the API gateway would do with it during request routing.

**Hint:** WSO2 custom claims all start with `http://wso2.org/claims/`. There are exactly 5
in this learning path's implementation.

**Solution sketch:**
- `subscriber` → identifies the application owner for analytics/billing
- `applicationname` → used in API analytics dashboards and quota counters
- `applicationtier` → gateway enforces this throttle tier per application
- `version` → gateway checks the token was issued for the correct API version
- `keytype` → gateway routes to production or sandbox backend URL

**Exercise 3: Explain kid rotation for zero-downtime key changes**

Describe the sequence of steps needed to rotate the RSA signing key in WSO2 IS without
causing any gateway to reject valid in-flight tokens. What would break if you removed the
old key from the JWKS before all tokens issued with it had expired?

**Hint:** Think about which component caches the JWKS and when it refreshes.

**Solution sketch:**
1. Generate new RSA key pair; add the *new public key* to the JWKS with a new `kid` value
2. Update IS config to sign new tokens with the new private key (new `kid` in JWT header)
3. Wait until all tokens signed with the old key have expired (typically 1 hour)
4. Remove the old public key from the JWKS
If you removed the old key before step 4, any gateway that cached the JWKS before step 2
would fail to find the old `kid` and reject still-valid tokens, causing production errors.

## Anti-patterns
- **Hard-coding the `kid`** — if you never rotate keys (because there's no rotation mechanism),
  a key compromise forces you to invalidate every outstanding token. Plan for rotation from day 1.
- **Putting secrets in JWT claims** — JWTs are signed, not encrypted. The payload is readable
  by anyone. Never put passwords, PII, or internal service credentials in JWT claims.
- **Trusting the JWT without verifying the signature** — a JWT is trivially forged by
  changing the payload. Always verify the signature against the JWKS before trusting any claim.
- **Ignoring `exp`** — a JWT is only valid until its expiry. A gateway that checks the
  signature but skips the `exp` check will accept stale tokens indefinitely.

## Teardown
Day 4 is source reading only — no processes to stop, no containers to remove.
