// Package event holds the shared OrderPlaced schema (event-carried state transfer:
// the event carries enough state that a consumer never has to call back to Orders).
package event

import "time"

const (
	Topic    = "orders"
	DLQTopic = "orders.DLQ"
	Broker   = "localhost:9092"
)

// OrderPlaced is emitted once per order. Keyed on Kafka by OrderID so all events
// for one order land on the same partition (per-order ordering).
type OrderPlaced struct {
	OrderID    string    `json:"order_id"`
	SKU        string    `json:"sku"`
	Quantity   int       `json:"quantity"`
	TotalCents int64     `json:"total_cents"`
	PlacedAt   time.Time `json:"placed_at"`
}
