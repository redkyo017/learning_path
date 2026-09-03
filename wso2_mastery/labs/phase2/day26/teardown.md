# Teardown: Day 26

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
- All containers (gateway, backend, KM)
- All volumes (anonymous volumes, named volumes)
- Networks created by docker-compose

### Step 3: Verify Cleanup

```bash
docker ps -a | grep day26
# Should return no results

docker volume ls | grep day26
# Should return no results
```

## Cleanup Complete

All lab resources have been removed. Your Go source code remains in `main.go` for reference or further modification.

## Next Steps

- **Day 27**: Add a mock Traffic Manager to the gateway and learn global throttling coordination.
