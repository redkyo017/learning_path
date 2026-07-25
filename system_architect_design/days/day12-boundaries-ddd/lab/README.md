# Day 12 Lab — enforce a bounded-context boundary in Go

**Goal:** take two concerns that could be tangled (`orders` and `inventory`) and
wire them so they communicate **only through an interface + DTOs**, with a
**runnable compile-time boundary test**. Then deliberately reach across the
boundary two ways and see exactly what the language does and does not prevent.

This is a **design-heavy** day: the code is small on purpose. The real work is the
context map (`context-map-worksheet.md`) and internalizing *why* the boundary is
built this way. Pure stdlib — builds and tests **offline**.

## Layout

```
orders/           consumer context: declares InventoryPort + its own DTOs; NO import of inventory
inventory/        supplier context: public Service in its own language
  internal/store/ inventory's guts — compiler forbids orders from importing this
cmd/demo/         composition root: an Anti-Corruption adapter wires the two
break-it/         two leak demos (rename .go.txt -> .go to run them)
```

## 1. Build, test, run

```bash
go build ./...        # compiles (cmd/demo + packages)
go test ./...         # orders boundary tests pass
go run ./cmd/demo     # places two orders through the boundary
```

Expected `go run ./cmd/demo` output:
```
place 2x widget  -> order-RSV-widget-0001
place 5x gadget  -> ERROR: orders: item not available
```
`orders` produced an order id and an out-of-stock error **without importing
`inventory`** — it only ever saw its own `InventoryPort` + DTOs. The `cmd/demo`
adapter did the translation (the Anti-Corruption Layer).

## 2. The compile-time boundary test (the deliverable)

The boundary is only real if it's *checked*. This is the check:

```bash
go list -deps lab/boundaries/orders | grep inventory   # prints NOTHING == boundary holds
```

`orders` has zero dependency on `inventory`, so the grep is empty. Put this in CI:
the day someone makes `orders` import `inventory`, the grep matches and the build
fails. (The `var _ orders.InventoryPort = ...` assertions in `orders_test.go` and
`cmd/demo/main.go` are the other half: they prove implementations satisfy the port
at compile time.)

Record the empty grep result in `results.md`.

## 3. BREAK IT — reach across the boundary

Follow `break-it/README.md`. Two experiments:

- **Part A (public reach):** rename `break-it/reach_public.go.txt` → `.go`,
  `go build ./...` → **it compiles**. Nothing stops you coupling to inventory's
  public `Reservation` type. This is the plan's point: *without discipline,
  nothing stops the leak.*
- **Part B (internal reach):** rename `orders/reach_internal.go.txt` → `.go`,
  `go build ./...` → **it fails** (`use of internal package ... not allowed`).
  `internal/` is the one compiler-enforced mechanism.

Rename both back to `.go.txt`. Record what happened in `results.md`, and the
discussion: **how would a network boundary (Day 13) have made the Part-A leak
impossible, and what does that cost?**

## 4. (Optional) TODO for you — add a second boundary

Add a `payments` context (its own package + DTOs) and have `orders` reserve
inventory *and* authorize payment through a second consumer-defined port. Keep the
`go list -deps ... | grep 'inventory\|payments'` check green. This is the "one
insight to implement yourself" — everything above already runs.
