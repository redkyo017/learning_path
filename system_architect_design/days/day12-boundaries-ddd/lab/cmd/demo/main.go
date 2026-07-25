// Command demo is the COMPOSITION ROOT: the only place that imports both
// contexts. It supplies orders with an implementation of orders.InventoryPort by
// wrapping inventory.Service in an Anti-Corruption Layer (the adapter), which
// translates between orders' DTOs and inventory's own model.
//
//	go run ./cmd/demo
package main

import (
	"errors"
	"fmt"

	"lab/boundaries/inventory"
	"lab/boundaries/orders"
)

// inventoryAdapter is the Anti-Corruption Layer. It is the ONLY code that knows
// both languages: it maps orders.ReserveRequest -> inventory's Reserve(sku, qty)
// and inventory.Reservation/ErrOutOfStock -> orders.ReserveResult. Neither
// context leaks into the other; the adapter absorbs the translation cost.
type inventoryAdapter struct {
	inv *inventory.Service
}

func (a inventoryAdapter) Reserve(req orders.ReserveRequest) (orders.ReserveResult, error) {
	r, err := a.inv.Reserve(req.SKU, req.Qty)
	switch {
	case errors.Is(err, inventory.ErrOutOfStock):
		// Translate inventory's domain error into a plain "not reserved" — do NOT
		// leak inventory.ErrOutOfStock across the boundary.
		return orders.ReserveResult{Reserved: false}, nil
	case err != nil:
		return orders.ReserveResult{}, err
	}
	return orders.ReserveResult{Reserved: true, ConfirmationID: r.Ref}, nil
}

// Compile-time proof the adapter satisfies the port orders declared.
var _ orders.InventoryPort = inventoryAdapter{}

func main() {
	adapter := inventoryAdapter{inv: inventory.New()}
	os := orders.New(adapter) // orders receives an InventoryPort, not a *inventory.Service

	for _, tc := range []struct {
		sku string
		qty int
	}{
		{"widget", 2}, // in stock
		{"gadget", 5}, // only 3 -> out of stock -> orders.ErrOutOfStock
	} {
		id, err := os.Place(tc.sku, tc.qty)
		if err != nil {
			fmt.Printf("place %dx %-7s -> ERROR: %v\n", tc.qty, tc.sku, err)
			continue
		}
		fmt.Printf("place %dx %-7s -> %s\n", tc.qty, tc.sku, id)
	}
}
