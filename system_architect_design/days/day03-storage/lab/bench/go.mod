module lab/bench

go 1.22

// `go mod tidy` resolves these and writes go.sum. Both are widely-cached modules.
require (
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.5.1
)
