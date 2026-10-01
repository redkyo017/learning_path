# Day 16 Lab — Solution

## The four B2B onboarding steps (in order)

### Step 1: Create the sub-organization

```
POST /o/api/identity/organization-mgt/v1.0/organizations
{name: "PartnerBankXYZ", parentId: "<root_org_id>"}
```

**What fails without it:** No sub-org context exists. IS 7.3 has no `org_id` to embed in tokens,
no sub-org-specific token endpoint, and no place to register the partner's federated IdP.

### Step 2: Register the federated IdP at the sub-org level

```
POST /o/{orgId}/api/server/v1/identity-providers
{name: "PartnerBankXYZ-Okta", type: "OIDC", ...}
```

Registered at `/o/{orgId}/api/server/v1/identity-providers` (sub-org path).

**What fails without it:** Partner users have no IdP to authenticate against in the sub-org.
IS 7.3 would fall back to its default (LOCAL) identity store, which has no partner user accounts.
Authentication fails.

**What fails if registered at root-org instead:** The Okta IdP becomes globally visible across
ALL sub-orgs. Any user at PartnerBankXYZ's Okta can authenticate into any sub-org. This breaks
the isolation model entirely.

### Step 3: Share the application to the sub-org

```
POST /o/{orgId}/api/server/v1/applications/{appId}/share
```

Alternatively, configure at root level to share to all sub-orgs.

**What fails without it:** The sub-org has no enabled application. Partner users cannot initiate
an OAuth2 authorization flow against the sub-org — the client_id is not recognised.

### Step 4: Partner user authenticates and obtains org-scoped token

Partner user hits `/o/{orgId}/oauth2/authorize`, IS 7.3 redirects to the sub-org's Okta IdP,
user authenticates, IS 7.3 issues a token from `/o/{orgId}/oauth2/token` with `org_id` embedded.

**What fails without the sub-org token endpoint path:** Using the root-org token endpoint
(`/oauth2/token`) issues a root-org token without the partner's sub-org `org_id`. The partner
would effectively have root-org access context — a serious privilege escalation.

---

## Why `org_id` prevents cross-org access

The `iss` claim of a sub-org token is:

```
https://identity.bank.com/o/<sub_org_id>/oauth2/token
```

A root-org token has:

```
https://identity.bank.com/oauth2/token
```

A correctly configured resource server validates:

1. JWT signature (standard).
2. `iss` matches the expected issuer for this resource server's org context.
3. `org_id` matches the expected sub-org ID.

If a partner at `org-abc123` tries to use their token against a resource server that only accepts
`org_id: org-def456`, the `org_id` check fails and the request is rejected with `403`.
If the resource server only checks signature and `exp` (ignoring `org_id`), it would accept any
valid sub-org token regardless of which org issued it — cross-org access attack.

---

## The `iss` claim difference between sub-org and root-org tokens

| Token type | `iss` example |
|------------|---------------|
| Sub-org token | `https://identity.bank.com/o/org-abc123/oauth2/token` |
| Root-org token | `https://identity.bank.com/oauth2/token` |

Resource servers should validate `iss` against their expected issuer. A sub-org resource server
that accepts root-org tokens (or vice versa) breaks the isolation boundary.

---

## Organization switch grant — what IS 7.3 does

1. Receives `grant_type=...organization_switch` with `token=<current_token>` and
   `switching_organization=<target_org_id>`.
2. Validates the current token (active, not expired, signature valid).
3. Derives the user's identity from the token's `sub` claim.
4. Checks that the application is enabled in the target org.
5. Checks that the user has permission to access the target org (IS 7.3 org membership check).
6. Issues a new token scoped to the target org — new `iss`, new `org_id`, same `sub`.

**No re-authentication.** The user does not see a login page. Trust flows from the original
token. This is the IS 7.3 equivalent of RFC 8693 token exchange for org context switching.

**What fails if the application is not shared to the target org:** IS 7.3 returns `400` at
the switch grant — the target org does not recognise the client_id.

---

## IS 7.3 Organizations vs. tenants — summary

| Feature | IS 7.3 Organizations | IS 7.3 Tenants |
|---------|---------------------|----------------|
| Same IS 7.3 instance | Yes | Yes |
| Shared applications | Yes (root → sub-org) | No |
| Root admin sees all | Yes | No |
| Cross-org token exchange | Yes (org switch grant) | No |
| Per-org federated IdP | Yes | Yes (separate tenant config) |
| Audit log aggregation | Yes (root-org level) | No (per-tenant only) |
| Data isolation | Logical (org_id claim) | Strong (separate schema/store) |
| Use case | B2B collaboration | Strong regulatory isolation |
