// Day 15 Lab — Final Key Manager: Request Logging at Every Handler Entry
//
// This is the Phase 1 capstone version of the Go Key Manager.
// It extends Day 12 with one addition: every handler logs
//   method + path + correlation_id
// as its first action, before any business logic.
//
// This lets you grep the structured JSON output by correlation_id and see
// the full lifecycle of any request:
//   grep "<corr_id>" /tmp/km.log | jq .
//
// The correlationMiddleware also reads the incoming "activityid" header
// (set by WSO2 APIM Gateway) and uses it as the correlation ID, so a single
// ID traces the request across both IS and the Go KM.
//
// Setup (run from this directory):
//   go mod init keymanager && go get github.com/golang-jwt/jwt/v5
//
// Run:
//   go run main.go
//   go run main.go 2>&1 | tee /tmp/km.log
//
// Requires Go 1.21+.

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
	"path"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ─── Client registry ──────────────────────────────────────────────────────────

// ClientRecord holds the OAuth 2.0 client credentials managed by the Key Manager.
type ClientRecord struct {
	ClientID     string   `json:"clientId"`
	ClientSecret string   `json:"clientSecret"`
	ClientName   string   `json:"clientName"`
	GrantTypes   []string `json:"grantTypes"`
	CallbackURL  string   `json:"callbackUrl"`
}

// clientRegistry stores registered OAuth clients; safe for concurrent access.
var clientRegistry sync.Map // key: clientID (string) → value: ClientRecord

// ─── WSO2 JWT claims ──────────────────────────────────────────────────────────

// WSO2Claims extends jwt.RegisteredClaims with the custom claims that
// WSO2 APIM gateways expect in every access token.
type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

// ─── Context key types ────────────────────────────────────────────────────────

// correlationKey is an unexported empty-struct context key.
type correlationKey struct{}

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

// ─── Correlation ID middleware ────────────────────────────────────────────────

// correlationMiddleware reads the "activityid" header forwarded by WSO2 APIM
// Gateway.  If absent it generates a new ID.  The ID is stored in the request
// context so every handler can include it in log lines.
//
// Matching the APIM "activityid" header means a single correlation ID traces
// the request across the IS logs (MDC Correlation-ID) and the Go KM logs
// (correlation_id JSON field).
func correlationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("activityid")
		if id == "" {
			id = generateID()
		}
		// Echo the ID back so callers can grep their own logs.
		w.Header().Set("X-Correlation-ID", id)
		ctx := context.WithValue(r.Context(), correlationKey{}, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// correlationFromCtx retrieves the correlation ID set by correlationMiddleware.
func correlationFromCtx(ctx context.Context) string {
	v, _ := ctx.Value(correlationKey{}).(string)
	return v
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// generateID returns a 22-character cryptographically random base64url string.
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b) //nolint:errcheck
	return base64.RawURLEncoding.EncodeToString(b)
}

// validateClient checks id/secret against the dynamic client registry
// plus a static fallback for development.
func validateClient(id, secret string) bool {
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

// issueJWT creates and signs a WSO2-shaped JWT.
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

func safePrefix(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// ─── Application registration handlers ───────────────────────────────────────

func registerApplicationHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

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
		slog.Warn("register_app_bad_json", "correlation_id", corrID, "err", err)
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

	slog.Info("app_registered",
		"correlation_id", corrID,
		"app_name", req.ApplicationName,
		"client_id", clientID,
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(rec)
}

func deleteApplicationHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

	if r.Method != http.MethodDelete {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	clientID := path.Base(r.URL.Path)
	clientRegistry.Delete(clientID)

	slog.Info("app_deleted", "correlation_id", corrID, "client_id", clientID)
	w.WriteHeader(http.StatusNoContent)
}

// applicationRouter dispatches to register or delete based on HTTP method.
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

// ─── Token endpoint ───────────────────────────────────────────────────────────

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

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
		slog.Warn("token_rejected",
			"correlation_id", corrID,
			"reason", "invalid_client_credentials",
			"client_id", clientID,
		)
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
		slog.Error("token_issue_failed", "correlation_id", corrID, "err", err)
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

// ─── Introspect endpoint ──────────────────────────────────────────────────────

func introspectHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		slog.Warn("introspect_caller_unauthenticated",
			"correlation_id", corrID,
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

// ─── Revoke endpoint ──────────────────────────────────────────────────────────

func revokeHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	clientID, clientSecret, ok := r.BasicAuth()
	if !ok || !validateClient(clientID, clientSecret) {
		slog.Warn("revoke_caller_unauthenticated", "correlation_id", corrID)
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
	w.WriteHeader(http.StatusOK)
}

// ─── JWKS endpoint ────────────────────────────────────────────────────────────

func jwksHandler(w http.ResponseWriter, r *http.Request) {
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

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
	corrID := correlationFromCtx(r.Context())
	// Day 15 addition: log every request at handler entry.
	slog.Info("request_received",
		"method", r.Method,
		"path", r.URL.Path,
		"correlation_id", corrID,
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
}

// ─── Route constants ──────────────────────────────────────────────────────────

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
	// Structured JSON logging to stdout.
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	port := os.Getenv("PORT")
	if port == "" {
		port = "9444"
	}
	addr := ":" + port

	slog.Info("server_starting", "addr", addr, "day", 15, "phase", 1)

	mux := http.NewServeMux()
	mux.HandleFunc(pathApplication, applicationRouter)
	mux.HandleFunc(pathApplication+"/", applicationRouter)
	mux.HandleFunc(pathToken, tokenHandler)
	mux.HandleFunc(pathIntrospect, introspectHandler)
	mux.HandleFunc(pathRevoke, revokeHandler)
	mux.HandleFunc(pathJWKS, jwksHandler)
	mux.HandleFunc(pathHealth, healthHandler)

	// correlationMiddleware reads "activityid" header (APIM Gateway) or generates an ID.
	handler := correlationMiddleware(mux)

	slog.Info("Key Manager ready — Phase 1 complete", "addr", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		slog.Error("server_failed", "err", err)
		os.Exit(1)
	}
}
