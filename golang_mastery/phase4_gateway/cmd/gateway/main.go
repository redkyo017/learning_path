package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	gw_middleware "github.com/yourname/golang-mastery/phase4-gateway/internal/middleware"
	"github.com/yourname/golang-mastery/phase4-gateway/internal/proxy"
	"github.com/yourname/golang-mastery/phase4-gateway/internal/transcoder"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	restUpstream := &proxy.Upstream{
		Name:    "rest",
		BaseURL: getEnv("REST_UPSTREAM", "http://localhost:8080"),
	}
	reg := proxy.NewRegistry(restUpstream)

	tc, err := transcoder.NewTaskTranscoder(getEnv("GRPC_UPSTREAM", "localhost:50051"))
	if err != nil {
		slog.Error("grpc client", "err", err)
		os.Exit(1)
	}

	cb := gw_middleware.NewCircuitBreaker(5, 30*time.Second)

	r := gin.New()
	r.Use(
		gin.Recovery(),
		gw_middleware.Logger(),
		gw_middleware.Metrics(),
		gw_middleware.RateLimit(100, 20),
		cb.Middleware(),
	)

	r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	r.GET("/readyz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	rest := r.Group("/api/v1")
	{
		up, _ := reg.Get("rest")
		restHandler := proxy.Handler(up)
		rest.Any("/*path", func(c *gin.Context) {
			restHandler.ServeHTTP(c.Writer, c.Request)
		})
	}

	grpcRoutes := r.Group("/grpc/v1")
	{
		grpcRoutes.GET("/tasks", tc.ListTasks)
		grpcRoutes.POST("/tasks", tc.CreateTask)
	}

	srv := &http.Server{Addr: ":9000", Handler: r}

	go func() {
		slog.Info("gateway listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("listen", "err", err)
			os.Exit(1)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	<-ctx.Done()
	stop()

	slog.Info("gateway shutting down")
	shutCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutCtx); err != nil {
		slog.Error("shutdown", "err", err)
	}
	slog.Info("gateway stopped")
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
