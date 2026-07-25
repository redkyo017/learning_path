// Package orders is the Orders bounded context.
//
// THE BOUNDARY RULE: orders talks to inventory ONLY through InventoryPort (an
// interface orders itself declares) using orders' OWN DTOs. It does NOT import
// the inventory package. Prove it after any change:
//
//	go list -deps lab/boundaries/orders | grep inventory   # must print NOTHING
//
// That command is the runnable "compile-time boundary test": if orders ever gains
// a dependency on inventory, the grep matches and you've breached the boundary.
package orders

import "errors"

// InventoryPort is the consumer-defined interface (dependency inversion): orders
// declares the shape it needs; whoever wires the app supplies an implementation.
// This is what lets orders be built, tested, and reasoned about with zero
// knowledge of the inventory package.
type InventoryPort interface {
	Reserve(req ReserveRequest) (ReserveResult, error)
}

// ReserveRequest / ReserveResult are orders' OWN DTOs — the "published language"
// of this boundary. They are deliberately NOT inventory.Reservation: no shared
// structs cross the boundary, so inventory can change its internal model freely.
type ReserveRequest struct {
	SKU string
	Qty int
}

type ReserveResult struct {
	Reserved       bool
	ConfirmationID string
}

var ErrOutOfStock = errors.New("orders: item not available")

type Service struct {
	inv InventoryPort
}

func New(inv InventoryPort) *Service { return &Service{inv: inv} }

// Place is the orders use case. All it knows about inventory is the port + DTOs.
func (s *Service) Place(sku string, qty int) (orderID string, err error) {
	res, err := s.inv.Reserve(ReserveRequest{SKU: sku, Qty: qty})
	if err != nil {
		return "", err
	}
	if !res.Reserved {
		return "", ErrOutOfStock
	}
	return "order-" + res.ConfirmationID, nil
}
