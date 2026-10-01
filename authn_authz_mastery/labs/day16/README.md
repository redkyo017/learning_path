# Day 16 Lab — B2B Organization Management in IS 7.3

**Goal:** Trace the IS 7.3 organization management API calls and org-scoped token flow
for a B2B partner onboarding scenario. Identify the four API calls needed to go from
zero to a partner user receiving an org-scoped token.

**Success signal:** You can list the four sequential API/configuration steps for onboarding
a B2B partner in IS 7.3, explain why the `org_id` claim in a sub-org token prevents the
partner from accessing another org's resources, and describe what happens when the organization
switch grant is used.

---

## Files in this lab

| File | Purpose |
|------|---------|
| `config/org_management_api.http` | Annotated HTTP exchanges: create sub-org, register IdP, org switch grant, org-scoped token claims |
| `diagram.md` | IS 7.3 org hierarchy and partner user authentication sequence diagram |
| `SOLUTION.md` | Step-by-step B2B onboarding guide + org_id enforcement explanation |

---

## Steps

### 1. Read the annotated HTTP file

Open `config/org_management_api.http`. This file contains:

- `POST /o/api/identity/organization-mgt/v1.0/organizations` — create a sub-org.
- The Management API call to register a federated IdP at the sub-org level.
- `POST /o/{orgId}/oauth2/token` — obtain an org-scoped token.
- `POST /oauth2/token` with `grant_type=...organization_switch` — switch org context.
- A sample org-scoped JWT decoded payload showing `org_id` and `iss`.

### 2. Identify the four B2B onboarding steps

Without looking at `SOLUTION.md`, list the four steps (in order) needed to go from a
fresh IS 7.3 instance to a partner user obtaining an org-scoped token. For each step,
note which IS 7.3 API endpoint or Console section is involved.

### 3. Analyse org_id enforcement

Using the sample JWT in `config/org_management_api.http`, answer:

- What is different about the `iss` claim in a sub-org token vs. a root-org token?
- If a resource server only validates the JWT signature and `exp` but not `org_id`,
  what attack does it become vulnerable to?

### 4. Trace the organization switch grant

Using `diagram.md`, trace what happens when a sub-org user switches to root-org context:

- What is the `subject_token` in the switch grant request?
- Does the user re-authenticate? Where does IS 7.3 check that the switch is permitted?
- What does the resulting token's `org_id` look like?

### 5. Check your answers

Compare to `SOLUTION.md`.

---

## Environment notes

No live IS 7.3 instance is required for this lab. If using a local IS 7.3 Docker instance,
the organization management API requires super-admin credentials and is accessible at:

```
https://localhost:9443/o/api/identity/organization-mgt/v1.0/
```

Replace `<PLACEHOLDER>` values with your actual org IDs and tokens before running live requests.
Never commit real tokens or org IDs to version control.
