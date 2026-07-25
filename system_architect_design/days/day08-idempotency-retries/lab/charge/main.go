// charge is the Day 8 idempotency + retry lab service.
//
// POST /charge
//
//	Header: Idempotency-Key: <client-chosen unique id>   (required)
//	Body:   {"amount_cents": 5000}
//	Returns 201 {"id":..,"replayed":false} on first execution,
//	        200 {"id":..,"replayed":true}  on any replay of the same key.
//
// The idempotency guard is a single INSERT ... ON CONFLICT DO NOTHING against a
// UNIQUE index. Under N concurrent requests with the same key, Postgres lets
// exactly ONE insert win; the losers block until the winner commits, then take
// the replay branch. The DATABASE arbitrates the race, not the app.
//
// Config via env:
//
//	PORT         (default 8095)
//	DATABASE_URL (default postgres://postgres:pass@localhost:5432/app?sslmode=disable)
//	IDEMPOTENT   (default true)  false => plain INSERT, no guard (break-it: N charges).
//	                             (drop the UNIQUE constraint first — see sql/schema.sql)
//	PROVIDER_URL (default "")    if set, the winner calls this downstream with
//	                             retries (use Toxiproxy + echo /work?ms=&fail= for
//	                             the backoff-vs-jitter experiment).
//	BACKOFF      (default jitter) fixed | jitter  — retry spacing strategy.
//	MAX_ATTEMPTS (default 4)      retry attempts against PROVIDER_URL.
//	BASE_MS      (default 50)     backoff base.
//
// Run:  DATABASE_URL=... go run .
package main

import (
	"database/sql"
	"encoding/json"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	_ "github.com/lib/pq"
)

var (
	db             *sql.DB
	providerCalls  atomic.Int64 // total downstream attempts (watch this under fixed vs jitter)
	providerFailed atomic.Int64
)

type chargeReq struct {
	AmountCents int `json:"amount_cents"`
}
type chargeResp struct {
	ID          int64  `json:"id"`
	Replayed    bool   `json:"replayed"`
	ProviderRef string `json:"provider_ref,omitempty"`
}

func main() {
	port := env("PORT", "8095")
	dsn := env("DATABASE_URL", "postgres://postgres:pass@localhost:5432/app?sslmode=disable")
	idempotent := env("IDEMPOTENT", "true") == "true"
	providerURL := env("PROVIDER_URL", "")
	backoff := env("BACKOFF", "jitter")
	maxAttempts := envInt("MAX_ATTEMPTS", 4)
	baseMS := envInt("BASE_MS", 50)

	var err error
	db, err = sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("ping db (%s): %v", dsn, err)
	}

	http.HandleFunc("/charge", func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("Idempotency-Key")
		if key == "" {
			http.Error(w, "missing Idempotency-Key header", http.StatusBadRequest)
			return
		}
		var req chargeReq
		_ = json.NewDecoder(r.Body).Decode(&req)
		if req.AmountCents <= 0 {
			req.AmountCents = 5000 // default $50 for the lab
		}

		var providerRef string
		if providerURL != "" {
			ref, err := callProviderWithRetry(providerURL, key, backoff, maxAttempts, baseMS)
			if err != nil {
				// Provider unrecoverable after retries: do not record a charge.
				http.Error(w, "provider failed: "+err.Error(), http.StatusBadGateway)
				return
			}
			providerRef = ref
		}

		if !idempotent {
			// BREAK-IT PATH: no guard. Every request inserts a fresh charge row.
			// (Drop the UNIQUE constraint first or this errors on the 2nd insert.)
			var id int64
			err := db.QueryRow(
				`INSERT INTO charges(idempotency_key, amount_cents, status, provider_ref)
				 VALUES ($1,$2,'succeeded',$3) RETURNING id`,
				key, req.AmountCents, nullStr(providerRef)).Scan(&id)
			if err != nil {
				http.Error(w, "insert failed: "+err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusCreated, chargeResp{ID: id, Replayed: false, ProviderRef: providerRef})
			return
		}

		// IDEMPOTENT PATH: claim the key. Exactly one concurrent request wins.
		var id int64
		err := db.QueryRow(
			`INSERT INTO charges(idempotency_key, amount_cents, status, provider_ref)
			 VALUES ($1,$2,'succeeded',$3)
			 ON CONFLICT (idempotency_key) DO NOTHING
			 RETURNING id`,
			key, req.AmountCents, nullStr(providerRef)).Scan(&id)

		switch err {
		case nil:
			// We won the insert — this is the one real charge.
			writeJSON(w, http.StatusCreated, chargeResp{ID: id, Replayed: false, ProviderRef: providerRef})
		case sql.ErrNoRows:
			// Conflict: the key already exists (winner has committed). Replay it.
			var existing int64
			var ref sql.NullString
			if e := db.QueryRow(
				`SELECT id, provider_ref FROM charges WHERE idempotency_key=$1`, key,
			).Scan(&existing, &ref); e != nil {
				http.Error(w, "replay lookup failed: "+e.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusOK, chargeResp{ID: existing, Replayed: true, ProviderRef: ref.String})
		default:
			http.Error(w, "insert failed: "+err.Error(), http.StatusInternalServerError)
		}
	})

	http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]int64{
			"provider_calls":  providerCalls.Load(),
			"provider_failed": providerFailed.Load(),
		})
	})
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })

	log.Printf("charge up on :%s  IDEMPOTENT=%v provider=%q backoff=%s maxAttempts=%d baseMS=%d",
		port, idempotent, providerURL, backoff, maxAttempts, baseMS)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

// callProviderWithRetry calls the downstream, retrying transient failures with
// either fixed or full-jitter exponential backoff. It forwards the idempotency
// key so the provider can dedupe too (end-to-end idempotency).
func callProviderWithRetry(url, key, strategy string, maxAttempts, baseMS int) (string, error) {
	client := &http.Client{Timeout: 2 * time.Second}
	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		if attempt > 0 {
			time.Sleep(backoffDelay(strategy, attempt, baseMS))
		}
		providerCalls.Add(1)
		req, _ := http.NewRequest(http.MethodGet, url, nil)
		req.Header.Set("Idempotency-Key", key) // forward for downstream dedup
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			providerFailed.Add(1)
			continue // transient (timeout/connreset): retry
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode >= 500 || resp.StatusCode == 429 {
			lastErr = &httpErr{resp.StatusCode}
			providerFailed.Add(1)
			continue // retryable
		}
		if resp.StatusCode >= 400 {
			// 4xx (except 429): deterministic — do NOT retry.
			return "", &httpErr{resp.StatusCode}
		}
		return "ok:" + string(body), nil
	}
	return "", lastErr
}

// backoffDelay: fixed = base every time (synchronized herd);
// jitter = random(0, base * 2^attempt) = exponential backoff with FULL jitter.
func backoffDelay(strategy string, attempt, baseMS int) time.Duration {
	base := time.Duration(baseMS) * time.Millisecond
	if strategy == "fixed" {
		return base
	}
	cap := base * (1 << attempt) // base * 2^attempt
	return time.Duration(rand.Int63n(int64(cap) + 1))
}

type httpErr struct{ code int }

func (e *httpErr) Error() string { return "http status " + strconv.Itoa(e.code) }

func nullStr(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}
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
