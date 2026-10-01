# Day 18 Lab — SOLUTION

## Answers to `consent_api.http` questions

### Step 1 (PAR with authorization_details)

**Why is `authorization_details` sent in a PAR body rather than in the browser URL?**
`authorization_details` for a payment initiation request contains sensitive data: the creditor's IBAN,
the payment amount, the debtor's account. If sent as a query parameter in the browser URL, it appears
in: browser history, server access logs, Referer headers, network proxies, and click-tracking scripts.
PAR sends the full authorization request body directly to IS 7.3 over TLS (server to server). IS 7.3
returns an opaque `request_uri` — a short, single-use reference. The browser URL carries only the
`request_uri`, containing no sensitive data. This is one of the core PAR threat model wins (see Day 2).

**What does IS 7.3 return, and how does the TPP use it?**
IS 7.3 returns `{"request_uri": "urn:ietf:params:oauth:request_uri:<id>", "expires_in": 90}`.
The TPP redirects the user's browser to the authorization endpoint with `?request_uri=<value>&client_id=<id>`.
IS 7.3 looks up the stored PAR object (including `authorization_details`) and uses it to drive the
authorization flow. The `request_uri` is single-use and expires after 90 seconds.

### Step 2 (Consent portal)

**How does the consent portal template access `creditorName` from `authorization_details`?**
IS 7.3 passes `authorization_details` as a URL-encoded query parameter (or POST param) on the redirect
to `/authenticationendpoint/oauth2_consent.do`. In the Jaggery/JSP template:
```javascript
var authDetails = JSON.parse(request.getParameter("authorization_details"));
var paymentEntry = authDetails.find(function(e) { return e.type === "payment_initiation"; });
var creditorName = paymentEntry ? paymentEntry.creditorName : "";
```
The template reads the JSON, finds the entry with the matching `type`, and extracts the field.

**What happens in IS 7.3 after the user clicks "Approve"?**
The consent portal POSTs the user's approval back to IS 7.3 (via the `sessionDataKey` form field).
IS 7.3 creates a consent record in its consent management store with: `sub` = the authenticated user,
`client_id` = the TPP's client, `consentType` = "payment_initiation", `state` = "ACTIVE", and
`consentAttributes` = the structured fields from `authorization_details`. IS 7.3 then issues an
authorization code to the TPP's redirect URI.

### Step 3 (List consents)

**What fields does IS 7.3 return in the consent record?**
`consentId`, `userId`, `clientId`, `consentType` (matching `authorization_details.type`), `state`
(ACTIVE/REVOKED), `createdTime`, `updatedTime`, and `consentAttributes` (the structured data from
the original `authorization_details` — amounts, IBANs, creditor name, etc.).

**Which field links this consent to the `authorization_details` type?**
`consentType` — it is set to the `type` field from the `authorization_details` object (e.g.,
`"payment_initiation"`). This is the key for selective revocation: to revoke only payment initiation
consent while preserving account information consent, the admin looks for the record where
`consentType == "payment_initiation"` and DELETEs that specific `consentId`.

### Step 4 (Consent revocation)

**What state does the consent record move to?**
The consent record moves from `ACTIVE` to `REVOKED` (or the record is deleted, depending on IS 7.3
configuration). A `GET` on the consent record after revocation returns `"state": "REVOKED"`.

**Is the existing access token immediately invalid after revocation?**
No. IS 7.3 does not proactively invalidate issued access tokens when consent is revoked. Access tokens
are self-contained JWTs — the resource server validates them locally by checking the signature and `exp`
claim, not by calling IS 7.3 on every request. The access token remains valid until its `exp` time.
Only the refresh token grant is blocked (IS 7.3 checks consent state at grant time). This is why
payment tokens must have very short lifetimes (≤ 15 minutes, or ideally a single-use with no refresh
token for `payment_initiation` type).

### Step 5 (Refresh token after revocation)

**What does IS 7.3 check before issuing a new access token?**
IS 7.3 looks up the consent record linked to the refresh token (stored at issuance time). It checks
the `state` field. If `state == REVOKED`, IS 7.3 rejects the grant.

**HTTP status and error code:**
`HTTP 400 Bad Request`, `{"error": "consent_revoked", "error_description": "Consent has been revoked"}`.

## Stretch exercise answers

**1. Can the TPP use the access token for the next 2 minutes?**
Yes. The access token is a signed JWT. The resource server validates it by checking IS 7.3's public key
signature and the `exp` claim. The resource server does not call IS 7.3 on every request (no token
introspection in the typical FAPI flow). Consent revocation does not invalidate already-issued tokens
on the resource server. The TPP can use the access token for up to 2 more minutes despite revocation.
This is the gap between consent revocation and token expiry — a design trade-off between performance
(avoid introspection on every call) and immediate revocation enforcement.

**2. What happens when the TPP tries to refresh after 2 minutes?**
`POST /oauth2/token` with `grant_type=refresh_token` returns `HTTP 400` with `error=consent_revoked`.
IS 7.3 checks the linked consent at grant time. The TPP cannot get a new access token without a new
user authorization flow (new consent).

**3. What design decision does this reveal?**
For `payment_initiation` consent, access tokens should be:
- **Short-lived**: 15 minutes or less, reducing the window where a revoked consent still has an active token
- **Single-use where possible**: some PSD2 implementations issue access tokens with no refresh token for
  `payment_initiation` — the payment is executed in one request, then the consent is expired. There is
  nothing to refresh. IS 7.3 can be configured to issue `payment_initiation` tokens with `expires_in` of
  60–300 seconds and no `refresh_token`, ensuring that revocation takes effect within one token lifetime.
