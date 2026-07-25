// Day 16 lab — transactional outbox + idempotent consumer + a tiny order saga.
//
// One binary, several subcommands (each is a separate process you run in its
// own terminal):
//
//	go run . api        # HTTP server; POST /placeOrder writes order + outbox in ONE tx
//	go run . relay      # polls outbox -> publishes to Kafka -> marks sent
//	go run . consumer   # idempotent Kafka consumer (dedupes on event_id)
//	go run . saga WIDGET 2   # runs the payment->inventory saga once
//	go run . status     # prints counts (orders / unsent outbox / processed)
//
// Env (all have sane defaults for the shared labs/ stack):
//
//	DATABASE_URL   default postgres://postgres:pass@localhost:5432/app
//	KAFKA_BROKER   default localhost:9092
//	TOPIC          default orders
//
// Break-it flags on the relay (set to "1"):
//
//	CRASH_BEFORE_PUBLISH   exit(1) after reading an outbox row, before publishing
//	CRASH_AFTER_PUBLISH    exit(1) after publishing, before marking it sent
package main

import (
	"context"
	"crypto/rand"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	ctx := context.Background()
	switch os.Args[1] {
	case "api":
		runAPI(ctx)
	case "relay":
		runRelay(ctx)
	case "consumer":
		runConsumer(ctx)
	case "saga":
		runSaga(ctx)
	case "status":
		runStatus(ctx)
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: go run . [api|relay|consumer|saga <product> <qty>|status]")
	os.Exit(2)
}

// ---- shared helpers ---------------------------------------------------------

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func databaseURL() string { return env("DATABASE_URL", "postgres://postgres:pass@localhost:5432/app") }
func broker() string      { return env("KAFKA_BROKER", "localhost:9092") }
func topic() string       { return env("TOPIC", "orders") }

func mustPool(ctx context.Context) *pgxpool.Pool {
	pool, err := pgxpool.New(ctx, databaseURL())
	if err != nil {
		fmt.Fprintln(os.Stderr, "db connect:", err)
		os.Exit(1)
	}
	return pool
}

// uuidv4 returns a random RFC-4122 v4 UUID string. Used as the stable event_id
// so the consumer can dedup regardless of Kafka offset.
func uuidv4() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40 // version 4
	b[8] = (b[8] & 0x3f) | 0x80 // variant 10
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}
