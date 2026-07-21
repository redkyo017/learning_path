package interceptor

import (
	"context"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/status"
)

var (
	grpcRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "grpc_requests_total",
		Help: "Total gRPC requests by method and code.",
	}, []string{"method", "code"})

	grpcDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "grpc_duration_seconds",
		Help:    "gRPC request duration.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method"})
)

func UnaryMetrics(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	st, _ := status.FromError(err)
	grpcRequests.WithLabelValues(info.FullMethod, st.Code().String()).Inc()
	grpcDuration.WithLabelValues(info.FullMethod).Observe(time.Since(start).Seconds())
	return resp, err
}
