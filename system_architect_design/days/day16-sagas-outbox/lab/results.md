# Day 16 lab results

Date: ____  Stack: postgres + kafka (shared `labs/`)

## Part 1 — outbox happy path

| Step | orders | outbox_unsent | outbox_sent | processed_events | widget stock |
|------|-------:|--------------:|------------:|-----------------:|-------------:|
| after place (relay down) |  |  |  |  |  |
| after relay runs         |  |  |  |  |  |

Consumer log for the placed event: `______` (expect `APPLIED`)

## Part 2 — crash BEFORE publish (prove no lost event)

| Step | outbox_unsent | Notes |
|------|--------------:|-------|
| order placed, relay down |  |  |
| after CRASH_BEFORE_PUBLISH |  | should be unchanged — event durable in DB |
| after clean relay restart |  | should drain to 0 |

Conclusion (did anything get lost? why not?): ______

## Part 3 — crash AFTER publish (prove dedupe)

- Consumer line on first publish: `______` (expect `APPLIED`)
- Consumer line after relay restart republishes: `______` (expect `DUPLICATE`)
- widget stock before test: ____  after test: ____  (should drop by qty **once**)

Conclusion (at-least-once delivery + idempotent consumer = ?): ______

## Part 4 — saga + compensation

| Command | order status | payment status |
|---------|--------------|----------------|
| `saga widget 2` |  |  |
| `saga gadget 1` |  |  |

What did the compensation undo, and what would happen if the refund call itself
failed?  ______

## Break-it summary
- What I broke: ______
- How I diagnosed it (which query/log line told me the truth): ______
- The fix / why the design already handles it: ______
