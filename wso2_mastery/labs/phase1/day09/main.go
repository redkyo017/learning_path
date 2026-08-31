// Day 9 Lab — End-to-End Lifecycle + Structured Logging
//
// This file extends the Day 8 server (issue + introspect + revoke) to add:
//   - Structured JSON logging via log/slog (Go 1.21+)
//   - Correlation ID middleware: one ID per HTTP request, in every log line
//   - Typed context key for correlation ID (unexported struct, prevents collisions)
//
// It is self-contained: all types, helpers, and the full server are defined here.
// No Day 7 or Day 8 files are imported.
//
// Required dependencies (run from this directory):
//   go mod init wso2lab/day09
//   go get github.com/golang-jwt/jwt/v5
//
// Requires Go 1.21+ for log/slog.
//
// Endpoints:
//   POST /oauth2/token      — client_credentials grant
//   GET  /oauth2/jwks       — RSA public key as JWK Set
//   POST /oauth2/introspect — RFC 7662
//   POST /oauth2/revoke     — RFC 7009
//   GET  /api/hello         — protected endpoint

package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"os"
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
//
// Two separate typed context keys are defined here:
//
//   - claimsKey (contextKey string alias): carries validated *WSO2Claims from
//     authMiddleware to protected handlers.
//
//   - correlationKey (unexported empty struct): carries the per-request
//     correlation ID from correlationMiddleware to every handler.
//
// Using a private struct type for correlationKey (rather than a string alias)
// provides the strongest collision guarantee: the type is unexported and has no
// value — it cannot be accidentally replicated by any imported package.

type contextKey string

const claimsContextKey contextKey = "wso2claims"

// correlationKey is an unexported struct used as a context key.
// An empty struct type is used (not a string) to make collisions impossible
// even if another package uses the string "correlation_id" as a context key.
type correlationKey struct{}

// ─── State ────────────────────────────────────────────────────────────────────

var (
	signingKey *rsa.PrivateKey
	keyID      = "dev-key-1"

	clients = map[string]string{
		"test-client": "test-secret",
	}

	revokedTokens sync.Map
)

func init() {
	var err error
	signingKey, err = rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		// log.Fatal equivalent via slog — slog is not yet set up at init time,
		// so use os.Stderr directly for this startup-critical message.
		fmt.Fprintf(os.Stderr, "failed to generate RSA key: %v\n", err)
		os.Exit(1)
	}
	// init-time message goes to the default slog handler (text, stderr).
	// The JSON handler is installed in main() after this runs.
	slog.Info("rsa_key_generated", "kid", keyID, "note", "DO NOT use in production")
}

// ─── Correlation ID helpers ───────────────────────────────────────────────────

// correlationMiddleware generates a unique ID for each HTTP request and stores
// it in the request context. All handlers downstream of this middleware can
// retrieve the ID with correlationFromCtx and include it in every slog call.
func correlationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := generateID() // 16 bytes of crypto/rand, base64url-encoded → 22 chars
		ctx := context.WithValue(r.Context(), correlationKey{}, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// correlationFromCtx retrieves the correlation ID stored by correlationMiddleware.
// Returns an empty string if the middleware was not applied to this request.
func correlationFromCtx(ctx context.Context) string {
	v, _ := ctx.Value(correlationKey{}).(string)
	return v
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
		corrID := correlationFromCtx(r.Context())
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			slog.Warn("token_invalid",
				"correlation_id", corrID,
				"reason", "missing_bearer_header",
			)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "missing_token"})
			return
		}
		bearer := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		claims, err := validateJWT(bearer)
		if err != nil {
			slog.Warn("token_invalid",
				"correlation_id", corrID,
				"reason", err.Error(),
			)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid_token"})
			return
		}
		slog.Info("token_validated",
			"correlation_id", corrID,
			"client_id", claims.Subscriber,
			"sub", claims.Subject,
		)
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
	corrID := correlationFromCtx(r.Context())
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok {
		clientID = r.FormValue("client_id")
		clientSecret = r.FormValue("client_secret")
	}
	if !validateClient(clientID, clientSecret) {
		slog.Warn("token_invalid",
			"correlation_id", corrID,
			"reason", "invalid_client_credentials",
			"client_id", clientID,
		)
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	scope := r.FormValue("scope")
	tokenStr, err := issueJWT(clientID, scope, "DefaultApp")
	if err != nil {
		slog.Error("server_error",
			"correlation_id", corrID,
			"err", err,
		)
		oauthError(w, "server_error", http.StatusInternalServerError)
		return
	}
	expUnix := time.Now().Add(3600 * time.Second).Unix()
	slog.Info("token_issued",
		"correlation_id", corrID,
		"client_id", clientID,
		"exp", expUnix,
	)
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

// introspectHandler implements RFC 7662.
func introspectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	corrID := correlationFromCtx(r.Context())
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		slog.Warn("token_invalid",
			"correlation_id", corrID,
			"reason", "introspect_caller_unauthenticated",
		)
		w.Header().Set("WWW-Authenticate", `Basic realm="introspection"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	r.ParseForm() //nolint:errcheck
	tokenStr := r.FormValue("token")

	w.Header().Set("Content-Type", "application/json")

	claims, err := validateJWT(tokenStr)
	if err != nil {
		slog.Info("introspect_called",
			"correlation_id", corrID,
			"caller_client_id", clientID,
			"active", false,
			"reason", "jwt_invalid",
		)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	if _, revoked := revokedTokens.Load(tokenStr); revoked {
		slog.Info("introspect_called",
			"correlation_id", corrID,
			"caller_client_id", clientID,
			"active", false,
			"reason", "revoked",
			"sub", claims.Subject,
		)
		json.NewEncoder(w).Encode(map[string]any{"active": false})
		return
	}

	slog.Info("introspect_called",
		"correlation_id", corrID,
		"caller_client_id", clientID,
		"active", true,
		"sub", claims.Subject,
		"exp", claims.ExpiresAt.Unix(),
	)
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

// revokeHandler implements RFC 7009.
func revokeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	corrID := correlationFromCtx(r.Context())
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		slog.Warn("token_invalid",
			"correlation_id", corrID,
			"reason", "revoke_caller_unauthenticated",
		)
		oauthError(w, "invalid_client", http.StatusUnauthorized)
		return
	}
	r.ParseForm() //nolint:errcheck
	token := r.FormValue("token")
	if token != "" {
		revokedTokens.Store(token, time.Now())
		slog.Info("token_revoked",
			"correlation_id", corrID,
			"client_id", clientID,
			"token_prefix", safePrefix(token, 8),
		)
	}
	slog.Info("revoke_called",
		"correlation_id", corrID,
		"client_id", clientID,
	)
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

func safePrefix(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	// Switch to JSON structured logging on stdout.
	// This must run before any request is handled so all handler logs use JSON.
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	slog.Info("server_starting", "addr", ":9443", "day", 9)

	// Wrap all routes with correlationMiddleware so every request gets a unique ID.
	mux := http.NewServeMux()
	mux.HandleFunc("/oauth2/token", tokenHandler)
	mux.HandleFunc("/oauth2/jwks", jwksHandler)
	mux.HandleFunc("/oauth2/introspect", introspectHandler)
	mux.HandleFunc("/oauth2/revoke", revokeHandler)
	mux.Handle("/api/hello", authMiddleware(http.HandlerFunc(helloHandler)))

	handler := correlationMiddleware(mux)

	slog.Info("Day 9 server listening on :9443")
	if err := http.ListenAndServe(":9443", handler); err != nil {
		slog.Error("server_failed", "err", err)
		os.Exit(1)
	}
}
