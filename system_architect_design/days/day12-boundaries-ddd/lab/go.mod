// Day 12 boundary-enforcement lab. Pure stdlib — builds and tests OFFLINE, no
// `go mod tidy` needed. Run from this lab/ directory:
//   go build ./...      # cmd/demo compiles
//   go test ./...       # boundary tests pass
//   go run ./cmd/demo   # wires inventory into orders across the boundary
module lab/boundaries

go 1.22
