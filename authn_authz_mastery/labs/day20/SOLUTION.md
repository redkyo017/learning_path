# Day 20 Lab — Solution

## Three integration endpoints and what APIM uses them for

| Endpoint | Purpose | Frequency |
|---|---|---|
| `jwks_url` | Fetch IS 7.3 public keys for local JWT signature verification | Cached (hourly) — not per-request |
| `introspect_url` | Validate opaque tokens and get token metadata (`scope`, `org_id`, `cnf`, `active`) | Per API request with opaque token |
| `client_registration_url` (DCR) | Register OAuth2 client when developer generates API keys in Dev Portal | Once per application key generation |

## Q1: JWT validation endpoint and contact frequency

APIM uses `jwks_url` for JWT validation. It calls `GET /oauth2/jwks` on IS 7.3 and caches the
response for `JWKSCacheTTL` seconds (default: 3600s = 1 hour). APIM verifies JWT signatures
locally using the cached public keys — it does **not** call IS 7.3 on every JWT request when
`EnableLocalJWTValidation = true`. IS 7.3 is only contacted when the JWKS cache expires or is
manually flushed.

## Q2: Field that enables org_id enforcement

`OrgIdClaimName = "org_id"` in `[apim.key_manager.configuration]`.

This field tells APIM which claim in the JWT (or introspection response) carries the organization
identifier. APIM reads the value of that claim and uses it to look up the org's API subscription.

## Q3: JWT validation after IS 7.3 key rotation

Immediately after IS 7.3 rotates its signing key, APIM still holds the **old** JWKS in cache.
APIM will reject valid JWTs signed with the new IS 7.3 key with "JWT signature verification failed"
for up to `JWKSCacheTTL` seconds (default: 1 hour).

`JWKSCacheTTL` is the controlling field. Mitigation: lower `JWKSCacheTTL` before rotation, or
flush APIM's JWKS cache via the Admin REST API after rotation. Opaque token flows are unaffected.

## Q4: Client registration endpoint and protocol

APIM calls `client_registration_url`: `POST /api/identity/oauth2/dcr/v1.1/register` on IS 7.3.
The protocol is **OAuth 2.0 Dynamic Client Registration (DCR)** as defined in RFC 7591 / OIDC
Dynamic Client Registration. IS 7.3 registers the OAuth2 client and returns `client_id` and
`client_secret` (or public key reference for `private_key_jwt` clients).

This endpoint is called once per "Generate Keys" action in the APIM Developer Portal — not on
every API request.

## Q5: Minimum changes for IS 2.x → IS 7.3 upgrade

The minimum changes to `deployment.toml`:

1. **Change `type`** from the old value (e.g., `"IsKeyManager"`) to `"WSO2-IS"`. This is the
   single most important change — it selects the native IS 7.3 connector.

2. **Update `introspect_url`** from the old IS-KM WAR path (e.g., `/keymanager-operations/validate-token`)
   to `/oauth2/introspect`. This is the most commonly missed update.

3. **Update `client_registration_url`** from any old DCR path to
   `/api/identity/oauth2/dcr/v1.1/register` (IS 7.3 uses DCR v1.1).

4. **Update `jwks_url`** to `/oauth2/jwks` if it was previously absent or pointed elsewhere.

5. **Update `token_url`** and `revoke_url`** to IS 7.3's standard `/oauth2/token` and
   `/oauth2/revoke` paths.

6. **Add `OrgIdClaimName`** if deploying B2B org-scoped tokens (IS 7.3 feature, absent in IS 2.x).

## Which field controls JWT local validation vs. introspection-based validation

`EnableLocalJWTValidation = true` — when set, APIM verifies JWT tokens locally using cached JWKS
without calling IS 7.3 per-request. For opaque tokens, APIM always calls `introspect_url`
regardless of this setting.

## How `org_id` flows to subscription enforcement

1. Partner receives IS 7.3 org-scoped token with `org_id: "org-abc"` claim.
2. APIM gateway reads the claim named in `OrgIdClaimName` (here: `"org_id"`) from the JWT payload
   or introspection response.
3. APIM looks up the subscription record for org `"org-abc"` against the requested API.
4. If no subscription exists for `org-abc`, APIM returns 403.
5. If subscribed, APIM adds `X-Org-ID: org-abc` header to the backend request.
6. Backend applies org-specific data isolation using the `X-Org-ID` header — without re-parsing
   the token.

## Upgrade gotcha: IS 2.x connector vs IS 7.3 native

The old IS 2.x Key Manager used a separate `wso2is-km.war` deployed on Identity Server. IS 7.3
removed this WAR — Key Manager integration is built into IS 7.3 natively via the
`KeyManagerConnector` extension.

After upgrade:
1. Delete the old `[apim.key_manager]` section pointing to the IS-KM WAR
2. Replace with the native IS 7.3 `[[apim.key_manager]]` config with `type = "WSO2-IS"`
3. Update all five endpoint URLs to IS 7.3 native paths

Failure to update causes APIM to call the old IS-KM endpoints (gone in IS 7.3), receiving 404s on
every token validation call — all API requests return 401.
