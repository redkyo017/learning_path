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
	"github.com/yourname/golang-mastery/phase2-rest/internal/handler"
	"github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
	"github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	if err := middleware.CheckSecret(); err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}

	repo := repository.NewMemoryTaskRepository()
	h := handler.NewTaskHandler(repo)

	r := gin.New()
	// Gin trusts every proxy by default, so c.ClientIP() would honour a
	// client-supplied X-Forwarded-For and the per-IP rate limit could be
	// bypassed. Trust none here; behind a load balancer, list its CIDRs.
	r.SetTrustedProxies(nil)
	r.Use(gin.Recovery(), middleware.GinLogger(), middleware.RateLimit(100))
	r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	r.GET("/readyz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

	v1 := r.Group("/api/v1")
	v1.Use(middleware.Auth())
	v1.GET("/tasks", h.List)
	v1.POST("/tasks", h.Create)
	v1.GET("/tasks/:id", h.Get)
	v1.PATCH("/tasks/:id/complete", h.Complete)

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		slog.Info("listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("listen", "err", err)
			os.Exit(1)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	<-ctx.Done()
	stop()

	slog.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown", "err", err)
	}
	slog.Info("stopped")
}
