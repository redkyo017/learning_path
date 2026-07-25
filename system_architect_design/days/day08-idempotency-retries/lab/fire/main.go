// fire hammers the Day 8 charge service with concurrent requests.
//
// Two modes:
//
//	same   (default): all N requests carry the SAME Idempotency-Key. With the
//	                   guard on, you should see 1 created (201) + N-1 replayed
//	                   (200), and exactly ONE charges row in the DB.
//	unique:           each request gets its own key. Used for the backoff-vs-
//	                  jitter experiment against a flaky downstream.
//
// Config via env:
//
//	URL   (default http://localhost:8095/charge)
//	N     (default 100)   number of requests
//	MODE  (default same)  same | unique
//	KEY   (default day8-demo-key)  the shared key for MODE=same
//
// Run:  N=100 MODE=same go run .
package main

import (
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	url := env("URL", "http://localhost:8095/charge")
	n := envInt("N", 100)
	mode := env("MODE", "same")
	key := env("KEY", "day8-demo-key")

	var created, replayed, failed atomic.Int64
	client := &http.Client{Timeout: 10 * time.Second}

	var wg sync.WaitGroup
	start := time.Now()
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			k := key
			if mode == "unique" {
				k = fmt.Sprintf("%s-%d", key, i)
			}
			req, _ := http.NewRequest(http.MethodPost, url,
				strings.NewReader(`{"amount_cents":5000}`))
			req.Header.Set("Idempotency-Key", k)
			req.Header.Set("Content-Type", "application/json")
			resp, err := client.Do(req)
			if err != nil {
				failed.Add(1)
				return
			}
			resp.Body.Close()
			switch resp.StatusCode {
			case http.StatusCreated:
				created.Add(1)
			case http.StatusOK:
				replayed.Add(1)
			default:
				failed.Add(1)
			}
		}(i)
	}
	wg.Wait()

	fmt.Printf("fired %d requests (mode=%s) in %s\n", n, mode, time.Since(start))
	fmt.Printf("  created (201): %d\n", created.Load())
	fmt.Printf("  replayed(200): %d\n", replayed.Load())
	fmt.Printf("  failed       : %d\n", failed.Load())
	fmt.Println("\nNow verify in Postgres:")
	fmt.Println(`  psql "postgres://postgres:pass@localhost:5432/app?sslmode=disable" \`)
	fmt.Println(`    -c "SELECT idempotency_key, count(*) FROM charges GROUP BY 1 ORDER BY 2 DESC LIMIT 5;"`)
	fmt.Println("Expected (guard ON, mode=same): exactly ONE row for the key.")
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
