# Lab: Day 25 — Teardown

## No Containers to Clean Up

This is a **source-reading lab** — no containers were created, no code was written, and no resources were deployed.

## Cleanup Steps

1. **Close your editor** — Exit your IDE or text editor
2. **Review your findings** — Take note of the reference answers for:
   - ThrottleHandler architecture (local bucket + TM coordination)
   - GlobalThrottleEngineClient HTTP endpoint and payload structure
   - Throttle event fields and tier mapping
   - Request flow for allowed vs. throttled requests
   - Fallback behavior when TM is unavailable

## What's Left Behind

- Notes or files you created while exploring the source code (optional cleanup)
- No running services to stop
- No Docker containers to remove
- No database state to reset

---

## Next Steps

Proceed to **Day 26**: Implement the token-bucket algorithm in Go and integrate throttle middleware.

Compare your findings from this day with the Go implementation to verify your understanding:
- How does the token bucket algorithm work in code?
- How is the TM endpoint configured in Go?
- How does error handling mirror the Java fallback strategy?
