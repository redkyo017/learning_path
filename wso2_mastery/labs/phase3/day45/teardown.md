# Day 45 Lab: Teardown

## Cleanup

Day 45 is a review day. To stop all services when you're done:

```bash
# From labs/phase3/day43/
docker compose down
```

This stops and removes all containers (is, cp, gw, backend).

## Keep Images for Future Runs

Images built during the lab (`wso2-is-go:local`, `wso2-cp-go:local`, `wso2-gw-go:local`) are kept on disk. Next time you run, the build will be faster (cached layers).

If you want to clean them up:

```bash
docker rmi wso2-is-go:local wso2-cp-go:local wso2-gw-go:local
```

## Clean Everything

To free up disk space (removes all unused images and volumes):

```bash
docker system prune -a --volumes
```

**Warning:** This is destructive. Use only if you want to completely reset.

## Verify Cleanup

```bash
docker ps          # Should show no day43/day44/day45 containers
docker images | grep wso2   # Should show no wso2 images (if you ran prune)
```

