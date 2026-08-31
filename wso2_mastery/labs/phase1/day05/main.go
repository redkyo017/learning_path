// Day 5 Lab — JWT-Issuing OAuth2 Server with JWKS Endpoint
//
// Required dependencies (run from this directory):
//   go mod init wso2lab/day05
//   go get github.com/golang-jwt/jwt/v5
//
// Run:
//   go run main.go
//
// Endpoints:
//   POST /oauth2/token   — client_credentials grant, returns a signed JWT
//   GET  /oauth2/jwks    — returns the RSA public key as a JWK Set

package main

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"log"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ─── WSO2Claims ──────────────────────────────────────────────────────────────
// WSO2Claims mirrors the claim format produced by JWTTokenGenerator.java in
// WSO2 IS. The JSON field names are the full claim URI strings.

type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"` // PRODUCTION or SANDBOX
}

// ─── RSA key (generated once at startup) ─────────────────────────────────────
// DEVELOPMENT ONLY — never use a generated key in production.
// In production, load the key from a secrets manager or Java keystore.

var (
	signingKey *rsa.PrivateKey
	keyID      = "dev-key-1"

	// clients maps clientID → clientSecret (plaintext for lab simplicity only)
	clients = map[string]string{
		"test-client": "test-secret",
	}
)

func init() {
	var err error
	signingKey, err = rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		log.Fatalf("failed to generate RSA key: %v", err)
	}
	log.Printf("RSA-2048 dev key generated (kid=%s) — DO NOT use in production", keyID)
}

// ─── JWT issuing ─────────────────────────────────────────────────────────────

// issueJWT builds and signs a WSO2-compatible JWT for the given client.
// appName is the application name stored in the applicationname claim.
func issueJWT(clientID, scope, appName string) (string, error) {
	now := time.Now()
	claims := WSO2Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "https://localhost:9443/oauth2/token",
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
	// Set kid BEFORE calling SignedString — this is included in the signed header
	token.Header["kid"] = keyID
	return token.SignedString(signingKey)
}

// ─── Token endpoint ───────────────────────────────────────────────────────────

// tokenHandler handles POST /oauth2/token.
// Supports the client_credentials grant only (sufficient for Day 5).
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
		// Also accept form-encoded credentials (less secure, but common in labs)
		clientID = r.FormValue("client_id")
		clientSecret = r.FormValue("client_secret")
	}
	if !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}

	scope := r.FormValue("scope")
	tokenStr, err := issueJWT(clientID, scope, "DefaultApp")
	if err != nil {
		log.Printf("issueJWT error: %v", err)
		oauthError(w, "server_error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]any{
		"access_token": tokenStr,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

// ─── JWKS endpoint ───────────────────────────────────────────────────────────

// jwksHandler handles GET /oauth2/jwks.
// Returns the RSA public key as a JWK Set so clients can verify JWT signatures
// without calling this server again (after caching the JWKS response).
func jwksHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	pub := signingKey.PublicKey
	// n: Base64URL-encoded big-endian modulus bytes (no padding)
	n := base64.RawURLEncoding.EncodeToString(pub.N.Bytes())
	// e: Base64URL-encoded big-endian public exponent bytes
	// 65537 encodes as 0x01 0x00 0x01, which is "AQAB" in Base64URL
	e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pub.E)).Bytes())

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"keys": []map[string]any{
			{
				"kty": "RSA",
				"kid": keyID,
				"use": "sig",
				"alg": "RS256",
				"n":   n,
				"e":   e,
			},
		},
	})
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func validateClient(id, secret string) bool {
	exp, ok := clients[id]
	return ok && exp == secret
}

// generateID returns a random URL-safe ID for use as jti.
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b) //nolint:errcheck — rand.Read never fails on stdlib
	return base64.RawURLEncoding.EncodeToString(b)
}

func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}

// scopesContain is a helper for downstream use — not needed by this server but
// useful when you extend it to check that a required scope is present.
func scopesContain(scopeStr, required string) bool {
	for _, s := range strings.Fields(scopeStr) {
		if s == required {
			return true
		}
	}
	return false
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler)
	http.HandleFunc("/oauth2/jwks", jwksHandler)
	log.Println("Day 5 server listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}
