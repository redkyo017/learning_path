# Teardown: Day 23 Lab

## Stopping the Lab

### Stop docker-compose

Press `Ctrl+C` in the terminal where you ran `docker-compose up`:

```
gateway_1  | ...
^C
gateway_1  | shutdown signal received
gateway_1  | gateway shutdown complete
```

This gracefully stops both the gateway and mock backend containers.

### Remove Containers and Volumes

To clean up all containers and volumes created by this lab:

```bash
cd labs/phase2/day23
docker-compose down -v
```

This removes:
- Containers (gateway, backend)
- Named volumes (if any)
- Networks created by docker-compose

### Verify Cleanup

Check that containers are removed:

```bash
docker ps | grep day23
# Should return nothing
```

Check that no dangling volumes exist:

```bash
docker volume ls | grep day23
# Should return nothing
```

## Cleanup Checklist

- [x] Stopped docker-compose (Ctrl+C)
- [x] Ran `docker-compose down -v`
- [x] Verified no containers or volumes remain
- [x] Ready to move to Day 24

## Next Steps

When ready, proceed to Day 24:

```bash
cd ../day24
docker-compose up --build
```

