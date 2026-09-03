# Teardown: Day 21

## Stopping Docker Compose

If you ran the lab with Docker Compose:

```bash
# In the labs/phase2/day21 directory where docker-compose.yml is located
docker-compose down
```

Expected output:

```
Stopping wso2-gateway ... done
Stopping wso2-km      ... done
Removing wso2-gateway ... done
Removing wso2-km      ... done
Removing network day21_default ... done
```

This stops and removes:
- The gateway container
- The Key Manager container
- The Docker network

### Cleaning Up Images

To remove the Docker images (optional):

```bash
docker rmi wso2-gateway wso2-km
# or
docker image prune  # removes all dangling images
```

## Stopping Local Go Execution

If you ran the services locally (not docker-compose):

### Terminal 1 (KM)

```bash
Ctrl+C
# Expected: graceful shutdown
```

### Terminal 2 (Gateway)

```bash
Ctrl+C
# Expected:
# shutdown signal received
# shutdown complete
```

Both services gracefully shut down active connections before exiting.

## Cleanup

### Remove Go Module Files

If you created `go.mod` and `go.sum`:

```bash
rm -f go.mod go.sum
rm -rf go.work.sum
```

### Remove Test Artifacts

If you saved tokens or logs:

```bash
rm -f token.txt *.jwt *.log
```

### Remove Docker Artifacts

If you built Docker images:

```bash
# List all images
docker images | grep wso2

# Remove specific images
docker rmi wso2-gateway:latest wso2-km:latest

# Or clean everything
docker system prune --all
```

## Verification

Verify both services are stopped:

```bash
# Try to connect to gateway (should fail)
curl http://localhost:9090/health
# Expected: curl: (7) Failed to connect to localhost port 9090

# Try to connect to KM (should fail)
curl http://localhost:8888/oauth2/jwks
# Expected: curl: (7) Failed to connect to localhost port 8888
```

## Next Steps

You have completed the JWT validation section (Days 19–21). The next task will add:
- **Day 22–24**: Throttling middleware based on subscription tier
- **Day 25–27**: Analytics/metering collection
- **Day 28**: Full end-to-end testing with realistic loads

The gateway skeleton is ready for these enhancements. All validation components (recovery,
request ID, logging, JWT) will remain in the middleware chain as later features are added.

