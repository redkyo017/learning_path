# FAPI 2.0 Banking Quick Reference

Quick-reference card for FAPI 2.0 Security Profile requirements, comparison with FAPI 1.0, PSD2 SCA exemption thresholds, and key RFC references for all Phase 1 protocols.

---

## Mandatory requirements (FAPI 2.0 Security Profile)

| Requirement | Value |
|-------------|-------|
| Authorization endpoint | PAR mandatory (`require_pushed_authorization_requests: true`) |
| Response type | `code` only — hybrid flows (`code id_token`) not allowed |
| Response mode | `jwt` (JARM) — signed authorization response required |
| PKCE | Required; S256 only — plain PKCE not allowed |
| Client auth | `private_key_jwt` or `tls_client_auth` — no `client_secret_*` |
| Token signing alg | PS256 or ES256 — RS256 explicitly disallowed |
| Token binding | DPoP (RFC 9449) or mTLS (RFC 8705) — plain Bearer not sufficient for FAPI 2.0 |
| `request_uri` TTL | ≤ 90 seconds from PAR response to authorization endpoint redirect |
| `state` | Required in authorization request; must be verified in JARM response |
| `nonce` | Required in OIDC flows; must appear in ID token |
| `iss` | Required in JARM response JWT; TPP must verify against registered issuer |

---

## FAPI 2.0 vs FAPI 1.0 comparison

| Feature | FAPI 1.0 Baseline | FAPI 1.0 Advanced | FAPI 2.0 |
|---------|------------------|------------------|---------|
| PAR | Optional | Recommended | **Mandatory** |
| PKCE | Optional | Required | **Required (S256 only)** |
| JARM | Not required | Optional | **Mandatory** |
| Client auth | `client_secret_jwt` allowed | `private_key_jwt` required | `private_key_jwt` or mTLS |
| `response_type` | `code id_token` allowed | `code id_token` allowed | **`code` only** |
| `request` object | Optional | Required | Superseded by PAR |
| Token binding | Not required | Not required | **DPoP or mTLS required** |
| `acr_values` | No requirement | Recommended | Implementation-defined |
| RAR support | No | No | Recommended for PSD2 |

---

## PSD2 SCA exemption thresholds (RTS on Strong Customer Authentication)

| Exemption | Threshold / Condition |
|-----------|----------------------|
| Low-value contactless (in-person) | ≤ €50/transaction AND (cumulative ≤ €150 OR ≤ 5 consecutive non-SCA transactions) |
| Low-value remote electronic payment | ≤ €30/transaction AND (cumulative ≤ €100 OR ≤ 5 consecutive non-SCA transactions) |
| TRA (Transaction Risk Analysis) — low risk | ≤ €100 if PSP fraud rate < 0.13% |
| TRA (Transaction Risk Analysis) — medium risk | ≤ €250 if PSP fraud rate < 0.06% |
| TRA (Transaction Risk Analysis) — high threshold | ≤ €500 if PSP fraud rate < 0.01% |
| Trusted beneficiary | Any amount if payee whitelisted by PSU with SCA |
| Recurring transaction | Same amount AND same payee AND first transaction used SCA |
| Corporate / B2B payment | Corporate PSU with dedicated payment instruments and risk processes |
| Secure corporate payment processes | B2B transactions where ASPSP risk controls are accepted by regulator |

**Important:** TRA exemptions apply to AIS (account information) and PIS (payment initiation) with the fraud-rate conditions met. For payment initiation above €30 with a new payee, SCA is generally mandatory regardless of TRA. Dynamic linking is always required for PIS when SCA is performed (RTS Art. 5).

---

## Key RFC and specification references

| Protocol | RFC / Specification |
|----------|---------------------|
| PAR | RFC 9126 |
| RAR | RFC 9396 |
| DPoP | RFC 9449 |
| mTLS Client Auth + Certificate-Bound Tokens | RFC 8705 |
| PKCE | RFC 7636 |
| JARM | openid-financial-api-jarm (OpenID Foundation) |
| CIBA | openid-client-initiated-backchannel-authentication-core-1_0 (OpenID Foundation) |
| SCIM Core Schema | RFC 7643 |
| SCIM Protocol | RFC 7644 |
| OBO / Token Exchange | RFC 8693 |
| JWT Bearer Assertion | RFC 7523 |
| JWT Confirmation Method (`cnf`) | RFC 7800 |
| FAPI 2.0 Security Profile | openid-fapi-2_0-security-profile (OpenID Foundation) |
| FAPI 2.0 Message Signing | openid-fapi-2_0-message-signing (OpenID Foundation) |
| OAuth 2.0 Token Revocation | RFC 7009 |
| OAuth 2.0 Token Introspection | RFC 7662 |
| JWT (JSON Web Token) | RFC 7519 |
| JWS (JSON Web Signature) | RFC 7515 |
| JWK (JSON Web Key) | RFC 7517 |

---

## FAPI 2.0 AS discovery metadata (key fields)

A FAPI 2.0-compliant AS must advertise these values in its OpenID Connect Discovery document (`.well-known/openid-configuration`):

```json
{
  "require_pushed_authorization_requests": true,
  "pushed_authorization_request_endpoint": "https://as.bank.com/par",
  "authorization_response_iss_parameter_supported": true,
  "response_modes_supported": ["jwt"],
  "response_types_supported": ["code"],
  "code_challenge_methods_supported": ["S256"],
  "token_endpoint_auth_methods_supported": [
    "private_key_jwt",
    "tls_client_auth",
    "self_signed_tls_client_auth"
  ],
  "dpop_signing_alg_values_supported": ["PS256", "ES256"],
  "tls_client_certificate_bound_access_tokens": true,
  "authorization_details_types_supported": [
    "payment_initiation",
    "account_information"
  ]
}
```

---

## Common FAPI 2.0 configuration errors

| Error | Symptom | Fix |
|-------|---------|-----|
| `require_pushed_authorization_requests` not set | TPPs bypass PAR and send params on redirect URL | Set `require_pushed_authorization_requests: true`; reject `/authorize` requests without `request_uri` |
| `response_mode` not enforced as `jwt` | AS returns plain `code` in redirect — no JARM | Enforce `response_mode=jwt` on all authorization requests |
| PKCE not restricted to S256 | `plain` PKCE accepted — weak protection | Restrict `code_challenge_methods_supported` to `["S256"]` |
| `RS256` token signing allowed | Weaker algorithm in production | Configure token endpoint to reject or not offer `RS256`; require `PS256` or `ES256` |
| DPoP/mTLS not enforced | Plain Bearer tokens accepted | Require `token_type=DPoP` or validate `cnf.x5t#S256` on every protected resource request |
