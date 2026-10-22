package interceptor

import (
	"context"
	"errors"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// jwtSecret reads the HS256 key from the environment; no silent fallback.
func jwtSecret() []byte { return []byte(os.Getenv("JWT_SECRET")) }

// CheckSecret fails fast at startup if JWT_SECRET is unset or shorter than
// 32 bytes (RFC 7518 §3.2: HS256 keys must be at least 256 bits).
func CheckSecret() error {
	if len(jwtSecret()) < 32 {
		return errors.New("JWT_SECRET must be set and at least 32 bytes")
	}
	return nil
}

// publicMethod reports RPCs that must work without a token: health checks
// (grpc-health-probe, ALB) and reflection (grpcurl) send no credentials.
func publicMethod(fullMethod string) bool {
	return strings.HasPrefix(fullMethod, "/grpc.health.v1.Health/") ||
		strings.HasPrefix(fullMethod, "/grpc.reflection.")
}

func UnaryAuth(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	if publicMethod(info.FullMethod) {
		return handler(ctx, req)
	}
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}
	vals := md.Get("authorization")
	if len(vals) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization header")
	}
	raw := strings.TrimPrefix(vals[0], "Bearer ")
	_, err := jwt.Parse(raw, func(t *jwt.Token) (any, error) {
		return jwtSecret(), nil
	}, jwt.WithValidMethods([]string{"HS256"}), jwt.WithExpirationRequired())
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "invalid token: %v", err)
	}
	return handler(ctx, req)
}
