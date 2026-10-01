# Protocol Decision Tree

Use this decision tree to determine which protocol combination to apply for a given banking use case. Start at the top and follow the branches that match your context. Appendix referenced by Day 10 and used throughout Phases 2 and 3.

---

## Is there a browser/redirect available?

**Yes → Standard OAuth2/OIDC redirect flow**
- FAPI 2.0 required? (regulated banking, PSD2, FAPI-certified AS) → **YES:** add PAR + JARM + PKCE (S256)
- Fine-grained authorization needed (payment amount, specific account, currency)? → **YES:** add RAR (`authorization_details`)
- Token replay protection needed beyond TLS? → **DPoP** (preferred for cloud APIs with TLS-terminating proxies) or **mTLS** (when TPP has PKI-enrolled certificate)

**No → CIBA (Client-Initiated Backchannel Authentication)**
- User has a mobile app → CIBA push or ping mode (AS pushes notification to app)
- User does NOT have a mobile app (batch/backend/call centre) → CIBA poll mode with `binding_message` displayed on consumption device
- SCA required for the operation? → YES (always for payment initiation): include `binding_message` matching `authorization_details` for dynamic linking

---

## Is the caller a human user or an institution?

**Human user (PSU — Payment Services User)**
- SCA required? (payments above threshold, new payee, first access in 90 days) → **YES:** require `acr_values=urn:openid:params:acr:mfa` + dynamic linking in consent screen or `binding_message`
- SCA exemption possible? → Check thresholds in `FAPI_BANKING_REFERENCE.md`: low-value, TRA, trusted beneficiary, recurring
  - TRA exemption: applies to AIS only (account information) — never to PIS (payment initiation) above low-value threshold
  - Trusted beneficiary: PSU must have previously whitelisted the payee
- Consent required? (PSD2 AIS/PIS) → **YES:** create consent object before auth; bind consent to `authorization_details`; set expiry (AIS max 90 days)

**Institution (TPP, partner bank, AI agent acting as service)**
- Client auth: `private_key_jwt` (FAPI 2.0, all environments) or `tls_client_auth` (PKI with eIDAS QWAC/QSEAL)
- No user-facing consent required → institution-level consent / contract-based authorization; use `authorization_details` to specify allowed accounts/operations
- User provisioning needed? → SCIM push provisioning from institution's IdP to bank's identity store
- AI agent calling on behalf of a user? → OBO token exchange (RFC 8693) — see Phase 3

---

## Is the token leaving the bank's internal network?

**No (internal service-to-service, same trust domain)**
- JWT Bearer Assertion (RFC 7523) → service presents private key JWT to token endpoint; client credentials grant
- No DPoP needed — internal mTLS on service mesh handles transport security
- No user SCA required

**Yes (external TPP, partner bank, AI agent, third-party API consumer)**
- Sender-constrained token mandatory:
  - **DPoP** (RFC 9449) → preferred for cloud API gateways, TLS-terminating proxies (Kong, AWS API Gateway, Azure APIM, Istio)
  - **mTLS** (RFC 8705) → preferred for institutional PKI-enrolled clients (eIDAS certificates, bank-to-bank)
  - Both simultaneously → allowed and recommended for highest assurance (mTLS for transport identity, DPoP for token binding)

---

## Which token binding method to choose?

| Criterion | Choose DPoP | Choose mTLS |
|-----------|-------------|-------------|
| Infrastructure | Cloud API gateway that terminates TLS | PKI with CA; cert forwarding works end-to-end |
| Key management | TPP self-manages key rotation without CA | Bank issues / validates client certificates via CA |
| TPP type | Small/medium TPP, cloud-native | Large institution, eIDAS-regulated, PKI-enrolled |
| Key rotation | Rotate without CA re-issuance | Requires CA re-issuance per rotation cycle |
| Proxy compatibility | Works through TLS-terminating proxy | Requires cert forwarding or mTLS passthrough |
| Regulatory evidence | Key thumbprint (`cnf.jkt`) in token | CA chain (`cnf.x5t#S256`) in token — stronger identity |

FAPI 2.0 allows either. In practice: use mTLS for institution-level clients; DPoP for TPP-level clients without PKI.

---

## Quick reference: which protocol for which threat

| Threat | Protocol |
|--------|----------|
| Auth params in browser history / logs | PAR (RFC 9126) |
| Authorization code interception | PKCE (RFC 7636) |
| Auth response tampering / substitution | JARM |
| Scope strings too coarse for PSD2 enforcement | RAR (RFC 9396) |
| No browser available (call centre, batch) | CIBA |
| Transaction substitution attack | SCA dynamic linking (PSD2 RTS Art. 5) |
| Bearer token theft / replay | DPoP (RFC 9449) or mTLS (RFC 8705) |
| No CA available for client cert | DPoP or `self_signed_tls_client_auth` |
| Manual / error-prone user provisioning | SCIM 2.0 (RFC 7643, RFC 7644) |
| Indefinite data access without re-consent | PSD2 consent lifecycle (Day 08) |
| Zombie access after user deprovisioning | SCIM deprovision → consent revocation cascade |
| AI agent calling on behalf of user | OBO token exchange (RFC 8693) — Phase 3 |
| Microservice calling another microservice | JWT Bearer Assertion (RFC 7523) |

---

## Phase 1 protocol stack summary

| Protocol | RFC / Spec | Phase 1 day |
|----------|-----------|-------------|
| FAPI 2.0 Security Profile | openid-fapi-2_0-security-profile | Day 01 |
| PAR | RFC 9126 | Day 02 |
| RAR | RFC 9396 | Day 03 |
| CIBA | openid-client-initiated-backchannel-authentication-core | Day 04 |
| DPoP | RFC 9449 | Day 05 |
| mTLS Client Auth + Certificate-Bound Tokens | RFC 8705 | Day 06 |
| SCIM 2.0 | RFC 7643, RFC 7644 | Day 07 |
| PSD2 Consent Management | PSD2 RTS Arts. 10–11 | Day 08 |
| SCA (Strong Customer Authentication) | PSD2 RTS Arts. 4–5 | Day 09 |
| Protocol Composition | — | Day 10 |
