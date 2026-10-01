# Day 20 Lab — IS 7.3 + APIM 4.7 Key Manager Config

**Goal:** Configure APIM 4.7 to use IS 7.3 as Key Manager for org-scoped token validation.

**Success signal:** You can identify the three integration endpoints (introspect, JWKS, DCR)
in `config/apim_keymanager.toml` and explain what APIM uses each one for.

## Steps

1. Open `config/apim_keymanager.toml` and read all annotated fields.
2. Identify which field controls JWT local validation vs. introspection-based validation.
3. Trace an org-scoped token through the APIM gateway — which field enables `org_id` enforcement?
4. Answer the questions below, then check your understanding against `SOLUTION.md`.

## Questions

**Q1:** APIM receives a request with a JWT access token. Which endpoint in `apim_keymanager.toml`
does APIM use to validate it, and how often does APIM actually contact IS 7.3?

**Q2:** A partner's token contains `org_id: "org-abc"`. Which field in `[apim.key_manager.configuration]`
tells APIM what claim to read for the organization identifier?

**Q3:** IS 7.3 rotates its signing key. What happens to JWT validation in APIM immediately after
the rotation? What field controls how long before APIM picks up the new key?

**Q4:** A developer generates an API key in the APIM Developer Portal. Which IS 7.3 endpoint does
APIM call to create the OAuth2 client, and what protocol does it use?

**Q5 (upgrade scenario):** You have an existing `[apim.key_manager]` block with `type = "IsKeyManager"`
pointing to IS 2.x. You are upgrading to IS 7.3. List the minimum changes needed to the
`deployment.toml` key manager section.

## Reference: endpoint summary table

| APIM action | IS 7.3 endpoint | When |
|---|---|---|
| JWT validation | `/oauth2/jwks` | Every JWT (cached, ~1h) |
| Opaque token validation | `/oauth2/introspect` | Every opaque token request |
| Client registration (DCR) | `/api/identity/oauth2/dcr/v1.1/register` | At subscription key generation |
| Token generation (APIM internal calls) | `/oauth2/token` | APIM service account tokens |
| Token revocation | `/oauth2/revoke` | Key deletion in Dev Portal |
