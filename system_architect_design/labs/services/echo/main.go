// echo is a tiny, dependency-light HTTP service reused across labs.
//
// Endpoints:
//   GET /health          -> 200 "ok"
//   GET /work?ms=50       -> sleeps ms then 200 "done" (simulate latency)
//   GET /work?ms=50&fail=0.2 -> fails ~20% of the time with 500 (simulate flakiness)
//   GET /call?url=...&ms=  -> calls another service (for cascade/breaker labs)
//
// Config via env: PORT (default 8080), NAME (label in responses, default "echo").
//
// Run:  PORT=8080 NAME=A go run .
// Build image:  docker build -t lab/echo .
package main

import (
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	name := env("NAME", "echo")
	port := env("PORT", "8080")

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		io.WriteString(w, "ok")
	})

	http.HandleFunc("/work", func(w http.ResponseWriter, r *http.Request) {
		ms, _ := strconv.Atoi(r.URL.Query().Get("ms"))
		if fail := r.URL.Query().Get("fail"); fail != "" {
			if p, err := strconv.ParseFloat(fail, 64); err == nil && rand.Float64() < p {
				time.Sleep(time.Duration(ms) * time.Millisecond)
				http.Error(w, "injected failure", http.StatusInternalServerError)
				return
			}
		}
		time.Sleep(time.Duration(ms) * time.Millisecond)
		fmt.Fprintf(w, "done by %s", name)
	})

	// /call proxies to another service; use it to build A->B topologies for
	// cascade and circuit-breaker labs (Day 9).
	http.HandleFunc("/call", func(w http.ResponseWriter, r *http.Request) {
		target := r.URL.Query().Get("url")
		if target == "" {
			http.Error(w, "missing url", http.StatusBadRequest)
			return
		}
		client := &http.Client{Timeout: 2 * time.Second}
		start := time.Now()
		resp, err := client.Get(target)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(w, "%s -> [%d in %s] %s", name, resp.StatusCode, time.Since(start), body)
	})

	log.Printf("%s listening on :%s", name, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
