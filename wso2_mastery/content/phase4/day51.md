# Day 51 — Go OAuthGrantHandler Dispatch Blueprint

## Why This Matters

Day 50 built request interception (APIHandler). Day 51 applies the same dispatch pattern to OAuth2 token issuance:

- **Multiple grant types** → One endpoint (`/oauth2/token`)
- **Each grant type** → One handler (ClientCredentialsHandler, ROPCHandler, your CustomHandler)
- **Dispatch** → Iterate handlers, first `CanHandle()` match wins

Your company uses WSO2 IS as a 3rd-party key manager. Understanding grant handler dispatch means you can:

1. **Add custom grant types without forking IS:** For example, issue tokens for internal service accounts using a non-standard grant type like `urn:mycompany:grant:service_account`.

2. **Test grant logic in Go before deploying to IS:** Prototype the handler locally, verify it works, then translate to Java for IS production.

3. **Extend IS's token issuance:** Currently IS supports standard OAuth2 grants. You might need to support device flow, JWT bearer, or a proprietary grant — without touching IS code.

4. **Understand token endpoint routing:** How does `/oauth2/token` decide which handler processes a request? Same pattern as the APIHandler chain, applied to grant types.

---

## Core Concept: Grant Handler Dispatch

### OAuthGrantHandler Interface

```go
type OAuthGrantHandler interface {
    CanHandle(grantType string) bool
    ValidateGrant(req *TokenRequest) error
    IssueToken(req *TokenRequest) (*TokenResponse, error)
}
```

**Semantics (same as WSO2's `OAuthGrantHandler`):**

- **`CanHandle(grantType) bool`**
  - Returns `true` if this handler processes the grant type
  - Called to dispatch; first match wins
  - Used for: signal that this handler understands the grant type

- **`ValidateGrant(req) error`**
  - Validates the incoming request
  - Returns `nil` on success, or an error with code (e.g., "invalid_client", "invalid_grant")
  - Use for: check client credentials, verify user, validate scope
  - Called only if `CanHandle()` returned `true`

- **`IssueToken(req) (*TokenResponse, error)`**
  - Mints and returns the access token
  - Called only after `ValidateGrant()` succeeds
  - Use for: generate token JWT/opaque, set expiry, include claims

### TokenRequest and TokenResponse

```go
type TokenRequest struct {
    GrantType    string  // Required: what kind of token request
    ClientID     string  // Client identifier
    ClientSecret string  // Client authentication
    Username     string  // Resource owner (for ROPC)
    Password     string  // Resource owner credentials
    Scope        string  // Requested scopes
}

type TokenResponse struct {
    AccessToken string `json:"access_token"`
    TokenType   string `json:"token_type"`        // Usually "Bearer"
    ExpiresIn   int    `json:"expires_in"`        // Seconds
    Scope       string `json:"scope,omitempty"`   // Granted scopes
}
```

### TokenEndpoint (Dispatcher)

```go
type TokenEndpoint struct {
    handlers []OAuthGrantHandler
}

func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // 1. Parse form data
    r.ParseForm()
    req := &TokenRequest{
        GrantType:    r.FormValue("grant_type"),
        ClientID:     r.FormValue("client_id"),
        ClientSecret: r.FormValue("client_secret"),
        Username:     r.FormValue("username"),
        Password:     r.FormValue("password"),
        Scope:        r.FormValue("scope"),
    }
    
    // 2. Validate required parameters
    if req.GrantType == "" {
        writeTokenError(w, "invalid_request", "grant_type required", http.StatusBadRequest)
        return
    }
    
    // 3. Dispatch to handler
    for _, h := range e.handlers {
        if !h.CanHandle(req.GrantType) {
            continue  // Try next handler
        }
        
        // 4. Validate
        if err := h.ValidateGrant(req); err != nil {
            status := http.StatusUnauthorized  // Default for auth errors
            if err.Error() == "invalid_request" {
                status = http.StatusBadRequest  // Request errors
            }
            writeTokenError(w, err.Error(), "", status)
            return
        }
        
        // 5. Issue token
        tok, err := h.IssueToken(req)
        if err != nil {
            writeTokenError(w, "server_error", err.Error(), http.StatusInternalServerError)
            return
        }
        
        // 6. Return token
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(tok)
        return
    }
    
    // 7. No handler matched
    writeTokenError(w, "unsupported_grant_type", req.GrantType, http.StatusBadRequest)
}
```

**Flow diagram:**

```
POST /oauth2/token
  grant_type=urn:custom:device_code
  password=device-abc
    ↓
Validate grant_type is present
    ↓
Iterate handlers:
  ClientCredentialsHandler.CanHandle("urn:custom:device_code") → false, skip
  ROPCHandler.CanHandle("urn:custom:device_code") → false, skip
  DeviceGrant.CanHandle("urn:custom:device_code") → true, dispatch
    ↓
DeviceGrant.ValidateGrant(req) → check device_code is approved
    ↓
On validation error: return 400 or 401
On validation success: continue
    ↓
DeviceGrant.IssueToken(req) → generate access token
    ↓
Return 200 with token JSON
```

---

## Example Handlers

### 1. ClientCredentialsHandler

Service-to-service authentication (no resource owner):

```go
type ClientCredentialsHandler struct {
    validClients map[string]string  // client_id → secret
}

func NewClientCredentialsHandler() *ClientCredentialsHandler {
    return &ClientCredentialsHandler{validClients: map[string]string{
        "demo-client-id": "demo-secret",
    }}
}

func (h *ClientCredentialsHandler) CanHandle(gt string) bool {
    return gt == "client_credentials"
}

func (h *ClientCredentialsHandler) ValidateGrant(req *TokenRequest) error {
    if secret, ok := h.validClients[req.ClientID]; !ok || secret != req.ClientSecret {
        return fmt.Errorf("invalid_client")
    }
    return nil
}

func (h *ClientCredentialsHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
    return &TokenResponse{
        AccessToken: fmt.Sprintf("cc-tok-%d", time.Now().UnixNano()),
        TokenType:   "Bearer",
        ExpiresIn:   3600,
        Scope:       req.Scope,
    }, nil
}
```

**Use case:** Two services; service A needs a token to call service B.
**Test:**
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret'
```

---

### 2. ROPCHandler (Password Grant)

Resource Owner Password Credentials — user provides username + password directly:

```go
type ROPCHandler struct {
    validUsers map[string]string  // username → password
}

func NewROPCHandler() *ROPCHandler {
    return &ROPCHandler{validUsers: map[string]string{
        "alice": "pass123",
        "bob":   "pass456",
    }}
}

func (h *ROPCHandler) CanHandle(gt string) bool {
    return gt == "password"
}

func (h *ROPCHandler) ValidateGrant(req *TokenRequest) error {
    if pass, ok := h.validUsers[req.Username]; !ok || pass != req.Password {
        return fmt.Errorf("invalid_grant")
    }
    return nil
}

func (h *ROPCHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
    return &TokenResponse{
        AccessToken: fmt.Sprintf("ropc-%s-%d", req.Username, time.Now().UnixNano()),
        TokenType:   "Bearer",
        ExpiresIn:   3600,
        Scope:       req.Scope,
    }, nil
}
```

**Use case:** Native mobile app; user logs in once, app gets token for subsequent API calls.
**Test:**
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=password&username=alice&password=pass123'
```

---

### 3. DeviceGrant (Custom Grant Type)

Simplified device flow — issue token for pre-approved device codes:

```go
type DeviceGrant struct {
    approvedCodes map[string]string  // device_code → username
}

func NewDeviceGrant() *DeviceGrant {
    return &DeviceGrant{approvedCodes: map[string]string{
        "device-abc": "carol",
    }}
}

func (h *DeviceGrant) CanHandle(gt string) bool {
    return gt == "urn:ietf:params:oauth:grant-type:device_code"
}

func (h *DeviceGrant) ValidateGrant(req *TokenRequest) error {
    // device_code passed in password field (simplified)
    if _, ok := h.approvedCodes[req.Password]; !ok {
        return fmt.Errorf("authorization_pending")
    }
    return nil
}

func (h *DeviceGrant) IssueToken(req *TokenRequest) (*TokenResponse, error) {
    user := h.approvedCodes[req.Password]
    return &TokenResponse{
        AccessToken: fmt.Sprintf("device-%s-%d", user, time.Now().UnixNano()),
        TokenType:   "Bearer",
        ExpiresIn:   900,  // 15 minutes for device flow
    }, nil
}
```

**Use case:** IoT devices, headless services, or browser-based apps with limited input.
**Test:**
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code&password=device-abc'
```

---

## Running the Lab

```bash
cd labs/phase4/day51
go run main.go
```

Output:
```
Custom grant handler blueprint on :8091
Test: curl -X POST http://localhost:8091/oauth2/token -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret'
```

**Test endpoints:**
```bash
# Client Credentials — 200
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret'

# ROPC with valid credentials — 200
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=password&username=alice&password=pass123'

# ROPC with invalid credentials — 400
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=password&username=alice&password=wrong'

# Device Code — 200
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code&password=device-abc'

# Unsupported grant type — 400
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=unsupported_grant'

# Missing grant_type — 400
curl -X POST http://localhost:8091/oauth2/token \
  -d 'client_id=demo'

# Health check
curl http://localhost:8091/health
```

---

## Design Patterns in This Blueprint

### 1. First-Match-Wins Dispatch

```go
for _, h := range e.handlers {
    if !h.CanHandle(req.GrantType) {
        continue
    }
    // Handle this grant type
    if err := h.ValidateGrant(req); err != nil { ... }
    tok, err := h.IssueToken(req)
    // ...
    return  // Exit early — first match wins
}
// Only reach here if no handler matched
```

This means **order matters**. If you register a custom `client_credentials` handler before the default one, yours takes precedence.

### 2. Error Codes as Strings

The lab uses simple `fmt.Errorf()` strings:

```go
return fmt.Errorf("invalid_client")
return fmt.Errorf("invalid_grant")
```

The endpoint checks error strings to determine HTTP status:

```go
status := http.StatusUnauthorized  // 401
if err.Error() == "invalid_request" {
    status = http.StatusBadRequest  // 400
}
```

This is simplified for the lab. Production code should use typed errors to carry both code and status.

### 3. Standard OAuth2 Error Response

```go
func writeTokenError(w http.ResponseWriter, code, desc string, status int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]string{
        "error": code,
        "error_description": desc,
    })
}
```

This follows RFC 6749:
- `error` — standard error code (`invalid_client`, `invalid_request`, `invalid_grant`, `unsupported_grant_type`)
- `error_description` — optional human-readable explanation
- HTTP status — 400 (bad request) or 401 (unauthorized)

---

## Comparison to WSO2 OAuthGrantHandler

| Aspect | WSO2 (Java) | Go Blueprint |
|--------|-------------|-------------|
| **Dispatch** | Registry indexed by grant_type | Iterate handlers, first match |
| **Validation** | Throws `IdentityOAuth2Exception` | Returns `error` |
| **Token issuance** | Returns `OAuthAuthzRespDTO` | Returns `(*TokenResponse, error)` |
| **Handler registration** | XML `identity.xml` | Go code, `TokenEndpoint.handlers` slice |
| **Configuration** | Properties passed to handler constructor | Fields in handler struct |
| **Super validation** | Call `super.validateGrant()` | Implement all validation yourself |

---

## Exercises

### Exercise 1: Implement JWTBearerGrant

**Question:**
Add a `JWTBearerGrant` handler for `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`. The client sends an incoming JWT in the `password` field. Validate the JWT's `sub` and `exp` claims, then issue a new token with the same subject.

**Hint:**
- Parse the JWT by base64-decoding the payload (simple, no signature check for lab)
- Extract `sub` (subject) and `exp` (expiry timestamp)
- Validate `exp > now`
- Issue a new token with same `sub`

**Solution sketch:**

```go
import (
    "encoding/base64"
    "encoding/json"
    "strings"
)

type JWTBearerGrant struct {
    issuedTokens map[string]bool  // Track issued tokens (simplified replay prevention)
}

func NewJWTBearerGrant() *JWTBearerGrant {
    return &JWTBearerGrant{issuedTokens: make(map[string]bool)}
}

func (h *JWTBearerGrant) CanHandle(gt string) bool {
    return gt == "urn:ietf:params:oauth:grant-type:jwt-bearer"
}

func (h *JWTBearerGrant) ValidateGrant(req *TokenRequest) error {
    jwtStr := req.Password
    if jwtStr == "" {
        return fmt.Errorf("invalid_request")
    }
    
    // Check for replay
    if h.issuedTokens[jwtStr] {
        return fmt.Errorf("invalid_grant")
    }
    
    // Parse JWT: split into header.payload.signature
    parts := strings.Split(jwtStr, ".")
    if len(parts) != 3 {
        return fmt.Errorf("invalid_grant")
    }
    
    // Base64 decode payload
    payload := parts[1]
    if len(payload)%4 != 0 {
        payload += strings.Repeat("=", 4-len(payload)%4)  // Add padding
    }
    decoded, err := base64.URLEncoding.DecodeString(payload)
    if err != nil {
        return fmt.Errorf("invalid_grant")
    }
    
    // Parse JSON claims
    var claims map[string]interface{}
    if err := json.Unmarshal(decoded, &claims); err != nil {
        return fmt.Errorf("invalid_grant")
    }
    
    // Validate exp
    if exp, ok := claims["exp"].(float64); !ok || exp < float64(time.Now().Unix()) {
        return fmt.Errorf("invalid_grant")
    }
    
    // Validate sub
    if _, ok := claims["sub"]; !ok {
        return fmt.Errorf("invalid_grant")
    }
    
    h.issuedTokens[jwtStr] = true
    req.Username = claims["sub"].(string)
    return nil
}

func (h *JWTBearerGrant) IssueToken(req *TokenRequest) (*TokenResponse, error) {
    return &TokenResponse{
        AccessToken: fmt.Sprintf("jwt-bearer-%s-%d", req.Username, time.Now().UnixNano()),
        TokenType:   "Bearer",
        ExpiresIn:   3600,
        Scope:       req.Scope,
    }, nil
}
```

**Use in main():**
```go
ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
    NewClientCredentialsHandler(),
    NewROPCHandler(),
    NewJWTBearerGrant(),  // Add before DeviceGrant
    NewDeviceGrant(),
}}
```

---

### Exercise 2: Dispatch Order and Handler Priority

**Question:**
The `TokenEndpoint` iterates handlers in order. What happens if two handlers both return `true` from `CanHandle()` for the same grant type?

**Hint:**
The loop returns after the first match (line: `return` after `IssueToken()`).

**Solution sketch:**

**The first matching handler wins.** Subsequent handlers are never called.

```go
for _, h := range e.handlers {
    if !h.CanHandle(req.GrantType) {
        continue  // Skip to next handler
    }
    // First handler that returns true processes the grant
    if err := h.ValidateGrant(req); err != nil {
        // ... error handling ...
        return  // Exit early — never check remaining handlers
    }
    tok, err := h.IssueToken(req)
    // ...
    return  // Exit early — never check remaining handlers
}
```

**Implication:** To override a built-in grant type, register your custom handler **before** the default:

```go
// CORRECT — custom takes precedence
ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
    NewCustomClientCredentialsHandler(),  // Registered first — wins
    NewClientCredentialsHandler(),         // Default, never reached
}}

// WRONG — default takes precedence
ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
    NewClientCredentialsHandler(),        // Default — always wins
    NewCustomClientCredentialsHandler(),  // Never reached
}}
```

This mirrors WSO2's grant handler registry (where you can register custom handlers with a priority override).

---

### Exercise 3: HTTP Status Codes for Token Errors

**Question:**
RFC 6749 specifies different HTTP status codes for different OAuth2 errors:
- `invalid_client` (auth failure) → HTTP 401
- `invalid_request`, `invalid_grant`, `authorization_pending` (request errors) → HTTP 400
- `unsupported_grant_type` (request error) → HTTP 400

How do you carry the correct HTTP status from the handler's error to the endpoint's response?

**Hint:**
Define a typed error struct that carries both the error code and HTTP status. Use `errors.As()` to type-assert the error.

**Solution sketch:**

```go
type GrantError struct {
    Code   string
    Status int
}

func (e *GrantError) Error() string {
    return e.Code
}

// Update handlers to return *GrantError
func (h *ClientCredentialsHandler) ValidateGrant(req *TokenRequest) error {
    if secret, ok := h.validClients[req.ClientID]; !ok || secret != req.ClientSecret {
        return &GrantError{
            Code: "invalid_client",
            Status: http.StatusUnauthorized,  // 401
        }
    }
    return nil
}

func (h *ROPCHandler) ValidateGrant(req *TokenRequest) error {
    if pass, ok := h.validUsers[req.Username]; !ok || pass != req.Password {
        return &GrantError{
            Code: "invalid_grant",
            Status: http.StatusBadRequest,  // 400
        }
    }
    return nil
}

// Update TokenEndpoint to use typed error
func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // ... parse request ...
    
    for _, h := range e.handlers {
        if !h.CanHandle(req.GrantType) {
            continue
        }
        
        if err := h.ValidateGrant(req); err != nil {
            status := http.StatusInternalServerError  // Default
            var ge *GrantError
            if errors.As(err, &ge) {
                status = ge.Status  // Use typed status
            }
            writeTokenError(w, err.Error(), "", status)
            return
        }
        
        // ... issue token ...
        return
    }
    
    writeTokenError(w, "unsupported_grant_type", ..., http.StatusBadRequest)
}
```

**Takeaway:** Use typed errors to carry domain-specific metadata (HTTP status, error severity, etc.) through the error return path. This is idiomatic Go for complex error handling.

---

## Next Steps

1. **Complete the lab:** `go run main.go`, test all grant types
2. **Implement Exercise 1:** Add JWTBearerGrant
3. **Test Exercise 3:** Implement typed errors for correct HTTP status codes
4. **Preview Day 52:** Capstone project — design a custom extension for your platform
5. **Integration:** When ready, translate your Go handlers to Java and deploy to WSO2 IS
