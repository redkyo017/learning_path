# Day 13 Lab — Solution

## Three fields that enforce PAR, JARM, and private_key_jwt

| FAPI requirement | deployment.toml field | What IS 7.3 rejects without it |
|---|---|---|
| PAR mandatory | `[oauth] fapi_conformance_enabled = true` + app-level FAPI flag | Auth requests without `request_uri` → 400 |
| JARM | `[oauth.oidc.jarm] jarm_signing_algorithm = "PS256"` | `response_mode=query` or `fragment` → 400 |
| `private_key_jwt` only | `supported_client_auth_methods = ["private_key_jwt", "tls_client_auth"]` | `client_secret_basic` → 401 |

## Request IS 7.3 accepts vs. rejects

| Request | Accepted? | Reason |
|---|---|---|
| PAR POST with `client_assertion` in form body | Yes | `private_key_jwt` via form params ✓ |
| PAR POST with client_assertion in the `Authorization` header (not form body) | No | `private_key_jwt` must be form body, not a Bearer header |
| `/authorize` with `request_uri` | Yes | PAR used ✓ |
| `/authorize` with full params (no PAR) | No | FAPI mandates PAR |
| Auth response with `response_mode=jwt` | Yes | JARM ✓ |
| Auth response with `response_mode=query` | No | JARM mandatory in FAPI mode |

## Why `fapi_conformance_enabled` alone is not enough
Server-level FAPI flag enforces the constraints only for applications that have "FAPI Conformance"
checked in the Console. A non-FAPI app registered on the same IS 7.3 instance is not subject to
these constraints. This is by design: IS 7.3 supports mixed-mode (FAPI and non-FAPI apps) on one instance.
