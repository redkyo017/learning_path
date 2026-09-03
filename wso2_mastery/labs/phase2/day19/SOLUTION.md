# Solution: Day 19 Source Reading Exercise

## Findings from JWTValidatorImpl.java

This document presents the expected answers when reading WSO2's JWT validation implementation.
Your findings should match these patterns.

---

## Question 1: How does JWTValidatorImpl extract the Bearer token?

**Answer:**

JWTValidatorImpl expects the Bearer token in the `Authorization` header:

```java
String authHeader = requestContext.getHeaders().get("Authorization");
if (authHeader == null || !authHeader.startsWith("Bearer ")) {
    throw new JWTClientException("Missing or invalid Authorization header");
}
String token = authHeader.substring(7);  // Strip "Bearer " prefix
```

The gateway extracts the substring after `"Bearer "` and validates that it's not empty.
If the header is missing or doesn't start with `"Bearer "`, validation fails immediately with a 401.

**Key detail**: The token is not verified at this stage — it's just extracted from the header.

---

## Question 2: What is the JWKS endpoint URL format?

**Answer:**

The JWKS endpoint is typically:

```
https://<key-manager-host>:<port>/oauth2/jwks
```

For example:
- Local development: `https://localhost:9443/oauth2/jwks`
- Production: `https://wso2-km.prod.example.com:9443/oauth2/jwks`

The endpoint URL is usually configured in `gateway.conf` or `deployment.yaml` under a section like:

```yaml
apim:
  oauth:
    token_endpoint_base_path: "https://wso2-km/oauth2"
  # Then the gateway appends "/jwks" to form the full URL
```

**Key detail**: The entire JWKS response (all keys) is fetched in one HTTP GET request.

---

## Question 3: How does WSO2 handle key rotation (missing `kid` in cache)?

**Answer:**

WSO2 uses a two-stage validation attempt:

**Stage 1: Try cached key**
- Extract the `kid` from the JWT header
- Look up the `kid` in the in-memory JWKS cache
- If found, verify the token signature using the cached public key
- If signature is valid, allow the request
- If signature fails, proceed to Stage 2

**Stage 2: Re-fetch JWKS if validation failed**
- Call the JWKS endpoint again (ignoring the cache)
- Find the matching `kid` in the fresh response
- Verify the token signature using the newly fetched public key
- If signature is still invalid, return 401 `invalid_token`
- If signature is valid, cache the new key and allow the request

**Code pattern** (pseudocode from JWTValidatorImpl):

```java
JWTValidationInfo info = validateWithCache(token, kid);
if (info == null) {
    // Cache miss or signature failure — re-fetch once
    info = validateWithFreshJWKS(token, kid);
    if (info == null) {
        // Still invalid
        throw new JWTClientException("invalid_token");
    }
}
return info;
```

**Key detail**: WSO2 re-fetches **only once** per validation. This prevents denial-of-service
attacks where an attacker sends malformed tokens causing the gateway to hammer the key server.

---

## Question 4: Which subscription claims does WSO2 extract?

**Answer:**

WSO2 extracts these custom claims from the JWT payload:

1. **`http://wso2.org/claims/subscriber`** — The username of the API consumer
   - Example: `"alice@carbon.super"`

2. **`http://wso2.org/claims/applicationname`** — The name or ID of the application
   - Example: `"MyMobileApp"`

3. **`http://wso2.org/claims/applicationtier`** — The subscription tier
   - Example: `"Unlimited"`, `"Bronze"`, `"Silver"`, `"Gold"`

4. **`http://wso2.org/claims/version`** — The API version being invoked
   - Example: `"1.0.0"`

5. **`http://wso2.org/claims/keytype`** — The token type
   - Example: `"PRODUCTION"`, `"SANDBOX"`

These claims are extracted and stored in the `RequestContext` so that downstream handlers
(throttling, analytics, authorization) can access them without re-parsing the JWT.

**Code pattern** (pseudocode):

```java
Claims claims = jwt.getClaims();
requestContext.set("subscriber", claims.get("http://wso2.org/claims/subscriber"));
requestContext.set("applicationName", claims.get("http://wso2.org/claims/applicationname"));
// ... and so on
```

**Key detail**: If any of these claims are missing, the token is **not** valid for API access
(though it may be valid for other purposes like refresh tokens). The gateway checks for their
presence and rejects the token if they're absent.

---

## Question 5: What is the default cache TTL for JWKS responses?

**Answer:**

The default JWKS cache TTL in WSO2 API Manager is typically **1 hour** (3600 seconds).

This is configurable in the gateway configuration, often under:

```yaml
apim:
  cache:
    jwks_ttl: 3600  # seconds
```

**Why 1 hour?**

- **Tradeoff**: Keys are cached long enough to avoid hammering the key server, but short enough
  that key rotation (removal of old keys) is detected within a reasonable time.
- **Fail-open risk**: If the cache TTL is too long (e.g., 24 hours) and the key server rotates
  all keys, tokens signed with new keys may be rejected for hours until the cache expires.
- **Fail-closed risk**: If the cache TTL is too short (e.g., 5 minutes), the gateway hits the
  key server frequently, increasing latency and creating a DoS vector.

**Key detail**: Even with a 1-hour TTL, the two-stage validation attempt (re-fetch on miss) means
that key rotation is detected immediately, not after 1 hour. The long TTL is for resilience,
not for staleness.

---

## Question 6: What happens if the JWKS endpoint is unreachable?

**Answer:**

WSO2 uses **fail-closed** semantics:

1. **If the cache is warm (has keys)**: Use the cached keys to validate tokens.
   - Tokens signed with cached keys are accepted.
   - If a token's `kid` is not in the cache, return 401 `invalid_token`.
   - The gateway remains operational for existing keys, even if the key server is down.

2. **If the cache is cold (empty) or has just expired**: Cannot validate any token.
   - Return 401 `jwks_unavailable`.
   - The gateway **does not** allow tokens through without validation.
   - This is intentional: security is prioritized over availability.

**Code pattern** (pseudocode):

```java
try {
    JWKSResponse response = httpClient.get(jwksURL);
    cache.put(jwksURL, response);
} catch (HttpException e) {
    // JWKS endpoint is unreachable
    if (cache.isEmpty()) {
        // No cached keys
        throw new JWTClientException("jwks_unavailable");
    }
    // Use cached keys anyway
}
```

**Key detail**: The fail-closed approach means the JWKS endpoint must be **highly available**.
In production, operators typically:
- Use a load balancer in front of the key server
- Deploy the key server in a cluster
- Cache JWKS responses in a CDN or local proxy
- Set up alerts if the key server is unreachable for more than a few seconds

---

## Summary: WSO2's JWT Validation Logic

When a request arrives with a Bearer token, WSO2 performs these steps in order:

1. **Extract** the Bearer token from the `Authorization` header
2. **Decode header** (no verification) to extract the `kid`
3. **Fetch** or use cached public key from JWKS endpoint (by `kid`)
4. **Verify** the JWT signature using the public key (RSA)
5. **Check** token expiration (`exp` claim is not in the past)
6. **Check** issuer (`iss` claim matches the expected key server)
7. **Extract** subscription claims (`subscriber`, `applicationname`, etc.)
8. **Store** claims in the request context for downstream handlers

**Key behaviors:**
- Caches JWKS responses (1-hour TTL by default)
- Re-fetches JWKS once on validation failure to handle key rotation
- Fails closed: no JWKS = no entry, even if cached keys don't match
- Always extracts subscription claims; missing claims make the token invalid for API access

This design mirrors WSO2's gateway behavior exactly. Your Go implementation (Days 20–21) will follow
the same logic to ensure compatibility with WSO2-issued tokens.

