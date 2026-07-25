# Break-it — reach across the boundary

Two demonstrations of what does and doesn't stop cross-context coupling in a
single Go binary. Files are `.go.txt` so the normal `go build ./...` ignores them.

## Part A — a PUBLIC reach compiles (discipline is all that stops you)

```bash
mv reach_public.go.txt reach_public.go
go build ./...        # SUCCEEDS — nothing prevents coupling to inventory's public type
mv reach_public.go reach_public.go.txt   # restore
```

Observe: importing `inventory` and using `Reservation.Ref` compiles cleanly. For
exported symbols, Go does **not** enforce the boundary — only your discipline
(port + DTOs) and the check `go list -deps lab/boundaries/orders | grep inventory`
keep it honest.

## Part B — an INTERNAL reach does NOT compile (the compiler stops you)

```bash
mv ../orders/reach_internal.go.txt ../orders/reach_internal.go
go build ./...        # FAILS: use of internal package ... not allowed
mv ../orders/reach_internal.go ../orders/reach_internal.go.txt   # restore
```

Observe: putting inventory's guts under `internal/` makes the boundary
**compiler-enforced** — orders physically cannot import them.

## The takeaway to journal

In-process, only `internal/` is enforced by the compiler; exported symbols rely on
convention (interfaces + DTOs + a dependency check in CI). A **network boundary**
(Day 13) makes the leak impossible by construction — the other side is only
reachable through its wire contract — but you pay latency, partial failure, and
serialization for that hard guarantee. That is the core boundaries tradeoff.
