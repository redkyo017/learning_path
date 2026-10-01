# Day 07 — SCIM Provisioning Lifecycle Diagram

## Full provisioning lifecycle: partner IdP → receiving bank

```mermaid
sequenceDiagram
    participant PIdP as Partner IdP
    participant SC as SCIM Client
    participant SS as Bank SCIM Server
    participant IS as Identity Store
    participant GS as Group Store
    participant AL as Audit Log

    note over PIdP,AL: Onboarding: new employee alice@partner.bank
    PIdP->>SC: New employee event (externalId=partner123, groups=[payment-approvers])
    SC->>SS: GET /Users?filter=externalId eq "partner123"
    SS->>IS: query by externalId
    IS-->>SS: 404 Not Found
    SS-->>SC: 200 OK, totalResults=0
    SC->>SS: POST /Users (userName, name, emails, externalId=partner123, active=true)
    SS->>IS: insert user record
    IS-->>SS: {id: "user-001", externalId: "partner123"}
    SS->>AL: log: user-001 created, actor=SCIM-client, timestamp
    SS-->>SC: 201 Created, id=user-001
    SC->>SS: PATCH /Groups/grp-payment-approvers (add member user-001)
    SS->>GS: add user-001 to payment-approvers
    GS-->>SS: updated
    SS->>AL: log: user-001 added to payment-approvers, timestamp
    SS-->>SC: 200 OK

    note over PIdP,AL: Offboarding: alice@partner.bank leaves
    PIdP->>SC: Termination event (externalId=partner123)
    SC->>SS: GET /Users?filter=externalId eq "partner123"
    SS->>IS: query by externalId
    IS-->>SS: {id: "user-001", active: true}
    SS-->>SC: 200 OK, id=user-001
    SC->>SS: PATCH /Users/user-001 (active=false)
    SS->>IS: set active=false
    IS-->>SS: updated
    SS->>AL: log: user-001 deactivated, timestamp
    SS-->>SC: 200 OK
    SC->>SS: PATCH /Groups/grp-payment-approvers (remove member user-001)
    SS->>GS: remove user-001 from payment-approvers
    GS-->>SS: updated
    SS->>AL: log: user-001 removed from payment-approvers, timestamp
    SS-->>SC: 200 OK

    note over PIdP,AL: Re-joining: same user returns 12 months later
    PIdP->>SC: New employee event (externalId=partner123)
    SC->>SS: GET /Users?filter=externalId eq "partner123"
    SS->>IS: query by externalId
    IS-->>SS: {id: "user-001", active: false}
    SS-->>SC: 200 OK, id=user-001 (found, inactive)
    SC->>SS: PATCH /Users/user-001 (active=true, update email if changed)
    SS->>IS: set active=true
    IS-->>SS: updated
    SS->>AL: log: user-001 re-activated, timestamp
    SS-->>SC: 200 OK
    SC->>SS: PATCH /Groups/grp-payment-approvers (add member user-001)
    SS->>GS: add user-001 to payment-approvers
    GS-->>SS: updated
    SS->>AL: log: user-001 re-added to payment-approvers, timestamp
    SS-->>SC: 200 OK
```

## Key observations

1. The SCIM client always checks for an existing user by `externalId` before creating — this prevents duplicate accounts on re-hire.
2. Group membership is managed on the `Group` resource, not the `User` resource. Two PATCH calls are always needed: one for the user, one for the group.
3. `DELETE /Users/{id}` is never called — `active=false` deactivates while preserving the audit record.
4. The audit log receives an entry at every lifecycle transition — this is the evidence trail for compliance reviews.
