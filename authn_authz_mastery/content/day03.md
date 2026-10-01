# Day 03 — RAR: Rich Authorization Requests

## Why this matters

A European bank deployed a PSD2 payment initiation API secured with `scope=payments`. The scope string was a boolean gate: if the token had the `payments` scope, the API accepted any payment instruction in the request body. A token issued for a €0.01 test payment could be used to initiate a €50,000 wire transfer — the API had no way to enforce per-transaction limits because the token contained no transaction-specific data. When a TPP was compromised and its tokens stolen, the attacker made 37 transfers totalling €2.1 million before the bank noticed the anomaly. The root cause: the authorisation artefact (the token) did not carry the authorisation details (what was actually consented to).

RAR (Rich Authorization Requests, RFC 9396) exists to carry structured, transaction-specific authorisation data from the consent capture all the way into the token, so that the resource server can enforce exactly what the user approved — no more, no less.

## Core concepts

### RFC 9396: the `authorization_details` parameter

RAR introduces the `authorization_details` parameter: a JSON array of one or more authorisation objects. Each object describes a specific, structured authorisation the client is requesting:

```json
[
  {
    "type": "payment_initiation",
    "instructedAmount": { "currency": "EUR", "amount": "250.00" },
    "creditorAccount": { "iban": "GB29NWBK60161331926819" },
    "creditorName": "Acme GmbH",
    "remittanceInformationUnstructured": "Invoice INV-2026-0042"
  }
]
```

### The required `type` field

Every `authorization_details` object must have a `type` field. This is a string that acts as a namespace, identifying the schema of the rest of the object. The authorization server uses `type` to:
- Route the object to the correct consent handler
- Render the appropriate consent UI
- Validate the object's fields against the registered schema for that type

If a server does not recognise a `type`, it must reject the request with `error=invalid_authorization_details`.

### Banking-specific `type` values

**`payment_initiation`** — for PSD2 payment orders:

```json
{
  "type": "payment_initiation",
  "instructedAmount": {
    "currency": "EUR",
    "amount": "250.00"
  },
  "creditorAccount": {
    "iban": "GB29NWBK60161331926819"
  },
  "creditorName": "Acme GmbH",
  "remittanceInformationUnstructured": "Invoice INV-2026-0042"
}
```

**`account_information`** — for PSD2 account data access:

```json
{
  "type": "account_information",
  "access": {
    "accounts": [{ "iban": "DE89370400440532013000" }],
    "balances": [{ "iban": "DE89370400440532013000" }],
    "transactions": [{ "iban": "DE89370400440532013000" }]
  },
  "recurringIndicator": false,
  "validUntil": "2026-12-31",
  "frequencyPerDay": 4
}
```

### Comparison with scope strings

Scope-based access control for structured data is a hack. Consider the alternatives:

| Approach | What the token says | RS enforcement |
|----------|-------------------|----------------|
| `scope=payments` | "This client can make payments" | None — amount, payee, account unconstrained |
| `scope=payments:write:iban:DE89...:EUR:100` | Encoding fields into the scope string | Brittle, non-standard, unreadable, no schema |
| `authorization_details` (RAR) | Structured JSON with typed fields and values | RS reads fields directly, checks amount, IBAN, payee |

Scope strings cannot carry complex, structured data in a machine-parseable, interoperable way. RAR is the correct solution for per-transaction authorisation constraints.

### How `authorization_details` survives into the access token

The authorization server includes the consented `authorization_details` in the token response. For JWT access tokens, it appears as a top-level claim:

```json
{
  "sub": "user123",
  "iss": "https://auth.bank.example.com",
  "aud": "https://api.bank.example.com",
  "exp": 1785600000,
  "authorization_details": [
    {
      "type": "payment_initiation",
      "instructedAmount": { "currency": "EUR", "amount": "250.00" },
      "creditorAccount": { "iban": "GB29NWBK60161331926819" },
      "creditorName": "Acme GmbH"
    }
  ]
}
```

For opaque tokens, the same data is returned in the token introspection response.

### RAR + PAR interaction

The `authorization_details` parameter belongs in the PAR POST body, not in a redirect URL. The parameter can be large (multiple objects, long IBANs, base64 data) and highly sensitive (payment amounts, account numbers). PAR's back-channel POST is the correct transport. Never send `authorization_details` in a redirect URL.

### Resource server enforcement

The resource server reads `authorization_details` from the token (or introspection response) and compares each relevant field against the actual request body:

1. Find the `authorization_details` object with `"type": "payment_initiation"`.
2. Compare `instructedAmount.currency` and `instructedAmount.amount` against the payment request body.
3. Compare `creditorAccount.iban` against the requested payee IBAN.
4. Compare `creditorName` against the payee name in the request.
5. If any field mismatches: return `403 Forbidden`. Log the discrepancy. Do not process the payment.

This prevents a token issued for a €1 verification payment being used for a €10,000 transfer.

### Downscoping

The authorization server can grant a subset of the requested `authorization_details`. This is called downscoping. The server issues a token with fewer or narrower permissions than the client requested.

Example: a TPP requests `account_information` access with `accounts`, `balances`, and `transactions`. The user consents only to `balances`. The server issues a token with:

```json
{
  "type": "account_information",
  "access": {
    "balances": [{ "iban": "DE89370400440532013000" }]
  }
}
```

The TPP receives the downscoped `authorization_details` in the token response and knows to update its consent record accordingly.

### Authorization details flow diagram

```mermaid
sequenceDiagram
    participant TPP as TPP Client
    participant PAR as PAR Endpoint
    participant AS as Authorization Server
    participant U as User
    participant TE as Token Endpoint
    participant RS as Payments API

    TPP->>PAR: POST /par<br/>authorization_details=[{type:payment_initiation,<br/>instructedAmount:{EUR,250.00},<br/>creditorAccount:{iban:GB29...},<br/>creditorName:Acme GmbH}]
    PAR-->>TPP: {request_uri, expires_in}

    TPP->>U: Redirect with request_uri
    U->>AS: Authenticate + review consent UI
    Note over AS,U: Consent UI shows: Pay Acme GmbH EUR 250.00<br/>(rendered from authorization_details)
    U->>AS: Approve
    AS->>AS: Store consent record linked to auth_code<br/>Bind authorization_details to consent

    AS-->>TPP: Auth code (JARM)
    TPP->>TE: POST /token + code + code_verifier
    TE-->>TPP: {access_token with authorization_details embedded}

    TPP->>RS: POST /payments<br/>Authorization: Bearer access_token<br/>Body: {amount: EUR 250.00, creditorIban: GB29...}
    RS->>RS: Read authorization_details from token<br/>Compare body fields vs token claims
    Note over RS: Amount matches? Payee matches? IBAN matches?
    RS-->>TPP: 201 Payment accepted or 403 if mismatch
```

## Anti-patterns / Common mistakes

- **Encoding authorization details in custom scope strings**: Scope strings are not machine-parseable structured data. Encoding `amount:250:EUR:iban:GB29...` into a scope string is brittle, breaks interop with third-party authorization servers, cannot be validated against a schema, and produces unmaintainable scope explosion. RAR is the standard.

- **Omitting `authorization_details` from the access token (only keeping it server-side)**: Some implementations store the consent details in a server-side database and issue tokens without the `authorization_details` claim, expecting the resource server to call back to the consent store. This creates a distributed state dependency. The RS must be able to enforce limits from the token alone (or introspection response). `authorization_details` must travel with the token.

- **Using a single global `type` namespace per organisation**: Defining one `type` like `"bank_access"` for all authorisation scenarios leads to bloated objects with dozens of optional fields and ambiguous semantics. Use distinct `type` values per resource type: `payment_initiation`, `account_information`, `standing_order`, `direct_debit_mandate`. Each type has a clear, documented schema.

## Exercises

1. Write an `authorization_details` array for a PSD2 payment initiation of €250.00 from IBAN DE89370400440532013000 to creditor "Acme GmbH" IBAN GB29NWBK60161331926819.

   **Hint:** Use the `payment_initiation` type. Include `instructedAmount` and `creditorAccount`.

   **Solution sketch:**
   ```json
   [
     {
       "type": "payment_initiation",
       "instructedAmount": { "currency": "EUR", "amount": "250.00" },
       "creditorAccount": { "iban": "GB29NWBK60161331926819" },
       "creditorName": "Acme GmbH",
       "remittanceInformationUnstructured": "Invoice INV-2026-0042"
     }
   ]
   ```

2. A resource server receives an access token. It needs to verify that the token authorises exactly the payment described in the request body. What claim does it read, and what fields does it check?

   **Hint:** The RS reads `authorization_details` from the introspection response or JWT payload.

   **Solution sketch:** The RS reads the `authorization_details` array and finds the object with `"type": "payment_initiation"`. It checks `instructedAmount.currency`, `instructedAmount.amount`, `creditorAccount.iban`, and `creditorName` against the request body. If any field mismatches, the RS rejects with 403. This prevents a token issued for a €1 payment being used for a €10,000 one.

3. Explain what "downscoping" means in the context of RAR and give a concrete banking example of when a server would downscope an `authorization_details` request.

   **Hint:** The authorisation server can grant less than what was requested.

   **Solution sketch:** Downscoping means the server issues a token with a subset of the requested `authorization_details`. Example: a TPP requests access to `accounts`, `balances`, and `transactions` for a customer's account. The customer consents only to `balances`. The server issues a token with `"access": {"balances": [...]}` only, omitting `accounts` and `transactions`. The TPP receives the downscoped `authorization_details` in the token response and knows to update its consent UI accordingly.

## Lab

See `labs/day03/`. Goal: annotate an `authorization_details` JSON and trace how it flows from the PAR request to the resource server enforcement check. Success signal: you can write valid `authorization_details` for a payment initiation and an account information request from memory.
