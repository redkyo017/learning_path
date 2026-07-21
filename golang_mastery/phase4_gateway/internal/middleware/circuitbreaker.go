package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type cbState int

const (
	cbClosed   cbState = iota // normal: requests pass through
	cbOpen                    // tripped: requests fail fast
	cbHalfOpen                // probe: one request allowed to test recovery
)

type CircuitBreaker struct {
	mu           sync.Mutex
	state        cbState
	failures     int
	threshold    int
	resetTimeout time.Duration
	openedAt     time.Time
}

func NewCircuitBreaker(threshold int, resetTimeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{threshold: threshold, resetTimeout: resetTimeout}
}

func (cb *CircuitBreaker) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		cb.mu.Lock()
		switch cb.state {
		case cbOpen:
			if time.Since(cb.openedAt) > cb.resetTimeout {
				cb.state = cbHalfOpen
			} else {
				cb.mu.Unlock()
				c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
					"error": "service unavailable (circuit open)",
				})
				return
			}
		}
		cb.mu.Unlock()

		c.Next()

		cb.mu.Lock()
		defer cb.mu.Unlock()

		if c.Writer.Status() >= 500 {
			cb.failures++
			if cb.failures >= cb.threshold {
				cb.state = cbOpen
				cb.openedAt = time.Now()
			}
		} else {
			cb.failures = 0
			cb.state = cbClosed
		}
	}
}
