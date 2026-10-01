# Day 11 — App-Native Auth Session State Machine

```mermaid
stateDiagram-v2
    [*] --> Initiated: POST /authenticate {clientId}
    Initiated --> Step1: flowStatus=INCOMPLETE, nextStep=BASIC
    Step1 --> Step2: credentials valid, nextStep=TOTP
    Step1 --> Step1: credentials invalid, flowStatus=FAIL_INCOMPLETE (retry allowed)
    Step2 --> Complete: TOTP valid, flowStatus=SUCCESS_COMPLETED
    Step2 --> Step2: TOTP invalid, flowStatus=FAIL_INCOMPLETE (retry allowed)
    Step1 --> Failed: max retries exceeded, flowStatus=FAIL_COMPLETED
    Step2 --> Failed: max retries exceeded, flowStatus=FAIL_COMPLETED
    Complete --> [*]: authCode issued
    Failed --> [*]: error returned to client
```

## Key session state transitions

| `flowStatus` | Meaning | App action |
|---|---|---|
| `INCOMPLETE` | More steps required | Submit next step credentials |
| `FAIL_INCOMPLETE` | Step failed, retry allowed | Prompt user, resubmit same step |
| `SUCCESS_COMPLETED` | All steps passed | Exchange `authCode` at `/oauth2/token` |
| `FAIL_COMPLETED` | Flow terminated (locked/expired) | New initiation required |
