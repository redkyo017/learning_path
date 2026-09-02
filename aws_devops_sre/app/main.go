package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"
)

// Injected at build time via -ldflags "-X main.version=... -X main.gitCommit=..."
var (
	version   = "dev"
	gitCommit = "unknown"
)

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	port := env("PORT", "8080")
	poisoned := env("POISON", "false") == "true"
	burnRate, err := strconv.ParseFloat(env("BURN_RATE", "0"), 64)
	if err != nil {
		log.Printf(`{"level":"warn","msg":"invalid BURN_RATE, defaulting to 0","value":%q}`, env("BURN_RATE", "0"))
		burnRate = 0
	}

	latencyMS, err := strconv.Atoi(env("LATENCY_MS", "0"))
	if err != nil {
		log.Printf(`{"level":"warn","msg":"invalid LATENCY_MS, defaulting to 0","value":%q}`, env("LATENCY_MS", "0"))
		latencyMS = 0
	}
	latency := time.Duration(latencyMS) * time.Millisecond

	hostname, _ := os.Hostname()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(latency)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"service":  "awsdevops-sample",
			"version":  version,
			"commit":   gitCommit,
			"hostname": hostname,
		})
	})

	// Liveness: is the process up? Never fails on purpose.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Readiness: should this instance receive traffic? The poison switch.
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if poisoned {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("poisoned"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	// Drives ALB 5XX metrics so rollback alarms can be tested deterministically.
	mux.HandleFunc("GET /burn", func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(latency)
		if rand.Float64() < burnRate {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte("burned"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	log.Printf(`{"level":"info","msg":"starting","version":%q,"commit":%q,"port":%q,"poisoned":%t,"burn_rate":%v,"latency_ms":%d}`,
		version, gitCommit, port, poisoned, burnRate, latencyMS)

	srv := &http.Server{Addr: ":" + port, Handler: mux}
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf(`{"level":"fatal","msg":%q}`, err.Error())
	}
}
