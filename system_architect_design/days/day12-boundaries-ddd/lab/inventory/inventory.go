// Package inventory is the Inventory bounded context. It speaks its OWN
// ubiquitous language (Reservation, ErrOutOfStock) and hides its guts in
// internal/store. It knows NOTHING about orders — no import of the orders
// package. Dependencies point inward (orders depends on an abstraction; inventory
// depends on nothing above it).
package inventory

import (
	"errors"

	"lab/boundaries/inventory/internal/store"
)

// ErrOutOfStock is inventory's domain error. Callers translate it at the boundary
// (see the adapter in cmd/demo) rather than leaking this type across contexts.
var ErrOutOfStock = errors.New("inventory: out of stock")

// Reservation is inventory's OWN aggregate-ish type. Orders must never see it —
// if orders imported this, the two contexts would be coupled to inventory's
// internal model (the god-model trap from content/day12.md).
type Reservation struct {
	SKU      string
	Quantity int
	Ref      string // internal reservation id
}

// Service is inventory's public API, expressed in inventory's language.
type Service struct {
	store *store.Store
}

func New() *Service { return &Service{store: store.New()} }

// Reserve holds stock for a SKU. Note the signature is in INVENTORY's terms,
// not in orders' terms — the translation happens in the anti-corruption adapter.
func (s *Service) Reserve(sku string, qty int) (Reservation, error) {
	ok, ref := s.store.Take(sku, qty)
	if !ok {
		return Reservation{}, ErrOutOfStock
	}
	return Reservation{SKU: sku, Quantity: qty, Ref: ref}, nil
}
