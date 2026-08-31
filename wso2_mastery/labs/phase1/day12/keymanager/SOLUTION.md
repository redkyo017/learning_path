# Day 12 Solution — PORT env var wiring

## The Exercise

Day 12 introduces configurable port via environment variable.  The pattern
in `main()` is:

```go
port := os.Getenv("PORT")
if port == "" {
    port = "9444"
}
addr := ":" + port
```

This is already implemented in `main.go` — it is not left as a TODO here
because the Day 12 exercise focuses on observing Docker behaviour, not writing
the wiring.  The wiring is shown so you can read it and understand it.

## Why os.Getenv + fallback?

`os.Getenv("PORT")` returns `""` when the variable is not set.  The `if`
guard provides a sensible default so the binary runs in development without
any configuration.

In Docker the `environment:` block in `docker-compose.yml` injects `PORT=9444`
into the container process, so the binary reads `"9444"` from the environment.

## Complete main() with PORT wiring

```go
func main() {
    slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

    port := os.Getenv("PORT")
    if port == "" {
        port = "9444"
    }
    addr := ":" + port

    slog.Info("server_starting", "addr", addr, "day", 12)

    mux := http.NewServeMux()
    // ... route registrations ...
    handler := correlationMiddleware(mux)

    if err := http.ListenAndServe(addr, handler); err != nil {
        slog.Error("server_failed", "err", err)
        os.Exit(1)
    }
}
```

## Verification

```bash
# Default port
go run main.go &
curl http://localhost:9444/health   # {"status":"UP"}
kill %1

# Override port
PORT=8080 go run main.go &
curl http://localhost:8080/health   # {"status":"UP"}
kill %1
```

## Docker Compose exercise answers

**Q: How does the container know which port to use?**

The `environment: - PORT=9444` entry in `docker-compose.yml` sets the `PORT`
variable in the container's process environment.  `os.Getenv("PORT")` reads it.

**Q: What would happen if you removed the `PORT` environment entry from docker-compose.yml?**

`os.Getenv("PORT")` returns `""`.  The fallback `if port == "" { port = "9444" }`
kicks in.  The server still listens on `:9444` — the explicit env entry is
redundant with the default, but it makes the port visible in the compose file.

**Q: How would you run the container on port 8080?**

Change `docker-compose.yml`:

```yaml
services:
  keymanager:
    build: .
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
```

Both the container port mapping and the `PORT` env var must match.
