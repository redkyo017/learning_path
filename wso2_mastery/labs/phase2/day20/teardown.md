# Teardown: Day 20

## Stopping the Gateway

### If Running in Foreground

```bash
Ctrl+C
```

You should see:

```
shutdown signal received
gateway shutdown complete
```

Both the gateway and mock backend shut down gracefully.

### If Running in Background

If you started the gateway in the background:

```bash
# Find the process
ps aux | grep "go run main.go"

# Kill it (replace PID with the process ID)
kill <PID>

# Or, more forcefully:
killall -9 go
```

## Cleaning Up

### Go Module Files

If you want to remove the Go build artifacts:

```bash
rm -f go.mod go.sum
rm -rf go.work.sum
```

### Test Tokens

If you saved tokens for testing:

```bash
rm -f token.txt *.jwt
```

### Logs

Go programs don't typically produce persistent logs unless redirected. If you redirected output:

```bash
rm -f gateway.log
```

## Verification

Verify the gateway is stopped:

```bash
curl http://localhost:9090/health
# Should fail with "connection refused"
```

Verify the mock backend is stopped:

```bash
curl http://localhost:8080/mock
# Should fail with "connection refused"
```

## Next Steps

When ready, proceed to Day 21 to integrate JWT validation into the complete gateway with
additional features like subscription extraction and analytics.

