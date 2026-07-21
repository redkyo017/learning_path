package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type clientLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// RateLimit limits each client IP to rps requests per second with burst b.
// Clients not seen for 3 minutes are evicted from memory.
func RateLimit(rps float64, burst int) gin.HandlerFunc {
	clients := make(map[string]*clientLimiter)
	var mu sync.Mutex

	// Background cleanup goroutine
	go func() {
		for range time.Tick(time.Minute) {
			mu.Lock()
			for ip, cl := range clients {
				if time.Since(cl.lastSeen) > 3*time.Minute {
					delete(clients, ip)
				}
			}
			mu.Unlock()
		}
	}()

	return func(c *gin.Context) {
		ip := c.ClientIP()
		mu.Lock()
		cl, ok := clients[ip]
		if !ok {
			cl = &clientLimiter{limiter: rate.NewLimiter(rate.Limit(rps), burst)}
			clients[ip] = cl
		}
		cl.lastSeen = time.Now()
		lim := cl.limiter
		mu.Unlock()

		if !lim.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
			})
			return
		}
		c.Next()
	}
}
