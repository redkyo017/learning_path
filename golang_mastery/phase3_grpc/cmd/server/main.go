package main

import (
	"context"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/reflection"

	taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
	"github.com/yourname/golang-mastery/phase3-grpc/internal/interceptor"
	"github.com/yourname/golang-mastery/phase3-grpc/internal/server"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		slog.Error("listen", "err", err)
		os.Exit(1)
	}

	s := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			interceptor.UnaryMetrics,
			interceptor.UnaryLogger,
			interceptor.UnaryAuth,
		),
		grpc.ChainStreamInterceptor(interceptor.StreamLogger),
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionIdle: 15 * time.Second,
			Time:              5 * time.Second,
			Timeout:           1 * time.Second,
		}),
	)

	taskv1.RegisterTaskServiceServer(s, server.NewTaskServer())

	// Health check (required by ECS and grpc-health-probe)
	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("task.v1.TaskService", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(s, healthSrv)

	// Reflection (enables grpcurl without proto files)
	reflection.Register(s)

	// Metrics HTTP server on separate port
	metricsSrv := &http.Server{
		Addr:    ":9090",
		Handler: promhttp.Handler(),
	}
	go func() {
		slog.Info("metrics listening", "addr", metricsSrv.Addr)
		if err := metricsSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("metrics", "err", err)
		}
	}()

	go func() {
		slog.Info("gRPC listening", "addr", lis.Addr())
		if err := s.Serve(lis); err != nil {
			slog.Error("serve", "err", err)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	<-ctx.Done()
	stop()

	slog.Info("shutting down")
	s.GracefulStop()
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	metricsSrv.Shutdown(shutCtx)
	slog.Info("stopped")
}
