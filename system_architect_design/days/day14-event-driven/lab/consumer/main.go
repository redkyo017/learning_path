// Consumer for the `orders` topic. Same binary, two roles via -group:
//
//	go run ./consumer -group inventory     # decrements stock
//	go run ./consumer -group analytics     # counts events + revenue
//	go run ./consumer -group inventory -dlq # enable the dead-letter path
//
// Each group commits its own offsets, so inventory and analytics independently
// receive EVERY event. Commit is AFTER processing (at-least-once): a crash before
// commit re-delivers the record, so processing must tolerate duplicates.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"

	"kafkalab/event"

	"github.com/segmentio/kafka-go"
)

func main() {
	group := flag.String("group", "inventory", "consumer group: inventory | analytics")
	dlq := flag.Bool("dlq", false, "on a poison message, dead-letter it and continue (instead of crashing)")
	flag.Parse()

	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers: []string{event.Broker},
		Topic:   event.Topic,
		GroupID: *group, // <-- distinct group => independent offsets => full fan-out
		// New group with no committed offset starts here. To REPLAY, reset offsets
		// via the CLI (see lab/README.md), not code.
		StartOffset: kafka.FirstOffset,
	})
	defer r.Close()

	// Writer used only to dead-letter poison messages.
	dlqWriter := &kafka.Writer{Addr: kafka.TCP(event.Broker), Topic: event.DLQTopic}
	defer dlqWriter.Close()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	// In-memory state, rebuilt from the log every run (that's the point).
	stock := map[string]int{"SKU1": 100, "SKU2": 100, "SKU3": 100}
	var count int
	var revenue int64

	log.Printf("[%s] consuming from offset=earliest (dlq=%v)", *group, *dlq)

	for {
		m, err := r.FetchMessage(ctx) // does NOT commit; we commit after processing
		if err != nil {
			log.Printf("[%s] stopped: %v", *group, err)
			return
		}

		var ev event.OrderPlaced
		if err := json.Unmarshal(m.Value, &ev); err != nil {
			// === POISON MESSAGE ===
			if *dlq {
				// Dead-letter it (with provenance headers) and move on.
				_ = dlqWriter.WriteMessages(context.Background(), kafka.Message{
					Key:   m.Key,
					Value: m.Value,
					Headers: []kafka.Header{
						{Key: "x-origin-topic", Value: []byte(m.Topic)},
						{Key: "x-origin-partition", Value: []byte(strconv.Itoa(m.Partition))},
						{Key: "x-origin-offset", Value: []byte(strconv.FormatInt(m.Offset, 10))},
						{Key: "x-error", Value: []byte(err.Error())},
					},
				})
				log.Printf("[%s] DEAD-LETTERED bad record at partition=%d offset=%d: %v",
					*group, m.Partition, m.Offset, err)
				_ = r.CommitMessages(ctx, m) // commit so we never see it again
				continue
			}
			// NAIVE path: crash. On restart we re-read from the uncommitted offset
			// and crash again -> crash loop -> this partition is WEDGED. Every
			// well-formed record behind the poison one stops being processed.
			log.Fatalf("[%s] POISON at partition=%d offset=%d: %v  (partition is now stalled; re-run to see the crash loop, or use -dlq)",
				*group, m.Partition, m.Offset, err)
		}

		// === business logic per role ===
		switch *group {
		case "inventory":
			// TODO (the one insight): reject/flag an oversell when stock would go
			// negative, and make this idempotent (you WILL re-see events after a
			// rebalance or replay). For now it just decrements.
			stock[ev.SKU] -= ev.Quantity
			log.Printf("[inventory] %s -%d %s -> on_hand=%d", ev.OrderID, ev.Quantity, ev.SKU, stock[ev.SKU])
		case "analytics":
			count++
			revenue += ev.TotalCents
			log.Printf("[analytics] %s -> count=%d revenue=%s", ev.OrderID, count, dollars(revenue))
		default:
			log.Fatalf("unknown group %q", *group)
		}

		if err := r.CommitMessages(ctx, m); err != nil {
			log.Printf("[%s] commit failed: %v", *group, err)
		}
	}
}

func dollars(cents int64) string { return fmt.Sprintf("$%d.%02d", cents/100, cents%100) }
