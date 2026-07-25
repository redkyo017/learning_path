package orders_test

import (
	"testing"

	"lab/boundaries/orders"
)

// fakeInventory implements orders.InventoryPort with NO reference to the real
// inventory package. The fact that this test file imports ONLY orders is the
// proof the boundary holds: orders is fully exercisable without inventory.
type fakeInventory struct {
	reserved bool
}

func (f fakeInventory) Reserve(req orders.ReserveRequest) (orders.ReserveResult, error) {
	return orders.ReserveResult{Reserved: f.reserved, ConfirmationID: "TEST-1"}, nil
}

// Compile-time assertion: the fake satisfies the port. (The real adapter in
// cmd/demo carries the same kind of assertion for inventory.Service.)
var _ orders.InventoryPort = fakeInventory{}

func TestPlace_ReservesAndReturnsOrderID(t *testing.T) {
	s := orders.New(fakeInventory{reserved: true})
	id, err := s.Place("widget", 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if id != "order-TEST-1" {
		t.Fatalf("got %q, want order-TEST-1", id)
	}
}

func TestPlace_OutOfStock(t *testing.T) {
	s := orders.New(fakeInventory{reserved: false})
	if _, err := s.Place("widget", 1); err == nil {
		t.Fatal("expected an out-of-stock error, got nil")
	}
}
