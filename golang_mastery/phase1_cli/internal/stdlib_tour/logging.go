package stdlib_tour

import (
	"log/slog"
	"os"
)

// NewJSONLogger creates a JSON-format slog logger at Info level.
func NewJSONLogger() *slog.Logger {
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
}

// NewTextLogger creates a human-readable logger for local dev.
func NewTextLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))
}

// LogWithAttrs demonstrates structured key-value pairs.
func LogWithAttrs(logger *slog.Logger) {
	logger.Info("request received",
		"method", "GET",
		"path", "/api/tasks",
		"remote_addr", "10.0.0.1",
	)
	logger.Warn("slow response",
		slog.Duration("latency", 1500*1000000), // 1.5s
		slog.String("path", "/api/tasks"),
	)
	logger.Error("db query failed",
		slog.String("query", "SELECT * FROM tasks"),
		slog.Any("err", ErrNotFound),
	)
}
