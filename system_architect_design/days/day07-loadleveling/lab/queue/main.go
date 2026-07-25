// queue is the Day 7 load-leveling lab service.
//
// It puts a bounded queue (a Redis list) between a bursty HTTP producer and a
// rate-limited pool of workers, so a traffic spike inflates QUEUE DEPTH instead
// of ingress latency. This is the "queue-based load leveling" pattern.
//
// Endpoints:
//
//	POST /enqueue   -> LPUSH a job; returns 202 Accepted.
//	                   If QUEUE_MAX > 0 and depth >= QUEUE_MAX, returns 429 +
//	                   Retry-After (this is backpressure / load shedding).
//	GET  /depth     -> current queue depth (LLEN) as plain text.
//	GET  /stats     -> JSON: {enqueued, shed, processed, depth}.
//	GET  /health    -> 200 ok.
//
// Config via env:
//
//	PORT         (default 8090)   HTTP port
//	REDIS_ADDR   (default localhost:6379)
//	QUEUE        (default day7:jobs)   Redis list key
//	QUEUE_MAX    (default 0)      bound; 0 = UNBOUNDED (the break-it mode)
//	WORKERS      (default 4)      concurrent worker goroutines
//	WORK_MS      (default 50)     simulated downstream work per job
//
// The service rate is set by Little's Law: μ = WORKERS / (WORK_MS/1000).
// Defaults 4 / 50ms => μ = 80 jobs/sec. That is the ceiling the queue drains at.
//
// Run:  REDIS_ADDR=localhost:6379 QUEUE_MAX=1000 go run .
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	enqueued  atomic.Int64
	shed      atomic.Int64
	processed atomic.Int64
)

func main() {
	port := env("PORT", "8090")
	addr := env("REDIS_ADDR", "localhost:6379")
	queue := env("QUEUE", "day7:jobs")
	queueMax := envInt("QUEUE_MAX", 0)
	workers := envInt("WORKERS", 4)
	workMS := envInt("WORK_MS", 50)

	rdb := redis.NewClient(&redis.Options{Addr: addr})
	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis ping failed at %s: %v", addr, err)
	}
	// Fresh queue each run so measurements aren't polluted by a prior run.
	rdb.Del(ctx, queue)

	// --- Worker pool: drains the queue at a fixed rate μ = WORKERS/WORK_MS. ---
	// Each worker loops: pop one job, do WORK_MS of "downstream work", repeat.
	// That fixed per-worker cost is what caps throughput and lets the queue
	// (not the ingress tier) absorb a burst.
	for i := 0; i < workers; i++ {
		go worker(ctx, rdb, queue, workMS)
	}

	// --- Ingress: enqueue + return 202, or 429 when the bound is hit. ---
	http.HandleFunc("/enqueue", func(w http.ResponseWriter, r *http.Request) {
		if queueMax > 0 {
			depth, _ := rdb.LLen(ctx, queue).Result()
			if depth >= int64(queueMax) {
				shed.Add(1)
				w.Header().Set("Retry-After", "1")
				http.Error(w, "queue full", http.StatusTooManyRequests) // 429 = backpressure
				return
			}
		}
		// The handler does the cheapest possible thing: push a job and return.
		if err := rdb.LPush(ctx, queue, time.Now().UnixNano()).Err(); err != nil {
			http.Error(w, "enqueue failed", http.StatusServiceUnavailable)
			return
		}
		enqueued.Add(1)
		w.WriteHeader(http.StatusAccepted) // 202: accepted, not yet done
	})

	http.HandleFunc("/depth", func(w http.ResponseWriter, r *http.Request) {
		depth, _ := rdb.LLen(ctx, queue).Result()
		w.Write([]byte(strconv.FormatInt(depth, 10)))
	})

	http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		depth, _ := rdb.LLen(ctx, queue).Result()
		json.NewEncoder(w).Encode(map[string]int64{
			"enqueued": enqueued.Load(), "shed": shed.Load(),
			"processed": processed.Load(), "depth": depth,
		})
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	mu := float64(workers) / (float64(workMS) / 1000.0)
	log.Printf("queue up on :%s  redis=%s queue=%s QUEUE_MAX=%d WORKERS=%d WORK_MS=%d  => mu=%.0f jobs/s",
		port, addr, queue, queueMax, workers, workMS, mu)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

// worker loops: pop one job (blocking up to 1s), then "process" it by sleeping
// WORK_MS to simulate a rate-limited downstream. WORKERS of these give the pool
// its fixed service rate μ.
func worker(ctx context.Context, rdb *redis.Client, queue string, workMS int) {
	for {
		res, err := rdb.BRPop(ctx, time.Second, queue).Result()
		if err != nil || len(res) < 2 {
			continue // timeout: no work available
		}
		time.Sleep(time.Duration(workMS) * time.Millisecond)
		processed.Add(1)
	}
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
