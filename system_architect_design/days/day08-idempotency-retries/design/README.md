Put your filled-in 7-step design here (see `reference/design-method.md`).
Today: the retry-safe charge flow — requirements, top-3 NFRs, ≥2 key-storage
options (same-tx Postgres vs Redis-TTL vs provider-side), tradeoff table,
decision, red-team (concurrent same-key race, crash between charge and key-store).
