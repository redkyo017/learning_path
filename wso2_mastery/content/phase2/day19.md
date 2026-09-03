# Day 19: JWT Validation in WSO2 API Gateway — Source Reading

## Why

Before you build a JWT validator in Go, you need to understand how WSO2's API Gateway validates
tokens in production. WSO2 does far more than just check the signature: it caches JWKS responses,
handles key rotation, extracts subscription metadata from claims, and enforces strict fail-closed
semantics when the key server is unreachable.

This day walks you through WSO2's JWT validation implementation so you can replicate its logic
and pitfalls in Day 20–21.

---

## WSO2 Source Reading

### The JWTValidator Chain

In `wso2am-universal-gw-4.7.0`, the gateway validates JWTs using:

1. **`JWTValidator.java`** — The interface defining the validation contract
2. **`JWTValidatorImpl.java`** — The production implementation

You'll find these in the WSO2 API Manager source or the compiled JAR. The validation method
signature is:

```java
public JWTValidationInfo validateToken(String token, RequestContext requestContext)
    throws JWTClientException
```

### The 7-Step JWT Validation Process

WSO2 GW performs these steps in sequence:

#### Step 1: Extract the Bearer Token

```
Authorization: Bearer <token>
```

If missing or malformed, return 401 `invalid_token`.

#### Step 2: Decode Header to Extract `kid`

Parse the JWT header (Base64-URL decoded) to extract the `kid` claim:

```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "4e31a7b4-5b0c-4d27-8e83-5f4c7d5a0b1c"
}
```

If `kid` is missing, WSO2 uses a fallback key or returns 401 `invalid_token`.

#### Step 3: Fetch Public Key from JWKS Endpoint

Using the `kid`, query the key server's JWKS endpoint:

```
GET https://<key-server>/oauth2/jwks
```

JWKS response:

```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "4e31a7b4-5b0c-4d27-8e83-5f4c7d5a0b1c",
      "n": "0vx7...",
      "e": "AQAB"
    }
  ]
}
```

Find the key with matching `kid`. If not found after re-fetching once, return 401 `invalid_token`.

#### Step 4: Verify Signature

Reconstruct the RSA public key from the JWK's `n` (modulus) and `e` (exponent) fields,
both Base64-URL encoded:

```go
nBytes, _ := base64.RawURLEncoding.DecodeString(jwk.N)
eBytes, _ := base64.RawURLEncoding.DecodeString(jwk.E)
pub := &rsa.PublicKey{
    N: new(big.Int).SetBytes(nBytes),
    E: int(new(big.Int).SetBytes(eBytes).Int64()),
}
// Verify JWT signature using pub
```

If signature is invalid, return 401 `invalid_token`.

#### Step 5: Check Token Expiration (`exp`)

Verify the `exp` claim is not in the past. If expired, return 401 `invalid_token`.

#### Step 6: Check Token Issuer (`iss`)

Verify the `iss` claim matches the expected key server (e.g., `https://<key-server>`).
If mismatch, return 401 `invalid_token`.

#### Step 7: Extract Subscription Claims

WSO2 uses custom claims to identify the subscriber and application:

- `http://wso2.org/claims/subscriber` — username of the API consumer
- `http://wso2.org/claims/applicationname` — application ID or name
- `http://wso2.org/claims/applicationtier` — subscription tier (e.g., "Unlimited", "Bronze")
- `http://wso2.org/claims/version` — API version being invoked
- `http://wso2.org/claims/keytype` — token type ("PRODUCTION", "SANDBOX")

These claims are stored in the request context and used downstream by throttling,
analytics, and authorization middlewares.

---

## Core Concepts

### JWKS Caching

WSO2 GW caches the entire JWKS response (all keys) in memory, keyed by the JWKS endpoint URL.
Default cache TTL is typically 1–24 hours. Why?

- **Reduces latency** — No HTTP round-trip on every token validation.
- **Improves reliability** — If the key server is temporarily down, cached keys still validate tokens issued before the outage.

**The cache invalidation problem:**

If the key server rotates keys (old `kid` removed, new `kid` added), the cached JWKS is stale.
WSO2 solves this by:

1. Attempting validation with the cached key.
2. If validation fails and this is the first attempt, **ignore the cache** and re-fetch JWKS once.
3. If re-fetched validation still fails, return 401 `invalid_token`.

This "fetch once on miss" strategy handles gradual key rotation without requiring explicit
cache invalidation from operators.

### Fail-Closed Semantics

**What if the JWKS endpoint is unreachable?**

WSO2 does NOT fail open (allow requests without validation). Instead:

- If cached keys exist and the current request can be validated using them, allow the request.
- If cached keys do not exist or do not match the token's `kid`, return 401 `jwks_unavailable`.

In other words, **no public key = no entry**. This is critical for security:
- If your key server goes down and the gateway cache expires, tokens are NOT automatically accepted.
- The gateway **waits** (backpressure) for the key server to recover.

---

## Lab

See `labs/phase2/day19/` — source reading exercise.

Your task: Find `JWTValidatorImpl.java` in the WSO2 API Manager source. Trace the `validateToken`
method and identify:

1. In which step does WSO2 fetch the public key from the JWKS endpoint?
2. What is the default cache invalidation strategy (how does WSO2 decide to re-fetch JWKS)?
3. What claims does WSO2 extract and store in the request context?

---

## Exercises

**Exercise 1:** What is the purpose of the `kid` (Key ID) claim in the JWT header?

**Hint:** The key server (e.g., WSO2 KM) may rotate multiple keys at once. The `kid` tells the
gateway which specific public key to use for verification.

**Solution sketch:**

The `kid` is a unique identifier for a specific public key in the JWKS. When a key server rotates
keys, it generates a new `kid` and publishes the new public key in the JWKS endpoint. The gateway
uses the `kid` from the JWT header to look up the correct public key for verification. If the
gateway cannot find a matching `kid`, it re-fetches the JWKS to handle key rotation.

---

**Exercise 2:** Explain why WSO2 re-fetches the JWKS on validation failure instead of failing
immediately.

**Hint:** The gateway may have a stale cache if the key server rotated keys. A single re-fetch
attempt allows the gateway to recover without restarting or waiting for cache expiration.

**Solution sketch:**

If validation fails with a cached key, the token's `kid` may not be in the cache because the
key server rotated keys. By re-fetching JWKS once, the gateway can fetch the new public key,
attempt validation again, and serve the request without cache staleness delays. If the re-fetch
still fails, the token is genuinely invalid or the key server is unreachable.

---

**Exercise 3:** What happens if the JWKS endpoint is unreachable and the gateway's cache is empty?

**Hint:** WSO2 uses fail-closed semantics: no cached keys = no entry.

**Solution sketch:**

If the JWKS endpoint is unreachable and the cache is empty (first startup, or cache expired),
the gateway cannot validate any token because it has no public key. It returns 401 `jwks_unavailable`.
This is intentional: the gateway does not allow requests to bypass validation just because the
key server is down. It waits for the key server to recover, ensuring security is maintained even
during outages.

---

## Anti-patterns

- **Failing open when the key server is down** — Some gateway implementations cache keys indefinitely
  and accept tokens when the cache is fresh but the key server is unreachable. This violates
  WSO2's fail-closed semantics and is a security risk if the key server goes down after a key
  rotation.

- **Not re-fetching JWKS on signature validation failure** — If you always use the cached key,
  you'll reject all tokens signed with new keys until the cache expires. WSO2 avoids this by
  re-fetching once.

- **Extracting subscription claims only if they exist** — Some implementations skip middleware
  if subscription claims are missing. WSO2 requires them; if absent, the token is invalid for
  API consumption (though it may be valid for other purposes). Check for their presence and
  reject if missing.

---

## Teardown

No code to run — this is a reading exercise. Proceed to Day 20.

