// router is the THIN cell router for the Day 10 blast-radius lab.
//
// It maps a tenant to exactly one cell with a deterministic hash and reverse-
// proxies the request there. That is ALL it does — no business logic, no
// per-request database lookup. The router is the one component every cell
// "shares", so it must stay small enough to reason about completely.
//
// Cells are configured as a comma-separated list of base URLs; the tenant comes
// from the `X-Tenant` header (fallback: ?tenant= query param).
//
//	cell_index = fnv1a(tenant) % len(cells)
//
// Run (3 terminals):
//
//	# cell-a and cell-b are just labelled echo instances (see labs/services/echo)
//	cd ../../../../labs/services/echo && PORT=8081 NAME=cell-a go run . &
//	cd ../../../../labs/services/echo && PORT=8082 NAME=cell-b go run . &
//	CELLS="http://localhost:8081,http://localhost:8082" PORT=8090 go run .
//
// Then:  curl -H "X-Tenant: acme"   localhost:8090/work?ms=10
//
//	curl -H "X-Tenant: globex" localhost:8090/work?ms=10
//
// The router also exposes /whichcell?tenant=NAME so you can see the mapping
// without proxying — handy for the loadgen tally.
package main

import (
	"hash/fnv"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
)

func main() {
	raw := env("CELLS", "http://localhost:8081,http://localhost:8082")
	port := env("PORT", "8090")

	var cellURLs []string
	var proxies []*httputil.ReverseProxy
	for _, c := range strings.Split(raw, ",") {
		c = strings.TrimSpace(c)
		if c == "" {
			continue
		}
		u, err := url.Parse(c)
		if err != nil {
			log.Fatalf("bad cell url %q: %v", c, err)
		}
		p := httputil.NewSingleHostReverseProxy(u)
		// If a cell is DOWN, fail fast with 503 so the client sees "this tenant's
		// cell is unavailable" — NOT a hang, and NOT a spillover to another cell.
		// Containment means a dead cell's tenants fail; it does not mean we
		// silently reroute them and drag a healthy cell down.
		p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
			w.Header().Set("X-Cell-Error", "1")
			http.Error(w, "cell unavailable: "+err.Error(), http.StatusServiceUnavailable)
		}
		cellURLs = append(cellURLs, c)
		proxies = append(proxies, p)
	}
	if len(proxies) == 0 {
		log.Fatal("no cells configured (set CELLS)")
	}

	cellFor := func(tenant string) int {
		h := fnv.New32a()
		_, _ = h.Write([]byte(tenant))
		return int(h.Sum32() % uint32(len(proxies)))
	}
	tenantOf := func(r *http.Request) string {
		if t := r.Header.Get("X-Tenant"); t != "" {
			return t
		}
		return r.URL.Query().Get("tenant")
	}

	// Debug endpoint: show the mapping without proxying.
	http.HandleFunc("/whichcell", func(w http.ResponseWriter, r *http.Request) {
		t := tenantOf(r)
		if t == "" {
			http.Error(w, "missing tenant", http.StatusBadRequest)
			return
		}
		i := cellFor(t)
		w.Header().Set("X-Cell", cellURLs[i])
		w.Write([]byte(cellURLs[i]))
	})

	// Everything else is routed to the tenant's cell.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		t := tenantOf(r)
		if t == "" {
			http.Error(w, "missing tenant (X-Tenant header or ?tenant=)", http.StatusBadRequest)
			return
		}
		i := cellFor(t)
		w.Header().Set("X-Cell", cellURLs[i]) // so the loadgen can tally per cell
		proxies[i].ServeHTTP(w, r)
	})

	log.Printf("router on :%s -> %d cells: %v", port, len(proxies), cellURLs)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
