# WSO2 Mastery Phase 1 — Identity Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author all content and lab files for Phase 1 (Days 1–15): Go OAuth2/OIDC server + WSO2 Key Manager REST interface.

**Architecture:** Each 3-day block produces three day `.md` files (theory + exercises) and three lab directories (Go source + README + SOLUTION.md + teardown). Days 1–12 build a working Go OAuth2 server incrementally. Days 13–15 produce a log4j2 debug playbook with a log-parsing lab.

**Tech Stack:** Go 1.22+, `github.com/golang-jwt/jwt/v5`, `golang.org/x/crypto`, standard `net/http`. Local Docker for test harness. No external identity provider needed.

**Spec:** `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`

## Global Constraints

- No `git commit`, `git add`, `git push`, `git status`, `git log`, or `git diff` in any subagent dispatch.
- No real credentials, keys, AWS account IDs, or tokens in any file — use placeholder comments.
- No `terraform apply` or live cloud commands — labs are authored, not run.
- Every exercise ships with Hint + Solution sketch — never a bare question.
- Every lab directory ships with: `README.md`, Go source file(s), `SOLUTION.md`, `teardown.md`.
- WSO2 IS source for reference: `/Users/hunghan/Downloads/wso2is-7.3.0`
- WSO2 APIM ACP source: `/Users/hunghan/Downloads/wso2am-acp-4.7.0`

---

### Task 0: Scaffold Phase 1 directory structure

**Files:**
- Create: `wso2_mastery/README.md`
- Create: `wso2_mastery/STRATEGY.md`
- Create: `wso2_mastery/content/GLOSSARY.md`
- Create: `wso2_mastery/content/phase1/` (empty dir marker)
- Create: `wso2_mastery/labs/phase1/` (empty dir marker)

- [ ] **Step 1: Create README.md**

```markdown
# WSO2 Mastery — 60-Day Go Port

## Quick Start
Open `PROGRESS.md` for current session status and handoff prompt.

## Phase Map
| Phase | Days | Focus |
|---|---|---|
| 1 | 1–15 | Identity Core — OAuth2/OIDC + Key Manager |
| 2 | 16–30 | API Gateway — JWT validation + throttle |
| 3 | 31–45 | Control Plane + event sync |
| 4 | 46–60 | Production mastery |

## Day Index
- Phase 1: `content/phase1/day01.md` … `day15.md`
- Labs: `labs/phase1/day01/` … `day15/`

## Lab Setup
Each lab directory has a `README.md`. Run: `docker compose up` (where present).
No AWS credentials needed for Phase 1 — all local.
```

- [ ] **Step 2: Create STRATEGY.md** — extract the Strategy section verbatim from the spec (copy from `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md` §Strategy), then add a one-page "daily loop" box:

```markdown
# WSO2 Mastery — Top 1% Strategy

[copy §Strategy section from spec verbatim]

---

## The Daily Loop (do this every single day)
1. Open the WSO2 source file named in the day's "WSO2 source reading" section.
2. Read 50–100 lines. Ask: what problem is this solving?
3. Build the Go equivalent — even 30 lines that handle the same HTTP contract.
4. Test it: `curl` or a Go test against your server.
5. Write one sentence in a personal "why" log: why did WSO2 make this design choice?
```

- [ ] **Step 3: Create content/GLOSSARY.md** with these initial terms (add more each phase):

```markdown
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
```

- [ ] **Step 4: Verify scaffold** — confirm these paths exist (write a placeholder `.gitkeep` if needed):
  - `wso2_mastery/content/phase1/`
  - `wso2_mastery/labs/phase1/`

---

### Task 1: Days 1–3 — OAuth2 Grant Types + Token Endpoint

**Files:**
- Create: `content/phase1/day01.md`
- Create: `content/phase1/day02.md`
- Create: `content/phase1/day03.md`
- Create: `labs/phase1/day01/README.md` (source reading lab — no Go)
- Create: `labs/phase1/day02/main.go`, `labs/phase1/day02/README.md`, `labs/phase1/day02/SOLUTION.md`, `labs/phase1/day02/teardown.md`
- Create: `labs/phase1/day03/main.go`, `labs/phase1/day03/README.md`, `labs/phase1/day03/SOLUTION.md`, `labs/phase1/day03/teardown.md`

**Interfaces:**
- Produces: `labs/phase1/day02/main.go` — a Go HTTP server with `POST /oauth2/token` handling `client_credentials`. Task 2 extends this file.

- [ ] **Step 1: Write content/phase1/day01.md**

```markdown
# Day 1 — OAuth2 Architecture & WSO2 IS Token Endpoint

## Why this matters
Every API call your company processes goes through token issuance (WSO2 IS) and token
validation (WSO2 GW). When a 401 hits production, you need to know immediately: did IS
fail to issue the token, or did the GW fail to validate it? Day 1 draws the boundary.

## WSO2 source reading
- File: `wso2is-7.3.0/repository/components/org.wso2.carbon.identity.oauth/`  
  Start with `OAuthEndpoint.java` — the HTTP entry point for `/oauth2/token`.  
  Key insight: every grant type funnels through a single endpoint; the `grant_type`
  parameter dispatches to a `GrantTypeHandler`.

## Core concepts

### The OAuth2 actors
- **Resource Owner** — the user (or service) that owns the data
- **Client** — the app requesting access (your API consumer)
- **Authorization Server (AS)** — WSO2 IS; issues tokens
- **Resource Server** — WSO2 API Gateway; enforces tokens

### Grant types in your company's stack
| Grant | Used for | WSO2 IS handler class |
|---|---|---|
| `client_credentials` | Service-to-service (no user) | `ClientCredentialsGrantHandler` |
| `authorization_code` | User login flows | `AuthorizationCodeGrantHandler` |
| `refresh_token` | Extend a session | `RefreshGrantHandler` |
| `urn:ietf:params:oauth:grant-type:token-exchange` | Federated identity | `TokenExchangeGrantHandler` |

### What happens at `/oauth2/token` (RFC 6749 §4)
1. Client sends `POST /oauth2/token` with `grant_type` + credentials
2. IS validates client identity (Basic Auth header = `clientId:clientSecret`, base64)
3. IS dispatches to the grant handler
4. Handler validates grant-specific params, builds a token response
5. Response: `{"access_token":"...", "token_type":"Bearer", "expires_in":3600}`

### WSO2 IS token storage
Tokens stored in `IDN_OAUTH2_ACCESS_TOKEN` table. Each token has: consumer_key,
authz_user, token_state (ACTIVE/EXPIRED/REVOKED), time_created, validity_period.

## Lab
See `labs/phase1/day01/`. Goal: read and annotate the WSO2 IS token endpoint source.
Success signal: you can draw the call path from HTTP request to token response on paper.

## Exercises
1. Draw the sequence: client → `/oauth2/token` → which Java class handles each step.  
   **Hint:** Search `OAuthEndpoint.java` for the method that reads `grant_type`.  
   **Solution sketch:** `OAuthEndpoint#issueAccessToken` → `OAuthAuthzServer#issueAccessToken` → `AbstractAuthorizationGrantHandler#issue`.

2. What HTTP status code does WSO2 IS return for an invalid `client_secret`?  
   **Hint:** Check `OAuthClientAuthnService` for authentication failure handling.  
   **Solution sketch:** `401 Unauthorized` with body `{"error":"invalid_client","error_description":"Client Authentication failed."}`.

3. Why does RFC 6749 require the token endpoint to use TLS? What breaks without it?  
   **Hint:** Think about what travels in the POST body.  
   **Solution sketch:** The `client_secret` and issued `access_token` are in cleartext in the POST body and response — interceptable without TLS.

## Anti-patterns / Common mistakes
- Confusing the *authorization endpoint* (`/oauth2/authorize`) with the *token endpoint* (`/oauth2/token`). Auth endpoint redirects users; token endpoint returns tokens.
- Sending `client_id`/`client_secret` as POST body params instead of Basic Auth — WSO2 IS accepts both, but Basic Auth is the RFC-compliant default.
- Assuming a 401 from the gateway means IS is down. A 401 usually means token validation failed *at the gateway* — IS may be fine.
```

- [ ] **Step 2: Write content/phase1/day02.md**

```markdown
# Day 2 — Client Credentials Grant: Go Implementation

## Why this matters
`client_credentials` is the grant type your company's service-to-service APIs use.
Building it in Go forces you to handle every edge case: missing headers, wrong content
type, unknown client — the same cases WSO2 IS handles in `ClientCredentialsGrantHandler`.

## WSO2 source reading
- File: `wso2is-7.3.0/...ClientCredentialsGrantHandler.java`  
  Key insight: the handler validates client, scope, then delegates token generation.
  The token itself is opaque (random bytes) or JWT — configurable via `OAuthServerConfiguration`.

## Core concepts

### The client_credentials flow
```
POST /oauth2/token HTTP/1.1
Authorization: Basic base64(clientId:clientSecret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=read:api
```
Response:
```json
{"access_token":"abc123","token_type":"Bearer","expires_in":3600,"scope":"read:api"}
```

### Token storage (opaque tokens)
WSO2 stores a random token in the DB; validation requires a DB lookup (`/introspect`).
JWT tokens are self-contained — validation needs only the public key.
Your Go lab uses opaque tokens stored in a `sync.Map` (no DB needed for the lab).

### Error responses (RFC 6749 §5.2)
| Scenario | `error` value | HTTP status |
|---|---|---|
| Unknown/invalid client | `invalid_client` | 401 |
| Wrong grant type | `unsupported_grant_type` | 400 |
| Bad scope | `invalid_scope` | 400 |
| Missing required param | `invalid_request` | 400 |

## Lab
See `labs/phase1/day02/`. Goal: run the Go token server and issue a `client_credentials` token with `curl`. Success signal: `curl` returns `{"access_token":"...","token_type":"Bearer","expires_in":3600}`.

## Exercises
1. Extend the lab server to reject requests without `Content-Type: application/x-www-form-urlencoded`.  
   **Hint:** Check `r.Header.Get("Content-Type")` before `r.ParseForm()`.  
   **Solution sketch:** Return `{"error":"invalid_request"}` with 400 if content type is missing or wrong.

2. What does WSO2 IS do when the same `client_id` requests a second token before the first expires?  
   **Hint:** Search for `REUSE_TOKEN` in the WSO2 IS source or config.  
   **Solution sketch:** By default WSO2 reuses the existing active token rather than issuing a new one (`OAuthServerConfiguration.isTokenRenewalPerRequestEnabled()`).

3. Add an in-memory token store to the lab server (a `map[string]TokenRecord]`). What fields does each record need?  
   **Hint:** Look at `IDN_OAUTH2_ACCESS_TOKEN` columns in WSO2 schema.  
   **Solution sketch:** `{Token, ClientID, Scope, IssuedAt time.Time, ExpiresIn int}`.

## Anti-patterns / Common mistakes
- Returning 403 for an invalid client — RFC 6749 requires 401.
- Not setting `Cache-Control: no-store` on the token response — tokens must not be cached by proxies.
- Issuing a new token on every request by default — WSO2 reuses active tokens; your lab should too.
```

- [ ] **Step 3: Write content/phase1/day03.md**

```markdown
# Day 3 — Authorization Code Grant + PKCE

## Why this matters
When a user logs into a portal backed by WSO2 IS, the authorization_code grant runs.
Understanding it explains WSO2 IS session management, consent pages, and the difference
between an authorization code (short-lived, single-use) and an access token.

## WSO2 source reading
- File: `AuthorizationCodeGrantHandler.java`, `OAuthAuthzEndpoint.java`  
  Key insight: the *authorization endpoint* issues a code; the *token endpoint* exchanges it.
  The code is stored in `IDN_OAUTH2_AUTHORIZATION_CODE` for single-use validation.

## Core concepts

### Two-step flow
```
Step 1 — redirect user to /oauth2/authorize:
  GET /oauth2/authorize?response_type=code&client_id=X&redirect_uri=Y&state=Z

Step 2 — exchange code at /oauth2/token:
  POST /oauth2/token
  grant_type=authorization_code&code=<code>&redirect_uri=Y
```

### PKCE (RFC 7636) — why it exists
Without PKCE, a malicious app that intercepts the redirect URI gets the code and can
exchange it. PKCE adds a `code_verifier` (random string) sent only at token exchange,
and a `code_challenge` (SHA256 of verifier) sent at authorization. The AS verifies they match.

```
code_challenge = BASE64URL(SHA256(code_verifier))
```

WSO2 IS enforces PKCE for public clients by default in IS 7.x.

### State in the Go lab (Day 3)
The Go server stores issued codes in a `sync.Map` with expiry. On exchange, it removes
the code (single-use) and returns a token. Redirect URI must match exactly.

## Lab
See `labs/phase1/day03/`. Goal: implement `/oauth2/authorize` (returns a code) and extend `/oauth2/token` to exchange it. Test the full round-trip with `curl`. Success signal: code issued → exchanged → token returned; second exchange of the same code returns `invalid_grant`.

## Exercises
1. Why must the `redirect_uri` in the token exchange match the one in the authorization request?  
   **Hint:** RFC 6749 §4.1.3.  
   **Solution sketch:** Prevents an attacker from replacing the redirect_uri to steal the code — the AS binds the code to the original URI at issuance.

2. Implement PKCE verification in the Go lab: store `code_challenge` with the code, verify `code_verifier` at exchange.  
   **Hint:** `sha256.Sum256([]byte(verifier))` then `base64.RawURLEncoding.EncodeToString(hash[:])`.  
   **Solution sketch:** See `labs/phase1/day03/SOLUTION.md` §PKCE.

3. What HTTP status should the `/oauth2/authorize` endpoint return if `response_type` is not `code`?  
   **Hint:** RFC 6749 §4.1.2.1 error response for authorization endpoint.  
   **Solution sketch:** Redirect to `redirect_uri?error=unsupported_response_type` (if redirect_uri is valid); 400 if not.

## Anti-patterns / Common mistakes
- Reusing authorization codes — each code is single-use; store and delete on first exchange.
- Not checking `redirect_uri` match — the most common authorization code attack vector.
- Confusing PKCE `code_challenge_method=plain` with `S256` — WSO2 IS requires `S256`; `plain` is insecure.
```

- [ ] **Step 4: Write labs/phase1/day01/README.md** (source-reading lab, no Go)

```markdown
# Lab Day 1 — WSO2 IS Token Endpoint Source Walk

## Goal
Trace the path from an HTTP POST to `/oauth2/token` through the WSO2 IS Java source.
Draw it on paper. No coding today.

## Prerequisites
- WSO2 IS source at `/Users/hunghan/Downloads/wso2is-7.3.0`
- A text editor / IDE to navigate Java files

## Steps
1. Open `wso2is-7.3.0/`. Find the Maven module containing `OAuthEndpoint.java`.
   (Hint: search for `@Path("/token")` annotation.)
2. Find the method annotated `@POST`. What are its parameters?
3. Search for where `grant_type` is read from the request.
4. Find `ClientCredentialsGrantHandler` — which interface does it implement?
5. Find where the access token string is generated (look for `UUID` or `SecureRandom`).

## Success signal
You can answer: "When a client sends `grant_type=client_credentials`, which Java class
runs, and what does it return to the HTTP layer?"

## Teardown
Nothing to stop — no processes started.
```

- [ ] **Step 5: Write labs/phase1/day02/main.go**

```go
package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

type tokenRecord struct {
	ClientID  string
	Scope     string
	IssuedAt  time.Time
	ExpiresIn int
}

var (
	// In-memory token store — keyed by token string
	tokenStore sync.Map
	// Registered clients: clientID -> clientSecret (placeholders — replace for testing)
	clients = map[string]string{
		"test-client": "test-secret",
	}
)

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler)
	log.Println("listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := r.ParseForm(); err != nil {
		oauthError(w, "invalid_request", http.StatusBadRequest)
		return
	}

	clientID, clientSecret, ok := r.BasicAuth()
	if !ok {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	if !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}

	grantType := r.FormValue("grant_type")
	if grantType != "client_credentials" {
		oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
		return
	}

	scope := r.FormValue("scope")
	token := generateToken()
	tokenStore.Store(token, tokenRecord{
		ClientID:  clientID,
		Scope:     scope,
		IssuedAt:  time.Now(),
		ExpiresIn: 3600,
	})

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"access_token": token,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

func validateClient(id, secret string) bool {
	expected, ok := clients[id]
	return ok && expected == secret
}

func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}
```

- [ ] **Step 6: Write labs/phase1/day02/README.md**

```markdown
# Lab Day 2 — Go Client Credentials Token Server

## Goal
Run a minimal Go OAuth2 server and issue a `client_credentials` token with `curl`.

## Prerequisites
- Go 1.22+
- `curl`

## Run
```bash
go run main.go
```

## Test
```bash
# Issue a token
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&scope=read:api"

# Expected: {"access_token":"...","token_type":"Bearer","expires_in":3600,"scope":"read:api"}

# Invalid client — should return 401
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'bad-client:bad-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

## Exercises
See `content/phase1/day02.md` §Exercises.

## Teardown
```bash
# Stop the server with Ctrl+C. No containers, no cloud resources.
```
```

- [ ] **Step 7: Write labs/phase1/day02/SOLUTION.md**

```markdown
# Day 2 Lab — Solution Notes

## Exercise 1: Reject wrong Content-Type
Add to `tokenHandler` before `r.ParseForm()`:
```go
if ct := r.Header.Get("Content-Type"); ct != "application/x-www-form-urlencoded" {
    oauthError(w, "invalid_request", http.StatusBadRequest)
    return
}
```

## Exercise 2: Token reuse
Before generating a new token, scan `tokenStore` for an existing active token for this client:
```go
var existing string
tokenStore.Range(func(k, v any) bool {
    rec := v.(tokenRecord)
    if rec.ClientID == clientID && time.Since(rec.IssuedAt) < time.Duration(rec.ExpiresIn)*time.Second {
        existing = k.(string)
        return false
    }
    return true
})
if existing != "" {
    // return existing token instead of generating a new one
}
```

## Exercise 3: Token record fields
```go
type tokenRecord struct {
    ClientID  string
    Scope     string
    IssuedAt  time.Time
    ExpiresIn int
    // optional: UserID string for user-bound grants
}
```
```

- [ ] **Step 8: Write labs/phase1/day02/teardown.md**

```markdown
# Teardown

1. Stop the server: `Ctrl+C` in the terminal running `go run main.go`.
2. No Docker containers to stop.
3. No cloud resources created.
4. Check: `lsof -i :9443` returns empty.
```

- [ ] **Step 9: Write labs/phase1/day03/main.go** — extend day02's server with authorization code grant:

```go
package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"
)

type tokenRecord struct {
	ClientID  string
	Scope     string
	IssuedAt  time.Time
	ExpiresIn int
}

type codeRecord struct {
	ClientID        string
	RedirectURI     string
	Scope           string
	CodeChallenge   string // PKCE: SHA256(code_verifier), base64url
	IssuedAt        time.Time
}

var (
	tokenStore sync.Map
	codeStore  sync.Map
	clients    = map[string]string{
		"test-client": "test-secret",
	}
)

func main() {
	http.HandleFunc("/oauth2/authorize", authorizeHandler)
	http.HandleFunc("/oauth2/token", tokenHandler)
	log.Println("listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}

func authorizeHandler(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if q.Get("response_type") != "code" {
		redirectError(w, q.Get("redirect_uri"), "unsupported_response_type", q.Get("state"))
		return
	}
	clientID := q.Get("client_id")
	if _, ok := clients[clientID]; !ok {
		http.Error(w, "unknown client", http.StatusBadRequest)
		return
	}
	code := generateToken()
	codeStore.Store(code, codeRecord{
		ClientID:      clientID,
		RedirectURI:   q.Get("redirect_uri"),
		Scope:         q.Get("scope"),
		CodeChallenge: q.Get("code_challenge"),
		IssuedAt:      time.Now(),
	})
	redirectTo := q.Get("redirect_uri") + "?code=" + code
	if state := q.Get("state"); state != "" {
		redirectTo += "&state=" + url.QueryEscape(state)
	}
	http.Redirect(w, r, redirectTo, http.StatusFound)
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.ParseForm()
	switch r.FormValue("grant_type") {
	case "client_credentials":
		handleClientCredentials(w, r)
	case "authorization_code":
		handleAuthCode(w, r)
	default:
		oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
	}
}

func handleClientCredentials(w http.ResponseWriter, r *http.Request) {
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	issueToken(w, clientID, r.FormValue("scope"))
}

func handleAuthCode(w http.ResponseWriter, r *http.Request) {
	code := r.FormValue("code")
	val, ok := codeStore.LoadAndDelete(code) // single-use
	if !ok {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	rec := val.(codeRecord)
	if time.Since(rec.IssuedAt) > 10*time.Minute {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	if r.FormValue("redirect_uri") != rec.RedirectURI {
		oauthError(w, "invalid_grant", http.StatusBadRequest)
		return
	}
	// PKCE verification
	if rec.CodeChallenge != "" {
		verifier := r.FormValue("code_verifier")
		h := sha256.Sum256([]byte(verifier))
		challenge := base64.RawURLEncoding.EncodeToString(h[:])
		if challenge != rec.CodeChallenge {
			oauthError(w, "invalid_grant", http.StatusBadRequest)
			return
		}
	}
	issueToken(w, rec.ClientID, rec.Scope)
}

func issueToken(w http.ResponseWriter, clientID, scope string) {
	token := generateToken()
	tokenStore.Store(token, tokenRecord{
		ClientID:  clientID,
		Scope:     scope,
		IssuedAt:  time.Now(),
		ExpiresIn: 3600,
	})
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]any{
		"access_token": token,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

func redirectError(w http.ResponseWriter, redirectURI, errCode, state string) {
	if redirectURI == "" {
		http.Error(w, errCode, http.StatusBadRequest)
		return
	}
	u := redirectURI + "?error=" + errCode
	if state != "" {
		u += "&state=" + url.QueryEscape(state)
	}
	http.Redirect(w, r, u, http.StatusFound)
}

func validateClient(id, secret string) bool {
	exp, ok := clients[id]
	return ok && exp == secret
}

func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}
```

- [ ] **Step 10: Write labs/phase1/day03/README.md, SOLUTION.md, teardown.md** following the same pattern as day02. README should include test commands for both the auth code flow and PKCE verification. SOLUTION.md should show the PKCE implementation detail. teardown.md: `Ctrl+C`, no containers.

- [ ] **Step 11: Verify** — all three day files exist and every exercise has a Hint + Solution sketch. All lab directories have README, main.go (or equivalent), SOLUTION.md, teardown.md.

---

### Task 2: Days 4–6 — JWT Assembly + WSO2 Claim Format

**Files:**
- Create: `content/phase1/day04.md`, `day05.md`, `day06.md`
- Create: `labs/phase1/day04/README.md` (source reading — no new Go)
- Create: `labs/phase1/day05/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day06/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase1/day03/main.go` — base OAuth2 server (token store, grant handlers).
- Produces: `labs/phase1/day06/main.go` — JWT-issuing OAuth2 server using RSA-signed tokens with WSO2 claim format. Task 3 extends this for introspection.

- [ ] **Step 1: Write content/phase1/day04.md** covering:
  - JWT structure: header (alg, kid), payload (standard claims + WSO2 custom claims), signature
  - WSO2 claim namespace: `http://wso2.org/claims/subscriber`, `applicationname`, `applicationtier`, `version`, `keytype`
  - Where to find: `JWTTokenGenerator.java` in IS source — the `buildJWTClaimSet` method
  - Key insight: the `kid` in the header maps to a public key in the JWKS endpoint (`/oauth2/jwks`); the gateway uses this to validate without calling IS
  - Exercises: decode a WSO2 JWT manually (base64 decode payload), identify all WSO2-specific claims, explain why `kid` rotation matters for zero-downtime key rotation

- [ ] **Step 2: Write content/phase1/day05.md** covering:
  - RSA key generation for signing (development only — never use generated keys in production)
  - Go JWT library: `github.com/golang-jwt/jwt/v5`
  - Building a `jwt.MapClaims` with all standard + WSO2 custom claims
  - Signing with `jwt.SigningMethodRS256`
  - JWKS endpoint: serving the public key as `{"keys":[{"kty":"RSA","kid":"...","n":"...","e":"..."}]}`

- [ ] **Step 3: Write content/phase1/day06.md** covering:
  - Token type selection: when to issue opaque vs JWT
  - WSO2 IS config that controls this: `identity.xml` → `OAuthConfiguration` → `TokenPersistenceProcessor`
  - `exp` claim and token lifetime; `nbf` and `iat`
  - Gateway-side JWT validation: verify signature, check `exp`, check `iss`, extract `sub` and application claims
  - Exercises: validate a self-issued JWT with `jwt.ParseWithClaims`; check `exp` is in the future

- [ ] **Step 4: Write labs/phase1/day05/main.go** — extend the Day 3 server to issue JWTs instead of opaque tokens:

```go
package main

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"log"
	"math/big"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// WSO2Claims mirrors the claim format from JWTTokenGenerator.java
type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"` // PRODUCTION or SANDBOX
}

var (
	signingKey *rsa.PrivateKey
	keyID      = "dev-key-1"
)

func init() {
	var err error
	// Generate a dev RSA key — never use generated keys in production
	signingKey, err = rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		log.Fatal(err)
	}
}

func issueJWT(clientID, scope, appName string) (string, error) {
	now := time.Now()
	claims := WSO2Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "https://localhost:9443/oauth2/token",
			Subject:   clientID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(3600 * time.Second)),
		},
		Subscriber:      clientID,
		ApplicationName: appName,
		ApplicationTier: "Unlimited",
		APIVersion:      "v1",
		KeyType:         "PRODUCTION",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = keyID
	return token.SignedString(signingKey)
}

func jwksHandler(w http.ResponseWriter, r *http.Request) {
	pub := signingKey.PublicKey
	n := base64.RawURLEncoding.EncodeToString(pub.N.Bytes())
	e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pub.E)).Bytes())
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"keys": []map[string]any{{
			"kty": "RSA",
			"kid": keyID,
			"use": "sig",
			"alg": "RS256",
			"n":   n,
			"e":   e,
		}},
	})
}

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler) // extend day03's handler to call issueJWT
	http.HandleFunc("/oauth2/jwks", jwksHandler)
	log.Println("listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}

// tokenHandler — same as day03 but calls issueJWT instead of generateToken
// (paste day03 tokenHandler here and replace generateToken with issueJWT)
func tokenHandler(w http.ResponseWriter, r *http.Request) {
	// TODO: implement — same as day03; call issueJWT(clientID, scope, "DefaultApp")
}
```

- [ ] **Step 5: Write labs/phase1/day05/README.md** with `go mod init` + `go get github.com/golang-jwt/jwt/v5` setup, curl test that decodes the JWT with `base64 -d`, JWKS endpoint test.

- [ ] **Step 6: Write labs/phase1/day05/SOLUTION.md** with the complete `tokenHandler` that calls `issueJWT`.

- [ ] **Step 7: Write labs/phase1/day06/main.go** — add JWT validation middleware (gateway side):

```go
// validateJWT parses and validates a Bearer JWT against the local JWKS.
// Returns the WSO2Claims on success.
func validateJWT(tokenStr string) (*WSO2Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return &signingKey.PublicKey, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*WSO2Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	return claims, nil
}

// authMiddleware is a sample gateway-side handler that validates the JWT.
func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if bearer == "" {
			http.Error(w, `{"error":"missing_token"}`, http.StatusUnauthorized)
			return
		}
		claims, err := validateJWT(bearer)
		if err != nil {
			http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
			return
		}
		// Attach claims to context for downstream handlers
		ctx := context.WithValue(r.Context(), "claims", claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```

- [ ] **Step 8: Write day06 README, SOLUTION.md, teardown.md** following day05 pattern. SOLUTION.md includes the full `tokenHandler` wiring.

- [ ] **Step 9: Verify** — all day04–06 files exist, exercises have hints+solutions, labs have all four required files.

---

### Task 3: Days 7–9 — Token Introspection + Revocation

**Files:**
- Create: `content/phase1/day07.md`, `day08.md`, `day09.md`
- Create: `labs/phase1/day07/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day08/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day09/README.md`, `SOLUTION.md`, `teardown.md` (integration test, no new Go)

**Interfaces:**
- Consumes: `labs/phase1/day06/main.go` — JWT-issuing server + authMiddleware.
- Produces: `labs/phase1/day08/main.go` — server with `/oauth2/introspect` + `/oauth2/revoke` + `/oauth2/jwks`. Task 4 wraps this into the Key Manager interface.

- [ ] **Step 1: Write content/phase1/day07.md** covering:
  - RFC 7662 introspection: `POST /oauth2/introspect`, request body `token=<token>`, response `{"active":true/false,...claims}`
  - WSO2 IS source: `IntrospectionDataProvider`, `OAuth2TokenValidationService`
  - Why the gateway needs introspection for opaque tokens but not JWTs
  - WSO2 introspection response fields: `active`, `sub`, `exp`, `iss`, `scope`, `client_id`, `username`, `token_type`, `nbf`, `iat`, `aud`
  - Exercises: call WSO2 IS `/oauth2/introspect` manually; compare the response fields to a decoded JWT payload

- [ ] **Step 2: Write content/phase1/day08.md** covering:
  - RFC 7009 revocation: `POST /oauth2/revoke`, params `token` + `token_type_hint`
  - WSO2 IS `OAuthRevocationProcessor` — marks token as REVOKED in DB
  - Token revocation propagation: IS revokes, but gateway may cache the JWT for its remaining lifetime — the "revocation gap"
  - WSO2 solution: event-based revocation notification to gateway via JMS (preview for Phase 2)
  - Exercises: revoke a token, attempt introspection, confirm `"active":false`

- [ ] **Step 3: Write content/phase1/day09.md** covering:
  - End-to-end flow: issue → introspect → revoke → introspect again
  - WSO2 IS log4j2 loggers to enable for token lifecycle debugging:
    ```
    logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
    logger.org-wso2-carbon-identity-oauth.level=DEBUG
    ```
  - Reading token lifecycle log lines: what ISSUED, VALIDATED, REVOKED look like
  - Exercises: enable DEBUG logging on the Go lab server (using `log/slog` structured logs), trace one full token lifecycle

- [ ] **Step 4: Write labs/phase1/day07/main.go** — add `/oauth2/introspect` to the day06 server:

```go
func introspectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	// Per RFC 7662: introspection endpoint itself requires authentication
	// (Basic Auth with a registered client)
	_, _, ok := r.BasicAuth()
	if !ok {
		w.Header().Set("WWW-Authenticate", `Basic realm="introspection"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	r.ParseForm()
	tokenStr := r.FormValue("token")

	w.Header().Set("Content-Type", "application/json")

	// Try JWT validation first
	claims, err := validateJWT(tokenStr)
	if err != nil {
		// Not a valid JWT or expired
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	// Check revocation list
	if _, revoked := revokedTokens.Load(tokenStr); revoked {
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	json.NewEncoder(w).Encode(map[string]any{
		"active":      true,
		"sub":         claims.Subject,
		"exp":         claims.ExpiresAt.Unix(),
		"iat":         claims.IssuedAt.Unix(),
		"iss":         claims.Issuer,
		"client_id":   claims.Subscriber,
		"token_type":  "Bearer",
		// WSO2-specific
		"http://wso2.org/claims/applicationname": claims.ApplicationName,
		"http://wso2.org/claims/keytype":          claims.KeyType,
	})
}

var revokedTokens sync.Map
```

- [ ] **Step 5: Write labs/phase1/day08/main.go** — add `/oauth2/revoke`:

```go
func revokeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	r.ParseForm()
	token := r.FormValue("token")
	if token != "" {
		revokedTokens.Store(token, time.Now())
	}
	// RFC 7009: always return 200, even if token was unknown
	w.WriteHeader(http.StatusOK)
}
```

- [ ] **Step 6: Write day07–09 README files** with curl commands for introspect + revoke.  
  day09 README should have a full round-trip script: issue → introspect (active=true) → revoke → introspect (active=false).

- [ ] **Step 7: Write SOLUTION.md files** for day07–08. day09 SOLUTION.md: add `log/slog` structured logging to each handler (issued, validated, revoked events).

- [ ] **Step 8: Verify** — exercises have hints+solutions, all labs have four required files.

---

### Task 4: Days 10–12 — WSO2 Key Manager REST API

**Files:**
- Create: `content/phase1/day10.md`, `day11.md`, `day12.md`
- Create: `labs/phase1/day10/README.md` (API spec reading — no new Go)
- Create: `labs/phase1/day11/keymanager/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day12/keymanager/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase1/day08/main.go` — full token server with introspect + revoke.
- Produces: `labs/phase1/day12/keymanager/main.go` — a Go HTTP server implementing the WSO2 3rd-party Key Manager REST interface. This is the capstone of Phase 1.

- [ ] **Step 1: Write content/phase1/day10.md** covering:
  - What a 3rd-party Key Manager is: APIM calls it to issue, validate, and revoke tokens; IS implements this interface
  - WSO2 Key Manager REST API endpoints (from APIM source `KeyManagerInterface.java`):
    ```
    POST   /api/am/keymanager/v1/oauth2/token         → issue token
    POST   /api/am/keymanager/v1/oauth2/introspect     → validate token
    POST   /api/am/keymanager/v1/oauth2/revoke          → revoke token
    GET    /api/am/keymanager/v1/oauth2/userinfo        → user info
    GET    /api/am/keymanager/v1/jwks                   → public keys
    POST   /api/am/keymanager/v1/keymanager/application → register an application (OAuth client)
    DELETE /api/am/keymanager/v1/keymanager/application/{id} → delete client
    ```
  - How APIM Control Plane registers WSO2 IS as a 3rd-party KM via admin UI → what REST calls it makes
  - Source: `KeyManagerConnector` in ACP checkout

- [ ] **Step 2: Write content/phase1/day11.md** covering:
  - Application (OAuth client) registration: `POST /keymanager/application` body and response
  - Request/response shapes (copy from WSO2 APIM REST API spec):
    ```json
    // Request
    {"applicationName":"MyApp","grantTypes":["client_credentials"],"callbackUrl":""}
    // Response
    {"clientId":"generated-id","clientSecret":"generated-secret","clientName":"MyApp"}
    ```
  - How APIM stores the client mapping: `AM_APPLICATION_KEY_MAPPING` table
  - Go: implement client registration with an in-memory `map[string]ClientRecord`

- [ ] **Step 3: Write content/phase1/day12.md** covering:
  - Wiring all endpoints together: the complete Key Manager Go service
  - Health check endpoint: `GET /health` → `{"status":"UP"}`
  - Docker packaging: a minimal `Dockerfile` with a multi-stage build
  - How to register this Go Key Manager in WSO2 APIM admin UI (step-by-step config)
  - The exact JSON payload APIM sends when it calls your KM to issue a token vs introspect

- [ ] **Step 4: Write labs/phase1/day11/keymanager/main.go** — client registration + token issue:

```go
package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"sync"
)

type ClientRecord struct {
	ClientID     string   `json:"clientId"`
	ClientSecret string   `json:"clientSecret"`
	ClientName   string   `json:"clientName"`
	GrantTypes   []string `json:"grantTypes"`
	CallbackURL  string   `json:"callbackUrl"`
}

var clientRegistry sync.Map // clientID → ClientRecord

func registerApplicationHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		ApplicationName string   `json:"applicationName"`
		GrantTypes      []string `json:"grantTypes"`
		CallbackURL     string   `json:"callbackUrl"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	clientID := generateID()
	clientSecret := generateID()
	rec := ClientRecord{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		ClientName:   req.ApplicationName,
		GrantTypes:   req.GrantTypes,
		CallbackURL:  req.CallbackURL,
	}
	clientRegistry.Store(clientID, rec)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(rec)
}

func deleteApplicationHandler(w http.ResponseWriter, r *http.Request) {
	// Extract client ID from path /keymanager/application/{id}
	// clientID := path.Base(r.URL.Path)
	// clientRegistry.Delete(clientID)
	w.WriteHeader(http.StatusNoContent)
}

func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func main() {
	// Wire all Key Manager endpoints
	http.HandleFunc("/api/am/keymanager/v1/keymanager/application", registerApplicationHandler)
	http.HandleFunc("/api/am/keymanager/v1/oauth2/token", tokenHandler)     // from day08
	http.HandleFunc("/api/am/keymanager/v1/oauth2/introspect", introspectHandler)
	http.HandleFunc("/api/am/keymanager/v1/oauth2/revoke", revokeHandler)
	http.HandleFunc("/api/am/keymanager/v1/jwks", jwksHandler)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
	})
	log.Println("Key Manager listening on :9444")
	log.Fatal(http.ListenAndServe(":9444", nil))
}
```

- [ ] **Step 5: Write labs/phase1/day12/keymanager/main.go** — complete Key Manager with Docker packaging. Add a `Dockerfile`:

```dockerfile
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o keymanager .

FROM alpine:3.19
WORKDIR /app
COPY --from=build /app/keymanager .
EXPOSE 9444
CMD ["./keymanager"]
```

And a `docker-compose.yml`:
```yaml
services:
  keymanager:
    build: .
    ports:
      - "9444:9444"
```

- [ ] **Step 6: Write README files** for day11–12. day12 README: `docker compose up`, then curl to register an application and issue a token.

- [ ] **Step 7: Write SOLUTION.md** for day11 (complete `deleteApplicationHandler`) and day12 (complete Key Manager wiring).

- [ ] **Step 8: Verify** — all day10–12 files exist, exercises have hints+solutions, labs have required files.

---

### Task 5: Days 13–15 — log4j2 Reading + IS Debug Patterns

**Files:**
- Create: `content/phase1/day13.md`, `day14.md`, `day15.md`
- Create: `labs/phase1/day13/README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day14/README.md`, `log_samples/`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase1/day15/README.md`, `playbook.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: All Phase 1 content (days 1–12).
- Produces: `labs/phase1/day15/playbook.md` — a personal WSO2 IS debug runbook. Referenced in Phase 4.

- [ ] **Step 1: Write content/phase1/day13.md** covering:
  - log4j2 config location in IS: `repository/conf/log4j2.properties`
  - log4j2 anatomy: logger name = Java package, level hierarchy (TRACE < DEBUG < INFO < WARN < ERROR)
  - The five loggers to enable for token debugging:
    ```properties
    logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
    logger.org-wso2-carbon-identity-oauth.level=DEBUG
    logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
    logger.org-wso2-carbon-identity-oauth2.level=DEBUG
    logger.org-wso2-carbon-identity-application-authentication.name=org.wso2.carbon.identity.application.authentication
    logger.org-wso2-carbon-identity-application-authentication.level=DEBUG
    ```
  - How to apply without restart: IS supports hot-reload of log4j2 config
  - Exercises: identify the logger name for WSO2 token validation failures; write the log4j2 config line

- [ ] **Step 2: Write content/phase1/day14.md** covering:
  - WSO2 IS log line anatomy: `[timestamp] [thread] [level] {logger-short-name} - message`
  - Five log line patterns to memorize:
    ```
    # Token issued successfully
    DEBUG {OAuth2} - Access token issued to [client_id] for scope [scope]
    # Token validation success
    DEBUG {OAuth2} - Token validation for access_token: [VALID]
    # Token validation failure — wrong sig or expired
    WARN  {OAuth2TokenValidation} - Invalid JWT token. failed: ...
    # Client auth failure
    WARN  {OAuthClientAuthn} - Client Authentication failed for client_id: [id]
    # Revocation
    INFO  {OAuth2} - Revoking access token issued to [client_id]
    ```
  - Log correlation: every request in WSO2 IS carries a correlation ID in MDC; all log lines for one request share it. Enable with `CorrelationLogFilter`.
  - Exercises: given a log snippet (provided in the day file), identify the failure class and which subsystem to check

- [ ] **Step 3: Write content/phase1/day15.md** covering:
  - The Phase 1 capstone: "given a 401 in production, trace it in 5 minutes"
  - Decision tree: `Is the token present? → Is it expired? → Is the signature valid? → Is the client registered? → Is the scope valid?`
  - How to add structured logging to the Go Key Manager (using `log/slog` with correlation IDs matching WSO2's MDC pattern)
  - WSO2 IS health endpoint: `GET /services/OAuth2TokenValidationService?wsdl` (SOAP — note it for Phase 2)
  - Exercises: add a correlation ID middleware to the Go KM server; log all events with the same correlation ID per request

- [ ] **Step 4: Write labs/phase1/day13/README.md** — source reading: find the log4j2 config in the IS checkout, identify the five loggers above, explain what changes if you switch from INFO to DEBUG.

- [ ] **Step 5: Write labs/phase1/day14/** — log analysis lab:
  - Create `log_samples/token_failure.log` with 15–20 sample log lines representing a token validation failure scenario (realistic WSO2 IS log format). Include: a valid token issue, a failed introspection, a client auth failure.
  - `README.md`: "Given the log file in `log_samples/`, answer: (1) which client failed auth? (2) was the token ever issued? (3) what was the failure class?"
  - `SOLUTION.md`: answers with the specific log lines quoted and explained.

- [ ] **Step 6: Write labs/phase1/day15/playbook.md** — the personal debug runbook:

```markdown
# WSO2 IS Debug Playbook — Phase 1

## First-response checklist (token 401)
- [ ] Check WSO2 IS is UP: `curl https://<is-host>:9443/healthz`
- [ ] Enable DEBUG logging: update `log4j2.properties` with OAuth2 loggers
- [ ] Pull IS logs: `docker logs <container> 2>&1 | grep -E "(ERROR|WARN|DEBUG.*token)"`
- [ ] Check for correlation ID in the 401 response header (`correlation-id`)
- [ ] Search logs for that correlation ID: `grep <correlation-id> wso2carbon.log`

## Token failure decision tree
```
401 received
├── Token missing → client bug (not sending Authorization header)
├── Token present but:
│   ├── "Invalid JWT" in logs → signature mismatch (check JWKS kid rotation)
│   ├── "Token expired" in logs → clock skew or long-lived token
│   ├── "Client Authentication failed" → wrong clientId/Secret
│   ├── "Invalid scope" → token scope doesn't cover the API
│   └── "Token revoked" → token was explicitly revoked (check revocation event propagation)
```

## Key log patterns
| Log pattern | Meaning | Action |
|---|---|---|
| `WARN {OAuthClientAuthn} - Client Authentication failed` | Wrong clientSecret | Check client registration in IS admin console |
| `WARN {OAuth2TokenValidation} - Invalid JWT` | Bad signature or tampered token | Check JWKS kid; check if IS restarted and key changed |
| `DEBUG {OAuth2} - Access token issued` | Healthy issue | Confirm token reaches the client |
| `INFO {OAuth2} - Revoking access token` | Explicit revocation | Check if revocation propagated to GW (Phase 2) |

## Common ECS Fargate gotchas
- IS log4j2 changes require either a restart or a hot-reload trigger — ECS task restart is clean.
- Correlation ID header: `correlation-id` in IS responses; check ALB logs for the same ID.
- IS health path: `GET /healthz` (not `/health`).
```

- [ ] **Step 7: Write labs/phase1/day15/README.md** — add structured logging (correlation ID) to the Go KM. `SOLUTION.md`: complete middleware implementation.

- [ ] **Step 8: Verify** — all day13–15 files exist, exercises have hints+solutions, log_samples file created, playbook.md complete.

---

## Self-Review Checklist

Run through this before marking the plan complete:

- [ ] Every exercise in every day file has a **Hint:** and **Solution sketch:** — no bare questions.
- [ ] Every lab directory has exactly: `README.md`, source file(s), `SOLUTION.md`, `teardown.md`.
- [ ] No real credentials, AWS account IDs, or secrets in any file.
- [ ] No `git commit`, `git add`, or `git status` commands in any step.
- [ ] Day file structure matches the skeleton: Why / WSO2 source reading / Core concepts / Lab / Exercises / Anti-patterns / Teardown.
- [ ] Go code in labs compiles (no obvious syntax errors; imports match function names used).
- [ ] `labs/phase1/day02/main.go` through `day12/` form an incremental build (each day extends the previous).
- [ ] `labs/phase1/day15/playbook.md` exists and covers the 5-step first-response checklist.
