# Teardown — Lab Day 18

Press `Ctrl+C` in the terminal running `go run main.go`.

The process handles `os.Interrupt` (SIGINT from Ctrl+C) and triggers graceful shutdown:

1. Gateway server (`srv.Shutdown`) drains in-flight requests — up to 5 seconds.
2. Mock backend server (`backendSrv.Shutdown`) drains in-flight requests — same 5-second context.
3. Process exits cleanly.

Expected log:
```
INFO shutdown signal received
INFO shutdown complete
```

No containers, databases, or external processes were started. Nothing else to stop.
