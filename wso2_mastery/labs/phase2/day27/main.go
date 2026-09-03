package main

import (
	"bytes"
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/time/rate"
)

// ---------------------------------------------------------------------------
// JWT Types and Caching
// ---------------------------------------------------------------------------

type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

type claimsKey struct{}

var jwksCache sync.Map // kid → *rsa.PublicKey

func fetchPublicKey(jwksURL, kid string) (*rsa.PublicKey, error) {
	resp, err := http.Get(jwksURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var set struct {
		Keys []struct {
			Kid string `json:"kid"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, err
	}
	for _, k := range set.Keys {
		if k.Kid == kid {
			nBytes, _ := base64.RawURLEncoding.DecodeString(k.N)
			eBytes, _ := base64.RawURLEncoding.DecodeString(k.E)
			pub := &rsa.PublicKey{
				N: new(big.Int).SetBytes(nBytes),
				E: int(new(big.Int).SetBytes(eBytes).Int64()),
			}
			jwksCache.Store(kid, pub)
			return pub, nil
		}
	}
	return nil, fmt.Errorf("kid %q not found in JWKS", kid)
}

func jwtValidationMiddleware(jwksURL string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenStr := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if tokenStr == "" {
				http.Error(w, `{"error":"missing_token"}`, http.StatusUnauthorized)
				return
			}
			// Parse without verification first to get the kid
			unverified, _, err := jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})
			if err != nil {
				http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
				return
			}
			kid, _ := unverified.Header["kid"].(string)

			// Try cached key, re-fetch on failure (handles key rotation)
			pub, _ := jwksCache.Load(kid)
			if pub == nil {
				pub, err = fetchPublicKey(jwksURL, kid)
				if err != nil {
					http.Error(w, `{"error":"jwks_unavailable"}`, http.StatusUnauthorized)
					return
				}
			}

			token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
				if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
					return nil, fmt.Errorf("unexpected alg: %v", t.Header["alg"])
				}
				return pub.(*rsa.PublicKey), nil
			})
			if err != nil {
				// Key may have rotated — re-fetch once
				newPub, ferr := fetchPublicKey(jwksURL, kid)
				if ferr != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
				token, err = jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
					return newPub, nil
				})
				if err != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
			}

			claims := token.Claims.(*WSO2Claims)
			ctx := context.WithValue(r.Context(), claimsKey{}, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// ---------------------------------------------------------------------------
// Subscription Types and Store
// ---------------------------------------------------------------------------

type SubscriptionRecord struct {
	ApplicationName  string `json:"applicationname"`
	APIName          string `json:"apiname"`
	SubscriptionTier string `json:"subscriptiontier"`
	KeyType          string `json:"keytype"`
}

// subscriptionStore: key = "appName::apiName"
var subscriptionStore sync.Map

func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
			if !ok || claims == nil {
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`, http.StatusForbidden)
				return
			}
			key := claims.ApplicationName + "::" + apiName
			if _, found := subscriptionStore.Load(key); !found {
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`, http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// ---------------------------------------------------------------------------
// Throttle Middleware (Token Bucket)
// ---------------------------------------------------------------------------

var throttleLimiters sync.Map

func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
	key := appName + "::" + tier
	if l, ok := throttleLimiters.Load(key); ok {
		return l.(*rate.Limiter)
	}
	// Map tier to requests/second
	rps := map[string]rate.Limit{
		"Gold":      rate.Limit(5000.0 / 60),
		"Silver":    rate.Limit(2000.0 / 60),
		"Bronze":    rate.Limit(1000.0 / 60),
		"Unlimited": rate.Inf,
	}
	r, ok := rps[tier]
	if !ok {
		r = rate.Limit(10) // default conservative
	}
	l := rate.NewLimiter(r, int(r*60)) // burst = 1 minute worth
	throttleLimiters.Store(key, l)
	return l
}

func throttleMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
		if !ok {
			next.ServeHTTP(w, r)
			return
		}
		limiter := getOrCreateLimiter(claims.ApplicationName, claims.ApplicationTier)
		if !limiter.Allow() {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			fmt.Fprint(w, `{"code":"900801","message":"Application level throttle limit exceeded"}`)
			return
		}

		// Send throttle event to TM (async, non-blocking)
		go sendThrottleEventToTM(claims.ApplicationName, claims.ApplicationTier)

		next.ServeHTTP(w, r)
	})
}

// ---------------------------------------------------------------------------
// Traffic Manager Client
// ---------------------------------------------------------------------------

func sendThrottleEventToTM(applicationName, tier string) {
	tmURL := os.Getenv("TM_URL")
	if tmURL == "" {
		tmURL = "http://localhost:9611"
	}

	event := map[string]interface{}{
		"applicationId":  applicationName,
		"subscriptionId": applicationName + "::" + tier,
		"tier":           tier,
		"userId":         "unknown",
		"timestamp":      time.Now().UTC().Format(time.RFC3339),
		"count":          1,
		"allowedCount":   5000, // Simplified for mock
	}

	body, _ := json.Marshal(event)
	resp, err := http.Post(tmURL+"/throttle/data", "application/json", bytes.NewReader(body))
	if err != nil {
		slog.Warn("failed to send throttle event to TM", "err", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		slog.Warn("TM returned error", "status", resp.StatusCode)
		return
	}

	slog.Debug("throttle event sent to TM", "app", applicationName, "tier", tier)
}

// ---------------------------------------------------------------------------
// Middleware types and utilities
// ---------------------------------------------------------------------------

type Middleware func(http.Handler) http.Handler

func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("request",
			"method",      r.Method,
			"path",        r.URL.Path,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Request-ID") == "" {
			r.Header.Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
		}
		next.ServeHTTP(w, r)
	})
}

func recoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("panic recovered", "error", rec, "path", r.URL.Path)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprint(w, `{"error":"internal_server_error"}`)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// ---------------------------------------------------------------------------
// Reverse proxy
// ---------------------------------------------------------------------------

func newReverseProxy(target string) *httputil.ReverseProxy {
	u, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(u)
	original := proxy.Director
	proxy.Director = func(req *http.Request) {
		original(req)
		req.Host = u.Host
		req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
	}
	return proxy
}

// ---------------------------------------------------------------------------
// Mock backend
// ---------------------------------------------------------------------------

func newMockBackend() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/mock/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]string{
			"message": "mock backend response",
			"path":    r.URL.Path,
			"method":  r.Method,
		}
		_ = json.NewEncoder(w).Encode(resp)
	})
	mux.HandleFunc("/mock", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]string{
			"message": "mock backend response",
			"path":    r.URL.Path,
		}
		_ = json.NewEncoder(w).Encode(resp)
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]string{
			"message": "backend echo",
			"path":    r.URL.Path,
		}
		_ = json.NewEncoder(w).Encode(resp)
	})
	return mux
}

// ---------------------------------------------------------------------------
// Mock Traffic Manager Server
// ---------------------------------------------------------------------------

func newMockTMHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var event struct {
			ApplicationID  string `json:"applicationId"`
			SubscriptionID string `json:"subscriptionId"`
			Tier           string `json:"tier"`
			UserID         string `json:"userId"`
			Timestamp      string `json:"timestamp"`
			Count          int    `json:"count"`
			AllowedCount   int    `json:"allowedCount"`
		}

		if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
			http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
			return
		}

		slog.Info("throttle event received from GW",
			"app", event.ApplicationID,
			"tier", event.Tier,
			"count", event.Count,
			"allowedCount", event.AllowedCount,
		)

		// Mock TM always returns: not throttled (permissive for testing)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"throttled":false,"globalCount":1000,"allowedCount":5000}`)
	}
}

// ---------------------------------------------------------------------------
// API Info Endpoint
// ---------------------------------------------------------------------------

func apiInfoHandler(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
	if !ok {
		http.Error(w, `{"error":"claims_missing"}`, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(claims)
}

// ---------------------------------------------------------------------------
// Admin Subscriptions Endpoints
// ---------------------------------------------------------------------------

func addSubscriptionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
		return
	}
	var rec SubscriptionRecord
	if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
		http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
		return
	}
	key := rec.ApplicationName + "::" + rec.APIName
	subscriptionStore.Store(key, &rec)
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprint(w, `{"status":"subscription_added"}`)
}

func deleteSubscriptionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
		return
	}
	appName := r.URL.Query().Get("appname")
	apiName := r.URL.Query().Get("apiname")
	if appName == "" || apiName == "" {
		http.Error(w, `{"error":"missing_params"}`, http.StatusBadRequest)
		return
	}
	key := appName + "::" + apiName
	subscriptionStore.Delete(key)
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprint(w, `{"status":"subscription_removed"}`)
}

func handleSubscriptions(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		addSubscriptionHandler(w, r)
	} else if r.Method == "DELETE" {
		deleteSubscriptionHandler(w, r)
	} else {
		http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	jwksURL := os.Getenv("JWKS_URL")
	if jwksURL == "" {
		jwksURL = "http://localhost:8888/oauth2/jwks"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "9090"
	}
	backendPort := os.Getenv("BACKEND_PORT")
	if backendPort == "" {
		backendPort = "8080"
	}
	backendURL := os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://localhost:" + backendPort
	}
	tmPort := os.Getenv("TM_PORT")
	if tmPort == "" {
		tmPort = "9611"
	}

	// --- Mock Traffic Manager server (separate port) ---
	tmMux := http.NewServeMux()
	tmMux.HandleFunc("/throttle/data", newMockTMHandler())
	tmSrv := &http.Server{Addr: ":" + tmPort, Handler: tmMux}

	go func() {
		slog.Info("mock traffic manager starting", "port", tmPort)
		if err := tmSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("TM error", "err", err)
		}
	}()

	// --- Mock backend server (separate mux, separate port) ---
	backendMux := newMockBackend()
	backendSrv := &http.Server{Addr: ":" + backendPort, Handler: backendMux}

	go func() {
		slog.Info("mock backend starting", "port", backendPort)
		if err := backendSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("mock backend error", "err", err)
		}
	}()

	// --- Gateway server ---
	proxy := newReverseProxy(backendURL)

	// Chain execution order (request in):
	// requestID → logging → jwtValidation → subscription → throttle → recovery → proxy
	apiMiddleware := Chain(proxy,
		requestIDMiddleware,
		loggingMiddleware,
		jwtValidationMiddleware(jwksURL),
		subscriptionMiddleware("hello"),
		throttleMiddleware,
		recoveryMiddleware,
	)

	mux := http.NewServeMux()

	// /health is outside the middleware chain (no JWT required)
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"UP"}`)
	}))

	// /api/info is inside the JWT validation middleware only (diagnostics)
	mux.Handle("/api/info", Chain(
		http.HandlerFunc(apiInfoHandler),
		jwtValidationMiddleware(jwksURL),
	))

	// /api/hello is protected by JWT validation + subscription check + throttle
	mux.Handle("/api/hello", apiMiddleware)

	// /admin/subscriptions is outside the middleware chain (for management)
	mux.HandleFunc("/admin/subscriptions", handleSubscriptions)

	// All other paths go through the middleware chain → proxy → mock backend
	mux.Handle("/", apiMiddleware)

	srv := &http.Server{Addr: ":" + port, Handler: mux}

	// Graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go func() {
		slog.Info("gateway starting", "port", port, "backend", backendURL, "jwks_url", jwksURL, "tm_url", "http://localhost:"+tmPort)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("gateway error", "err", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("shutdown signal received")

	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutCtx); err != nil {
		slog.Error("gateway shutdown error", "err", err)
	}

	if err := backendSrv.Shutdown(shutCtx); err != nil {
		slog.Error("backend shutdown error", "err", err)
	}

	if err := tmSrv.Shutdown(shutCtx); err != nil {
		slog.Error("TM shutdown error", "err", err)
	}

	slog.Info("shutdown complete")
}
