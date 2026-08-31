// Day 7 Lab — Token Introspection (RFC 7662)
//
// This file extends the Day 6 JWT-issuing + gateway-validation server to add
// an RFC 7662 introspection endpoint. It is self-contained: all types, helpers,
// and the full server are defined here — no Day 6 files are imported.
//
// Required dependencies (run from this directory):
//   go mod init wso2lab/day07
//   go get github.com/golang-jwt/jwt/v5
//
// Endpoints:
//   POST /oauth2/token      — client_credentials grant, returns signed JWT
//   GET  /oauth2/jwks       — RSA public key as JWK Set
//   POST /oauth2/introspect — RFC 7662; requires Basic Auth; returns active status + claims
//   GET  /api/hello         — protected; requires valid Bearer JWT

package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ─── WSO2Claims ──────────────────────────────────────────────────────────────

// WSO2Claims mirrors the claim format from JWTTokenGenerator.java in WSO2 IS.
type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"` // PRODUCTION or SANDBOX
}

// ─── Context key types ────────────────────────────────────────────────────────
// Private named types prevent key collisions with other packages.

type contextKey string

const claimsContextKey contextKey = "wso2claims"

// ─── RSA key (generated once at startup) ─────────────────────────────────────
// DEVELOPMENT ONLY — never use a generated key in production.

var (
	signingKey *rsa.PrivateKey
	keyID      = "dev-key-1"

	clients = map[string]string{
		"test-client": "test-secret",
	}

	// revokedTokens holds token strings that have been explicitly revoked.
	// sync.Map is used because HTTP handlers run concurrently.
	// Key: token string, Value: time.Time of revocation.
	revokedTokens sync.Map
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
	token.Header["kid"] = keyID
	return token.SignedString(signingKey)
}

// ─── JWT validation ───────────────────────────────────────────────────────────

// validateJWT parses and validates a Bearer JWT against the local signing key.
func validateJWT(tokenStr string) (*WSO2Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		&WSO2Claims{},
		func(t *jwt.Token) (any, error) {
			// Algorithm guard: reject non-RSA tokens to prevent alg confusion attacks.
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

// ─── Auth middleware ──────────────────────────────────────────────────────────

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "missing_token"})
			return
		}
		bearer := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))

		claims, err := validateJWT(bearer)
		if err != nil {
			log.Printf("JWT validation failed: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid_token"})
			return
		}

		ctx := context.WithValue(r.Context(), claimsContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func claimsFromContext(ctx context.Context) *WSO2Claims {
	v := ctx.Value(claimsContextKey)
	if v == nil {
		return nil
	}
	c, _ := v.(*WSO2Claims)
	return c
}

// ─── HTTP handlers ────────────────────────────────────────────────────────────

// tokenHandler handles POST /oauth2/token.
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
	tokenStr, err := issueJWT(clientID, scope, "DefaultApp")
	if err != nil {
		log.Printf("issueJWT error: %v", err)
		oauthError(w, "server_error", http.StatusInternalServerError)
		return
	}
	log.Printf("token_issued client_id=%s exp=+3600s", clientID)
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	json.NewEncoder(w).Encode(map[string]any{
		"access_token": tokenStr,
		"token_type":   "Bearer",
		"expires_in":   3600,
		"scope":        scope,
	})
}

// jwksHandler handles GET /oauth2/jwks.
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

// introspectHandler handles POST /oauth2/introspect per RFC 7662.
//
// The endpoint itself requires authentication (Basic Auth with a registered
// client) to prevent "token oracle" attacks where an unauthenticated caller
// can enumerate valid tokens by submitting arbitrary strings.
func introspectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Require Basic Auth on the introspect caller (RFC 7662 §2.1).
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		w.Header().Set("WWW-Authenticate", `Basic realm="introspection"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	r.ParseForm() //nolint:errcheck
	tokenStr := r.FormValue("token")

	w.Header().Set("Content-Type", "application/json")

	// Attempt JWT validation first.
	claims, err := validateJWT(tokenStr)
	if err != nil {
		// Token is malformed, expired, or has an invalid signature.
		// Per RFC 7662: return only active:false — do not reveal the reason.
		log.Printf("introspect active=false caller=%s reason=jwt_invalid", clientID)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	// Check the server-side revocation map.
	// A JWT that passes validateJWT is cryptographically valid and not expired,
	// but may still have been explicitly revoked after issuance.
	if _, revoked := revokedTokens.Load(tokenStr); revoked {
		log.Printf("introspect active=false caller=%s reason=revoked sub=%s", clientID, claims.Subject)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	// Token is valid and not revoked — return full RFC 7662 response.
	log.Printf("introspect active=true caller=%s sub=%s exp=%d", clientID, claims.Subject, claims.ExpiresAt.Unix())
	json.NewEncoder(w).Encode(map[string]any{
		"active":     true,
		"sub":        claims.Subject,
		"exp":        claims.ExpiresAt.Unix(),
		"iat":        claims.IssuedAt.Unix(),
		"iss":        claims.Issuer,
		"client_id":  claims.Subscriber,
		"token_type": "Bearer",
		// WSO2-specific extension claims
		"http://wso2.org/claims/applicationname": claims.ApplicationName,
		"http://wso2.org/claims/keytype":          claims.KeyType,
	})
}

// helloHandler is a protected API endpoint.
func helloHandler(w http.ResponseWriter, r *http.Request) {
	claims := claimsFromContext(r.Context())
	if claims == nil {
		http.Error(w, "no claims in context", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"message":     "hello from protected endpoint",
		"subject":     claims.Subject,
		"issuer":      claims.Issuer,
		"expires_at":  claims.ExpiresAt.Time.UTC().Format(time.RFC3339),
		"application": claims.ApplicationName,
		"keytype":     claims.KeyType,
	})
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func validateClient(id, secret string) bool {
	exp, ok := clients[id]
	return ok && exp == secret
}

func generateID() string {
	b := make([]byte, 16)
	rand.Read(b) //nolint:errcheck
	return base64.RawURLEncoding.EncodeToString(b)
}

func oauthError(w http.ResponseWriter, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code})
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler)
	http.HandleFunc("/oauth2/jwks", jwksHandler)
	http.HandleFunc("/oauth2/introspect", introspectHandler)
	http.Handle("/api/hello", authMiddleware(http.HandlerFunc(helloHandler)))

	log.Println("Day 7 server listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}
