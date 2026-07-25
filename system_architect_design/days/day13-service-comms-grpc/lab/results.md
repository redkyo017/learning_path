# Day 13 Lab Results

## A — baseline

| Call | Response | Notes |
|------|----------|-------|
| `client -sku SKU1 -qty 3` | available=____ on_hand=____ | |
| `client -sku SKU2 -qty 1` | available=____ on_hand=____ | |
| `go test ./compat/` | PASS / FAIL: ____ | |

## B — additive change (`warehouse = 4`)

- Client call after regenerate: works? ______
- `go test ./compat/`: PASS / FAIL ______
- Why nothing broke (in your words): ______________________________________

## C — the break (renumber `quantity` 3 → 7)

- `go test ./compat/` output: `quantity = ___, want 5`
- `protoc --decode_raw` of the old bytes showed field: `___: ___`
- What an old client + new server would do in production: __________________
- The correct way to retire a field instead: ______________________________

## Takeaways

- The wire contract is the field ______ (number / name — circle one).
- Backward vs forward compatibility — why a rolling deploy needs both: ______
- `buf breaking` would have caught step C in CI because: ___________________
