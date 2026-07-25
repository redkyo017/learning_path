// Orders producer. Emits keyed OrderPlaced events to the `orders` topic.
//
//	go run ./producer -n 20            # 20 well-formed events
//	go run ./producer -poison          # 1 well-formed then 1 malformed (poison)
//
// Keyed by order_id -> same order's events share a partition (ordering).
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"time"

	"kafkalab/event"

	"github.com/segmentio/kafka-go"
)

func main() {
	n := flag.Int("n", 10, "number of well-formed events to emit")
	poison := flag.Bool("poison", false, "also emit one malformed (poison) message")
	flag.Parse()

	w := &kafka.Writer{
		Addr:     kafka.TCP(event.Broker),
		Topic:    event.Topic,
		Balancer: &kafka.Hash{}, // hash(key) % partitions -> deterministic per key
	}
	defer w.Close()

	ctx := context.Background()
	skus := []string{"SKU1", "SKU2", "SKU3"}

	for i := 0; i < *n; i++ {
		ev := event.OrderPlaced{
			OrderID:    fmt.Sprintf("order-%03d", i),
			SKU:        skus[i%len(skus)],
			Quantity:   1 + i%3,
			TotalCents: int64(1000 + i*250),
			PlacedAt:   time.Now().UTC(),
		}
		val, _ := json.Marshal(ev)
		if err := w.WriteMessages(ctx, kafka.Message{
			Key:   []byte(ev.OrderID), // <-- the partition key
			Value: val,
		}); err != nil {
			log.Fatalf("write: %v", err)
		}
		log.Printf("produced %s sku=%s qty=%d", ev.OrderID, ev.SKU, ev.Quantity)
	}

	if *poison {
		// A malformed record — not valid JSON. Same key so it lands in a real
		// partition behind well-formed records the consumer still needs.
		if err := w.WriteMessages(ctx, kafka.Message{
			Key:   []byte("order-POISON"),
			Value: []byte("}}} this is not json {{{"),
		}); err != nil {
			log.Fatalf("write poison: %v", err)
		}
		log.Println("produced POISON message (malformed JSON)")
	}
}
