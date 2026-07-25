// Package store is the INTERNAL implementation of the inventory context.
//
// Because it lives under .../inventory/internal/, Go's compiler only lets code
// rooted at .../inventory/ import it. The `orders` package physically CANNOT
// import this — try it (see ../../../break-it/) and the build fails with
// "use of internal package ... not allowed". This is the language enforcing the
// boundary, not just convention.
package store

import "fmt"

// Store holds inventory's private state. Its shape is an implementation detail
// that no other context is allowed to know about.
type Store struct {
	stock map[string]int
	seq   int
}

func New() *Store {
	return &Store{stock: map[string]int{"widget": 10, "gadget": 3}}
}

// Take decrements stock if enough is available, returning an internal ref.
func (s *Store) Take(sku string, qty int) (ok bool, ref string) {
	if s.stock[sku] < qty {
		return false, ""
	}
	s.stock[sku] -= qty
	s.seq++
	return true, fmt.Sprintf("RSV-%s-%04d", sku, s.seq)
}
