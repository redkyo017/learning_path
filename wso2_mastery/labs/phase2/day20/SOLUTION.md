# Solution: Day 20 — JWKS-Backed JWT Validator

## Extended main.go with Full Gateway

The provided `main.go` contains the JWT validation middleware. To make it a complete, runnable gateway,
add this code to the end of `main.go`:

```go
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

	// Chain execution order (request in): requestID → logging → jwtValidation → recovery → proxy
	gateway := Chain(proxy,
		requestIDMiddleware,
		loggingMiddleware,
		jwtValidationMiddleware(jwksURL),
		recoveryMiddleware,
	)

	mux := http.NewServeMux()

	// /health is outside the middleware chain
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"UP"}`)
	}))

	// All other paths go through the middleware chain → proxy → mock backend
	mux.Handle("/", gateway)

	srv := &http.Server{Addr: ":" + port, Handler: mux}

	// Graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go func() {
		slog.Info("gateway starting", "port", port, "backend", backendURL, "jwks_url", jwksURL)
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

	slog.Info("shutdown complete")
}
```

**Don't forget the import**:

```go
import (
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
	"os/signal"  // Add this
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)
```

## Running the Full Lab

```bash
# Terminal 1: Phase 1 KM
cd ../../phase1/day15
go run main.go

# Terminal 2: Day 20 Gateway
cd ../../day20
export JWKS_URL=http://localhost:8888/oauth2/jwks
go mod init gateway
go get github.com/golang-jwt/jwt/v5
go mod tidy
go run main.go

# Terminal 3: Test
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/health
curl http://localhost:9090/health  # No token — should still work (JWT validation is only on /)
```

## Key Points

1. **JWT validation is applied to all routes except `/health`**
   - `/health` is registered directly on the mux, bypassing the middleware chain
   - This is intentional: health checks should not fail due to auth issues

2. **Cache behavior**
   - First request with a `kid`: fetches from JWKS, caches the key
   - Subsequent requests with the same `kid`: use cached key
   - If signature validation fails: re-fetches JWKS once (handles key rotation)

3. **Request context flow**
   - JWT middleware stores claims in context
   - Downstream handlers can retrieve claims with `r.Context().Value(claimsKey{})`
   - In this basic gateway, we don't use the claims, but Day 21 will add an `/api/info` endpoint

4. **Environment variables**
   - `JWKS_URL`: JWKS endpoint (default: `http://localhost:8888/oauth2/jwks`)
   - `PORT`: Gateway port (default: `9090`)
   - `BACKEND_URL`: Mock backend URL (default: `http://localhost:8080`)
   - `BACKEND_PORT`: Mock backend port (default: `8080`)

## Debugging

To see detailed logs:

```bash
export GODEBUG=http2debug=1
go run main.go
```

To decode a JWT and inspect claims:

```bash
TOKEN=$(curl -s "http://localhost:8888/token?username=alice" | jq -r .token)
jq -R 'split(".")[1] | @base64d | fromjson' <<< $TOKEN
# Output: {"http://wso2.org/claims/subscriber": "alice", ...}
```

To check JWKS endpoint:

```bash
curl http://localhost:8888/oauth2/jwks | jq .
```

## Common Issues

**"error":"jwks_unavailable"**

- `JWKS_URL` is not set or incorrect
- The KM is not running on the expected port
- Firewall or network issue

**"error":"invalid_token"**

- Token is expired (check `exp` claim)
- Token is signed with a different key than what's in JWKS
- Token's `kid` doesn't match any key in JWKS

**"error":"missing_token"**

- Forgot to include `Authorization: Bearer <token>` header
- Token string is empty

