# Day 4 lab results

Record what you measured and what you broke. Numbers, not adjectives.

## Setup
- Postgres primary (`:5432`) + async streaming replica (`:5433`)
- Lag inducer used: [ ] `pg_wal_replay_pause()`  [ ] Toxiproxy latency (___ ms)
- Date / machine: ___

## Baseline replication lag (replay running)

| Measurement | Value |
|-------------|-------|
| Lag window from `lagcheck` (write → visible on replica) | ___ ms |
| `now() - pg_last_xact_replay_timestamp()` while idle | ___ |
| `now() - pg_last_xact_replay_timestamp()` under a write burst (optional) | ___ |
| `pg_stat_replication.state` / `sync_state` | ___ / ___ |

## The stale read (break-it)

| Step | Observed |
|------|----------|
| After `pg_wal_replay_pause()`, wrote `fresh1` to primary | committed? ___ |
| Read `fresh1` from **replica** | rows returned: ___ (expect 0) |
| Read `fresh1` from **primary** | rows returned: ___ (expect 1) |
| `lagcheck -timeout 3s` output | ___ |

Read-your-writes violated? ___  |  How long did it persist? ___ (until resume)

## The fix

| Approach | Result |
|----------|--------|
| Route the creator's own-link read to the **primary** | rows: ___ (expect 1) |
| After `pg_wal_replay_resume()`, re-read replica | rows: ___ (expect 1, caught up) |

## Reflection
- What is my RPO if the primary dies at this lag and 2k writes/s? ___ (≈ lag × wps)
- Which shortener reads did I decide are replica-safe vs primary-only? ___
- Production version (LSN token) — would I need it here? Why / why not? ___
