# Day 43 Lab: Teardown

## Stop and Remove Containers

To stop all running services and remove containers:

```bash
docker compose down
```

This command:
- Stops all containers (is, cp, gw, backend).
- Removes containers.
- Keeps images on disk (for faster rebuild next time).

**Output:**
```
Container day43-gw-1       Stopped
Container day43-cp-1       Stopped
Container day43-is-1       Stopped
Container day43-backend-1  Stopped
Removing day43-gw-1 ...
Removing day43-cp-1 ...
Removing day43-is-1 ...
Removing day43-backend-1 ...
...done
```

## Remove Images (Optional)

If you want to free up disk space or rebuild from scratch:

```bash
docker rmi wso2-is-go:local wso2-cp-go:local wso2-gw-go:local
```

Or remove all unused images:

```bash
docker image prune -a
```

## Clean Build Cache (Optional)

To force a full rebuild (not using cached layers):

```bash
docker compose down
docker system prune -a --volumes
docker compose up --build
```

**Warning:** This removes all unused Docker images and volumes. Be careful if you have other containers/projects.

## Verify Cleanup

```bash
docker compose ps  # Should show "No containers"
docker ps          # All day43-* containers should be gone
```

