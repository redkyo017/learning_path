# Day 16 Lab — B2B Organization Management Diagrams

## Diagram 1: IS 7.3 organization hierarchy

```mermaid
flowchart TD
    ROOT["IS 7.3 Super-tenant\n(Root Org: 'Bank Corp')\norg_id: root-org-id"]

    ROOT --> ORG_A["Sub-org: PartnerBankXYZ\norg_id: org-abc123\nIdentity store: FEDERATED\n→ PartnerBankXYZ Okta IdP"]
    ROOT --> ORG_B["Sub-org: FintechCo\norg_id: org-def456\nIdentity store: LOCAL\n(IS 7.3 manages users)"]
    ROOT --> ORG_C["Sub-org: InternalTeams\norg_id: org-ghi789\nIdentity store: LOCAL"]

    ROOT --> APP1["Shared App: FAPI-TPP-Client\n(registered at root-org level)\nread-only in all sub-orgs"]
    ROOT --> APP2["Shared App: AdminPortal\n(root-org only)"]

    ORG_A -.->|inherits shared apps\n(read-only)| APP1
    ORG_B -.->|inherits shared apps\n(read-only)| APP1

    ORG_A --> IDP_A["Federated IdP:\nPartnerBankXYZ Okta\n(registered at sub-org level only)"]
```

---

## Diagram 2: B2B partner user authentication and org-scoped token issuance

```mermaid
sequenceDiagram
    participant A as Root Org Admin<br/>(Bank IT team)
    participant IS as WSO2 IS 7.3<br/>Management API
    participant IdP as PartnerBankXYZ<br/>Okta IdP
    participant U as Partner User<br/>(Alice @ PartnerBankXYZ)
    participant TE as IS 7.3 Token Endpoint<br/>/o/org-abc123/oauth2/token
    participant RS as Bank Resource Server

    Note over A,IS: Step 1 — Create sub-org (one-time onboarding)
    A->>IS: POST /o/api/identity/organization-mgt/v1.0/organizations<br/>{name:"PartnerBankXYZ", parentId:"<root_org_id>"}
    IS-->>A: 201 {id:"org-abc123", status:"ACTIVE"}

    Note over A,IS: Step 2 — Register federated IdP at sub-org level
    A->>IS: POST /o/org-abc123/api/server/v1/identity-providers<br/>{name:"PartnerBankXYZ-Okta", type:"OIDC"<br/> issuer:"https://partnerbank.okta.com"<br/> clientId:"<PLACEHOLDER>", ...}
    IS-->>A: 201 {id:"idp-okta-xyz"}

    Note over A,IS: Step 3 — Share application to sub-org
    A->>IS: POST /o/org-abc123/api/server/v1/applications/<APP_ID>/share
    IS-->>A: 200 OK

    Note over U,IS: Step 4 — Partner user initiates authentication
    U->>IS: GET /o/org-abc123/oauth2/authorize<br/>?client_id=FAPI-TPP-Client<br/>&scope=payments<br/>&response_type=code<br/>&request_uri=<PAR_reference>

    IS->>IS: Detect sub-org org-abc123<br/>Load federated IdP for this sub-org:<br/>PartnerBankXYZ-Okta

    IS->>IdP: Redirect to Okta (OIDC auth request)
    IdP->>U: Okta login page
    U->>IdP: Alice authenticates (password + MFA)
    IdP-->>IS: OIDC callback with id_token<br/>{sub:"alice@partnerbank.com", email:"alice@partnerbank.com"}

    IS->>IS: Map external claims to IS 7.3 profile<br/>JIT provision user in sub-org org-abc123<br/>Set org_id = org-abc123 in session

    IS-->>U: Redirect to redirect_uri with auth code

    Note over U,TE: Step 5 — Code exchange for org-scoped token
    U->>TE: POST /o/org-abc123/oauth2/token<br/>grant_type=authorization_code<br/>code=<auth_code><br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    TE->>TE: Issue org-scoped access token<br/>Embed org_id="org-abc123"<br/>iss="https://identity.bank.com/o/org-abc123/oauth2/token"

    TE-->>U: {access_token, token_type:"Bearer", expires_in:3600}

    Note over U,RS: Step 6 — Access bank API with org-scoped token
    U->>RS: GET /api/partner-payments<br/>Authorization: Bearer <org_scoped_token>

    RS->>RS: Decode JWT:<br/>  org_id = "org-abc123" ✓<br/>  iss matches expected sub-org issuer ✓<br/>  scope contains "payments" ✓
    RS-->>U: 200 Partner payment data
```

---

## Diagram 3: Organization switch grant

```mermaid
sequenceDiagram
    participant U as Sub-org User<br/>(org-abc123 token)
    participant IS as WSO2 IS 7.3<br/>Token Endpoint
    participant RS as Shared Root-Org Service

    Note over U: User has org-abc123 token<br/>Needs to access root-org analytics service

    U->>IS: POST /oauth2/token<br/>grant_type=urn:ietf:params:oauth:grant-type:organization_switch<br/>token=<current_org_abc123_access_token><br/>token_type_hint=access_token<br/>switching_organization=<root_org_id><br/>scope=analytics<br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    IS->>IS: Validate current token (active, not expired)<br/>Check user has permission in target org (root)<br/>Check application is enabled in target org<br/>Issue new token scoped to root org

    IS-->>U: {access_token (root-org scoped)<br/>  org_id: "<root_org_id>" (or absent for root)<br/>  iss: "https://identity.bank.com/oauth2/token"}

    Note over U: No re-authentication required.<br/>IS 7.3 derives trust from the original sub-org token.

    U->>RS: GET /api/analytics<br/>Authorization: Bearer <root_org_token>
    RS->>RS: Validate token<br/>iss = root-org issuer ✓<br/>scope = analytics ✓
    RS-->>U: 200 Analytics data
```
