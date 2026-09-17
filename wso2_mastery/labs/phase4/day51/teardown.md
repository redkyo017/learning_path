# Day 51 — Teardown

To stop the server:

1. In the terminal where `go run main.go` is running, press **Ctrl+C**

```
^C
```

Expected output:
```
^C
```

The server will shut down and return to the shell prompt.

## Optional: Clean up compiled binary

If you ran `go build`:

```bash
rm -f day51  # or day51.exe on Windows
```

## Next steps

- Review the exercises in SOLUTION.md
- Modify `main.go` to add the JWTBearerGrant handler
- Test the unsupported grant type error
- Compare the dispatch pattern to the WSO2 OAuthGrantHandler interface from Day 49
