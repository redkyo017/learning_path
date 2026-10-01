# Day 04 — CIBA Flow Diagrams

## Poll Mode

```mermaid
sequenceDiagram
    participant B as Backend (Consumption Device)
    participant AS as Authorization Server
    participant M as Mobile App (Auth Device)

    B->>AS: POST /bc-authorize<br/>login_hint=user@bank.com<br/>binding_message=PAY-4821<br/>scope=openid payments<br/>authorization_details=[{...}]
    AS-->>B: 200 {auth_req_id: "0c7839a1...", expires_in: 120, interval: 5}

    AS->>M: Push notification: "Approve PAY-4821"

    Note over B,AS: Poll #1 (5 seconds after bc-authorize)
    B->>AS: POST /token<br/>grant_type=urn:openid:params:grant-type:ciba<br/>auth_req_id=0c7839a1...
    AS-->>B: 400 {error: authorization_pending}

    Note over M: User opens app, sees PAY-4821, taps Approve
    M->>AS: User approves auth_req_id=0c7839a1...

    Note over B,AS: Poll #2 (5 seconds later)
    B->>AS: POST /token<br/>grant_type=urn:openid:params:grant-type:ciba<br/>auth_req_id=0c7839a1...
    AS-->>B: 200 {access_token, id_token, token_type: Bearer}
```

## Push Mode

```mermaid
sequenceDiagram
    participant B as Backend (Consumption Device)
    participant AS as Authorization Server
    participant M as Mobile App (Auth Device)
    participant N as Notification Endpoint

    B->>AS: POST /bc-authorize<br/>login_hint=user@bank.com<br/>binding_message=PAY-9173<br/>scope=openid payments
    AS-->>B: 200 {auth_req_id: "f3a2b1c0...", expires_in: 120}

    AS->>M: Push notification: "Approve PAY-9173"

    Note over M: User opens app, sees PAY-9173, taps Approve
    M->>AS: User approves auth_req_id=f3a2b1c0...

    Note over AS,N: No polling — AS pushes tokens directly
    AS->>N: POST /client/notify<br/>Authorization: Bearer client_notification_token<br/>{access_token, id_token, auth_req_id: f3a2b1c0...}
    N-->>AS: 200 OK
```

## Key differences

| Aspect | Poll mode | Push mode |
|--------|-----------|-----------|
| Token delivery | Client polls until approval | AS pushes to notification endpoint |
| Infrastructure | No endpoint required | Requires `client_notification_endpoint` |
| Load at 1,000 sessions | ~200 req/s polling | ~1 req per approval |
| Security requirement | Standard token endpoint | Notification endpoint must validate bearer token |
