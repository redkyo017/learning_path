// shortener is a minimal URL-shortener used to VALIDATE the Day-2 capacity estimate.
// It is intentionally single-instance and un-optimized so you can find its real
// throughput ceiling with k6 and compare it to your back-of-envelope number.
//
// Endpoints:
//
//	POST /shorten   body {"url":"https://..."}  -> 201 {"code":"aZ3k9Qs"}   (one INSERT)
//	GET  /r/{code}                              -> 302 redirect, or 404     (one SELECT)
//	GET  /health                                -> 200 "ok"
//	GET  /stats                                 -> {"rows": N}               (row count)
//
// Config via env:
//
//	DATABASE_URL   default postgres://postgres:pass@localhost:5432/app?sslmode=disable
//	PORT           default 8080
//	MAX_OPEN_CONNS default 20   <- lower this to feel the connection-pool ceiling sooner
//
// Run (from this dir, with the shared labs Postgres up):
//
//	go mod tidy
//	go run .
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

const base62 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

var db *sql.DB

func main() {
	dsn := env("DATABASE_URL", "postgres://postgres:pass@localhost:5432/app?sslmode=disable")
	port := env("PORT", "8080")
	maxConns, _ := strconv.Atoi(env("MAX_OPEN_CONNS", "20"))

	var err error
	db, err = sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	// The pool size is a knob for the ceiling experiment (Little's Law, Day 2).
	db.SetMaxOpenConns(maxConns)
	db.SetMaxIdleConns(maxConns)
	db.SetConnMaxLifetime(5 * time.Minute)

	waitForDB()
	mustMigrate() // creates the table if it doesn't exist (see schema.sql for the DDL)

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	http.HandleFunc("/stats", handleStats)
	http.HandleFunc("/shorten", handleShorten)
	http.HandleFunc("/r/", handleResolve)

	log.Printf("shortener listening on :%s (max_open_conns=%d)", port, maxConns)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleShorten(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST only", http.StatusMethodNotAllowed)
		return
	}
	var body struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.URL == "" {
		http.Error(w, "bad body: expected {\"url\":\"...\"}", http.StatusBadRequest)
		return
	}
	// Random 7-char base62 code = 62^7 ~= 3.5T keyspace. On the rare collision
	// (unique index violation) we regenerate. This is the "hash-ish" option; try
	// swapping in a counter/KGS scheme (your ADR-0002) and re-measure.
	for attempt := 0; attempt < 5; attempt++ {
		code := randCode(7)
		_, err := db.Exec(`INSERT INTO short_urls (code, url) VALUES ($1, $2)`, code, body.URL)
		if err == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusCreated)
			json.NewEncoder(w).Encode(map[string]string{"code": code})
			return
		}
		if strings.Contains(err.Error(), "duplicate key") {
			continue // collision, try another code
		}
		http.Error(w, "insert failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	http.Error(w, "could not allocate code", http.StatusInternalServerError)
}

func handleResolve(w http.ResponseWriter, r *http.Request) {
	code := strings.TrimPrefix(r.URL.Path, "/r/")
	if code == "" {
		http.Error(w, "missing code", http.StatusBadRequest)
		return
	}
	var url string
	err := db.QueryRow(`SELECT url FROM short_urls WHERE code = $1`, code).Scan(&url)
	if err == sql.ErrNoRows {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "lookup failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, url, http.StatusFound) // 302 (keeps analytics; see interview Problem 1)
}

func handleStats(w http.ResponseWriter, r *http.Request) {
	var n int64
	_ = db.QueryRow(`SELECT count(*) FROM short_urls`).Scan(&n)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int64{"rows": n})
}

func randCode(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = base62[rand.Intn(len(base62))]
	}
	return string(b)
}

func mustMigrate() {
	const ddl = `
CREATE TABLE IF NOT EXISTS short_urls (
    code       TEXT PRIMARY KEY,
    url        TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);`
	if _, err := db.Exec(ddl); err != nil {
		log.Fatalf("migrate: %v", err)
	}
}

func waitForDB() {
	for i := 0; i < 30; i++ {
		if err := db.Ping(); err == nil {
			return
		}
		log.Printf("waiting for postgres... (%d)", i)
		time.Sleep(time.Second)
	}
	log.Fatal("postgres not reachable at DATABASE_URL")
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
