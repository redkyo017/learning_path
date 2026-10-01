# Day 09 — SCA Step-Up Authentication Sequence Diagram

## Payment initiation → TRA evaluation → SCA step-up → authorisation

```mermaid
sequenceDiagram
    participant U as User / PSU
    participant CA as Client App
    participant RS as Payment Resource Server
    participant TRA as TRA Engine
    participant AS as Authorization Server
    participant DL as Dynamic Link Verifier

    note over U,DL: Phase 1 — Normal session (single-factor token)
    U->>CA: Normal API call (account balance)
    CA->>RS: GET /accounts (Bearer: initial-token, acr=password)
    RS-->>CA: 200 OK — balance returned

    note over U,DL: Phase 2 — High-value payment to new payee triggers step-up
    U->>CA: Initiate payment €1500 to new payee IBAN
    CA->>RS: POST /payments (Bearer: initial-token, acr=password)
    RS->>TRA: evaluate risk (amount=1500, newPayee=true, deviceRisk=low)
    TRA-->>RS: HIGH RISK — amount exceeds threshold, new payee, no SCA exemption applicable
    RS-->>CA: 401 Unauthorized (error=insufficient_user_authentication, acr_values=urn:openid:params:acr:mfa)

    note over U,DL: Phase 3 — Client initiates step-up OIDC flow
    CA->>AS: authorization request (acr_values=mfa, max_age=0, prompt=login, request_uri=PAR)
    AS->>U: SCA challenge — device (possession) + PIN (knowledge)
    U->>AS: PIN entered on device + biometric confirmation
    AS->>AS: generate dynamic link code (user-key + amount=1500 + payee-IBAN)
    AS->>DL: verify dynamic link (code, amount=1500, payee=IBAN)
    DL-->>AS: dynamic link valid
    AS-->>CA: authorization code

    note over U,DL: Phase 4 — Token exchange and payment retry
    CA->>AS: token request (code, code_verifier)
    AS-->>CA: step-up access token (acr=urn:openid:params:acr:mfa, amr=[mfa,swk], dynamicLink=verified)
    CA->>RS: POST /payments (Bearer: step-up-token, acr=mfa)
    RS->>RS: verify acr=mfa, verify dynamic link in token claims
    RS-->>CA: 201 Created — payment authorised
    CA->>U: Payment confirmed
```

## Phase annotations

| Phase | Authentication strength | What the RS checks |
|---|---|---|
| Normal API call | `acr=password` (single factor) | Token valid, not expired, scope matches |
| Payment 401 | — | Amount + new payee → TRA fails → SCA required |
| Step-up auth | `acr=urn:openid:params:acr:mfa` | Two independent factors completed, dynamic link generated |
| Payment retry | `acr=mfa`, dynamic link in token | `acr` meets requirement, dynamic link matches this payment's amount + payee |

## Dynamic linking — what binds the code to this payment

The step-up code is computed over `(user-device-key, payment-amount, payee-iban)`. If an attacker intercepts the code:

- Cannot reuse it for a different amount — the code does not validate against a different amount
- Cannot reuse it for a different payee — the code does not validate against a different IBAN
- Cannot reuse it tomorrow — the code includes a time component (TOTP-style)
- Cannot use it on a different device — the code is bound to the user's device private key
