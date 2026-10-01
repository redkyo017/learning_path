# Day 03 Lab — Solution

## Field-by-field annotation

### Payment initiation object

| Field | Written by | Read by | Missing = |
|-------|-----------|---------|-----------|
| `type: "payment_initiation"` | TPP | AS (consent UI), RS (enforcement) | Unknown object type — server must reject |
| `instructedAmount` | TPP | AS (consent display), RS (amount check) | No amount constraint — token authorises any amount |
| `creditorAccount.iban` | TPP | AS (consent display), RS (payee check) | No payee constraint — token authorises payment to anyone |
| `creditorName` | TPP | AS (consent display UI only) | Consent UI shows blank payee name |
| `remittanceInformationUnstructured` | TPP | RS (payment reference) | Payment has no reference |

### Standing order (recurring payment) example

```json
{
  "type": "standing_order",
  "instructedAmount": {
    "currency": "EUR",
    "amount": "50.00"
  },
  "frequency": "Monthly",
  "startDate": "2026-10-01",
  "endDate": "2027-09-30",
  "dayOfExecution": "01",
  "creditorAccount": {
    "iban": "GB29NWBK60161331926819"
  },
  "creditorName": "Acme GmbH"
}
```

The `type` value (`standing_order`) is the key differentiator. The auth server must know this `type` and its schema to render a meaningful consent UI. If the server does not recognise the `type`, it must reject with `invalid_authorization_details`.
