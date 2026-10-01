# Day 14 Lab — Solution

## The three configuration changes to switch from poll to push mode

### Change 1: `deployment.toml` — enable CIBA globally

This change is **already required for poll mode** — it is not new for push. If poll mode is working,
this is already in place:

```toml
[oauth.ciba]
enabled = true
ciba_auth_req_expiry_seconds = 120
ciba_auth_req_id_poll_interval = 5
```

**What fails without it:** `POST /oauth2/ciba` returns `400 {"error": "unsupported_grant_type"}`.
IS 7.3 does not recognise the CIBA endpoint at all.

---

### Change 2: Application setting — `deliveryMode = "push"`

Set in IS 7.3 Console (Application → Protocol → CIBA → Token Delivery Mode) or via the
Management API:

```json
"cibaParameters": {
  "deliveryMode": "push"
}
```

**What fails without it:** Even if `clientNotificationEndpoint` is registered, IS 7.3 uses
the delivery mode field to decide whether to poll or push. With `deliveryMode = "poll"` (default),
IS 7.3 holds the grant internally and waits for the client to poll. The notification endpoint
URL is ignored. The bank continues running poll loops, generating the same load as before.

---

### Change 3: Application setting — `clientNotificationEndpoint`

Set in IS 7.3 Console (Application → Protocol → CIBA → Client Notification Endpoint) or via
the Management API:

```json
"cibaParameters": {
  "deliveryMode": "push",
  "clientNotificationEndpoint": "https://backend.bank.com/ciba/notify"
}
```

**What fails without it:** IS 7.3 cannot deliver the token on approval because it has no
destination URL. IS 7.3 returns a registration validation error if push mode is selected but
the endpoint URL is absent or is HTTP (not HTTPS).

**What fails if HTTP is used:** IS 7.3 rejects the application registration with a validation
error. The token payload (including `access_token`) would be sent in plaintext, which is
directly exploitable by network-layer interception.

---

## auth_req_id lifecycle — what IS 7.3 does in each mode

### Poll mode lifecycle

1. `POST /oauth2/ciba` → IS 7.3 stores `auth_req_id` in its server-side session store (Carbon
   registry or RDBMS). State: PENDING.
2. Each `POST /oauth2/token` poll → IS 7.3 checks state. Returns `authorization_pending` while PENDING.
3. User approves → IS 7.3 sets state to APPROVED.
4. Next poll → IS 7.3 issues token, sets state to CONSUMED. Auth_req_id is now invalid.
5. Any further poll with the same `auth_req_id` → IS 7.3 returns `400 invalid_grant`.

### Push mode lifecycle

1. `POST /oauth2/ciba` → same as poll mode. State: PENDING.
2. **No polling loop runs** — the client waits for a POST to its notification endpoint.
3. User approves → IS 7.3 issues the token immediately, POSTs it to `client_notification_endpoint`.
4. State → CONSUMED. No token endpoint call is needed.

**Key insight:** In push mode, the client never calls `POST /oauth2/token` with the CIBA grant type.
The token arrives at the notification endpoint. The `auth_req_id` in the push payload lets the backend
correlate the token to the original payment request it initiated.

---

## `client_notification_token` validation

IS 7.3 sends `Authorization: Bearer <client_notification_token>` in the push delivery POST.
This token is issued by IS 7.3 and tied to the specific `auth_req_id`.

**The notification endpoint must:**

1. Parse the `Authorization: Bearer` header.
2. Introspect the `client_notification_token` with IS 7.3 (`POST /oauth2/introspect`).
3. Verify `active: true` and that the token's claims match the expected client.
4. Only then process the `access_token` in the push payload.

**What fails without validation:** Any party that discovers the notification endpoint URL can POST
a forged payload with a fabricated `access_token`. The backend would process a fraudulent payment
approval. This is a common misconfiguration in push-mode CIBA deployments.

---

## Summary table

| Config item | Location | Poll mode | Push mode |
|-------------|----------|-----------|-----------|
| `[oauth.ciba] enabled = true` | `deployment.toml` | Required | Required (no change) |
| `deliveryMode` | IS 7.3 application | `"poll"` (default) | **`"push"`** |
| `clientNotificationEndpoint` | IS 7.3 application | Not needed | **HTTPS URL required** |
| Token delivery | Runtime | Client polls `/oauth2/token` | IS 7.3 POSTs to notification endpoint |
| Token endpoint load | Runtime | `n_agents × 1/interval` req/s | `n_approvals_per_second` only |
