package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type tokenBucket struct {
	mu       sync.Mutex
	tokens   float64
	max      float64
	rate     float64 // tokens per second
	lastFill time.Time
}

func (b *tokenBucket) allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	now := time.Now()
	elapsed := now.Sub(b.lastFill).Seconds()
	b.tokens = min(b.max, b.tokens+elapsed*b.rate)
	b.lastFill = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// RateLimit limits each client IP to maxRPS requests per second.
func RateLimit(maxRPS float64) gin.HandlerFunc {
	buckets := make(map[string]*tokenBucket)
	var mu sync.Mutex

	return func(c *gin.Context) {
		ip := c.ClientIP()
		mu.Lock()
		b, ok := buckets[ip]
		if !ok {
			b = &tokenBucket{tokens: maxRPS, max: maxRPS, rate: maxRPS, lastFill: time.Now()}
			buckets[ip] = b
		}
		mu.Unlock()

		if !b.allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
			return
		}
		c.Next()
	}
}
