# Day 20: Building a JWKS-Backed JWT Validator Middleware in Go

## Why

Now that you understand how WSO2 validates JWTs (Day 19), you'll implement the same logic in Go.
This day focuses on the JWKS client: fetching keys from an endpoint, parsing JWK format,
caching public keys, and handling key rotation via re-fetch-on-miss.

The middleware you build today becomes the core building block for Day 21's full gateway.

---

## WSO2 Source Reading

The JWKS endpoint URL is configured in WSO2 as:

```
[apim.oauth.token_endpoint_base_path]/oauth2/jwks
```

For a local WSO2 KM on `localhost:9443`:

```
https://localhost:9443/oauth2/jwks
```

The endpoint returns keys in standard JWK Set format (RFC 7517):

```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "4e31a7b4-5b0c-4d27-8e83-5f4c7d5a0b1c",
      "n": "0vx7agoebGcQSuuPiLJXZptN...",
      "e": "AQAB",
      "alg": "RS256",
      "use": "sig"
    }
  ]
}
```

Keys are cached in your Go gateway's memory using `sync.Map`, keyed by `kid`.

---

## Core Concepts

### Fetching and Parsing JWK

A JWK (JSON Web Key) describes a public key in JSON:

```json
{
  "kty": "RSA",
  "kid": "...",
  "n": "...",      // modulus (Base64-URL encoded)
  "e": "..."       // exponent (Base64-URL encoded)
}
```

To convert a JWK to Go's `rsa.PublicKey`:

1. Decode `n` and `e` from Base64-URL format.
2. Convert bytes to `big.Int`.
3. Construct `&rsa.PublicKey{N: ..., E: ...}`.

```go
nBytes, _ := base64.RawURLEncoding.DecodeString(jwk.N)
eBytes, _ := base64.RawURLEncoding.DecodeString(jwk.E)
pub := &rsa.PublicKey{
    N: new(big.Int).SetBytes(nBytes),
    E: int(new(big.Int).SetBytes(eBytes).Int64()),
}
```

### Caching with sync.Map

`sync.Map` is a thread-safe map optimized for read-heavy workloads (like caching public keys).

```go
var cache sync.Map  // kid → *rsa.PublicKey

// Store
cache.Store("kid1", publicKeyPtr)

// Load
pub, ok := cache.Load("kid1")
if ok {
    rsaPub := pub.(*rsa.PublicKey)  // type assertion
}
```

Unlike `map[string]*rsa.PublicKey` with a mutex, `sync.Map` allows concurrent reads without
locking, improving throughput under high concurrency.

### The Two-Stage Validation Attempt

When a token arrives:

1. **Try cached key** — Look up `kid` in the cache.
   - If found, verify the token's signature.
   - If signature is valid, allow the request.
   - If signature fails, proceed to stage 2 (key may have rotated).

2. **Re-fetch JWKS if validation failed** — The cached key is stale.
   - Fetch the JWKS endpoint.
   - Find the matching `kid`.
   - Verify the signature again.
   - If still invalid, return 401 `invalid_token`.

This approach avoids the overhead of always calling the JWKS endpoint (cached keys work 99% of the time)
while gracefully handling key rotation without operator intervention.

### WSO2 Claims Structure

WSO2 tokens carry custom claims using the namespace `http://wso2.org/claims/`:

```go
type WSO2Claims struct {
    jwt.RegisteredClaims
    Subscriber      string `json:"http://wso2.org/claims/subscriber"`
    ApplicationName string `json:"http://wso2.org/claims/applicationname"`
    ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
    APIVersion      string `json:"http://wso2.org/claims/version"`
    KeyType         string `json:"http://wso2.org/claims/keytype"`
}
```

These claims identify who is using which application to call which API. Downstream middleware
uses them for throttling and analytics.

### Parsing JWT Without Verification (to Extract `kid`)

Before fetching the JWKS, you need to know which key to fetch. Extract the `kid` from the
JWT header without verifying the signature:

```go
unverified, _, err := jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})
if err != nil {
    return 401  // malformed token
}
kid, _ := unverified.Header["kid"].(string)
```

This parse step is safe: you're only reading the header, not trusting any claims yet.

### Context Keys as Typed Receivers

Store validated claims in the request context using a typed key:

```go
type claimsKey struct{}

ctx := context.WithValue(r.Context(), claimsKey{}, claims)
r = r.WithContext(ctx)
```

Later, extract them:

```go
claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
```

Typed keys prevent collisions with unrelated middleware storing values under string keys.

---

## Lab

See `labs/phase2/day20/` — standalone JWT validation middleware with a mock token generator.

```bash
cd labs/phase2/day20
go run main.go
# In another terminal:
# Use the test endpoint to generate a token
# Send it to the gateway with Bearer header
```

---

## Exercises

**Exercise 1:** Parse a JWK's `n` and `e` fields and construct an `rsa.PublicKey`.

**Hint:** Use `base64.RawURLEncoding.DecodeString()` to convert Base64-URL to bytes. Use
`new(big.Int).SetBytes()` to convert bytes to big integers.

**Solution sketch:**

```go
nBytes, _ := base64.RawURLEncoding.DecodeString(jwk.N)
eBytes, _ := base64.RawURLEncoding.DecodeString(jwk.E)
pub := &rsa.PublicKey{
    N: new(big.Int).SetBytes(nBytes),
    E: int(new(big.Int).SetBytes(eBytes).Int64()),
}
```

---

**Exercise 2:** Extract the `kid` from a JWT header without verifying the signature.

**Hint:** Use `jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})`. The parsed token's
`Header` field is a map. Extract the `kid` with a type assertion: `unverified.Header["kid"].(string)`.

**Solution sketch:**

```go
unverified, _, err := jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})
if err != nil {
    return errors.New("malformed token")
}
kid, ok := unverified.Header["kid"].(string)
if !ok {
    return errors.New("missing kid")
}
```

---

**Exercise 3:** Implement the two-stage validation attempt: try cached key, re-fetch on failure.

**Hint:** Store keys in a `sync.Map`. On validation failure, call `fetchPublicKey` again with
the JWKS URL and `kid`. The second attempt uses the freshly fetched key.

**Solution sketch:**

```go
// Stage 1: Try cache
pub, ok := jwksCache.Load(kid)
if ok {
    token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
        return pub.(*rsa.PublicKey), nil
    })
    if err == nil {
        // Success with cached key
        return token.Claims.(*WSO2Claims), nil
    }
}

// Stage 2: Re-fetch on miss or validation failure
newPub, err := fetchPublicKey(jwksURL, kid)
if err != nil {
    return nil, err
}
token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
    return newPub, nil
})
if err != nil {
    return nil, err
}
return token.Claims.(*WSO2Claims), nil
```

---

## Anti-patterns

- **Caching keys forever** — Set a TTL on cached keys (e.g., 1 hour) so stale keys eventually
  disappear. The provided code caches indefinitely; in production, add eviction or TTL.

- **Not type-asserting the RSA public key** — The `jwt.ParseWithClaims` callback receives an
  `interface{}` from the key lookup. Always type-assert to `*rsa.PublicKey` and check the
  signing method is RSA (not HS256 or others).

- **Logging JWK material or tokens** — Public keys are safe to log, but never log token strings
  in production. They may contain sensitive claims.

- **Not handling the `iss` claim mismatch** — The provided code verifies the signature but does
  not check that `iss` matches the expected key server. Add this check in production.

---

## Teardown

Stop the gateway with `Ctrl+C`. No containers or persistent state to clean up.

