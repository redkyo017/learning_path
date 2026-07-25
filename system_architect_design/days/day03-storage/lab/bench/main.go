// bench compares Postgres (indexed) vs Redis (KV) for the shortener's read paths.
//
// Ops:
//
//	-op=load-redis           copy every short_urls row from Postgres into Redis (SET code url)
//	-op=bench  -store=postgres|redis   time N random point lookups (code -> url); print p50/p95/p99
//	-op=range  -store=postgres|redis   the BREAK-IT: "codes created today"
//	                                     postgres = indexed range scan (fast);
//	                                     redis    = full keyspace SCAN, no time index (slow/impossible)
//
// Flags: -n (lookups, default 20000), -pg (DSN), -redis (addr).
//
// Run (from this dir, with shared labs postgres+redis up and the table seeded):
//
//	go mod tidy
//	go run . -op=load-redis
//	go run . -op=bench -store=postgres
//	go run . -op=bench -store=redis
//	go run . -op=range -store=postgres
//	go run . -op=range -store=redis
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"sort"
	"time"

	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

func main() {
	op := flag.String("op", "bench", "load-redis | bench | range")
	store := flag.String("store", "postgres", "postgres | redis")
	n := flag.Int("n", 20000, "number of point lookups for -op=bench")
	pgDSN := flag.String("pg", "postgres://postgres:pass@localhost:5432/app?sslmode=disable", "Postgres DSN")
	redisAddr := flag.String("redis", "localhost:6379", "Redis address")
	flag.Parse()

	ctx := context.Background()

	pg, err := sql.Open("postgres", *pgDSN)
	if err != nil {
		log.Fatalf("open pg: %v", err)
	}
	defer pg.Close()
	pg.SetMaxOpenConns(16)
	if err := pg.Ping(); err != nil {
		log.Fatalf("ping pg (is the shared labs stack up and seeded?): %v", err)
	}

	rdb := redis.NewClient(&redis.Options{Addr: *redisAddr, PoolSize: 16})
	defer rdb.Close()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("ping redis: %v", err)
	}

	switch *op {
	case "load-redis":
		loadRedis(ctx, pg, rdb)
	case "bench":
		codes := sampleCodes(pg, *n)
		if *store == "postgres" {
			benchPostgres(pg, codes)
		} else {
			benchRedis(ctx, rdb, codes)
		}
	case "range":
		if *store == "postgres" {
			rangePostgres(pg)
		} else {
			rangeRedis(ctx, rdb)
		}
	default:
		log.Fatalf("unknown -op %q", *op)
	}
}

// loadRedis mirrors the whole table into Redis with pipelined SETs.
func loadRedis(ctx context.Context, pg *sql.DB, rdb *redis.Client) {
	rows, err := pg.Query(`SELECT code, url FROM short_urls`)
	if err != nil {
		log.Fatalf("select: %v", err)
	}
	defer rows.Close()

	start := time.Now()
	pipe := rdb.Pipeline()
	count, batch := 0, 0
	for rows.Next() {
		var code, url string
		if err := rows.Scan(&code, &url); err != nil {
			log.Fatal(err)
		}
		pipe.Set(ctx, code, url, 0)
		batch++
		count++
		if batch >= 10000 {
			if _, err := pipe.Exec(ctx); err != nil {
				log.Fatalf("pipe exec: %v", err)
			}
			pipe = rdb.Pipeline()
			batch = 0
		}
	}
	if batch > 0 {
		if _, err := pipe.Exec(ctx); err != nil {
			log.Fatalf("pipe exec (tail): %v", err)
		}
	}
	fmt.Printf("loaded %d keys into Redis in %s\n", count, time.Since(start).Round(time.Millisecond))
}

// sampleCodes pulls N random existing codes so lookups hit real keys in BOTH stores.
func sampleCodes(pg *sql.DB, n int) []string {
	// TABLESAMPLE is far cheaper than ORDER BY random() on 1M rows.
	rows, err := pg.Query(`SELECT code FROM short_urls TABLESAMPLE SYSTEM (10) LIMIT $1`, n)
	if err != nil {
		log.Fatalf("sample: %v", err)
	}
	defer rows.Close()
	var codes []string
	for rows.Next() {
		var c string
		if err := rows.Scan(&c); err != nil {
			log.Fatal(err)
		}
		codes = append(codes, c)
	}
	if len(codes) == 0 {
		log.Fatal("no codes sampled — did you run schema.sql + seed.sql?")
	}
	rand.Shuffle(len(codes), func(i, j int) { codes[i], codes[j] = codes[j], codes[i] })
	return codes
}

func benchPostgres(pg *sql.DB, codes []string) {
	stmt, err := pg.Prepare(`SELECT url FROM short_urls WHERE code = $1`)
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	lat := make([]time.Duration, 0, len(codes))
	for _, c := range codes {
		t0 := time.Now()
		var url string
		if err := stmt.QueryRow(c).Scan(&url); err != nil {
			log.Fatalf("lookup %s: %v", c, err)
		}
		lat = append(lat, time.Since(t0))
	}
	report("Postgres point lookup (indexed PK)", lat)
}

func benchRedis(ctx context.Context, rdb *redis.Client, codes []string) {
	lat := make([]time.Duration, 0, len(codes))
	for _, c := range codes {
		t0 := time.Now()
		if err := rdb.Get(ctx, c).Err(); err != nil {
			log.Fatalf("GET %s: %v (did you run -op=load-redis?)", c, err)
		}
		lat = append(lat, time.Since(t0))
	}
	report("Redis point lookup (KV GET)", lat)
}

// rangePostgres: "codes created today" — an INDEX RANGE SCAN. Fast + trivial.
func rangePostgres(pg *sql.DB) {
	t0 := time.Now()
	var count int
	err := pg.QueryRow(
		`SELECT count(*) FROM short_urls WHERE created_at >= date_trunc('day', now())`,
	).Scan(&count)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Postgres range 'created today': %d rows in %s (uses idx_short_urls_created_at)\n",
		count, time.Since(t0).Round(time.Millisecond))
	fmt.Println("  -> run EXPLAIN ANALYZE on this query in psql to see the index range scan.")
}

// rangeRedis: the same question is IMPOSSIBLE to answer efficiently. A KV keyed by
// code has no secondary index on time, and doesn't even store created_at. The only
// way to touch every key is a full SCAN — O(N) over the whole keyspace, and you STILL
// can't filter by time. This is the missing-index pain the SQL model handles trivially.
func rangeRedis(ctx context.Context, rdb *redis.Client) {
	t0 := time.Now()
	var cursor uint64
	var scanned int
	for {
		keys, next, err := rdb.Scan(ctx, cursor, "*", 1000).Result()
		if err != nil {
			log.Fatal(err)
		}
		scanned += len(keys)
		cursor = next
		if cursor == 0 {
			break
		}
	}
	fmt.Printf("Redis SCAN touched %d keys in %s — and it STILL can't answer "+
		"'created today' (no timestamp, no secondary index).\n", scanned, time.Since(t0).Round(time.Millisecond))
	fmt.Println("  -> To support this in Redis you'd bolt on a sorted set (ZADD score=created_at),")
	fmt.Println("     i.e. hand-build the index the relational engine gave you for free.")
}

func report(label string, lat []time.Duration) {
	sort.Slice(lat, func(i, j int) bool { return lat[i] < lat[j] })
	p := func(q float64) time.Duration { return lat[int(float64(len(lat))*q)] }
	var sum time.Duration
	for _, d := range lat {
		sum += d
	}
	fmt.Printf("%s\n  n=%d  mean=%s  p50=%s  p95=%s  p99=%s  max=%s\n",
		label, len(lat),
		(sum / time.Duration(len(lat))).Round(time.Microsecond),
		p(0.50).Round(time.Microsecond),
		p(0.95).Round(time.Microsecond),
		p(0.99).Round(time.Microsecond),
		lat[len(lat)-1].Round(time.Microsecond),
	)
}
