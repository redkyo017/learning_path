# Day 38 — Teardown

## What Was Built

A standalone EventBus demo (`main.go`) that demonstrates:

- Non-blocking publish operation
- Type-specific subscribers (receive only their event type)
- All-events subscribers (receive all event types)
- Buffered channels for async event handling

## Cleanup

Stop the running process:

```bash
Ctrl+C
```

(The demo runs to completion, so there's typically nothing to stop explicitly.)

### No Containers

This lab runs entirely in Go; no Docker containers or external services.

### No Persistent State

The demo is in-memory; no files are written or databases used. You can safely delete the lab directory if needed.

### Optional: Clean Build Artifacts

```bash
go clean
```

This removes the compiled binary (if any).

---

## Next

Move on to Day 39: Unified Control Plane (API Registry + Subscriptions + Event Bus + SSE).

The day39 lab will integrate this EventBus into a full HTTP server with:
- All Day 33 (API Registry) endpoints
- All Day 35/36 (Subscription Store) endpoints
- New `GET /events` (SSE endpoint)
- New `GET /admin/sync` (snapshot endpoint)

The server runs on `:8082` and is the single source of truth for the system.
