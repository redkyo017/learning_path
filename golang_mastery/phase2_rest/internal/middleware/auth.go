package middleware

import (
	"errors"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// jwtSecret reads the HS256 key from the environment. There is deliberately
// no fallback: a silent default secret is a production incident waiting to happen.
func jwtSecret() []byte { return []byte(os.Getenv("JWT_SECRET")) }

// CheckSecret fails fast at startup if JWT_SECRET is unset or shorter than
// 32 bytes (RFC 7518 §3.2: HS256 keys must be at least 256 bits).
func CheckSecret() error {
	if len(jwtSecret()) < 32 {
		return errors.New("JWT_SECRET must be set and at least 32 bytes")
	}
	return nil
}

type Claims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken creates a signed JWT for the given userID (used in tests).
func GenerateToken(userID string) (string, error) {
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret())
}

// Auth validates the Bearer token in Authorization header and attaches
// the userID to the Gin context under the key "userID".
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
			return
		}
		raw := strings.TrimPrefix(header, "Bearer ")
		var claims Claims
		// WithValidMethods pins the algorithm: a token signed with any other
		// alg (algorithm-confusion attack) is rejected before the key is used.
		token, err := jwt.ParseWithClaims(raw, &claims, func(t *jwt.Token) (any, error) {
			return jwtSecret(), nil
		}, jwt.WithValidMethods([]string{"HS256"}), jwt.WithExpirationRequired())
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}
		c.Set("userID", claims.UserID)
		c.Next()
	}
}
