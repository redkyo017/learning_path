# Lab Day 07 — Solution

## Why `DELETE` is avoided in regulated environments

`DELETE /Users/{id}` removes the user record from the identity store. In a banking context, this is dangerous for three reasons:

1. **Audit trail breakage**: Every access log, transaction record, and consent object references the user's internal `id`. A deleted user record orphans those references. A regulator asking "who approved this payment on date X?" receives a broken reference.

2. **Referential integrity**: Payment records, consent objects, and session logs store the user's `id` as a foreign key. Deleting the user breaks that relationship — joins fail, audit queries return nulls.

3. **Re-hire scenario**: If the same user returns, `POST /Users` assigns a new `id`. The new account has no history. The user appears as a brand-new subject in the audit system despite having years of prior activity.

**Correct approach**: `PATCH active=false`
- The account record is preserved.
- The user cannot log in (`active=false` is checked at every authentication attempt).
- Access tokens must still be explicitly invalidated (add `jti` to revocation list).
- All historical records remain intact and queryable.
- Re-hire is a single `PATCH active=true` — identity continuity is preserved.

---

## How `externalId` enables idempotent re-activation

The `externalId` field stores the partner IdP's identifier for the user — it is set once at provisioning and never changes, even across deactivation and re-activation cycles.

Re-hire sequence:
1. Partner IdP emits: new employee `partner123`.
2. SCIM client calls `GET /Users?filter=externalId eq "partner123"`.
3. SCIM server returns `{id: "user-001", active: false}` — user exists, was previously deprovisioned.
4. SCIM client calls `PATCH /Users/user-001` with `active=true` (and any attribute updates).
5. Result: same `id` ("user-001"), same audit history, no duplicate account.

Without `externalId`, the SCIM client would call `POST /Users`, the server would either reject the duplicate `userName` or create a new user with a new `id`. Either outcome loses the historical identity linkage.

---

## Annotation of `scim_user_patch.json`

### PATCH 1 — Offboarding

```
Operation 1: op=replace, path=active, value=false
```
Sets the user's `active` attribute to `false`. This is the single most important deprovisioning step — it prevents all further authentication. The bank's AS and IdP check `active` on every login attempt.

```
Operation 2: op=remove, path=groups, value=[{value: "<group-id>"}]
```
Removes the user from the `payment-approvers` group. Important caveat: in most SCIM implementations, the `groups` attribute on the `User` resource is **read-only** (it reflects group membership but cannot be written). The authoritative way to remove a user from a group is to PATCH the **Group** resource, not the User resource:

```
PATCH /Groups/<group-id>
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
  "Operations": [
    {
      "op": "remove",
      "path": "members[value eq \"<user-id>\"]"
    }
  ]
}
```

### PATCH 2 — Re-activation

```
Operation 1: op=replace, path=active, value=true
```
Re-enables the account. The user can now authenticate.

```
Operation 2: op=replace, path=emails[type eq "work"].value
```
Updates the work email using SCIM filter path syntax. This is the standard way to target a specific element of a multi-valued attribute.

```
Operation 3: op=replace, path=urn:...:EnterpriseUser:department
```
Updates the department using the `EnterpriseUser` extension path. The full URN is required as the path prefix when targeting extension attributes.

---

## Audit log entry format

A compliant SCIM server should generate an audit log entry at each lifecycle transition. Minimum required fields:

```json
{
  "eventId": "<PLACEHOLDER-uuid>",
  "eventType": "USER_DEACTIVATED",
  "timestamp": "<PLACEHOLDER-iso8601-timestamp>",
  "subjectId": "user-001",
  "subjectExternalId": "partner123",
  "actorType": "SCIM_CLIENT",
  "actorId": "<PLACEHOLDER-scim-client-id>",
  "changedAttributes": ["active"],
  "previousValues": {"active": true},
  "newValues": {"active": false},
  "requestId": "<PLACEHOLDER-request-correlation-id>"
}
```

A regulator reviewing this log can reconstruct the full deprovisioning timeline, the actor responsible, and the exact change made — without any ambiguity.

---

## Three most common SCIM provisioning events — quick reference

| Event | Method + Path | Key operation(s) |
|---|---|---|
| Create user | `POST /Users` | Full user object including `externalId` |
| Deactivate user | `PATCH /Users/{id}` + `PATCH /Groups/{id}` | `replace active=false` + `remove member` |
| Group membership change | `PATCH /Groups/{id}` | `add member` or `remove member` |
