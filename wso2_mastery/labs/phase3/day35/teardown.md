# Day 35 — Teardown

## Stopping the Server

If the server is running, stop it:

```bash
Ctrl+C
```

**Expected output:**
```
^C
(prompt returns)
```

## Cleanup

No containers were created on Day 35 (unlike earlier labs). The server was a standalone Go binary running on your local machine.

**No additional cleanup needed.**

If you ran into any issues or want a fresh start for Day 36:
- The in-memory store is reset when the server restarts
- No state is persisted to disk

## Next Step

Move to Day 36, where you'll extend this server with:
- The `GET /subscriptions/validate` endpoint (what the Gateway calls)
- The `POST /admin/apis` endpoint (to register API contexts)
- A third map for API context resolution
