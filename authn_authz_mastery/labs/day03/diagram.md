# Day 03 — Authorization Details Flow

```mermaid
sequenceDiagram
    participant TPP as TPP Client
    participant PAR as PAR Endpoint
    participant AS as Authorization Server
    participant U as User
    participant TE as Token Endpoint
    participant RS as Payments API

    TPP->>PAR: POST /par<br/>authorization_details=[{type:payment_initiation,<br/>instructedAmount:{EUR,250.00},<br/>creditorAccount:{iban:GB29...}}]
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
    RS->>RS: Introspect token, read authorization_details<br/>Compare body fields vs token claims
    Note over RS: Amount matches? Payee matches? IBAN matches?
    RS-->>TPP: 201 Payment accepted or 403 if mismatch
```
