// gateway is the Day 9 resilience lab: service A calling dependency B, with the
// protections you can toggle on and off to see the cascade vs the containment.
//
// It always uses a small bounded connection pool (MaxConnsPerHost = POOL) — like
// every real service. The difference is whether we PROTECT that pool:
//
//	PROTECT=off : call B with a long timeout, no breaker, no bulkhead, no
//	              fallback. A slow B holds every connection -> new requests block
//	              on the pool -> A's latency collapses -> CASCADE.
//	PROTECT=on  : per-call context timeout + bulkhead (semaphore) + sony/gobreaker
//	              circuit breaker + cached last-known fallback -> A stays
//	              responsive and serves DEGRADED results when B is bad.
//
// Endpoints:
//
//	GET /get     -> the protected (or unprotected) call to B.
//	GET /state   -> breaker state + whether a cached fallback value exists.
//	GET /health  -> 200 ok.
//
// Config via env:
//
//	PORT        (default 8082)
//	TARGET      (default http://localhost:18080/work?ms=50)  B, usually via Toxiproxy
//	PROTECT     (default on)   on | off
//	POOL        (default 10)   max concurrent connections to B (the pool that exhausts)
//	TIMEOUT_MS  (default 200)  per-call timeout when PROTECT=on
//	BULKHEAD    (default 10)   max concurrent in-flight calls to B when PROTECT=on
//
// Run:  TARGET=http://localhost:18080/work?ms=50 PROTECT=on go run .
package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker/v2"
)

var (
	target    string
	protect   bool
	timeoutMS int
	client    *http.Client
	sem       chan struct{} // bulkhead: bounded concurrency to B
	cb        *gobreaker.CircuitBreaker[string]
	lastGood  atomic.Value // string: last successful body (the cached fallback)
)

func main() {
	port := env("PORT", "8082")
	target = env("TARGET", "http://localhost:18080/work?ms=50")
	protect = env("PROTECT", "on") == "on"
	pool := envInt("POOL", 10)
	timeoutMS = envInt("TIMEOUT_MS", 200)
	bulkhead := envInt("BULKHEAD", 10)

	// A bounded connection pool to B — this is the resource that exhausts.
	client = &http.Client{
		Transport: &http.Transport{
			MaxConnsPerHost:     pool,
			MaxIdleConnsPerHost: pool,
		},
		// In unprotected mode we deliberately allow a long wait so a slow B holds
		// connections (the cascade). In protected mode the per-call context
		// timeout does the bounding instead.
		Timeout: 5 * time.Second,
	}

	sem = make(chan struct{}, bulkhead)

	cb = gobreaker.NewCircuitBreaker[string](gobreaker.Settings{
		Name:        "B",
		MaxRequests: 3,                // half-open: allow only a trickle of probes
		Interval:    10 * time.Second, // rolling window for counting
		Timeout:     5 * time.Second,  // sleep window before half-open
		ReadyToTrip: func(c gobreaker.Counts) bool {
			// Trip on >50% errors, but only with enough volume to be signal.
			return c.Requests >= 20 && float64(c.TotalFailures)/float64(c.Requests) > 0.5
		},
		OnStateChange: func(name string, from, to gobreaker.State) {
			log.Printf("breaker %s: %s -> %s", name, from, to)
		},
	})

	http.HandleFunc("/get", handleGet)
	http.HandleFunc("/state", func(w http.ResponseWriter, r *http.Request) {
		cached := "none"
		if v := lastGood.Load(); v != nil {
			cached = "present"
		}
		io.WriteString(w, "breaker="+cb.State().String()+" fallback_cache="+cached)
	})
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, "ok") })

	log.Printf("gateway up on :%s  PROTECT=%v POOL=%d TIMEOUT_MS=%d BULKHEAD=%d target=%s",
		port, protect, pool, timeoutMS, bulkhead, target)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleGet(w http.ResponseWriter, r *http.Request) {
	if !protect {
		// UNPROTECTED: straight call, long timeout, no breaker/bulkhead/fallback.
		// A slow B will hold the connection pool and this handler will pile up.
		body, err := callB(context.Background(), 5000)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		io.WriteString(w, body)
		return
	}

	// PROTECTED path.
	// 1) Bulkhead: try to grab a slot; if none free fast, shed to fallback.
	select {
	case sem <- struct{}{}:
		defer func() { <-sem }()
	case <-time.After(20 * time.Millisecond):
		serveFallback(w, "bulkhead full")
		return
	}

	// 2) Breaker wraps 3) the timeout-bounded call.
	body, err := cb.Execute(func() (string, error) {
		ctx, cancel := context.WithTimeout(r.Context(), time.Duration(timeoutMS)*time.Millisecond)
		defer cancel()
		return callB(ctx, timeoutMS)
	})
	if err != nil {
		// Breaker open, timeout, or B error -> degrade gracefully.
		serveFallback(w, err.Error())
		return
	}
	lastGood.Store(body) // refresh the cached fallback on every success
	w.Header().Set("X-Source", "live")
	io.WriteString(w, body)
}

// serveFallback returns the cached last-known value (degraded) or 503 if we have
// nothing to serve — which is the "no safe fallback => you just fail faster" case.
func serveFallback(w http.ResponseWriter, reason string) {
	if v := lastGood.Load(); v != nil {
		w.Header().Set("X-Source", "fallback-cache")
		w.Header().Set("X-Degraded-Reason", reason)
		io.WriteString(w, v.(string)+" [degraded]")
		return
	}
	w.Header().Set("X-Degraded-Reason", reason)
	http.Error(w, "no fallback available: "+reason, http.StatusServiceUnavailable)
}

func callB(ctx context.Context, _ int) (string, error) {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	resp, err := client.Do(req)
	if err != nil {
		return "", err // timeout / connection error -> failure the breaker counts
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 500 {
		return "", &statusErr{resp.StatusCode}
	}
	return string(body), nil
}

type statusErr struct{ code int }

func (e *statusErr) Error() string { return "B returned " + strconv.Itoa(e.code) }

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
