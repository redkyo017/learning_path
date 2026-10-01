# Lab Day 08 — Solution

## Field-by-field explanation

| Field | Compliance role |
|---|---|
| `consentId` | Primary key — links to tokens, audit logs, consent receipts. Immutable. Without this, revocation cannot be targeted. |
| `access` | Defines exact scope — accounts, balances, transactions per IBAN. A regulator can verify the TPP accessed only what was consented. |
| `recurringIndicator` | Determines whether the 90-day re-authentication rule applies. True = AIS recurring = must renew within 90 days. |
| `validUntil` | Enforces the PSD2 RTS Article 10 time limit. The bank sets this; the TPP cannot request a date beyond 90 days from creation for AIS recurring. |
| `frequencyPerDay` | Enforces the PSD2 RTS Article 36 call frequency limit. Prevents a TPP from making excessive API calls under a single consent. |
| `consentStatus` | Current lifecycle state. Server-authoritative. The resource server must check this (or the linked token revocation list) on every API call. |
| `psuId` | Links the consent to the specific bank customer. Required for the bank's consent management portal — shows the user their active consents. |
| `tppId` | Scopes the consent to the TPP that created it. Prevents one TPP from using a consent granted to another. |
| `createdAt` | Immutable creation timestamp. Used to compute whether the 90-day window has been respected. |
| `authorisedAt` | Timestamp of user authorisation. Proves the PSU actively approved the consent (not just that the TPP created the object). |
| `revokedAt` | Timestamp of revocation. Proves revocation was immediate. A regulator can verify the gap between revocation trigger and token invalidation. |
| `revokedBy` | Actor who revoked: PSU or ASPSP. Determines which status name to use (`revokedByPsu` vs `revokedByAspsp`). |
| `revocationReason` | Why it was revoked. Required for fraud-triggered revocations (`FRAUD_DETECTED`) — provides the context for the audit trail. |
| `accessRights` | Immutable snapshot of the consented scope. Preserved even if the mutable `access` field is modified. The authoritative record of what the PSU agreed to. |
| `consentReceipt` | The document handed to the PSU at authorisation time. The bank retains this to prove informed consent was given. |
| `linkedTokenJtis` | The token IDs issued under this consent. The revocation list is built from this array — without it, token invalidation on revocation is impossible. |
| `modificationHistory` | Append-only audit trail of all status transitions. Reconstructs the full lifecycle for regulators. |

---

## State machine — ASCII diagram

```
[*] ---(POST /consents by TPP)---> received
        |
        +---(PSU authorises)---> valid
        |                         |
        +---(PSU declines)---> rejected ---> [*]
                                  |
                      +-----------+----------------+-------------------+
                      |                            |                   |
             (validUntil passed)           (PSU revokes)      (Bank revokes)
                      |                            |                   |
                   expired                  revokedByPsu        revokedByAspsp
                      |                            |                   |
                    [*]                          [*]                 [*]
```

All states other than `received` and `valid` are terminal — no transition out.

---

## Token revocation walkthrough

When `consentStatus` transitions to `revokedByPsu` or `revokedByAspsp`:

```
function revokeConsent(consentId, revokedBy, reason):
    consent = store.getConsent(consentId)
    
    if consent.consentStatus not in ["valid", "received"]:
        raise ConsentAlreadyTerminated(consentId)
    
    newStatus = "revokedByPsu" if revokedBy == "PSU" else "revokedByAspsp"
    now = currentTimestamp()
    
    store.updateConsent(consentId, {
        consentStatus: newStatus,
        revokedAt: now,
        revokedBy: revokedBy,
        revocationReason: reason,
        modificationHistory: append({
            timestamp: now,
            previousStatus: consent.consentStatus,
            newStatus: newStatus,
            actor: revokedBy,
            note: reason
        })
    })
    
    for jti in consent.linkedTokenJtis:
        tokenRevocationList.add(jti, expiresAt=consent.validUntil)
    
    if newStatus == "revokedByAspsp":
        notificationService.sendWebhook(consent.tppId, {
            event: "CONSENT_REVOKED",
            consentId: consentId,
            reason: reason,
            timestamp: now
        })
    
    return {consentId: consentId, newStatus: newStatus, tokensInvalidated: len(consent.linkedTokenJtis)}
```

Key points:
- Token revocation is **synchronous** — it happens as part of the revocation call, not asynchronously.
- The revocation list must be checked by all resource servers on every API call (not just at token issuance).
- The `linkedTokenJtis` array is the only reliable source of which tokens to invalidate — this is why storing it server-side is mandatory.
- `revokedByAspsp` sends a webhook; `revokedByPsu` may not (the PSU already knows they revoked it).

---

## Exercise answers

**Question 2 — Maximum `validUntil`**: PSD2 RTS Article 10 requires re-authentication at least every 90 days for AIS with `recurringIndicator: true`. Maximum `validUntil` = creation date + 90 days. The bank must enforce this programmatically and reject any TPP-requested `validUntil` that exceeds this ceiling.

**Question 4 — Expiry**: When the server clock passes `validUntil`, the consent's status transitions to `expired`. Linked access tokens return 401 on the next resource server call (the RS checks `validUntil` against the token's `exp` or the consent store's status). The TPP must initiate a new consent flow — it cannot extend the existing consent.
