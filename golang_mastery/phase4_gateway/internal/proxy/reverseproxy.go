package proxy

import (
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
)

// Handler returns an http.Handler that proxies requests to the named upstream.
func Handler(upstream *Upstream) http.Handler {
	target, err := url.Parse(upstream.BaseURL)
	if err != nil {
		panic(fmt.Sprintf("invalid upstream URL %q: %v", upstream.BaseURL, err))
	}

	rp := httputil.NewSingleHostReverseProxy(target)
	rp.Transport = Transport()

	rp.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		slog.Error("proxy error",
			"upstream", upstream.Name,
			"path", r.URL.Path,
			"err", err,
		)
		http.Error(w, "bad gateway", http.StatusBadGateway)
	}

	// Rewrite strips the path prefix so upstream sees clean paths
	original := rp.Director
	rp.Director = func(req *http.Request) {
		original(req)
		req.Header.Set("X-Forwarded-Host", req.Host)
		req.Header.Set("X-Gateway", "phase4-gateway")
	}

	return rp
}
