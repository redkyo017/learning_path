package interceptor

import (
	"context"
	"log/slog"
	"time"

	"google.golang.org/grpc"
)

func UnaryLogger(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	slog.Info("grpc",
		"method", info.FullMethod,
		"latency_ms", time.Since(start).Milliseconds(),
		"err", err,
	)
	return resp, err
}

// StreamLogger logs each streaming RPC after it completes (added Day 14).
func StreamLogger(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	start := time.Now()
	err := handler(srv, ss)
	slog.Info("grpc-stream",
		"method", info.FullMethod,
		"latency_ms", time.Since(start).Milliseconds(),
		"err", err,
	)
	return err
}
