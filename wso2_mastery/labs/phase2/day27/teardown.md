# Teardown: Day 27

## Stopping the Lab

### Step 1: Stop Docker Compose

Press `Ctrl+C` in the terminal where you ran `docker-compose up`:

```bash
^C
Shutting down...
```

### Step 2: Clean Up Containers and Volumes

```bash
docker-compose down -v
```

This removes:
- All containers (gateway, backend, TM, KM)
- All volumes (anonymous volumes, named volumes)
- Networks created by docker-compose

### Step 3: Verify Cleanup

```bash
docker ps -a | grep day27
# Should return no results

docker volume ls | grep day27
# Should return no results
```

## Cleanup Complete

All lab resources have been removed. Your Go source code remains in `main.go` for reference or further modification.

## Next Steps

- **Task 5**: Add gateway debug patterns (request logging, metrics, tracing).
- **Production deployment**: Replace mock TM with real WSO2 Traffic Manager and configure multi-replica coordination.
