// Day 11 Lab — WSO2 Key Manager: Client Registration + Token Service
//
// This file implements the full WSO2 3rd-party Key Manager REST interface:
//   POST   /api/am/keymanager/v1/keymanager/application     — register OAuth client
//   DELETE /api/am/keymanager/v1/keymanager/application/{id} — delete OAuth client
//   POST   /api/am/keymanager/v1/oauth2/token               — issue JWT
//   POST   /api/am/keymanager/v1/oauth2/introspect          — RFC 7662 introspect
//   POST   /api/am/keymanager/v1/oauth2/revoke              — RFC 7009 revoke
//   GET    /api/am/keymanager/v1/jwks                       — JWK Set (public key)
//   GET    /health                                          — liveness probe
//
// It is fully self-contained. No other day's files are imported.
//
// Exercise: the deleteApplicationHandler body is intentionally incomplete —
// finish it using path.Base to extract the client ID from the URL.
//
// Setup (run from this directory):
//   go mod init keymanager && go get github.com/golang-jwt/jwt/v5
//
// Run:
//   go run main.go
//
// Requires Go 1.21+.

package main

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"path"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ─── Client registry ──────────────────────────────────────────────────────────

// ClientRecord holds the OAuth 2.0 client credentials created by
// registerApplicationHandler and validated by the token endpoint.
type ClientRecord struct {
	ClientID     string   `json:"clientId"`
	ClientSecret string   `json:"clientSecret"`
	ClientName   string   `json:"clientName"`
	GrantTypes   []string `json:"grantTypes"`
	CallbackURL  string   `json:"callbackUrl"`
}

// clientRegistry is the in-memory store of registered OAuth clients.
// sync.Map is safe for concurrent reads and writes.
var clientRegistry sync.Map // key: clientID (string) → value: ClientRecord

// ─── WSO2 JWT claims ──────────────────────────────────────────────────────────

// WSO2Claims extends jwt.RegisteredClaims with the custom claims that
// WSO2 APIM gateways expect to find in every access token.
type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

// ─── Server state ─────────────────────────────────────────────────────────────

var (
	signingKey *rsa.PrivateKey
	keyID      = "km-dev-key-1"

	revokedTokens sync.Map // key: token string → value: time.Time
)

func init() {
	var err error
	signingKey, err = rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to generate RSA key: %v\n", err)
		os.Exit(1)
	}
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// generateID returns a 22-character cryptographically random base64url string.
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b) //nolint:errcheck
	return base64.RawURLEncoding.EncodeToString(b)
}

// validateClient checks credentials against the dynamic client registry.
// A static fallback client (test-client / test-secret) is provided for
// development convenience; remove it in production.
func validateClient(id, secret string) bool {
	// Fallback: static test client for smoke-testing without registration.
	if id == "test-client" && secret == "test-secret" {
		return true
	}
	v, ok := clientRegistry.Load(id)
	if !ok {
		return false
	}
	rec := v.(ClientRecord)
	return rec.ClientSecret == secret
}

// issueJWT creates and signs a WSO2-shaped JWT access token.
func issueJWT(clientID, scope, appName string) (string, error) {
	now := time.Now()
	claims := WSO2Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "https://localhost:9444/oauth2/token",
			Subject:   clientID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(3600 * time.Second)),
			ID:        generateID(),
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

// validateJWT parses and verifies a JWT signed by this server.
func validateJWT(tokenStr string) (*WSO2Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		&WSO2Claims{},
		func(t *jwt.Token) (any, error) {
			if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return &signingKey.PublicKey, nil
		},
	)
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*WSO2Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}

// oauthError writes an RFC 6749-compliant JSON error response.
func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}

// ─── Application registration handlers ───────────────────────────────────────

// registerApplicationHandler handles:
//
//	POST /api/am/keymanager/v1/keymanager/application
//
// APIM calls this when a developer subscribes an application to an API.
// The handler generates a clientId + clientSecret, stores the record, and
// returns 201 Created with the full ClientRecord.
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
	if req.ApplicationName == "" {
		http.Error(w, "applicationName required", http.StatusBadRequest)
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

	log.Printf("registered_app name=%q client_id=%s", req.ApplicationName, clientID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(rec)
}

// deleteApplicationHandler handles:
//
//	DELETE /api/am/keymanager/v1/keymanager/application/{id}
//
// EXERCISE: the body below is intentionally incomplete.
// Replace the TODO comment with the two lines that:
//   (a) extract clientID from the URL path using path.Base
//   (b) delete it from clientRegistry
//
// See SOLUTION.md for the complete implementation.
func deleteApplicationHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// TODO: extract clientID from r.URL.Path using path.Base
	//       then call clientRegistry.Delete(clientID)

	w.WriteHeader(http.StatusNoContent)
}

// ─── Token endpoint ───────────────────────────────────────────────────────────

// tokenHandler handles:
//
//	POST /api/am/keymanager/v1/oauth2/token
//
// Supports grant_type=client_credentials only.
func tokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := r.ParseForm(); err != nil {
		oauthError(w, "invalid_request", http.StatusBadRequest)
		return
	}
	switch r.FormValue("grant_type") {
	case "client_credentials":
		handleClientCredentials(w, r)
	default:
		oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
	}
}

func handleClientCredentials(w http.ResponseWriter, r *http.Request) {
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok {
		clientID = r.FormValue("client_id")
		clientSecret = r.FormValue("client_secret")
	}
	if !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	scope := r.FormValue("scope")
	appName := "DefaultApp"
	if v, loaded := clientRegistry.Load(clientID); loaded {
		appName = v.(ClientRecord).ClientName
	}
	tokenStr, err := issueJWT(clientID, scope, appName)
	if err != nil {
		oauthError(w, "server_error", http.StatusInternalServerError)
		return
	}
	log.Printf("token_issued client_id=%s", clientID)
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]any{
		"access_token": tokenStr,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

// ─── Introspect endpoint ──────────────────────────────────────────────────────

// introspectHandler handles:
//
//	POST /api/am/keymanager/v1/oauth2/introspect
//
// RFC 7662: validates a token and returns its claims.
// Caller must authenticate with Basic Auth (any registered client).
func introspectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		w.Header().Set("WWW-Authenticate", `Basic realm="introspection"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	r.ParseForm() //nolint:errcheck
	tokenStr := r.FormValue("token")

	w.Header().Set("Content-Type", "application/json")

	claims, err := validateJWT(tokenStr)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}
	if _, revoked := revokedTokens.Load(tokenStr); revoked {
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}
	json.NewEncoder(w).Encode(map[string]any{
		"active":     true,
		"sub":        claims.Subject,
		"exp":        claims.ExpiresAt.Unix(),
		"iat":        claims.IssuedAt.Unix(),
		"iss":        claims.Issuer,
		"client_id":  claims.Subscriber,
		"token_type": "Bearer",
		"http://wso2.org/claims/applicationname": claims.ApplicationName,
		"http://wso2.org/claims/keytype":          claims.KeyType,
	})
}

// ─── Revoke endpoint ──────────────────────────────────────────────────────────

// revokeHandler handles:
//
//	POST /api/am/keymanager/v1/oauth2/revoke
//
// RFC 7009: marks a token as revoked.  Always returns 200 (even for unknown tokens).
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
	r.ParseForm() //nolint:errcheck
	token := r.FormValue("token")
	if token != "" {
		revokedTokens.Store(token, time.Now())
		log.Printf("token_revoked client_id=%s prefix=%s", clientID, safePrefix(token, 8))
	}
	w.WriteHeader(http.StatusOK)
}

// ─── JWKS endpoint ────────────────────────────────────────────────────────────

// jwksHandler handles:
//
//	GET /api/am/keymanager/v1/jwks
//
// Returns the RSA public key as a JWK Set so that APIM (and any gateway) can
// validate tokens locally without calling introspect for every request.
func jwksHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	pub := signingKey.PublicKey
	n := base64.RawURLEncoding.EncodeToString(pub.N.Bytes())
	e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pub.E)).Bytes())
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"keys": []map[string]any{
			{"kty": "RSA", "kid": keyID, "use": "sig", "alg": "RS256", "n": n, "e": e},
		},
	})
}

// ─── Health endpoint ──────────────────────────────────────────────────────────

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
}

// ─── Misc helpers ─────────────────────────────────────────────────────────────

func safePrefix(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// applicationRouter dispatches /keymanager/application and
// /keymanager/application/{id} to the correct handler based on method.
// net/http's default mux does not support path parameters, so we do a
// simple method check here.
func applicationRouter(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodPost:
		registerApplicationHandler(w, r)
	case http.MethodDelete:
		deleteApplicationHandler(w, r)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// ─── Route paths (exported as constants for readability) ─────────────────────

const (
	pathApplication = "/api/am/keymanager/v1/keymanager/application"
	pathToken       = "/api/am/keymanager/v1/oauth2/token"
	pathIntrospect  = "/api/am/keymanager/v1/oauth2/introspect"
	pathRevoke      = "/api/am/keymanager/v1/oauth2/revoke"
	pathJWKS        = "/api/am/keymanager/v1/jwks"
	pathHealth      = "/health"
)

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	// applicationRouter handles both POST (register) and DELETE (delete/{id}).
	// For DELETE, path.Base in deleteApplicationHandler extracts the client ID.
	// We register the prefix so DELETE /keymanager/application/abc matches too.
	http.HandleFunc(pathApplication, applicationRouter)
	http.HandleFunc(pathApplication+"/", applicationRouter) // with trailing /{id}

	http.HandleFunc(pathToken, tokenHandler)
	http.HandleFunc(pathIntrospect, introspectHandler)
	http.HandleFunc(pathRevoke, revokeHandler)
	http.HandleFunc(pathJWKS, jwksHandler)
	http.HandleFunc(pathHealth, healthHandler)

	addr := ":9444"
	log.Printf("Key Manager listening on %s (Day 11 — no structured logging yet)", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

// Ensure path is imported now; the student's deleteApplicationHandler will
// call path.Base — adding that call activates the import fully.
var _ = path.Base
