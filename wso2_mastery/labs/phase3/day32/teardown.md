# Day 32 — Teardown

## Stopping the Server

If the server is still running, stop it by:

1. **In the terminal where it's running:** Press `Ctrl+C`

You should see output like:
```
^C
```

The server will shut down gracefully. No data to persist (it's all in memory).

## Cleanup

Since this is a standalone Go program with no external dependencies or containers:

- No database to clean up
- No environment variables to reset
- No temporary files to remove

The program is fully self-contained. Once you stop it, everything is cleaned up.

## Next Lab

When you're ready for Day 33, navigate to the `day33` directory and repeat the same process. The Day 33 server extends Day 32 with tier and policy management.

---

**Tip:** If you want to experiment further with the Day 32 server, you can:
- Modify the `main.go` file to add new endpoints or validation rules
- Rebuild with `go run main.go`
- Test your changes with curl

This is a great way to practice Go HTTP programming and concurrent data structures!
