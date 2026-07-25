// orders is a tiny HTTP service used for the Day 17 canary lab. One binary runs
// as both v1 and v2 (set VERSION). It has runtime toggles so you can simulate a
// bad v2 mid-canary without redeploying:
//
//	GET  /orders                 -> 200 "orders <VERSION>", header X-Orders-Version
//	                                (returns 500 at the injected error rate)
//	GET  /health                 -> 200 "ok"  (503 when marked unhealthy)
//	POST /admin/unhealthy?v=true  -> flip the health check to failing (503)
//	POST /admin/errors?rate=0.5   -> inject 500s at the given probability [0..1]
//
// Env: VERSION (default v1), PORT (default 8080).
package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync"
)

type state struct {
	mu        sync.RWMutex
	unhealthy bool
	errRate   float64
}

func main() {
	version := env("VERSION", "v1")
	port := env("PORT", "8080")
	st := &state{}

	http.HandleFunc("/orders", func(w http.ResponseWriter, r *http.Request) {
		st.mu.RLock()
		rate := st.errRate
		st.mu.RUnlock()
		w.Header().Set("X-Orders-Version", version)
		if rate > 0 && rand.Float64() < rate {
			http.Error(w, "injected error from "+version, http.StatusInternalServerError)
			return
		}
		fmt.Fprintf(w, "orders %s", version)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		st.mu.RLock()
		bad := st.unhealthy
		st.mu.RUnlock()
		if bad {
			http.Error(w, "unhealthy", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "ok")
	})

	http.HandleFunc("/admin/unhealthy", func(w http.ResponseWriter, r *http.Request) {
		v, _ := strconv.ParseBool(r.URL.Query().Get("v"))
		st.mu.Lock()
		st.unhealthy = v
		st.mu.Unlock()
		fmt.Fprintf(w, "%s unhealthy=%v\n", version, v)
	})

	http.HandleFunc("/admin/errors", func(w http.ResponseWriter, r *http.Request) {
		rate, _ := strconv.ParseFloat(r.URL.Query().Get("rate"), 64)
		st.mu.Lock()
		st.errRate = rate
		st.mu.Unlock()
		fmt.Fprintf(w, "%s errRate=%.2f\n", version, rate)
	})

	log.Printf("orders %s listening on :%s", version, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
