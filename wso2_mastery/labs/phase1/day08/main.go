// Day 8 Lab — Token Revocation (RFC 7009)
//
// This file extends the Day 7 introspection server to add an RFC 7009
// revocation endpoint. It is self-contained: all types, helpers, and the
// full server are defined here — no Day 7 files are imported.
//
// Required dependencies (run from this directory):
//   go mod init wso2lab/day08
//   go get github.com/golang-jwt/jwt/v5
//
// Endpoints:
//   POST /oauth2/token      — client_credentials grant, returns signed JWT
//   GET  /oauth2/jwks       — RSA public key as JWK Set
//   POST /oauth2/introspect — RFC 7662; requires Basic Auth
//   POST /oauth2/revoke     — RFC 7009; requires Basic Auth; always returns 200
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

type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

// ─── Context key types ────────────────────────────────────────────────────────

type contextKey string

const claimsContextKey contextKey = "wso2claims"

// ─── State ────────────────────────────────────────────────────────────────────

var (
	signingKey *rsa.PrivateKey
	keyID      = "dev-key-1"

	clients = map[string]string{
		"test-client": "test-secret",
	}

	// revokedTokens stores explicitly revoked token strings.
	// Key: token string (full JWT), Value: time.Time of revocation.
	// sync.Map is safe for concurrent handler goroutines.
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

// introspectHandler implements RFC 7662 token introspection.
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
		log.Printf("introspect active=false caller=%s reason=jwt_invalid", clientID)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	if _, revoked := revokedTokens.Load(tokenStr); revoked {
		log.Printf("introspect active=false caller=%s reason=revoked sub=%s", clientID, claims.Subject)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	log.Printf("introspect active=true caller=%s sub=%s", clientID, claims.Subject)
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

// revokeHandler implements RFC 7009 token revocation.
//
// Key RFC 7009 requirement: always return HTTP 200, even if the token is
// unknown, already revoked, or was never issued. Returning a different status
// for unknown tokens would let an attacker enumerate valid token IDs.
func revokeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// The client submitting the revocation must authenticate.
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}

	r.ParseForm() //nolint:errcheck
	token := r.FormValue("token")

	if token != "" {
		// Store the token in the revocation map regardless of whether it was
		// ever a valid token — the 200 response must not change either way.
		revokedTokens.Store(token, time.Now())
		log.Printf("token_revoked client_id=%s token_prefix=%s", clientID, safePrefix(token, 8))
	}

	// RFC 7009 §2.2: always 200, even for unknown/already-revoked tokens.
	w.WriteHeader(http.StatusOK)
}

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

// safePrefix returns up to n characters of s, or the full string if shorter.
// Used to log a token prefix for traceability without logging the full token.
func safePrefix(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	http.HandleFunc("/oauth2/token", tokenHandler)
	http.HandleFunc("/oauth2/jwks", jwksHandler)
	http.HandleFunc("/oauth2/introspect", introspectHandler)
	http.HandleFunc("/oauth2/revoke", revokeHandler)
	http.Handle("/api/hello", authMiddleware(http.HandlerFunc(helloHandler)))

	log.Println("Day 8 server listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}
