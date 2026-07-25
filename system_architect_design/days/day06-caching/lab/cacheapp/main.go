// cacheapp is a tiny cache-aside service over Redis + Postgres for the Day 6 lab.
// It exposes the hit ratio and DB-query count so you can SEE the cache working,
// reproduce a stampede, and fix it with singleflight.
//
// Endpoints:
//
//	GET /lookup?code=abc   cache-aside lookup (or straight-to-DB if CACHE=off)
//	GET /bust?code=abc     DELETE the key from Redis (simulate a TTL expiry/eviction)
//	GET /stats             JSON: hits, misses, dbQueries, hitRatio, flags
//	GET /reset             zero the counters
//	GET /health            200 ok
//
// Config via env:
//
//	PORT             (default 8090)
//	PG_DSN           (default host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable)
//	REDIS_ADDR       (default localhost:6379)
//	CACHE            on|off  (default on)      — off = every read hits the DB (baseline)
//	SINGLEFLIGHT     on|off  (default off)     — on = coalesce concurrent misses (the fix)
//	CACHE_TTL_SECONDS (default 60)
//	DB_DELAY_MS      (default 50)              — simulated cost of an "expensive" query
//
// Seed the DB once with:  go run . -seed 1000   (then it keeps serving)
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
	"golang.org/x/sync/singleflight"
)

var (
	db  *sql.DB
	rdb *redis.Client
	ctx = context.Background()

	cacheOn  = env("CACHE", "on") == "on"
	singleOn = env("SINGLEFLIGHT", "off") == "on"
	ttl      = time.Duration(atoiDef(env("CACHE_TTL_SECONDS", "60"), 60)) * time.Second
	dbDelay  = time.Duration(atoiDef(env("DB_DELAY_MS", "50"), 50)) * time.Millisecond
	group    singleflight.Group

	hits, misses, dbQueries int64
)

func main() {
	seed := flag.Int("seed", 0, "if >0, (re)create and seed N link rows, then keep serving")
	flag.Parse()

	var err error
	db, err = sql.Open("postgres", env("PG_DSN",
		"host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable"))
	if err != nil {
		log.Fatal(err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("postgres not reachable (bring up labs stack): %v", err)
	}
	rdb = redis.NewClient(&redis.Options{Addr: env("REDIS_ADDR", "localhost:6379")})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis not reachable (bring up labs stack): %v", err)
	}

	if *seed > 0 {
		seedDB(*seed)
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) { fmt.Fprint(w, "ok") })
	http.HandleFunc("/lookup", handleLookup)
	http.HandleFunc("/bust", handleBust)
	http.HandleFunc("/stats", handleStats)
	http.HandleFunc("/reset", func(w http.ResponseWriter, r *http.Request) {
		atomic.StoreInt64(&hits, 0)
		atomic.StoreInt64(&misses, 0)
		atomic.StoreInt64(&dbQueries, 0)
		fmt.Fprint(w, "reset")
	})

	port := env("PORT", "8090")
	log.Printf("cacheapp on :%s  cache=%v singleflight=%v ttl=%v dbDelay=%v",
		port, cacheOn, singleOn, ttl, dbDelay)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleLookup(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "missing code", http.StatusBadRequest)
		return
	}

	// Baseline mode: skip the cache entirely (measures the "without cache" p95).
	if !cacheOn {
		v, err := loadFromDB(code)
		respond(w, v, err)
		return
	}

	// Cache-aside: check Redis first.
	v, err := rdb.Get(ctx, key(code)).Result()
	if err == nil {
		atomic.AddInt64(&hits, 1)
		fmt.Fprint(w, v)
		return
	}
	if err != redis.Nil {
		http.Error(w, "cache error: "+err.Error(), http.StatusBadGateway)
		return
	}

	// MISS: load from DB, then populate the cache with a TTL.
	atomic.AddInt64(&misses, 1)
	val, lerr := loadCoalesced(code)
	if lerr != nil {
		respond(w, val, lerr)
		return
	}
	// Jitter would go here in prod (ttl ± rand) to avoid avalanche; kept fixed
	// for a deterministic lab.
	rdb.Set(ctx, key(code), val, ttl)
	fmt.Fprint(w, val)
}

// loadCoalesced optionally wraps the DB load in singleflight so that N concurrent
// misses for the SAME key trigger exactly ONE DB query — the stampede fix.
func loadCoalesced(code string) (string, error) {
	if !singleOn {
		return loadFromDB(code)
	}
	v, err, _ := group.Do(code, func() (interface{}, error) {
		return loadFromDB(code)
	})
	if err != nil {
		return "", err
	}
	return v.(string), nil
}

// loadFromDB is the "expensive" query. Every call here is a real DB hit — this is
// the counter the stampede blows up.
func loadFromDB(code string) (string, error) {
	atomic.AddInt64(&dbQueries, 1)
	time.Sleep(dbDelay) // simulate an expensive query/aggregation/join
	var url string
	err := db.QueryRow(`SELECT long_url FROM links WHERE short_code=$1`, code).Scan(&url)
	if err == sql.ErrNoRows {
		// TODO (learner): implement NEGATIVE CACHING here — cache the "not found"
		// with a short TTL so repeated lookups of a bad/expired code stop hitting
		// the DB (cache penetration). Then add a k6 run against random non-existent
		// codes and show dbQueries stops climbing. Nothing else depends on this.
		return "", fmt.Errorf("not found")
	}
	return url, err
}

func handleBust(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	n, _ := rdb.Del(ctx, key(code)).Result()
	fmt.Fprintf(w, "busted %q (deleted %d)", code, n)
}

func handleStats(w http.ResponseWriter, r *http.Request) {
	h, m, q := atomic.LoadInt64(&hits), atomic.LoadInt64(&misses), atomic.LoadInt64(&dbQueries)
	ratio := 0.0
	if h+m > 0 {
		ratio = float64(h) / float64(h+m)
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"hits": h, "misses": m, "dbQueries": q,
		"hitRatio":     ratio,
		"cache":        cacheOn,
		"singleflight": singleOn,
	})
}

func seedDB(n int) {
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS links(
		short_code TEXT PRIMARY KEY, long_url TEXT NOT NULL)`); err != nil {
		log.Fatal(err)
	}
	if _, err := db.Exec(
		`INSERT INTO links SELECT 'code-'||g, 'https://x/'||g
		   FROM generate_series(0,$1) g ON CONFLICT DO NOTHING`, n-1); err != nil {
		log.Fatal(err)
	}
	if _, err := db.Exec(
		`INSERT INTO links VALUES ('hot','https://x/hot') ON CONFLICT DO NOTHING`); err != nil {
		log.Fatal(err)
	}
	log.Printf("seeded %d rows (code-0..code-%d) + 'hot'", n, n-1)
}

func respond(w http.ResponseWriter, v string, err error) {
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	fmt.Fprint(w, v)
}

func key(code string) string { return "url:" + code }

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func atoiDef(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil {
		return n
	}
	return def
}
