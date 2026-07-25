// lagcheck writes a unique row to the PRIMARY, then polls the REPLICA until the
// row appears — printing the replication-lag window in milliseconds. It is the
// programmatic version of the psql walkthrough in ../README.md.
//
// Usage (run `go mod tidy` first):
//
//	go run .                 # measure the normal lag window (replay running)
//	go run . -timeout 3s     # give up after 3s — run this while replay is PAUSED
//	                         # on the replica to prove the stale read never resolves
//	go run . -replica "host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable"
//	                         # the FIX: point the read at the primary -> always fresh
//
// Primary:  localhost:5432    Replica: localhost:5433    (db app / postgres / pass)
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"
)

func main() {
	primaryDSN := flag.String("primary",
		"host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable",
		"DSN of the primary (writes go here)")
	replicaDSN := flag.String("replica",
		"host=localhost port=5433 user=postgres password=pass dbname=app sslmode=disable",
		"DSN the read is served from (the replica, by default)")
	timeout := flag.Duration("timeout", 5*time.Second,
		"give up waiting for the read to see the write after this long")
	flag.Parse()

	primary := mustOpen(*primaryDSN)
	defer primary.Close()
	reader := mustOpen(*replicaDSN)
	defer reader.Close()

	code := fmt.Sprintf("lag-%d", time.Now().UnixNano())

	// 1. Write to the primary; t=0 is the moment the commit returns.
	start := time.Now()
	if _, err := primary.Exec(
		`INSERT INTO links(short_code, long_url) VALUES ($1, $2)`,
		code, "https://lagtest"); err != nil {
		log.Fatalf("write to primary failed: %v", err)
	}
	fmt.Printf("wrote %q to primary at t=0\n", code)

	// 2. Poll the reader until the row is visible (or we time out).
	deadline := start.Add(*timeout)
	for {
		var n int
		if err := reader.QueryRow(
			`SELECT count(*) FROM links WHERE short_code=$1`, code).Scan(&n); err != nil {
			log.Fatalf("read failed: %v", err)
		}
		if n == 1 {
			fmt.Printf("CAUGHT UP: row visible after %v  <-- this is your lag window\n",
				time.Since(start).Round(time.Millisecond))
			return
		}
		if time.Now().After(deadline) {
			fmt.Printf("STALE READ: row STILL not visible after %v — read-your-writes VIOLATED.\n",
				time.Since(start).Round(time.Millisecond))
			fmt.Println("  (expected if you ran  SELECT pg_wal_replay_pause();  on the replica)")
			fmt.Println("  FIX: serve this read from the primary:")
			fmt.Println("       go run . -replica \"host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable\"")
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
}

func mustOpen(dsn string) *sql.DB {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("open: %v", err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("ping (%s): %v", dsn, err)
	}
	return db
}
