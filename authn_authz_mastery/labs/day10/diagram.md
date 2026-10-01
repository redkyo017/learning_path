# Phase 1 Capstone Diagram — Full PSD2 Payment Flow

This is the grand composite diagram for Phase 1. Every protocol covered in Days 01–09 appears here in a single coherent flow. Study this diagram until you can reproduce it from memory — it is the mental model for everything in Phase 2 and Phase 3.

## Full PSD2 Payment Initiation — All Protocols

```mermaid
sequenceDiagram
    autonumber
    participant TPP as TPP Client<br/>(Third-Party Provider)
    participant AS as Authorization Server<br/>(ASPSP / Bank AS)
    participant PSU as User Browser
    participant App as User Banking App<br/>(Authentication Device)
    participant RS as Payment API<br/>(Resource Server)

    rect rgb(230, 244, 255)
    Note over TPP,AS: STEP A — PAR (RFC 9126)<br/>Authorization parameters pushed off the front channel
    TPP->>AS: POST /par<br/>Content-Type: application/x-www-form-urlencoded<br/>Authorization: (private_key_jwt — FAPI 2.0 client auth)<br/>response_type=code<br/>scope=payments<br/>code_challenge=<S256 hash> (PKCE — RFC 7636)<br/>authorization_details=[{type:"payment_initiation",<br/>  instructed_amount:{amount:100,currency:"EUR"},<br/>  creditor_account:"DE89..."}] (RAR — RFC 9396)
    AS-->>TPP: HTTP 201 Created<br/>{"request_uri":"urn:ietf:params:oauth:request_uri:abc",<br/> "expires_in":60}
    end

    rect rgb(255, 248, 220)
    Note over TPP,PSU: STEP B — FAPI 2.0 front-channel<br/>Only request_uri on the URL — params never in browser
    TPP->>PSU: HTTP 302 Redirect<br/>/authorize?client_id=tpp123&request_uri=urn:…
    PSU->>AS: GET /authorize?client_id=tpp123&request_uri=urn:…
    end

    rect rgb(240, 255, 240)
    Note over AS: STEP C — Consent lifecycle (PSD2 RTS Art. 66/67)<br/>Consent object created and linked to authorization_details
    AS->>AS: Resolve request_uri → retrieve PAR params<br/>Create consent record:<br/>  consentId=cst-001<br/>  authorization_details=[{type:"payment_initiation",...}]<br/>  status=AwaitingAuthorisation
    end

    rect rgb(255, 235, 235)
    Note over AS,App: STEP D — SCA (PSD2 RTS Art. 4 + Dynamic Linking Art. 5)<br/>User must authenticate with 2 factors; approval bound to this transaction
    AS->>App: Push / display consent screen:<br/>"Approve payment: €100 to DE89... ref:XR99"<br/>(binding_message = dynamic linking element)
    App-->>PSU: Display: Amount=€100, Payee=DE89..., Ref=XR99<br/>(content matches authorization_details — tamper-evident)
    PSU->>App: Approve (factor 1: device possession, factor 2: biometric)
    App-->>AS: SCA complete — acr=urn:openid:params:acr:mfa<br/>consent status → Authorised
    end

    rect rgb(248, 230, 255)
    Note over AS,PSU: STEP E — JARM (openid-financial-api-jarm)<br/>Authorization response integrity-protected as signed JWT
    AS-->>PSU: HTTP 302 Redirect<br/>/callback?response=<signed JWT><br/>(JWT contains: code, state, iss, aud, exp — PS256 signed)
    PSU->>TPP: Deliver JARM response JWT
    TPP->>TPP: Verify JWT: sig, iss, aud, exp, state<br/>Extract authorization_code
    end

    rect rgb(255, 248, 220)
    Note over TPP,AS: STEP F — Token exchange<br/>PKCE verifier proves code legitimacy; DPoP binds token to TPP key
    TPP->>AS: POST /token<br/>grant_type=authorization_code<br/>code=<extracted from JARM JWT><br/>code_verifier=<original random value — PKCE><br/>DPoP: <DPoP proof JWT: typ=dpop+jwt, htm=POST,<br/>  htu=https://as.bank.com/token, jti=unique, iat=now><br/>Authorization: (private_key_jwt — FAPI 2.0)
    AS->>AS: Verify PKCE (code_verifier matches code_challenge)<br/>Verify private_key_jwt client auth<br/>Verify DPoP proof (htm, htu, jti uniqueness)<br/>Issue access token:<br/>  cnf.jkt = DPoP key thumbprint<br/>  authorization_details embedded in claims<br/>  aud=https://api.bank.com/payments
    AS-->>TPP: {"access_token":"eyJ...", "token_type":"DPoP", ...}
    end

    rect rgb(230, 244, 255)
    Note over TPP,RS: STEP G — Payment API call<br/>DPoP proof binds this specific request to the token
    TPP->>RS: POST /payments<br/>Authorization: DPoP eyJ...<br/>DPoP: <DPoP proof JWT: htm=POST,<br/>  htu=https://api.bank.com/payments,<br/>  ath=base64url(SHA256(access_token)),<br/>  jti=new-unique, iat=now>
    RS->>AS: (Optional) Introspect or validate JWT locally
    RS->>RS: Validate DPoP proof:<br/>  ath == base64url(SHA256(access_token)) ✓<br/>  htm == POST ✓<br/>  htu == /payments ✓<br/>  jti not in replay cache ✓<br/>Check authorization_details:<br/>  type == "payment_initiation" ✓<br/>  amount == 100 EUR ✓ (matches request body)<br/>  creditor_account == request body payee ✓<br/>Check consent status == Authorised ✓
    RS-->>TPP: HTTP 201 Created<br/>{"paymentId":"pmt-xyz", "status":"AcceptedSettlementInProcess"}
    end
```

## Protocol map

| Protocol | Where it appears | Security guarantee |
|----------|-----------------|-------------------|
| PAR (RFC 9126) | Step A | Authorization parameters never on browser URL |
| PKCE (RFC 7636) | Step A (challenge), Step F (verify) | Authorization code interception protection |
| RAR (RFC 9396) | Step A | Fine-grained authorization data (amount, payee) |
| FAPI 2.0 client auth | Step A, Step F | Client authenticates without shared secrets |
| Consent lifecycle | Step C | PSD2-compliant consent object, traceable lifecycle |
| SCA — Dynamic Linking | Step D | SCA approval cryptographically bound to this transaction |
| JARM | Step E | Authorization response tamper protection |
| DPoP (RFC 9449) | Step F (bind), Step G (prove) | Token bound to TPP key; replay protection per request |

## What to study

- Trace the `authorization_details` object from Step A through to Step G — it must survive every step intact.
- Note that DPoP has two moments: key binding at token issuance (Step F, `cnf.jkt`) and proof-of-possession at each API call (Step G, `ath`).
- The JARM JWT (Step E) and the DPoP proof JWT (Step G) are different JWT types with different claims — do not confuse them.
- SCA dynamic linking (Step D) happens before the authorization code is issued — the user approves the specific transaction, not a generic login.
