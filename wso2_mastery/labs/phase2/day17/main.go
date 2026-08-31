// go module: go mod init gateway && go get
// No external dependencies required — stdlib only.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"time"
)

// Middleware is a function that wraps one http.Handler with another.
// The outer handler can run code before and after calling next.ServeHTTP,
// or short-circuit by writing a response without calling next at all.
type Middleware func(http.Handler) http.Handler

// Chain applies middlewares around h so that the first middleware listed runs outermost
// (first to see the request, last to see the response).
//
// Chain(h, m1, m2, m3) produces m1(m2(m3(h))).
// Execution order on a request: m1.before → m2.before → m3.before → h → m3.after → m2.after → m1.after
//
// The loop iterates right-to-left (from len-1 down to 0) so that wrapping builds
// inside-out: the last middleware becomes the innermost wrapper, and the first becomes
// the outermost — matching the order you read in the variadic list.
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

// loggingMiddleware logs the HTTP method, path, and round-trip duration for every request.
// It uses log/slog (structured logging, stdlib since Go 1.21).
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

// requestIDMiddleware ensures every request carries an X-Request-ID header.
// If the client did not supply one, a nanosecond timestamp is used as a simple unique ID.
// In production you would use a UUID (e.g. github.com/google/uuid), but a timestamp
// avoids any external dependency for this lab.
func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Request-ID") == "" {
			r.Header.Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
		}
		next.ServeHTTP(w, r)
	})
}

// newReverseProxy creates an httputil.ReverseProxy that forwards requests to target.
// The Director is extended to:
//   - reset req.Host so virtual-host routing on the backend works correctly
//   - set the activityid header from X-Request-ID, mirroring WSO2 GW correlation behavior
func newReverseProxy(target string) *httputil.ReverseProxy {
	u, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(u)
	// Capture the default Director set by NewSingleHostReverseProxy so we can call it
	// first (it sets URL scheme, host, and path) and then add our own mutations.
	original := proxy.Director
	proxy.Director = func(req *http.Request) {
		original(req)
		// Override the Host header so the backend receives its own host, not the client's.
		req.Host = u.Host
		// WSO2 GW sets activityid on upstream requests for end-to-end correlation.
		// By this point requestIDMiddleware has already set X-Request-ID.
		req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
	}
	return proxy
}

func main() {
	backendURL := os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://localhost:8080"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "9090"
	}

	proxy := newReverseProxy(backendURL)

	// Chain applies middlewares so requestIDMiddleware runs first (outermost),
	// then loggingMiddleware, then the proxy.
	gateway := Chain(proxy, requestIDMiddleware, loggingMiddleware)

	mux := http.NewServeMux()

	// /health is outside the middleware chain — healthchecks must not depend on
	// backend reachability or trigger analytics events.
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"UP"}`)
	}))

	// All other paths go through the middleware chain and then the reverse proxy.
	mux.Handle("/", gateway)

	srv := &http.Server{Addr: ":" + port, Handler: mux}

	// Graceful shutdown: block until SIGTERM or Ctrl+C, then drain connections.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go func() {
		slog.Info("gateway starting", "port", port, "backend", backendURL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("shutdown signal received")

	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutCtx); err != nil {
		slog.Error("shutdown error", "err", err)
	}
	slog.Info("shutdown complete")
}
