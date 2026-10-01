# Glossary

Terms introduced in Phase 1 (Hard Protocols). Phase 2 and 3 terms appended by their respective plans.

## A

**ASPSP** — Account Servicing Payment Service Provider. Under PSD2, the bank or financial institution that holds the payment account and must expose Open Banking APIs to TPPs.

**Actor claim (`act`)** — JWT claim in an OBO token identifying the party that is acting on behalf of the subject. RFC 8693.

**`authorization_details`** — JSON array parameter (RFC 9396 / RAR) carrying fine-grained authorization information beyond scopes. Each element has a `type` field identifying the authorization type.

**`auth_req_id`** — Opaque identifier issued by the server in a CIBA flow. The client polls or waits for a push notification using this ID.

## C

**CIBA** — Client-Initiated Backchannel Authentication. An OpenID Connect flow where the authentication request and the user's authentication happen on separate channels (RFC draft: openid-client-initiated-backchannel-authentication-core).

**`cnf` claim** — Confirmation claim in a JWT (RFC 7800). Used by DPoP and mTLS to bind a token to a cryptographic key. Sub-claims: `jkt` (DPoP key thumbprint), `x5t#S256` (mTLS certificate thumbprint).

**Consent receipt** — A structured record given to the user documenting what data processing they consented to. PSD2 requires consent receipts for payment and account-information services.

## D

**DPoP** — Demonstrating Proof of Possession (RFC 9449). A mechanism for sender-constraining OAuth2 tokens using a public/private key pair. The client proves possession of the private key on every request via a DPoP proof JWT.

**Dynamic linking** — PSD2 SCA requirement that the authentication code be cryptographically linked to the specific transaction amount and payee, preventing substitution attacks.

## E

**eIDAS** — Electronic Identification, Authentication and Trust Services. EU regulation (910/2014) establishing legally recognised electronic identities and signatures. Relevant to open banking as the regulatory basis for qualified certificates used in PSD2 mTLS client authentication.

## F

**FAPI 2.0** — Financial-grade API Security Profile 2.0. An OAuth2/OIDC security profile mandating PAR, PKCE, JARM, and other hardening measures for open banking and financial APIs.

**FAPI Baseline / Advanced** — FAPI 1.0 profiles (deprecated in favour of FAPI 2.0). Still encountered in legacy UK Open Banking and older Australian CDR implementations.

## J

**JARM** — JWT Secured Authorization Response Mode (openid-financial-api-jarm). The authorization response is returned as a signed (and optionally encrypted) JWT, preventing response tampering.

**JIT provisioning** — Just-in-Time provisioning. A user account is created in the target system the first time the user authenticates via federation, rather than via a pre-provisioned sync.

## M

**`may_act` claim** — JWT claim (RFC 8693) that identifies parties authorised to impersonate the token subject. Used to pre-authorise an actor before the token exchange happens.

**mTLS** — Mutual TLS. Both the client and server present X.509 certificates during the TLS handshake, providing two-way authentication at the transport layer.

## P

**PSD2** — Payment Services Directive 2 (EU 2015/2366). EU regulation requiring banks (ASPSPs) to open payment account APIs to licensed third parties (TPPs) and mandating Strong Customer Authentication for electronic payments.

**PSU** — Payment Services User. The individual or business that holds the payment account and whose consent is required for a TPP to access or initiate payments on their behalf.

**PAR** — Pushed Authorization Requests (RFC 9126). The client POSTs the authorization request directly to the authorization server and receives a `request_uri` to use in the redirect, keeping request parameters off the front channel.

**PKCE** — Proof Key for Code Exchange (RFC 7636). The client generates a `code_verifier` and sends its hash (`code_challenge`) in the auth request; the server verifies possession of the verifier at token exchange, preventing authorization code interception.

## R

**RAR** — Rich Authorization Requests (RFC 9396). Extends OAuth2 to carry structured, fine-grained authorization information in the `authorization_details` parameter.

**`request_uri`** — An opaque URI returned by the PAR endpoint. Replaces the full authorization request parameters in the redirect URI, valid for a short TTL (typically 60–90 seconds).

## S

**SCA** — Strong Customer Authentication. PSD2 RTS requirement that customer-facing payment or account-access authentication combines at least two of: possession, knowledge, inherence.

**SCIM** — System for Cross-domain Identity Management (RFC 7643, 7644). A REST API standard for provisioning and deprovisioning user and group accounts across systems.

**Sender-constrained token** — An access token bound to a client's cryptographic key (via DPoP or mTLS) so that possession of the token alone is insufficient to use it.

## T

**TPP** — Third Party Provider. Under PSD2, a licensed fintech or aggregator that accesses a PSU's payment accounts via the ASPSP's Open Banking API, with the PSU's consent. Subdivided into AISP (account information) and PISP (payment initiation).

**TRA** — Transaction Risk Analysis. A PSD2 SCA exemption allowing low-risk transactions below a value threshold to skip the full SCA flow based on fraud scoring.

---

## Phase 2 — WSO2 IS 7.3 Terms

**App-Native Authentication** — IS 7.3's REST-based auth API that lets mobile/SPA clients drive
authentication step-by-step without browser redirects. The client POSTs to `/api/identity/auth/v1.0/authenticate`,
receives a `flowId` for the session, and submits credentials for each step.

**Adaptive Authentication** — IS 7.3's JavaScript policy engine that evaluates risk signals at
login time and conditionally inserts or skips authentication steps. Policy scripts run server-side,
not in the browser.

**`onLoginRequest(context)`** — The JavaScript entry-point called by IS 7.3's adaptive auth engine
on every authentication request. The `context` object carries step results, request metadata, and
the current user subject.

**`executeStep(stepNumber, {options})`** — IS 7.3 adaptive auth function that triggers an
authentication step. The `options` object accepts `onSuccess` and `onFail` callbacks.

**FAPI Compliance Mode (IS 7.3)** — A server-level flag in `deployment.toml` that enables PAR
enforcement, JARM signing, and `private_key_jwt`-only client auth for FAPI-registered applications.

**DCR (Dynamic Client Registration)** — RFC 7591. IS 7.3 exposes `/api/identity/oauth2/dcr/v1.1/register`
for programmatic FAPI client registration. Requires a DCR-permitted JWT (`software_statement`).

**Backchannel Endpoint (IS 7.3 CIBA)** — IS 7.3's CIBA request entry point: `POST /oauth2/ciba`.
Issues `auth_req_id` for poll/push delivery. Config toggles poll vs. push mode per application.

**`client_notification_endpoint`** — URL registered on a CIBA push-mode client where IS 7.3
POSTs tokens when the user authenticates. Must validate the `client_notification_token` Bearer header.

**Token Binding (IS 7.3)** — IS 7.3's mechanism for embedding `cnf` claims (DPoP JWK thumbprint
or mTLS cert thumbprint) into access tokens. Enabled in `deployment.toml` under `[oauth]`.

**Root Organization** — Top-level org in IS 7.3's B2B org model. Owns the super-admin identity
store, shared applications, and sub-org governance policies.

**Sub-organization** — A child org in IS 7.3 with its own identity store or federated IdP.
Users authenticate against the sub-org's IdP; tokens carry `org_id` scoped to that sub-org.

**Org-scoped Token** — An IS 7.3 access token carrying `org_id` claim. The resource server
enforces access only to resources belonging to that org. Issued via org-switch grant or B2B flow.

**Organization Switch Grant** — IS 7.3 custom grant type `urn:ietf:params:oauth:grant-type:organization_switch`
that exchanges a root-org token for a sub-org token without re-authentication.

**WebAuthn / FIDO2** — W3C standard for public-key auth via hardware authenticators. IS 7.3
implements FIDO2 registration ceremony (`/fido2/v2/registration/start`) and assertion ceremony
(`/fido2/v2/assertion/start`).

**Resident Key / Passkey** — A FIDO2 credential stored on the authenticator (no username hint
needed at assertion). IS 7.3 supports resident keys when `residentKey=required` in the RP policy.

**`userVerification`** — WebAuthn RP policy: `required` (biometric/PIN mandatory), `preferred`
(use if available), `discouraged` (fast tap, no PIN). IS 7.3 config: `user_verification_requirement`.

**Custom Authenticator SPI** — IS 7.3 Java extension: implement `AbstractApplicationAuthenticator`
or `LocalApplicationAuthenticator`, package as OSGi bundle, deploy to `dropins/`. IS 7.3 discovers
it at startup and exposes it in the Console flow builder.

**Identity Event Framework** — IS 7.3 event bus for pre/post hooks on identity operations
(login, token issue, user create, password reset). Handlers implement `AbstractIdentityHandler`.
Used to publish events to external systems (Choreo, webhooks, Kafka).

**IS 7.3 Key Manager role** — IS 7.3 acts as APIM 4.7's OAuth2 key manager: token generation,
introspection, revocation, scope validation. Replaces the older IS-as-KM connector with a
native integration via `KeyManagerConnector` config in `deployment.toml`.

---

## Phase 3 — AI Agent Identity Terms

**Act claim (`act`)** — RFC 8693 JWT claim identifying the acting agent. Structure: `{"sub": "<agent_client_id>"}`. Multi-hop: `act` nests inside itself — `{"sub": "tool_id", "act": {"sub": "orchestrator_id"}}`. The `sub` claim remains the original user throughout; `act` chain grows at each delegation hop.

**Actor token (`actor_token`)** — In RFC 8693 token exchange, the token identifying the agent (acting party) requesting the exchange. Typically a JWT signed by the agent's private key. IS 7.3 validates this token to ensure the agent is authorized to exchange on behalf of the subject.

**AgentCore Gateway** — AWS service that acts as an identity-aware proxy for AI agents. Provides per-agent IAM roles, SigV4 request signing, and credential vending. Each agent gets a scoped IAM role with session tags (`agentId`, `userId`, `sessionId`) rather than a shared service account.

**Confused deputy problem** — Security vulnerability where a less-privileged agent is tricked (e.g., via prompt injection) into using its authority to act on behalf of a different principal than intended. Prevented by binding tokens to specific principals via `sub` + `act` claims and scope narrowing.

**Credential vending** — AgentCore's mechanism for issuing short-lived AWS credentials (via `sts:AssumeRole`) to AI agents on a per-request or per-session basis. Credentials carry session tags that trace back to the originating user and agent instance.

**Delegation chain** — The ordered sequence of principals in a multi-hop agent auth flow: User → Orchestrator Agent → Tool Agent → Backend API. Each hop adds an `act` nesting level; `sub` is preserved throughout as the original user's identity.

**IAM trust policy** — AWS IAM document controlling which principals can assume a role. For AgentCore agents: restricts assumption to specific AgentCore service principals and adds required condition keys (`aws:SourceArn`, session tag conditions).

**`may_act` claim** — RFC 8693 optional claim pre-authorizing specific agents to exchange the token on behalf of the subject in future hops. Structure: `{"sub": "<pre-authorized_agent_client_id>"}`. Enables IS 7.3 to skip re-validation of expired parent tokens in deep chains.

**MCP (Model Context Protocol)** — Anthropic's open protocol for AI agents to discover and call tools. MCP tools are OAuth2 resource servers; the MCP client authenticates via Authorization Code flow or token exchange. IS 7.3 can act as the OAuth2 AS for MCP tool authentication.

**OBO (On-Behalf-Of)** — Common shorthand for RFC 8693 token exchange when an agent exchanges a user's token for a delegated token. The resulting token carries the user's identity (`sub`) plus the agent's identity (`act`). Not to be confused with Microsoft's non-standard "OBO flow" — here OBO always means RFC 8693.

**Principal hierarchy** — The identity stack in an AI-augmented system: the set of principals (user, orchestrator, tool, API) and the authority relationships between them. Each principal must have a distinct verifiable identity; authority flows downward via token exchange.

**RFC 7523** — "JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication and Authorization Grants." Defines two uses: (1) `private_key_jwt` client authentication (section 2.2) and (2) JWT bearer grant for service-to-user delegation (section 2.1). IS 7.3 supports both.

**RFC 8693** — "OAuth 2.0 Token Exchange." Defines `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`. The master pattern for AI agent identity: exchanges a `subject_token` (user's token) for a narrowed `act`-scoped token. IS 7.3 supports this grant type in the application config.

**Scoped tool token** — A short-lived OAuth2 access token issued to an MCP tool with a scope limited to a single tool capability (e.g., `mcp:payments:read`). Prevents a compromised tool from accessing unrelated capabilities.

**SigV4** — AWS Signature Version 4. The signing algorithm used to authenticate HTTP requests to AWS services. AgentCore agents sign API requests with temporary IAM credentials using SigV4; the signature includes request body hash, timestamp, and service scope, preventing replay.

**Subject token (`subject_token`)** — In RFC 8693, the token representing the user whose identity is being delegated. Typically the user's IS 7.3 access token. The exchange produces a new token that preserves the subject token's `sub` claim and adds the agent's `act` claim.

**Token exchange grant** — Shorthand for `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` (RFC 8693). IS 7.3 must have this grant type enabled per-application in Console or via DCR.

**Trust federation (AWS ↔ IS 7.3)** — The mechanism by which IS 7.3 trusts AgentCore's identity claims. AgentCore's OIDC provider is registered as an external IdP in IS 7.3; IS 7.3 validates the `actor_token` against this IdP's JWKS before issuing exchange tokens.
