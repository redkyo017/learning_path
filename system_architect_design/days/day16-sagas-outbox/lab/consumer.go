package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/segmentio/kafka-go"
)

type orderEvent struct {
	Type    string `json:"type"`
	EventID string `json:"event_id"`
	OrderID int64  `json:"order_id"`
	Product string `json:"product"`
	Qty     int    `json:"qty"`
}

// runConsumer is the idempotent consumer. Delivery is at-least-once, so the same
// event_id may arrive more than once (e.g. after a relay CRASH_AFTER_PUBLISH).
// The dedup ledger insert and the side effect happen in ONE transaction:
//
//	INSERT INTO processed_events(event_id) ... ON CONFLICT DO NOTHING
//	  rows == 0 -> duplicate, skip the side effect
//	  rows == 1 -> first time, apply the side effect in THIS tx
//
// Kafka offsets are committed only AFTER the DB tx commits, so a crash re-delivers
// rather than silently dropping. We dedup on event_id (a business key), never on
// the offset — offsets change on replay/repartition.
func runConsumer(ctx context.Context) {
	pool := mustPool(ctx)
	defer pool.Close()

	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:     []string{broker()},
		GroupID:     "orders-consumer",
		Topic:       topic(),
		StartOffset: kafka.FirstOffset,
	})
	defer r.Close()

	log.Printf("consumer reading topic %q as group orders-consumer", topic())
	for {
		m, err := r.FetchMessage(ctx) // does NOT auto-commit the offset
		if err != nil {
			log.Println("fetch error:", err)
			return
		}

		var ev orderEvent
		if err := json.Unmarshal(m.Value, &ev); err != nil {
			log.Printf("poison message at offset %d: %v (skipping)", m.Offset, err)
			_ = r.CommitMessages(ctx, m) // move past it; a real system routes to a DLQ
			continue
		}

		applied, err := applyOnce(ctx, pool, ev)
		if err != nil {
			log.Println("apply error (will re-deliver):", err)
			continue // do NOT commit the offset -> Kafka re-delivers
		}
		if applied {
			log.Printf("APPLIED  event_id=%s order=%d %dx%s", ev.EventID, ev.OrderID, ev.Qty, ev.Product)
		} else {
			log.Printf("DUPLICATE event_id=%s -> deduped, no side effect", ev.EventID)
		}
		if err := r.CommitMessages(ctx, m); err != nil {
			log.Println("offset commit error:", err)
		}
	}
}

// applyOnce records the event_id and applies the side effect in one transaction.
// Returns applied=true only the first time we see event_id; false on a duplicate.
func applyOnce(ctx context.Context, pool *pgxpool.Pool, ev orderEvent) (bool, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx,
		`INSERT INTO processed_events (event_id) VALUES ($1) ON CONFLICT DO NOTHING`,
		ev.EventID)
	if err != nil {
		return false, err
	}
	if tag.RowsAffected() == 0 {
		// Already processed — commit nothing new and report a duplicate.
		return false, tx.Commit(ctx)
	}

	// First time: apply the side effect in the SAME tx as the dedup record.
	if _, err := tx.Exec(ctx,
		`UPDATE inventory SET stock = stock - $1 WHERE product = $2`,
		ev.Qty, ev.Product); err != nil {
		return false, err
	}
	return true, tx.Commit(ctx)
}
