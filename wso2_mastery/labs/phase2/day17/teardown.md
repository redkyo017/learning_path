# Teardown — Lab Day 17

Press `Ctrl+C` in the terminal running `go run main.go`.

The gateway handles `os.Interrupt` (SIGINT from Ctrl+C), triggers graceful shutdown, and
exits cleanly. You should see:

```
INFO shutdown signal received
INFO shutdown complete
```

No containers, databases, or background services were started. Nothing else to stop.
