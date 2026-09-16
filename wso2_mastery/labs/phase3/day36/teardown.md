# Day 36 — Teardown

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

No containers or persistent state were created on Day 36.

**No additional cleanup needed.**

The in-memory store is reset when the server restarts. All subscriptions, applications, and API registrations are ephemeral.

## Summary: What You Built

Over Days 34–36, you've built a complete subscription management system:

1. **Day 34:** Learned the WSO2 subscription data model from source code
2. **Day 35:** Implemented the Application and Subscription store with two-map indexing
3. **Day 36:** Added the validate endpoint that the Gateway calls for verification

The resulting system can:
- Register applications with cryptographically random keys
- Map applications to APIs (subscriptions) with tiers
- Validate subscriptions in O(1) time (for both index lookups)
- Return structured 200 responses (never 404) so the GW can distinguish network errors from invalid subscriptions

## Next Steps

Day 37 will integrate this store with the event bus, so when subscriptions change, the Gateway is notified and can invalidate its cache. This completes the real-time subscription management loop.

## Architecture Summary

```
Developer
  ↓ (registers app & subscribes)
CP Subscription Store (Day 36)
  ↓ (validates subscription)
Gateway
  ↓ (evaluates access based on validation response)
Backend Service
```

The validate endpoint is the critical link. Every request that requires authorization flows through it (or through the GW's cache of previous validations).
