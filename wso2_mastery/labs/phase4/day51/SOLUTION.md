# Day 51 — Solutions

## Exercise 1: JWTBearerGrant Handler

**Concept:** Accept an incoming JWT as `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer` with the JWT in the `password` field. Validate the JWT signature (or for lab simplicity, just check `sub` and `exp` claims), then issue a new token with the same subject.

**Solution:**

For a full production solution, use a JWT library like `golang-jwt/jwt`. For the lab, we'll do a simplified base64 decode and validate:

```go
import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"
)

type JWTBearerGrant struct {
	issuedTokens map[string]bool // Track issued tokens to prevent replay (simplified)
}

func NewJWTBearerGrant() *JWTBearerGrant {
	return &JWTBearerGrant{issuedTokens: make(map[string]bool)}
}

func (h *JWTBearerGrant) CanHandle(gt string) bool {
	return gt == "urn:ietf:params:oauth:grant-type:jwt-bearer"
}

func (h *JWTBearerGrant) ValidateGrant(req *TokenRequest) error {
	// JWT is passed in password field
	jwtStr := req.Password
	if jwtStr == "" {
		return fmt.Errorf("invalid_request")
	}
	
	// Check if already used (simplified replay prevention)
	if h.issuedTokens[jwtStr] {
		return fmt.Errorf("invalid_grant")
	}

	// Parse JWT: extract and decode payload
	parts := strings.Split(jwtStr, ".")
	if len(parts) != 3 {
		return fmt.Errorf("invalid_grant")
	}

	// Decode payload (add padding if needed)
	payload := parts[1]
	if len(payload)%4 != 0 {
		payload += strings.Repeat("=", 4-len(payload)%4)
	}
	decoded, err := base64.URLEncoding.DecodeString(payload)
	if err != nil {
		return fmt.Errorf("invalid_grant")
	}

	// Extract claims
	var claims map[string]interface{}
	if err := json.Unmarshal(decoded, &claims); err != nil {
		return fmt.Errorf("invalid_grant")
	}

	// Validate exp claim (simplified: check if present and > 0)
	if exp, ok := claims["exp"].(float64); !ok || exp < float64(time.Now().Unix()) {
		return fmt.Errorf("invalid_grant")
	}

	// Validate sub claim (must be present)
	if _, ok := claims["sub"]; !ok {
		return fmt.Errorf("invalid_grant")
	}

	h.issuedTokens[jwtStr] = true
	req.Username = claims["sub"].(string) // Store for token issuance
	return nil
}

func (h *JWTBearerGrant) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	// Issue a new token with the same subject
	return &TokenResponse{
		AccessToken: fmt.Sprintf("jwt-bearer-%s-%d", req.Username, time.Now().UnixNano()),
		TokenType:   "Bearer",
		ExpiresIn:   3600,
		Scope:       req.Scope,
	}, nil
}
```

**How to use:**

Add to `main()`:

```go
func main() {
	ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
		NewClientCredentialsHandler(),
		NewROPCHandler(),
		NewJWTBearerGrant(),      // Add before DeviceGrant
		NewDeviceGrant(),
	}}
	// ... rest of main
}
```

**Test (simplified JWT):**

Create a minimal JWT (base64-encoded payload with `sub` and `exp`):

```bash
# Payload: {"sub":"user123","exp":9999999999}
# Base64: eyJzdWIiOiJ1c2VyMTIzIiwiZXhwIjo5OTk5OTk5OTk5fQ
PAYLOAD="eyJzdWIiOiJ1c2VyMTIzIiwiZXhwIjo5OTk5OTk5OTk5fQ"
JWT="header.${PAYLOAD}.signature"

curl -X POST http://localhost:8091/oauth2/token \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&password=${JWT}"
```

Expected output:
```json
{
  "access_token": "jwt-bearer-user123-<timestamp>",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Key points:**
- Validate `exp` claim to prevent expired tokens
- Validate `sub` claim (subject/user ID)
- For production, use `golang-jwt/jwt` and verify the signature
- Simplified replay prevention: track issued JWTs in a map (production would use a DB or cache)

---

## Exercise 2: What happens if two handlers both return `true` for CanHandle()?

**Answer:** The first matching handler wins. Subsequent handlers are never called.

**Code reference:**

```go
func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// ... parse request ...
	
	for _, h := range e.handlers {
		if !h.CanHandle(req.GrantType) {
			continue  // Skip this handler
		}
		// First match processes the grant
		if err := h.ValidateGrant(req); err != nil {
			// ... handle error ...
			return  // Exit here — no other handlers checked
		}
		tok, err := h.IssueToken(req)
		// ... handle response ...
		return  // Exit here — no other handlers checked
	}
	// Only reach here if NO handler matches
	writeTokenError(w, "unsupported_grant_type", ...)
}
```

**Implication:**

To override a built-in grant type (e.g., `client_credentials`), register your custom handler BEFORE the default one:

```go
// CORRECT — custom handler takes precedence
ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
	NewCustomClientCredentialsHandler(),  // Registered first
	NewClientCredentialsHandler(),         // Default, never reached
	NewROPCHandler(),
}}

// WRONG — default handler always takes precedence
ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
	NewClientCredentialsHandler(),         // Default, always wins
	NewCustomClientCredentialsHandler(),   // Never reached
	NewROPCHandler(),
}}
```

This mirrors WSO2's grant handler registry priority.

---

## Exercise 3: How do you carry HTTP status through error handling?

**Problem:**
- `invalid_client` (auth failure) → HTTP 401
- `invalid_request`, `authorization_pending`, `invalid_grant` (request errors) → HTTP 400
- But `ValidateGrant()` only returns `error`; how do we encode the status?

**Solution:**

Define a typed error that carries both the error code and HTTP status:

```go
type GrantError struct {
	Code   string
	Status int
}

func (e *GrantError) Error() string {
	return e.Code
}

// Update grant handlers to return *GrantError
func (h *ClientCredentialsHandler) ValidateGrant(req *TokenRequest) error {
	if secret, ok := h.validClients[req.ClientID]; !ok || secret != req.ClientSecret {
		return &GrantError{Code: "invalid_client", Status: http.StatusUnauthorized}
	}
	return nil
}

func (h *ROPCHandler) ValidateGrant(req *TokenRequest) error {
	if pass, ok := h.validUsers[req.Username]; !ok || pass != req.Password {
		return &GrantError{Code: "invalid_grant", Status: http.StatusBadRequest}
	}
	return nil
}

func (h *DeviceGrant) ValidateGrant(req *TokenRequest) error {
	if _, ok := h.approvedCodes[req.Password]; !ok {
		return &GrantError{Code: "authorization_pending", Status: http.StatusBadRequest}
	}
	return nil
}
```

**Update TokenEndpoint to use typed error:**

```go
func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// ... parse request ...
	
	for _, h := range e.handlers {
		if !h.CanHandle(req.GrantType) {
			continue
		}
		if err := h.ValidateGrant(req); err != nil {
			status := http.StatusInternalServerError // default
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
	writeTokenError(w, "unsupported_grant_type", req.GrantType, http.StatusBadRequest)
}
```

**Current lab code (simplified):**

The current `main.go` uses a simpler heuristic:

```go
if err := h.ValidateGrant(req); err != nil {
	status := http.StatusUnauthorized
	if err.Error() == "invalid_request" || err.Error() == "authorization_pending" {
		status = http.StatusBadRequest
	}
	writeTokenError(w, err.Error(), "", status)
	return
}
```

This works for the lab but isn't extensible. The typed error approach is production-ready.

**Takeaway:**

Use typed errors to carry domain-specific information (HTTP status, error codes, severity) through the error return path. `errors.As()` is the idiomatic Go pattern for type-asserting errors.
