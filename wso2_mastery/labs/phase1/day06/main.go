// Day 6 Lab — Gateway Validation Middleware
//
// This file extends the Day 5 JWT-issuing server to add gateway-side JWT
// validation. It is self-contained: all types, helpers, and the full server
// are defined here — no Day 5 files are imported.
//
// Required dependencies (run from this directory):
//   go mod init wso2lab/day06
//   go get github.com/golang-jwt/jwt/v5
//
// Endpoints:
//   POST /oauth2/token   — client_credentials grant, returns signed JWT
//   GET  /oauth2/jwks    — RSA public key as JWK Set
//   GET  /api/hello      — protected; requires valid Bearer JWT, returns claims

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
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ─── WSO2Claims ──────────────────────────────────────────────────────────────

// WSO2Claims mirrors the claim format from JWTTokenGenerator.java in WSO2 IS.
// Embedding jwt.RegisteredClaims lets ParseWithClaims validate exp/nbf/iss
// automatically.
type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"` // PRODUCTION or SANDBOX
}

// ─── Context key type ─────────────────────────────────────────────────────────
// Using a private named type prevents key collisions with other packages that
// might use the plain string "wso2claims" as a context key.

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

// ─── JWT validation (gateway side) ───────────────────────────────────────────

// validateJWT parses and validates a Bearer JWT against the local signing key.
// It returns the WSO2Claims on success, or a non-nil error on any failure
// (expired, bad signature, wrong algorithm, malformed).
func validateJWT(tokenStr string) (*WSO2Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		&WSO2Claims{},
		func(t *jwt.Token) (any, error) {
			// Algorithm guard: reject non-RSA tokens to prevent the HS256/RS256
			// algorithm confusion attack (an attacker signs with the public key
			// bytes as an HMAC secret and sets alg:HS256).
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

// authMiddleware is a sample gateway-side middleware that:
//  1. Extracts the Bearer token from the Authorization header
//  2. Calls validateJWT to verify the signature and standard time claims
//  3. Puts the validated *WSO2Claims into the request context
//  4. Calls the next handler — or returns 401 if anything fails
//
// The context key is a typed private type (contextKey), not a plain string,
// so it cannot accidentally collide with keys set by other packages.
func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "missing_token"})
			return
		}
		bearer := strings.TrimPrefix(authHeader, "Bearer ")
		bearer = strings.TrimSpace(bearer)

		claims, err := validateJWT(bearer)
		if err != nil {
			log.Printf("JWT validation failed: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid_token"})
			return
		}

		// Attach validated claims to the request context for downstream handlers.
		ctx := context.WithValue(r.Context(), claimsContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// claimsFromContext retrieves the WSO2Claims stored by authMiddleware.
// Returns nil if the claims are not present (i.e. request did not pass through middleware).
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

// helloHandler is a protected API endpoint that reads claims from the context
// (put there by authMiddleware) and returns a summary as JSON.
func helloHandler(w http.ResponseWriter, r *http.Request) {
	claims := claimsFromContext(r.Context())
	if claims == nil {
		// Should not reach here if authMiddleware is wired correctly
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
		"tier":        claims.ApplicationTier,
		"version":     claims.APIVersion,
		"subscriber":  claims.Subscriber,
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
	// Public endpoints
	http.HandleFunc("/oauth2/token", tokenHandler)
	http.HandleFunc("/oauth2/jwks", jwksHandler)

	// Protected endpoint — wrapped with authMiddleware
	http.Handle("/api/hello", authMiddleware(http.HandlerFunc(helloHandler)))

	log.Println("Day 6 server listening on :9443")
	log.Fatal(http.ListenAndServe(":9443", nil))
}
