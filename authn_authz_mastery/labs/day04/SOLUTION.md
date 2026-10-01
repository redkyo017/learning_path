# Day 04 Lab — Solution

## Step 2: POST /bc-authorize field explanations

| Field | Purpose |
|-------|---------|
| `client_id` | Identifies the consumption device (call centre backend) to the AS |
| `scope=openid payments` | Requests the OIDC and payment scopes; the resulting token will have access to payment APIs |
| `login_hint=user@bank.com` | Identifies which user the AS should send the authentication push to; opaque to the TPP |
| `binding_message=PAY-4821` | Short human-readable code shown on BOTH the bank UI (consumption device) AND the user's mobile app — links the two devices so the user can verify they are approving the correct transaction |
| `authorization_details` | RAR payload specifying what is being authorised (payment amount, currency) — shown to the user in the mobile app push notification |
| `client_assertion_type` + `client_assertion` | `private_key_jwt` client authentication — form body params, not an Authorization header |

## Step 3: /bc-authorize response field explanations

| Field | Meaning |
|-------|---------|
| `auth_req_id` | Opaque identifier for this backchannel auth request; used in all subsequent polling calls |
| `expires_in: 120` | The user has 120 seconds to approve on their mobile before this request expires; after expiry, the client receives `expired_token` on the next poll |
| `interval: 5` | The minimum number of seconds the client must wait between polls; polling faster returns `slow_down` |

## Step 4: Poll mode — authorization_pending

`authorization_pending` means: the `auth_req_id` is valid and has not expired, but the user has not yet authenticated on their mobile app. The client should continue polling at the `interval` cadence.

Polling stops when:
- User approves → 200 token response
- User rejects → `access_denied`
- Request expires → `expired_token`
- Client polls too fast → `slow_down` (must increase interval)

## Step 5: Successful token response

After user approval, the token response is a standard OAuth2 token response. Key differences from a normal authorization code flow:
- The grant type used was `urn:openid:params:grant-type:ciba` (not `authorization_code`)
- There was no redirect; the call centre backend polled directly
- The `id_token` carries the user's identity, confirming who authenticated on the mobile app

## Why binding_message is shown to the user

The binding message links the consumption device session to the authentication device session. Without it:
1. Attacker sees user X is about to receive a legitimate CIBA request
2. Attacker initiates their own CIBA request for user X (fraudulent payment)
3. User receives two push notifications; no way to tell which is legitimate
4. User approves one — 50% chance it is the fraudulent one

With `binding_message=PAY-4821`:
- Call centre agent says: "you will see PAY-4821 on your app — only approve if you see that code"
- The legitimate request shows PAY-4821; the attacker's request shows a different code
- User sees the mismatch and rejects the attacker's request
- This is the CIBA equivalent of transaction dynamic linking (SCA requirement under PSD2)
