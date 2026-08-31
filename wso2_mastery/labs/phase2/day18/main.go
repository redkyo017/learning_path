// go module: go mod init gateway && go mod tidy
// Dependencies: stdlib only (net/http, net/http/httputil, log/slog, os/signal, encoding/json).
// No external packages required.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"time"
)

// ---------------------------------------------------------------------------
// Middleware types
// ---------------------------------------------------------------------------

// Middleware is a function that wraps one http.Handler with another.
type Middleware func(http.Handler) http.Handler

// Chain applies middlewares so that the first listed runs outermost (first on the
// way in, last on the way out). Iterates right-to-left to build m1(m2(m3(h))).
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

// ---------------------------------------------------------------------------
// Middleware implementations
// ---------------------------------------------------------------------------

// loggingMiddleware logs method, path, and round-trip duration for every request.
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

// requestIDMiddleware ensures X-Request-ID is set on every request.
// Generates a nanosecond timestamp ID if the client didn't supply one.
func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Request-ID") == "" {
			r.Header.Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
		}
		next.ServeHTTP(w, r)
	})
}

// recoveryMiddleware catches panics anywhere in the downstream chain and returns a
// structured JSON 500 response instead of crashing or dropping the connection.
//
// Placement matters: recoveryMiddleware must be LAST in the Chain variadic list so it
// is closest to the proxy. A panic in the proxy unwinds through recoveryMiddleware first.
//
// Example: Chain(proxy, requestIDMiddleware, loggingMiddleware, recoveryMiddleware)
// Execution: requestID → logging → recovery → proxy
// A panic in proxy unwinds: proxy panics → recovery's defer catches it → logging runs after → requestID runs after
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

// newReverseProxy creates a reverse proxy to target, setting Host and activityid headers
// in the Director to match WSO2 GW correlation behavior.
func newReverseProxy(target string) *httputil.ReverseProxy {
	u, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(u)
	original := proxy.Director
	proxy.Director = func(req *http.Request) {
		original(req)
		// Reset Host so the backend receives its own host, not the client's.
		req.Host = u.Host
		// Mirror WSO2's activityid pattern: copy X-Request-ID to activityid.
		// requestIDMiddleware runs before us in the chain, so X-Request-ID is guaranteed set.
		req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
	}
	return proxy
}

// ---------------------------------------------------------------------------
// Mock backend
// ---------------------------------------------------------------------------

// newMockBackend returns a ServeMux that acts as a lightweight backend server.
// It handles /mock (and any sub-path) by returning a JSON response with the
// request path. This lets you test the full gateway → backend round-trip without
// any external dependency.
//
// The mock runs on a separate *http.Server (backendSrv) on port 8080 by default,
// so BACKEND_URL=http://localhost:8080 routes to it.
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
	// Default handler for all other backend paths
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
	backendURL := os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://localhost:8080"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "9090"
	}
	backendPort := os.Getenv("BACKEND_PORT")
	if backendPort == "" {
		backendPort = "8080"
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

	// Chain execution order (request in): requestID → logging → recovery → proxy
	// recoveryMiddleware is last (innermost) so it catches panics in the proxy.
	gateway := Chain(proxy, requestIDMiddleware, loggingMiddleware, recoveryMiddleware)

	mux := http.NewServeMux()

	// /health is outside the middleware chain.
	// WSO2 GW equivalent: GET /services/Version
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"UP"}`)
	}))

	// All other paths go through the middleware chain → proxy → mock backend.
	mux.Handle("/", gateway)

	srv := &http.Server{Addr: ":" + port, Handler: mux}

	// Graceful shutdown:
	// ECS Fargate sends SIGTERM when stopping a task (deploy, scaling, health failure).
	// Fargate waits up to 30 seconds before sending SIGKILL.
	// signal.NotifyContext converts SIGTERM/SIGINT into context cancellation.
	// srv.Shutdown drains in-flight connections within the 5-second timeout —
	// well inside Fargate's 30-second window.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go func() {
		slog.Info("gateway starting", "port", port, "backend", backendURL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("gateway error", "err", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("shutdown signal received")

	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Shut down gateway (drain in-flight requests)
	if err := srv.Shutdown(shutCtx); err != nil {
		slog.Error("gateway shutdown error", "err", err)
	}

	// Shut down mock backend
	if err := backendSrv.Shutdown(shutCtx); err != nil {
		slog.Error("backend shutdown error", "err", err)
	}

	slog.Info("shutdown complete")
}
