# Lab Day 09 — Solution

## HTTP response explanations

### Phase 1 — 200 OK on balance read

The initial access token carries `acr=urn:openid:params:acr:classes:password` (single-factor: password only). The balance read endpoint requires no elevated authentication. The RS validates: token signature, expiry, scope — all pass. Response: 200 OK.

### Phase 2 — 401 on high-value payment

The RS receives a payment request for €1,500 to a new payee. It queries the TRA engine:
- Amount (€1,500) exceeds the bank's TRA exemption threshold for single-factor sessions
- Payee IBAN is not in the user's trusted beneficiary list
- No other applicable exemption (not low-value, not recurring)

Result: SCA is required. The token's `acr` claim is insufficient for this operation. RS returns:

```
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer error="insufficient_user_authentication",
  error_description="SCA required",
  acr_values="urn:openid:params:acr:mfa"
```

The three `WWW-Authenticate` parameters and what each instructs the client:

| Parameter | Meaning | Client action |
|---|---|---|
| `error="insufficient_user_authentication"` | Current token's ACR level is too low for this operation | Discard the current token for this operation; do not retry with it |
| `error_description="SCA required"` | Human-readable reason | Display to developer/log; do not present to end user |
| `acr_values="urn:openid:params:acr:mfa"` | The minimum ACR level required | Use this value in the step-up authorization request |

### Phase 3 — `max_age=0` in the step-up request

`max_age=0` instructs the AS to require the user to authenticate immediately, regardless of any existing session. Without `max_age=0`, the AS might satisfy the request using a recent session where the user already authenticated — but with only a password. The bank cannot rely on an existing session for SCA compliance; the user must actively perform both factors now, bound to this specific payment. `max_age=0` removes any possibility of session reuse.

### Phase 4 — Token claims comparison

| Claim | Initial token | Step-up token |
|---|---|---|
| `acr` | `urn:openid:params:acr:classes:password` | `urn:openid:params:acr:mfa` |
| `amr` | `["password"]` | `["mfa", "swk"]` |
| `authorization_details` | absent | present (amount=1500, payee=IBAN) |
| `dynamic_link_verified` | absent | `true` |
| `exp` | longer (e.g., 3600s) | shorter (e.g., 300s) |

The RS checks the `acr` claim to verify the authentication strength. `urn:openid:params:acr:mfa` confirms that at least two independent factors were used. The RS also checks that the `authorization_details` in the token match the payment being submitted — this is the dynamic link check.

---

## Dynamic linking — concrete explanation

The payment body contains: `amount=1500.00`, `creditorAccount.iban=<PLACEHOLDER-new-payee-iban>`.

During the step-up flow, the AS passed both values to the authentication app (via the `authorization_details` parameter in the PAR). The authentication app:
1. Showed the user: "Approve payment of €1,500.00 to IBAN `<PLACEHOLDER-new-payee-iban>`"
2. Generated an authentication code derived from: `HMAC(device-private-key, amount="1500.00" || iban="<PLACEHOLDER-new-payee-iban>" || timestamp)`
3. The code is valid only for this amount and this payee.

The AS verified the code. The token carries `authorization_details` with the amount and payee locked in.

The RS, on receiving the payment retry, checks:
- `token.authorization_details.amount == payment_body.instructedAmount.amount` → match
- `token.authorization_details.creditorAccount.iban == payment_body.creditorAccount.iban` → match

If an attacker intercepts the code and tries to use it for a different amount (e.g., €15,000 instead of €1,500):
- The code does not match (the HMAC input differs)
- The token's `authorization_details` would carry the original €1,500 — the RS would reject the mismatched payment body

If the attacker tries to use the step-up token for a different payee:
- The `authorization_details.creditorAccount.iban` in the token is locked to the original payee IBAN
- The RS rejects the payment body with a different IBAN

Dynamic linking makes the authentication inseparable from the specific transaction it authorised.

---

## SCA exemptions — quick reference for this lab

For the €1,500 payment in this lab:

| Exemption | Applicable? | Reason |
|---|---|---|
| Low-value payment | No | €1,500 >> €30 |
| TRA | Depends | Only if bank fraud rate < 0.01% (€500 cap); €1,500 exceeds even the maximum TRA cap |
| Trusted beneficiary | No | Payee is new, not whitelisted |
| Recurring | No | This is a first payment to this payee |

Conclusion: SCA is mandatory for this payment. No exemption applies.
