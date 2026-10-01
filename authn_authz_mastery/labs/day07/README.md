# Lab Day 07 — SCIM 2.0 Provisioning

## Goal

Annotate SCIM PATCH operations for two provisioning lifecycle events:
1. User deactivation and group membership removal (offboarding)
2. User re-activation and group membership restoration (re-joining)

## What you will practise

- Reading and writing the SCIM PatchOp envelope (`schemas`, `Operations`)
- Distinguishing `replace`, `remove`, and `add` operations
- Understanding why `DELETE` is avoided in regulated environments
- Using `externalId` to enable idempotent re-provisioning

## Files

| File | Purpose |
|---|---|
| `config/scim_user_patch.json` | Two annotated SCIM PATCH operation payloads |
| `diagram.md` | Mermaid sequence diagram of the full SCIM provisioning lifecycle |
| `SOLUTION.md` | Field-by-field explanations and the audit log entry format |

## Exercise

1. Open `config/scim_user_patch.json`.
2. For the first PATCH object (offboarding), write down in plain English what each `Operations` entry does.
3. For the second PATCH object (re-activation), identify which attributes are being restored and why the `externalId` check must happen before this call.
4. Draw the sequence of SCIM calls the SCIM client must make to fully offboard a user (search → patch user → patch group). Verify against `diagram.md`.
5. Answer: why is `active=false` preferred over `DELETE /Users/{id}` in a regulated bank environment?

## Success signal

You can write SCIM PATCH operations for the three most common provisioning events — create, deactivate, group-membership change — without referring to the spec, and you can explain the compliance reason for each design choice.
