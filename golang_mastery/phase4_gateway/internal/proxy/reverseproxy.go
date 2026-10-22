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

	// Rewrite replaces the deprecated Director hook (Go 1.26): it runs after
	// hop-by-hop headers are removed and drops client-sent X-Forwarded-*
	// headers, so clients can neither strip nor spoof what the gateway sets.
	rp := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(target)
			pr.SetXForwarded() // X-Forwarded-For/-Host/-Proto from the real client
			pr.Out.Header.Set("X-Gateway", "phase4-gateway")
		},
		Transport: Transport(),
	}

	rp.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		slog.Error("proxy error",
			"upstream", upstream.Name,
			"path", r.URL.Path,
			"err", err,
		)
		http.Error(w, "bad gateway", http.StatusBadGateway)
	}

	return rp
}
