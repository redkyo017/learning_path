# Day 22 Lab — Solution

## The 5 JWT Claims and IS 7.3 Validation

Every `client_assertion` JWT for `private_key_jwt` authentication must contain exactly 5 claims. Here's what each does and why IS 7.3 requires it:

| Claim | Example | IS 7.3 Validation | Why It Matters |
|-------|---------|-------------------|----------------|
| `iss` (issuer) | `payment-orchestrator-v1` | Must equal registered `client_id` | Proves who signed the JWT. Prevents one client from forging assertions on behalf of another. |
| `sub` (subject) | `payment-orchestrator-v1` | For client auth: must equal `iss` | Confirms the JWT is about this client (self-assertion). In other grant types, `sub` might differ. |
| `aud` (audience) | `https://is.bank.local:9443/oauth2/token` | Must exactly match token endpoint URL | Prevents JWT reuse. A JWT issued for one endpoint (token, introspection, userinfo) cannot be used at another. |
| `jti` (JWT ID) | `<UUIDv4>` | Must not appear in replay cache | Prevents replay attacks. IS 7.3 caches `jti` values for the assertion's lifetime (up to 5 min). Duplicate `jti` = rejected. |
| `exp` (expiration) | `now + 300` (Unix timestamp) | Must not be expired; max 5 min future | Limits the window during which the JWT is valid. IS 7.3 may enforce a max assertion lifetime (recommend ≤ 600s). |

---

## IS 7.3 Verification Steps (In Order)

When IS 7.3 receives a token request with `client_assertion`:

### Step 1: Parse the JWT

```
JWT format: header.payload.signature (base64url encoded)
IS 7.3: Base64 decode each part, verify signature can be parsed
```

If malformed → `400 invalid_client "invalid_assertion"` (or parse error)

### Step 2: Extract Algorithm and Key ID

```
JWT header:
{
  "alg": "RS256",
  "kid": "2024-fintech-key-001"
}

IS 7.3 uses alg to determine which key type to expect (RSA, EC, etc.)
Uses kid to find the right key in JWKS
```

### Step 3: Fetch JWKS from Registered URI

```
IS 7.3: GET https://fintech.local/.well-known/jwks.json
Response:
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "2024-fintech-key-001",
      "alg": "RS256",
      "use": "sig",
      "n": "<modulus>",
      "e": "AQAB",
      ...
    }
  ]
}
```

IS 7.3 caches this response (TTL ~1 hour) to avoid repeated JWKS fetches.

If JWKS unreachable → `invalid_client "JWKS validation failed"`

### Step 4: Verify Signature

```
IS 7.3: Find key with matching kid
Extract public key from JWKS entry
Verify signature: RS256(header.payload, signature) == public_key
```

If signature invalid → `invalid_client "JWT signature verification failed"`

If kid not found → `invalid_client "kid_not_found"`

### Step 5: Check `aud` Claim

```
JWT payload: "aud": "https://is.bank.local:9443/oauth2/token"
Endpoint URL: https://is.bank.local:9443/oauth2/token
IS 7.3: aud == endpoint?
```

If mismatch → `invalid_client "aud_mismatch"` or similar

### Step 6: Check `exp` Claim

```
JWT: "exp": 1726845300
Current time: 1726845250
IS 7.3: is (current_time <= exp)?
IS 7.3: is (exp - now) <= max_assertion_lifetime?  // typically 600s
```

If expired → `invalid_client "assertion_expired"`

If `exp` too far in future → `invalid_client "assertion_lifetime_exceeds_limit"`

### Step 7: Check `iss` Claim

```
JWT: "iss": "payment-orchestrator-v1"
Registered client_id: "payment-orchestrator-v1"
IS 7.3: iss == client_id?
```

If mismatch → `invalid_client "issuer_mismatch"`

### Step 8: Check `jti` Not Seen Before

```
Replay cache in IS 7.3 (in-memory or Redis):
  "jti": {
    "exp_time": 1726845300,
    "seen": true
  }

IS 7.3: is jti in cache?
```

If yes (duplicate) → `invalid_client "assertion_already_used"`

If no: add jti to cache with TTL = exp_time

### Step 9: Authenticate and Proceed

```
All checks passed → IS 7.3 authenticates request as client_id
Proceeds with the rest of the OAuth2 flow (authorization_code, token-exchange, etc.)
```

---

## Error Scenarios and Fixes

### Scenario 1: Expired Assertion

**Symptoms:**
```
Error: invalid_client "assertion_expired"
```

**Root cause:**
```
JWT payload: "exp": 1726841900
Current time: 1726845000 (exp is in the past)
```

**Fix:**
```python
import time
from datetime import datetime, timedelta

now = int(time.time())
exp = now + 300  # 5 minutes from now

jwt_payload = {
  "iss": "payment-orchestrator-v1",
  "sub": "payment-orchestrator-v1",
  "aud": "https://is.bank.local:9443/oauth2/token",
  "jti": str(uuid.uuid4()),
  "exp": exp,
  "iat": now
}
```

### Scenario 2: Reused `jti`

**Symptoms:**
```
Request 1: 200 OK (token issued)
Request 2 (same jti): 400 invalid_client "assertion_already_used"
```

**Root cause:**
```
Request 1:
  "jti": "uuid-123"
  IS 7.3 caches: {"uuid-123": {"exp_time": 1726845300}}

Request 2:
  "jti": "uuid-123"
  IS 7.3 finds in cache → reject
```

**Fix:**
```python
# For every token request, generate a fresh jti
jwt_payload = {
  ...
  "jti": str(uuid.uuid4()),  # UUIDv4 each time
  ...
}
```

### Scenario 3: Wrong `aud`

**Symptoms:**
```
Error: invalid_client (or aud mismatch, depends on IS 7.3 version)
```

**Root cause:**
```
JWT payload: "aud": "https://is.bank.local:9443/oauth2/userinfo"
Actual endpoint: https://is.bank.local:9443/oauth2/token
Mismatch!
```

**Fix:**
```python
token_endpoint = "https://is.bank.local:9443/oauth2/token"
jwt_payload = {
  ...
  "aud": token_endpoint,  # Must match exactly, including path and port
  ...
}
```

### Scenario 4: JWKS Unreachable

**Symptoms:**
```
Error: invalid_client "JWKS validation failed"
(after a short delay, suggesting network timeout)
```

**Root cause:**
```
1. IS 7.3 tries to fetch https://fintech.local/.well-known/jwks.json
2. Firewall blocks the request (IS 7.3 cannot reach fintech.local)
3. Request times out
4. IS 7.3 returns error
```

**Diagnostic:**
```bash
# From IS 7.3's network perspective, can you reach the JWKS endpoint?
curl -v https://fintech.local/.well-known/jwks.json
# Should return 200 with JWKS JSON

# Check DNS resolution:
nslookup fintech.local
```

**Fix:**
```
1. Ensure fintech.local is resolvable from IS 7.3's network
2. Check firewall rules allow HTTPS outbound to fintech.local:443
3. Verify JWKS endpoint is publicly accessible (or from IS 7.3's IP)
4. Test with: curl -v https://fintech.local/.well-known/jwks.json
5. If cert untrusted, add to IS 7.3's trusted CA store
```

### Scenario 5: Algorithm Mismatch

**Symptoms:**
```
Error: invalid_client "JWKS validation failed" or "algorithm_mismatch"
```

**Root cause:**
```
JWT header: {"alg": "RS256", "kid": "..."}
JWKS entry: {"kty": "RSA", "alg": "ES256", ...}

Mismatch: RS256 (RSA) vs ES256 (Elliptic Curve)
```

**Fix:**
```json
// Ensure JWKS entry matches JWT algorithm
{
  "kty": "RSA",           // For RS256, must be RSA
  "alg": "RS256",         // Matches JWT alg
  "kid": "2024-001",
  "use": "sig",
  "n": "<modulus>",       // RSA modulus
  "e": "AQAB"             // RSA exponent
}

// Or for ES256:
{
  "kty": "EC",            // For ES256, must be EC
  "alg": "ES256",         // Matches JWT alg
  "kid": "2024-002",
  "use": "sig",
  "crv": "P-256",         // Curve
  "x": "<x-coord>",       // EC coordinates
  "y": "<y-coord>"
}
```

---

## Self-Check: JWT Creation Checklist

Before sending a token request with `client_assertion`, verify:

- [ ] JWT has exactly 5 claims: `iss`, `sub`, `aud`, `jti`, `exp`
- [ ] `iss` == registered `client_id`
- [ ] `sub` == registered `client_id`
- [ ] `aud` == token endpoint URL (including protocol, host, port, path)
- [ ] `jti` is a fresh UUIDv4 (not reused from previous request)
- [ ] `exp` is in Unix timestamp format, `now + 300` (≤ 5 minutes)
- [ ] `iat` is Unix timestamp of now
- [ ] JWT is signed with private key corresponding to JWKS public key
- [ ] JWT header includes `alg` and `kid`
- [ ] JWKS endpoint is reachable from IS 7.3's network
- [ ] JWT is placed in POST body as `client_assertion` (not in Authorization header)
- [ ] `client_assertion_type` is `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`

All checked? Token request should succeed.

---

## References

- RFC 7523 Section 2.2 (JWT Profile for OAuth 2.0 Client Authentication): https://tools.ietf.org/html/rfc7523#section-2.2
- JWT Replay Attack Prevention: https://tools.ietf.org/html/rfc7519#section-4.1.7
- WSO2 IS 7.3 OAuth2 Token Endpoint: https://is.docs.wso2.com/en/7.3.0/guides/access-delegation/oauth2-token-endpoint/
