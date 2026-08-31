# Day 13 Lab — Teardown

## Nothing to stop

Day 13 is a source-reading lab.  No services were started.

If you temporarily enabled DEBUG logging in a running IS container, restore INFO:

1. Edit `repository/conf/log4j2.properties` and change each new logger's level back to INFO.
2. Save the file.  IS hot-reloads within 30 seconds.
3. Verify:

```bash
docker logs <is-container> 2>&1 | grep DEBUG | wc -l
# Should drop to near zero within 30 seconds
```

No Docker containers to stop.  No files to delete.
