# Day 8 lab results

## Environment
- Machine / CPU:
- Go / Postgres versions:
- Date:

## Idempotency — 100× the same key, concurrently

| Run | guard | created (201) | replayed (200) | DB rows for key |
|-----|-------|---------------|----------------|-----------------|
| guard ON  | UNIQUE + ON CONFLICT | | | (expect 1) |
| guard OFF (break-it) | dropped | | | (expect ~100) |

- Why exactly one under concurrency (in my own words):
- What the break-it proves about "retry without a key":

## Backoff: fixed vs full jitter (flaky provider, fail=0.5)

| Strategy | N requests | provider_calls | provider_failed | wall-clock |
|----------|-----------|----------------|-----------------|------------|
| fixed    |
| jitter   |

- Observed difference in load *shape* (synchronized bursts vs spread):
- Which finished faster / hit the provider less, and why:
- Timeout-driven retries: what changed when I added / removed the 2500ms toxic:

## Takeaways
- The ambiguous timeout: what I'd actually do (retry-same-key vs reconcile):
- When I would NOT retry at all:
- Retry amplification: where it would bite in this setup:
