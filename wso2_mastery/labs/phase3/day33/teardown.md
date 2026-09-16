# Day 33 — Teardown

## Stopping the Server

If the server is still running, stop it by:

1. **In the terminal where it's running:** Press `Ctrl+C`

You should see output like:
```
^C
```

The server will shut down gracefully. No data to persist (it's all in memory).

## Cleanup

Since this is a standalone Go program with no external dependencies or containers:

- No database to clean up
- No environment variables to reset
- No temporary files to remove
- No event bus or message queue to shut down

The program is fully self-contained. Once you stop it, everything is cleaned up.

## Summary of Day 33

You've now built:

1. **API Registry** with full CRUD operations
2. **Lifecycle State Machine** (CREATED → PUBLISHED → DEPRECATED → RETIRED)
3. **Business Rule Enforcement** (no publishing without tiers, no tier changes while PUBLISHED)
4. **Subscription Tier Management** (`GET /policies`, `PUT /tiers`)
5. **Tier Description Lookup** (simulating the database tier definitions)

The server implements the Control Plane side of the API lifecycle and tier management system. On the Gateway side (not built in this task), the implementation would:

- Subscribe to lifecycle and tier update events
- Maintain a cache of active API routes and their allowed subscription tiers
- Validate incoming subscription requests against the tier restrictions
- Keep its local state in sync with the CP via event notifications

---

## Next Steps

When you're ready for Day 34, you'll add event publishing to this server, so the Gateway can receive real-time notifications of API changes and keep its route table synchronized with the CP.

**Tip:** This code is production-grade in structure, though simplified for learning. Real WSO2:
- Uses a database instead of an in-memory map
- Publishes events to a message broker (Kafka, RabbitMQ, or WSO2 Event Broker)
- Runs as a cluster with distributed coordination (Zookeeper/etcd)
- Includes audit logging, metrics, and rate limiting
- Has extensive error handling and recovery logic

But the core patterns you've learned here are the same in production.
