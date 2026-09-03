# Teardown: Day 28

This lab is a source-reading exercise with no running services or changes made.

## No Cleanup Required

Since you only read the WSO2 source distribution and didn't modify any gateway configurations or start any containers, there is nothing to tear down.

## Optional: If You Made Changes

If you edited the log4j2.properties file to test the logger configuration:

```bash
# Revert changes to the original log4j2.properties
git checkout wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties

# Or manually remove the 5 logger definitions you added
```

If you started a gateway container to test DEBUG logging:

```bash
docker-compose down -v
```

## Next Steps

You're ready for Day 29: analyzing synthetic log files with the patterns you've learned.

