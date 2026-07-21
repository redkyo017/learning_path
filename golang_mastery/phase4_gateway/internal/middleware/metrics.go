package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "gateway_http_requests_total",
		Help: "Total HTTP requests handled by the gateway.",
	}, []string{"method", "path", "status"})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "gateway_http_duration_seconds",
		Help:    "HTTP request duration at the gateway.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "path"})
)

func Metrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		httpRequests.WithLabelValues(
			c.Request.Method,
			c.FullPath(),
			strconv.Itoa(c.Writer.Status()),
		).Inc()
		httpDuration.WithLabelValues(
			c.Request.Method,
			c.FullPath(),
		).Observe(time.Since(start).Seconds())
	}
}
