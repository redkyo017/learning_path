# Day 12 Lab results — enforcing a boundary in code

## Build / test / run
- `go build ./...`: ______ (pass/fail)
- `go test ./...`: ______ (pass/fail)
- `go run ./cmd/demo` output:
  ```
  (paste)
  ```

## Compile-time boundary test
- `go list -deps lab/boundaries/orders | grep inventory` output: ______
  (empty == boundary holds; orders does not depend on inventory)

## Break-it
| Experiment | Command | Result | Lesson |
|------------|---------|--------|--------|
| A: reach a PUBLIC type | rename reach_public.go.txt; `go build ./...` | compiles? ___ | nothing stops coupling to exported symbols; only discipline |
| B: reach an INTERNAL package | rename orders/reach_internal.go.txt; `go build ./...` | error? ___ | `internal/` is compiler-enforced |

- How a NETWORK boundary (Day 13) would have prevented the Part-A leak: ________
- What that hard boundary costs (latency / partial failure / serialization): ___

## Context-map takeaways (from the worksheet)
- Chattiest sync boundary found: __________
- My monolith-vs-microservices decision + the one-sentence why: __________

## Takeaway
- One-line: an in-process boundary is enforced by ______ for exported symbols and
  by ______ for internal packages; distribution trades a hard boundary for ______.
