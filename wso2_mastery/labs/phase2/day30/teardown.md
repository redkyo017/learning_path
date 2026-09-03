# Teardown: Day 30

This lab runs the full Day 27 gateway stack (gateway, identity server, traffic manager, admin API).
When done, clean up all running containers.

## Full Cleanup

Navigate to the Day 27 lab directory and stop all services:

```bash
cd labs/phase2/day27
docker-compose down -v
```

This command:
- Stops all running containers (gateway, is, tm, admin)
- Removes containers
- Removes volumes (data is not persisted in dev)
- Removes networks

## Verify Cleanup

Check that all containers are stopped:

```bash
docker ps | grep wso2
# Should return no results
```

## Optional: Remove Leftover Files

If you created temporary log files or analysis files:

```bash
rm -f /tmp/gw.log
rm -f /tmp/is.log
rm -f /tmp/analysis.txt
rm -f /tmp/log4j2.properties
```

## Next Steps

**Congratulations! You've completed Phase 2 of the WSO2 Mastery path.**

### Phase 2 Completion Checklist

- [x] Days 16–20: HTTPS, certificates, JWT fundamentals
- [x] Days 21–23: IS-GW integration, JWKS, key management
- [x] Days 24–26: JWT validation, subscriptions, throttling
- [x] Day 27: Distributed throttling with Traffic Manager
- [x] Days 28–30: Debug logging, log patterns, playbook diagnostics

### What You Can Now Do

1. **Deploy a production-grade API gateway** with JWT validation
2. **Debug 401/403/429 errors** using logs and the playbook
3. **Handle multi-replica deployments** with distributed throttling
4. **Diagnose incidents** in < 3 minutes
5. **Monitor and troubleshoot** in ECS Fargate with CloudWatch Logs

### Phase 3 (Future)

Phase 3 will cover:
- Multi-region deployments and failover
- Advanced monitoring, metrics, and alerting
- Disaster recovery and backup strategies
- Custom policies and request transformation
- Real-world incident case studies

