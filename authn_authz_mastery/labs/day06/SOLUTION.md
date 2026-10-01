# Day 06 Lab — Solution

## tls_client_auth vs self_signed_tls_client_auth

| Dimension | `tls_client_auth` | `self_signed_tls_client_auth` |
|-----------|-------------------|-------------------------------|
| CA requirement | Cert must chain to a CA in AS trust store | No CA required — client generates own cert |
| Identity assurance | CA-issued identity validation | Bank's own onboarding process |
| Cert issuance | Must wait for CA approval; may have cost | Instant — client generates locally |
| Rotation | New cert from CA required | Immediate — register new thumbprint in JWKS |
| Use case | Open banking ecosystems with defined CA lists | Closed ecosystems, internal services, sandbox |
| `x5c` in JWKS | Optional | Required — AS computes thumbprint from this cert |

### When to prefer each

Use `tls_client_auth` when:
- Your ecosystem mandates specific CAs (UK FCA, Brazil BCB, Australia CDR)
- You need CA-issued identity for regulatory compliance
- You already have a CA relationship

Use `self_signed_tls_client_auth` when:
- You control onboarding and can verify identity independently
- You have many clients rotating certificates frequently
- You want zero CA dependency and instant rotation

## Certificate rotation without downtime (zero-downtime window)

1. Generate new key pair and certificate (CA-issued or self-signed)
2. Register the new cert's `x5t#S256` in the JWKS URI alongside the existing cert (dual-registration)
3. Both thumbprints are now valid — no traffic disruption
4. Deploy new cert to the client application
5. Wait for all active sessions using the old cert to complete (or force re-auth)
6. Remove old cert's registration from JWKS URI
7. Revoke old cert if CA-issued (CRL/OCSP)

The critical constraint: never remove the old registration before the new cert is confirmed working. Always test a connection with the new cert while both are registered.

## What cnf.x5t#S256 means

`cnf` stands for "confirmation" (RFC 7800). The `x5t#S256` key is the SHA-256 thumbprint of the X.509 certificate:

```
x5t#S256 = base64url( sha256( DER_bytes_of_certificate ) )
```

It is a 43-character base64url string that uniquely identifies the certificate. The AS computes this from the client cert presented during the mTLS token request and embeds it in the access token. The token is now bound to that cert — any resource server can verify the binding without storing the certificate itself.

## Why thumbprints, not full PEM, are forwarded

1. **Size**: A typical X.509 PEM is 2–4 KB. A SHA-256 thumbprint is 43 characters. At high request rates, PEM forwarding adds significant per-request overhead.
2. **Unnecessary exposure**: The full PEM reveals subject DN, SAN, issuer chain, serial number, and validity period — more PKI detail than the backend needs. The thumbprint reveals nothing about the certificate structure.
3. **Sufficient for validation**: The backend only needs to answer "does the presenting client cert match `cnf.x5t#S256`?" The thumbprint is sufficient for that comparison.
4. **Consistent**: The thumbprint is the same value embedded in the token — the backend directly compares two identical values without re-parsing a certificate.

## Full validation path trace

```
Client cert presented at TLS handshake
    ↓
Gateway computes x5t#S256 = base64url(sha256(DER cert))
    ↓
Gateway forwards: X-Client-Cert-Thumbprint: <x5t#S256>
    ↓
Backend introspects token → receives cnf.x5t#S256 from AS
    ↓
Backend asserts: X-Client-Cert-Thumbprint == cnf.x5t#S256
    ↓
Match → 200; Mismatch → 401 (token stolen, cert not present)
```
