# WSO2 Mastery Glossary

**OAuth2** — Authorization framework (RFC 6749). Defines how a client gets an access token from an authorization server. WSO2 IS is the authorization server in your company's stack.

**OIDC (OpenID Connect)** — Identity layer on top of OAuth2. Adds an ID token (JWT) that carries claims about the authenticated user.

**JWT (JSON Web Token)** — A signed, base64-encoded token. Three parts: header.payload.signature. WSO2 IS issues JWTs; the API Gateway validates them without calling IS again.

**Key Manager** — WSO2's abstraction for "the thing that issues and validates tokens." WSO2 IS acts as a 3rd-party Key Manager in your company's deployment. The interface is a REST API contract.

**Introspection (RFC 7662)** — An endpoint (`/introspect`) where a resource server (e.g., the gateway) can ask the authorization server "is this token valid and what are its claims?"

**Grant type** — The OAuth2 flow used to get a token. Common ones: `client_credentials` (service-to-service), `authorization_code` (user login), `refresh_token` (extend a session).

**Carbon** — WSO2's internal OSGi-based runtime framework. Not important to understand deeply — just know it's why WSO2 source has `org.wso2.carbon.*` package names.

**Synapse** — WSO2's mediation engine inside the API Gateway. Processes inbound/outbound messages through a handler chain. Your Go gateway will use a middleware chain as the equivalent.

**JMS (Java Message Service)** — Messaging API. WSO2 uses it internally to sync throttle data and events between components. Go equivalent: channels or NATS.

**log4j2** — Java logging framework used by all WSO2 components. Configuration in `repository/conf/log4j2.properties`. Knowing which logger to enable is half of debugging WSO2.

**Throttle policy** — A rule that limits API calls (e.g., 1000/min per application). Enforced at the Gateway; policy data synced from Traffic Manager.

**3rd-party Key Manager** — A non-WSO2 identity provider plugged into WSO2 APIM via the Key Manager REST interface. In your company: WSO2 IS plays this role.
