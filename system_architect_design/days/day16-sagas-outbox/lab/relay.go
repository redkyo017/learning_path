package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/segmentio/kafka-go"
)

// runRelay polls the outbox for unsent rows, publishes them to Kafka, and marks
// them sent. Ordering is deliberate: read -> publish -> mark sent. If we marked
// sent before publishing, a crash would LOSE the event (dual-write reintroduced
// inside the relay). Because we mark sent only after a successful publish, a
// crash between publish and mark causes a REPUBLISH (duplicate) on restart —
// which the idempotent consumer absorbs. Net: at-least-once delivery, no loss.
//
// FOR UPDATE SKIP LOCKED lets you run several relay workers safely: each grabs a
// disjoint batch instead of fighting over the same rows.
func runRelay(ctx context.Context) {
	pool := mustPool(ctx)
	defer pool.Close()

	w := &kafka.Writer{
		Addr:                   kafka.TCP(broker()),
		Topic:                  topic(),
		Balancer:               &kafka.Hash{}, // same key (event_id) -> same partition
		AllowAutoTopicCreation: true,
	}
	defer w.Close()

	crashBefore := os.Getenv("CRASH_BEFORE_PUBLISH") == "1"
	crashAfter := os.Getenv("CRASH_AFTER_PUBLISH") == "1"

	log.Printf("relay polling outbox -> topic %q (crashBefore=%v crashAfter=%v)", topic(), crashBefore, crashAfter)
	tick := time.NewTicker(500 * time.Millisecond)
	defer tick.Stop()

	for range tick.C {
		if err := relayBatch(ctx, pool, w, crashBefore, crashAfter); err != nil {
			log.Println("relay batch error:", err)
		}
	}
}

func relayBatch(ctx context.Context, pool *pgxpool.Pool, w *kafka.Writer, crashBefore, crashAfter bool) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) // rolls back on any early return / crash-before-commit

	rows, err := tx.Query(ctx,
		`SELECT id, event_id, payload FROM outbox
		 WHERE sent_at IS NULL
		 ORDER BY id
		 LIMIT 10
		 FOR UPDATE SKIP LOCKED`)
	if err != nil {
		return err
	}

	type item struct {
		id      int64
		eventID string
		payload []byte
	}
	var batch []item
	for rows.Next() {
		var it item
		if err := rows.Scan(&it.id, &it.eventID, &it.payload); err != nil {
			rows.Close()
			return err
		}
		batch = append(batch, it)
	}
	rows.Close()
	if len(batch) == 0 {
		return tx.Commit(ctx) // nothing to do
	}

	for _, it := range batch {
		if crashBefore {
			log.Printf("CRASH_BEFORE_PUBLISH: exiting with outbox row %d still unsent (event_id=%s)", it.id, it.eventID)
			os.Exit(1)
		}
		if err := w.WriteMessages(ctx, kafka.Message{
			Key:   []byte(it.eventID),
			Value: it.payload,
		}); err != nil {
			return err // tx rolls back; row stays unsent; retried next tick
		}
		log.Printf("published outbox row %d (event_id=%s)", it.id, it.eventID)
		if crashAfter {
			log.Printf("CRASH_AFTER_PUBLISH: exiting before marking row %d sent -> will REPUBLISH on restart", it.id)
			os.Exit(1)
		}
		if _, err := tx.Exec(ctx, `UPDATE outbox SET sent_at = now() WHERE id = $1`, it.id); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
