module grpclab

go 1.22

// Versions are pinned for reproducibility; run `go mod tidy` after `buf generate`
// to populate go.sum and reconcile transitive deps.
require (
	google.golang.org/grpc v1.64.0
	google.golang.org/protobuf v1.34.2
)
