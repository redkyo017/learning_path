# Day 14 Lab — CIBA Sequence Diagrams (IS 7.3)

## Diagram 1: CIBA Poll Mode (IS 7.3 default)

The IS 7.3 CIBA endpoint is `POST /oauth2/ciba`. Poll mode is active when no
`client_notification_endpoint` is registered in the application's CIBA settings.
The client polls `POST /oauth2/token` using the CIBA grant type.

```mermaid
sequenceDiagram
    participant B as Call Centre Backend
    participant IS73 as WSO2 IS 7.3<br/>/oauth2/ciba
    participant TE as IS 7.3 Token Endpoint<br/>/oauth2/token
    participant CP as IS 7.3 Consent Portal
    participant M as Customer Mobile App

    Note over B,IS73: Step 1 — Backchannel auth request
    B->>IS73: POST /oauth2/ciba<br/>Content-Type: application/x-www-form-urlencoded<br/><br/>scope=openid payments<br/>login_hint=customer@bank.com<br/>binding_message=PAY-8821<br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    IS73->>IS73: Validate client (private_key_jwt)<br/>Look up user by login_hint<br/>Store auth_req_id in session store<br/>Set expiry = now + ciba_auth_req_expiry_seconds

    IS73-->>B: 200<br/>{auth_req_id:"<PLACEHOLDER>", expires_in:120, interval:5}

    Note over IS73,M: Step 2 — IS 7.3 triggers consent on user device
    IS73->>CP: Create consent request for user
    CP->>M: Push notification: "PAY-8821 — Approve €500 payment?"

    Note over B,TE: Step 3 — Client polls token endpoint every 5 seconds
    B->>TE: POST /oauth2/token<br/>grant_type=urn:openid:params:grant-type:ciba<br/>auth_req_id=<PLACEHOLDER><br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>
    TE-->>B: 400<br/>{error:"authorization_pending"}

    B->>TE: POST /oauth2/token (poll 2, 5s later)
    TE-->>B: 400<br/>{error:"authorization_pending"}

    Note over M,IS73: Step 4 — User approves on mobile app
    M->>IS73: User taps Approve (binding_message verified: PAY-8821)
    IS73->>IS73: Bind auth_req_id to authorization grant<br/>auth_req_id state = APPROVED

    Note over B,TE: Step 5 — Next poll succeeds
    B->>TE: POST /oauth2/token (poll 3)
    TE->>TE: auth_req_id state = APPROVED<br/>Issue access_token + id_token<br/>Mark auth_req_id as CONSUMED

    TE-->>B: 200<br/>{access_token, id_token, token_type:"Bearer", expires_in:3600}
```

---

## Diagram 2: CIBA Push Mode (IS 7.3 with notification endpoint)

Push mode is activated by setting delivery mode to `push` in the IS 7.3 application CIBA
configuration AND registering an HTTPS `client_notification_endpoint`. IS 7.3 delivers tokens
directly — no polling required.

```mermaid
sequenceDiagram
    participant B as Call Centre Backend
    participant IS73 as WSO2 IS 7.3<br/>/oauth2/ciba
    participant CP as IS 7.3 Consent Portal
    participant M as Customer Mobile App
    participant N as Client Notification Endpoint<br/>https://backend.bank.com/ciba/notify

    Note over B,IS73: Step 1 — Backchannel auth request (identical to poll mode)
    B->>IS73: POST /oauth2/ciba<br/>scope=openid payments<br/>login_hint=customer@bank.com<br/>binding_message=PAY-8821<br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    IS73->>IS73: Validate client<br/>Look up user<br/>Detect push mode (notification endpoint registered)<br/>Store auth_req_id

    IS73-->>B: 200<br/>{auth_req_id:"<PLACEHOLDER>", expires_in:120}
    Note over IS73: No interval field — push mode does not require polling

    Note over IS73,M: Step 2 — IS 7.3 triggers consent on user device
    IS73->>CP: Create consent request for user
    CP->>M: Push notification: "PAY-8821 — Approve €500 payment?"

    Note over M,IS73: Step 3 — User approves on mobile app
    M->>IS73: User taps Approve (binding_message verified: PAY-8821)
    IS73->>IS73: Issue access_token + id_token<br/>auth_req_id state = CONSUMED

    Note over IS73,N: Step 4 — IS 7.3 pushes tokens to notification endpoint
    IS73->>N: POST https://backend.bank.com/ciba/notify<br/>Content-Type: application/json<br/>Authorization: Bearer <client_notification_token><br/><br/>{<br/>  auth_req_id: "<PLACEHOLDER>",<br/>  access_token: "<PLACEHOLDER>",<br/>  token_type: "Bearer",<br/>  expires_in: 3600,<br/>  id_token: "<PLACEHOLDER>"<br/>}

    N->>N: MUST validate Authorization: Bearer header<br/>before trusting the payload

    N-->>IS73: 200 OK

    Note over B,N: Backend processes the token received at its notification endpoint
    Note over B: No polling loop required — zero token endpoint load from polling
```

---

## Diagram 3: auth_req_id lifecycle state machine

```mermaid
flowchart TD
    A([POST /oauth2/ciba received]) --> B[CREATED\nauth_req_id stored\nexpiry set]
    B --> C{User response?}
    C -->|No response yet| D[PENDING\nauthorization_pending\non poll]
    D --> C
    C -->|expires_in elapsed| E[EXPIRED\nexpired_token\nreturned on poll]
    C -->|User rejects| F[REJECTED\naccess_denied\nreturned on poll]
    C -->|User approves| G[APPROVED\ntoken issuable]
    G -->|Poll mode: client polls| H[CONSUMED\ntoken issued\nauth_req_id invalidated]
    G -->|Push mode: IS 7.3 pushes| H
    E --> I([Flow terminated])
    F --> I
    H --> I
```
