# Day 5 — RSA Key Generation, JWT Signing, and JWKS Endpoint

## Why this matters
In production, WSO2 IS signs JWTs with its own RSA private key and serves the public key at
`/oauth2/jwks`. In this lab you replicate that behaviour in Go: generate an RSA key on
startup, sign tokens with it, and expose a JWKS endpoint so any consumer can verify tokens
without needing to call your server again. This is the gateway-cacheable, zero-round-trip
token validation model that makes JWT attractive at scale.

Understanding this lets you: write gateway-side validation code, mock WSO2 IS in integration
tests, and diagnose real-world JWT verification failures (wrong `kid`, key mismatch, clock skew).

## WSO2 source reading
- **File:** `JWTTokenGenerator.java` — look for `buildJWTClaimSet` and `signJWT`
  - `signJWT` retrieves the private key from the IS keystore (`wso2carbon.jks`) using
    the alias configured in `identity.xml`
  - It creates a `com.nimbusds.jose.JWSHeader` with `alg=RS256` and the `kid`
  - The `kid` value comes from the certificate's alias in the keystore
- **File:** `OAuth2Util.java` — look for `getThumbPrint` — this is how WSO2 derives the `kid`
  from the certificate's SHA-256 thumbprint (a hex string)
- **Endpoint:** `GET /oauth2/jwks` — handled by `OAuthServerConfiguration` which serialises
  the current signing key as a JWK using the Nimbus JOSE library

## Core concepts

### Why RSA, not HMAC

HMAC-SHA256 (`HS256`) uses a single shared secret: both the signer and the verifier need
the same key. In a multi-gateway deployment this means every gateway that validates tokens
must know the secret. If any gateway is compromised, the secret is exposed and an attacker
can forge tokens for every API.

RSA (`RS256`) uses a key pair: the private key signs (held only by the issuer — WSO2 IS),
and the public key verifies (distributed freely via JWKS). Compromising a gateway does not
compromise the signing key. Revoking a gateway's access is as simple as removing it from
the network — you do not need to rotate the secret.

```
IS (private key) → signs JWT
                        ↓
         JWT travels to the client
                        ↓
Gateway (public key from JWKS) → verifies signature
```

### RSA key generation in Go

```go
import (
    "crypto/rand"
    "crypto/rsa"
)

// 2048-bit key — adequate for development; use 4096 in production
key, err := rsa.GenerateKey(rand.Reader, 2048)
// key.PublicKey is the verification key
// key (the PrivateKey) is used for signing — never expose it
```

In production, load the key from a secrets manager (AWS Secrets Manager, HashiCorp Vault)
or from the Java keystore that WSO2 IS uses. Never generate a key at runtime in production —
the key changes on every restart, invalidating all outstanding tokens.

### The `github.com/golang-jwt/jwt/v5` library

Key types and functions:

| Symbol | Purpose |
|--------|---------|
| `jwt.RegisteredClaims` | Struct with standard claims: `Issuer`, `Subject`, `ExpiresAt`, `IssuedAt`, `ID` |
| `jwt.NewWithClaims(method, claims)` | Create an unsigned token |
| `token.Header["kid"] = "..."` | Set the `kid` header field before signing |
| `token.SignedString(key)` | Sign and serialise the token |
| `jwt.ParseWithClaims(str, &claims, keyFunc)` | Parse and verify a token string |
| `jwt.SigningMethodRS256` | The RSA-SHA256 algorithm constant |

### Building WSO2Claims

```go
type WSO2Claims struct {
    jwt.RegisteredClaims
    // WSO2 custom claims — JSON field names are the full URI
    Subscriber      string `json:"http://wso2.org/claims/subscriber"`
    ApplicationName string `json:"http://wso2.org/claims/applicationname"`
    ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
    APIVersion      string `json:"http://wso2.org/claims/version"`
    KeyType         string `json:"http://wso2.org/claims/keytype"`
}
```

Embedding `jwt.RegisteredClaims` means the library handles `exp`/`iat`/`iss` validation
automatically during `ParseWithClaims` — you do not need to re-check them manually.

### Signing flow

```go
func issueJWT(clientID, scope, appName string) (string, error) {
    now := time.Now()
    claims := WSO2Claims{
        RegisteredClaims: jwt.RegisteredClaims{
            Issuer:    "https://localhost:9443/oauth2/token",
            Subject:   clientID,
            IssuedAt:  jwt.NewNumericDate(now),
            ExpiresAt: jwt.NewNumericDate(now.Add(3600 * time.Second)),
        },
        Subscriber:      clientID,
        ApplicationName: appName,
        ApplicationTier: "Unlimited",
        APIVersion:      "v1",
        KeyType:         "PRODUCTION",
    }
    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    token.Header["kid"] = keyID   // critical: MUST be set before SignedString
    return token.SignedString(signingKey)
}
```

Note: `jwt.NewWithClaims` creates the token object but does not sign it. `SignedString`
performs the RSA signing and returns the final `header.payload.signature` string.

### JWKS endpoint format

The JWKS endpoint returns the public key encoded as a JWK (JSON Web Key):

```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "dev-key-1",
      "use": "sig",
      "alg": "RS256",
      "n": "<Base64URL-encoded big-endian modulus bytes>",
      "e": "<Base64URL-encoded big-endian public exponent bytes>"
    }
  ]
}
```

Field meanings:
| Field | Meaning |
|-------|---------|
| `kty` | Key type — always `RSA` for RSA keys |
| `kid` | Key ID — must match the `kid` in JWT headers signed with this key |
| `use` | Usage — `sig` means signature verification |
| `alg` | Algorithm — `RS256` for RSA-SHA256 |
| `n` | RSA modulus — the large prime product; this is the public key material |
| `e` | RSA public exponent — almost always `65537` which encodes as `AQAB` |

In Go, encode the modulus and exponent from the `rsa.PublicKey`:

```go
pub := signingKey.PublicKey
n := base64.RawURLEncoding.EncodeToString(pub.N.Bytes())
e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pub.E)).Bytes())
```

`RawURLEncoding` produces Base64URL without padding (`=` characters), which is what the
JWK specification requires.

## Lab
See `labs/phase1/day05/` — JWT-issuing server with JWKS endpoint.

## Exercises

**Exercise 1: Set the kid header before signing**

In the lab's `issueJWT`, what happens if you remove `token.Header["kid"] = keyID` before
calling `token.SignedString`? How would the gateway behave when it receives such a token?

**Hint:** Look at the JWKS endpoint — it serves keys indexed by `kid`. If the JWT header
has no `kid`, how does the validator know which public key to use?

**Solution sketch:**
Without `kid`, the validator must try every key in the JWKS until one verifies the signature —
or it must assume the first key. The `jwt.ParseWithClaims` key function receives the parsed
token (including `t.Header["kid"]`); if `kid` is missing, the key function cannot select
the correct key. The standard behaviour is to attempt all keys or fail. In production this
causes `invalid token` errors and breaks gateway validation. Always set `kid`.

**Exercise 2: Encode a custom expiry**

Modify `issueJWT` to accept a `ttl time.Duration` argument instead of hard-coding 3600
seconds. Write a call that issues a 30-second token and explain what `exp` would look like
in the decoded JWT.

**Hint:** `jwt.NewNumericDate` takes a `time.Time`. Add `ttl` to `time.Now()`.

**Solution sketch:**
```go
func issueJWT(clientID, scope, appName string, ttl time.Duration) (string, error) {
    now := time.Now()
    claims := WSO2Claims{
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
            IssuedAt:  jwt.NewNumericDate(now),
            // ...
        },
        // ...
    }
    // ...
}
// 30-second token:
tok, _ := issueJWT("test-client", "read", "TestApp", 30*time.Second)
// decoded exp = Unix(time.Now() + 30s), e.g. 1600000030
```

**Exercise 3: Verify the JWKS n and e values**

Fetch the JWKS from your running server with curl. Decode the `n` value with
`base64 -d` and convert it to a hex string. Compare its byte length to the RSA key size.
Explain why `e` is almost always `AQAB`.

**Hint:** A 2048-bit RSA key has a 256-byte modulus. `AQAB` in Base64URL decodes to 3 bytes:
`0x01 0x00 0x01` = 65537 in big-endian.

**Solution sketch:**
```bash
curl -s http://localhost:9443/oauth2/jwks | python3 -m json.tool
# Copy the "n" value
echo "<n-value>" | base64 -d | xxd | wc -l
# Should show ~16 lines x 16 bytes = 256 bytes = 2048 bits
echo "AQAB" | base64 -d | xxd
# 00000000: 0100 01   (hex) = 65537 decimal
# 65537 is the standard RSA public exponent — it's prime, not too small, and efficient to compute
```

## Anti-patterns
- **Generating an RSA key at runtime in production** — key changes on every restart,
  invalidating all outstanding tokens. Persist keys in a keystore or secrets manager.
- **Using a 512-bit or 1024-bit key** — these are considered broken. 2048-bit minimum;
  prefer 4096-bit for long-lived production keys.
- **Exposing the private key in any response** — JWKS serves only the *public* key.
  Accidentally logging or returning `signingKey` (the private key) instead of
  `signingKey.PublicKey` is a critical security failure.
- **Skipping the `kid` in the JWT header** — ambiguates key selection during rotation
  and makes zero-downtime key rotation impossible.

## Teardown
The lab server runs on `:9443`. Stop it with `Ctrl+C`.
No state is persisted — the RSA key and any issued tokens exist only in memory.
