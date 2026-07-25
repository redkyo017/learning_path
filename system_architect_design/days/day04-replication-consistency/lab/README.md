# Day 4 lab — replication lag → stale reads → read-your-writes fix

**Goal:** run a Postgres primary + streaming replica, induce replication lag, and
*observe* a stale read (a read-your-writes violation), then fix it by routing the
read to the primary. Copy-pasteable throughout.

Prereqs: Docker running. Go 1.22+ only if you run the optional `lagcheck` tool.
All commands run **from the `labs/` directory**.

---

## 0. Set up a shorthand for the layered compose

```bash
cd labs
export COMPOSE="docker compose -f docker-compose.yml -f ../days/day04-replication-consistency/lab/docker-compose.override.yml"
```

## 1. Bring up primary + replica

```bash
$COMPOSE up -d postgres postgres-replica
$COMPOSE ps                       # both should be running; replica may take ~10s to base-backup
$COMPOSE logs postgres-replica    # look for "base backup from primary" then a normal startup
```

Apply the schema **to the primary** (the replica gets it via WAL):

```bash
$COMPOSE exec -T postgres psql -U postgres -d app < ../days/day04-replication-consistency/lab/schema.sql
```

## 2. Verify replication is actually streaming

```bash
# On the PRIMARY: exactly one connected standby, streaming, async.
$COMPOSE exec postgres psql -U postgres -d app -c \
  "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
# expect: state=streaming, sync_state=async

# On the REPLICA: it is in recovery (read-only standby).
$COMPOSE exec postgres-replica psql -U postgres -d app -c "SELECT pg_is_in_recovery();"
# expect: t

# Seed rows already replicated?
$COMPOSE exec postgres-replica psql -U postgres -d app -c "SELECT count(*) FROM links;"
# expect: 2
```

## 3. Baseline — a fresh write usually appears on the replica fast

```bash
$COMPOSE exec postgres psql -U postgres -d app -c \
  "INSERT INTO links(short_code,long_url) VALUES ('base1','https://base');"

# Immediately read the replica:
$COMPOSE exec postgres-replica psql -U postgres -d app -c \
  "SELECT short_code FROM links WHERE short_code='base1';"
# Usually 1 row — lag is sub-millisecond when idle. That's the trap:
# it "works on my machine" until the replica falls behind.
```

Quantify the lag anytime (run on the **replica**):

```bash
$COMPOSE exec postgres-replica psql -U postgres -d app -c \
  "SELECT now() - pg_last_xact_replay_timestamp() AS replica_lag;"
```

Optional, precise: measure the lag *window in milliseconds* with the Go tool.

```bash
cd ../days/day04-replication-consistency/lab/lagcheck
go mod tidy
go run .          # writes to :5432, polls :5433 until visible; prints the window
cd -              # back to labs/
```

## 4. BREAK IT (the core) — induce lag and catch a stale read

Freeze the replica by **pausing WAL replay** — the cleanest, most deterministic
way to force lag (it simulates a replica that has fallen arbitrarily far behind):

```bash
# (a) Pause replay on the REPLICA:
$COMPOSE exec postgres-replica psql -U postgres -d app -c "SELECT pg_wal_replay_pause();"

# (b) Write to the PRIMARY:
$COMPOSE exec postgres psql -U postgres -d app -c \
  "INSERT INTO links(short_code,long_url) VALUES ('fresh1','https://just-created');"

# (c) The creator immediately reads their new link — but from the REPLICA:
$COMPOSE exec postgres-replica psql -U postgres -d app -c \
  "SELECT short_code,long_url FROM links WHERE short_code='fresh1';"
#   -> 0 ROWS.  <-- STALE READ. The write succeeded, but this reader can't see it.
#      This is a read-your-writes VIOLATION: the user who just created the link
#      is told it doesn't exist.

# (d) Prove the write is really committed — read the PRIMARY:
$COMPOSE exec postgres psql -U postgres -d app -c \
  "SELECT short_code FROM links WHERE short_code='fresh1';"
#   -> 1 row. The data is safe; only the replica is behind.
```

Optional Go reproduction of the same violation (run while replay is paused):

```bash
cd ../days/day04-replication-consistency/lab/lagcheck
go run . -timeout 3s      # prints "STALE READ ... read-your-writes VIOLATED"
cd -
```

## 5. FIX IT — route the read-your-writes path to the primary

The redirect path can keep reading the replica (staleness is fine). The
*creator's* read of their *own* link must go to the **primary**:

```bash
# Same read, but against the PRIMARY (port 5432 inside the container network):
$COMPOSE exec postgres psql -U postgres -d app -c \
  "SELECT short_code,long_url FROM links WHERE short_code='fresh1';"
#   -> 1 row. Read-your-writes restored by routing THIS read to the primary.
```

With the Go tool, the fix is literally pointing the read at the primary:

```bash
cd ../days/day04-replication-consistency/lab/lagcheck
go run . -replica "host=localhost port=5432 user=postgres password=pass dbname=app sslmode=disable"
cd -
```

Now resume replication and watch the replica catch up:

```bash
$COMPOSE exec postgres-replica psql -U postgres -d app -c "SELECT pg_wal_replay_resume();"
$COMPOSE exec postgres-replica psql -U postgres -d app -c \
  "SELECT short_code FROM links WHERE short_code='fresh1';"   # -> 1 row now
```

Record the lag window, the stale-read observation, and the fix in `results.md`.

## 6. (Optional) alternative lag inducer — Toxiproxy latency

Instead of pausing replay, you can add real network latency to the replica's
link to the primary. Bring up Toxiproxy (`--profile fault`), create a proxy in
front of the primary's 5432, point the replica's `primary_conninfo` at it, and
add a `latency` toxic (e.g. 3000 ms). This produces a *continuous* lag rather
than a hard freeze — closer to what you see under a congested network. See
`labs/README.md` for the Toxiproxy REST recipe.

## 7. TEARDOWN (mandatory)

```bash
$COMPOSE down -v      # from labs/ — removes containers AND volumes
```

---

## What you should have observed

- With replay running, the lag window is **sub-millisecond to a few ms** — which
  is exactly why stale-read bugs hide in dev and bite in production under load.
- With replay paused (lag → ∞), a read of the just-written row from the replica
  returns **0 rows** while the primary returns the row: a concrete
  read-your-writes violation.
- Routing that one read to the primary fixes it **without** moving the whole
  read-heavy redirect load off the replicas.

See `../../../content/day04.md` (Exercise 4) for the production-grade version:
LSN tokens that let *most* reads stay on the replica and only fall back to the
primary when the chosen replica hasn't caught up past the user's write.
