module lab/shortener

go 1.22

// Run `go mod tidy` once to resolve this (writes go.sum). Offline? If the module
// cache lacks lib/pq, swap to the Go stdlib-only fallback described in ../README.md.
require github.com/lib/pq v1.10.9
