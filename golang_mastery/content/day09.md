# Day 9 — Database Integration

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Explain what `pgx` adds over `database/sql` and when to choose each
- Configure a connection pool with all four critical settings and explain what each protects against
- Implement the repository pattern with a Go interface and two implementations (real + in-memory)
- Run schema migrations with `golang-migrate` and understand why migrations belong in source control

---

## Core mental model: the repository interface is a seam

A seam is a place in code where you can substitute one behavior for another without changing the caller. In Go, interfaces are seams. The repository pattern puts a Go interface between your business logic and your database driver:

```
Handler → UserRepository (interface) → pgxRepository (real, uses pgx)
                                    → memoryRepository (test, uses map)
```

Your handlers and services call the interface. In production, the concrete type is `pgxRepository`. In tests, you swap in `memoryRepository` — it is a plain map with mutex. No Docker, no Postgres, no network. Tests run in milliseconds.

The analogy: think of the repository interface as a power outlet. Your lamp (business logic) does not know or care whether the power comes from the grid (Postgres), a generator (test double), or a battery (in-memory). It just uses the outlet. The repository interface is the outlet shape.

If you find yourself unable to test business logic without a real database, the interface boundary is missing or wrong. That is the diagnostic: testability reveals design.

---

## database/sql vs pgx

`database/sql` is Go's standard database abstraction layer. It works with any database via a driver, provides connection pooling, and has a stable API. `pgx` is a pure-Go PostgreSQL driver and toolkit that also provides its own connection pool, and it exposes PostgreSQL-specific features that `database/sql` abstracts away.

| Feature | database/sql + lib/pq | pgx (native) |
|---|---|---|
| Connection pooling | Built into database/sql | `pgxpool` — richer configuration |
| Named parameters | Not supported (positional `$1`) | Not supported either (use sqlc or pgx named args via pgconn) |
| COPY protocol (bulk insert) | Not supported | Supported via `pgx.Conn.CopyFrom` |
| PostgreSQL array types | Manual serialization | Native `pgtype` support |
| PostgreSQL JSONB | Manual | Native `pgtype.JSONB` |
| Listen/Notify | Not supported | Supported |
| Prepared statements | Supported | Supported with automatic caching |
| Batch queries | Not supported | Supported via `pgx.Batch` |
| Context cancellation | Supported | Supported, with better semantics |
| Error types | Generic `*pq.Error` | Typed `*pgconn.PgError` with code, constraint |

**When to use `database/sql`**: when you might switch databases, or when your team already uses GORM or sqlx which abstract over `database/sql`. When you need portability.

**When to use `pgx` natively**: when you are committed to PostgreSQL, need bulk inserts (COPY), need JSONB/arrays, or want finer error typing. Most new Go+Postgres services use `pgxpool` directly.

**`sqlc` is the synthesis**: generates type-safe Go from SQL queries, supports both `database/sql` and `pgx`. If you are starting fresh in 2024, the recommended stack is `pgxpool` + `sqlc`. This eliminates the ORM vs hand-written SQL debate.

---

## Connection pool configuration

A connection pool reuses database connections across requests. The critical insight: database connections are expensive to create (TLS handshake + Postgres auth = ~5ms). Pooling amortizes that cost. But a misconfigured pool is worse than no pool.

### The four settings everyone gets wrong

| Setting | What it controls | Zero value behavior | Production recommendation |
|---|---|---|---|
| `MaxOpenConns` | Maximum concurrent connections to the database | Unlimited — exhausts Postgres `max_connections` | Set to `(max_connections / number_of_app_instances) * 0.8` |
| `MaxIdleConns` | Connections kept open in the idle pool | `= MaxOpenConns` (pre-Go 1.2 had limit of 1) | `MaxOpenConns / 2` or `10` — idle connections hold server resources |
| `ConnMaxLifetime` | Maximum age of a connection before recycling | Unlimited — misses credential rotations, TCP silent drops | `30m` to `1h` — recycle before firewall idle timeouts (typically 10-20 min) |
| `ConnMaxIdleTime` | Maximum time a connection can sit idle in the pool | Unlimited — idle connections consume Postgres slots | `5m` to `10m` |

```go
// database/sql pool configuration
db, err := sql.Open("pgx", dsn)
if err != nil { ... }

db.SetMaxOpenConns(25)
db.SetMaxIdleConns(10)
db.SetConnMaxLifetime(30 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)

// Verify the connection is alive before serving traffic
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
if err := db.PingContext(ctx); err != nil { ... }
```

```go
// pgxpool configuration (richer, recommended for pgx)
config, _ := pgxpool.ParseConfig(dsn)
config.MaxConns = 25
config.MinConns = 2
config.MaxConnLifetime = 30 * time.Minute
config.MaxConnIdleTime = 5 * time.Minute
config.HealthCheckPeriod = 1 * time.Minute

pool, err := pgxpool.NewWithConfig(context.Background(), config)
```

### Why the zero value kills you in production

`MaxOpenConns = 0` means unlimited. A traffic spike spins up thousands of goroutines, each opening a new connection. Postgres has a hard `max_connections` limit (default 100). When that limit is hit, new connections fail with "FATAL: sorry, too many clients already". The service falls over completely. Without `MaxOpenConns`, your connection pool provides no back-pressure.

`ConnMaxLifetime = 0` means connections live forever. Cloud environments (RDS, Cloud SQL) rotate credentials, rotate certificates, and have firewalls that drop TCP connections silent after 10-15 minutes of inactivity. A connection that was opened 30 minutes ago may be dead — the pool does not know until the next query fails. Setting `ConnMaxLifetime` to 30 minutes ensures connections are recycled before the firewall kills them.

---

## Repository pattern

### The interface (the seam)

```go
// internal/repository/user.go
package repository

import "context"

type User struct {
    ID    int64
    Email string
    Name  string
}

type UserRepository interface {
    GetByID(ctx context.Context, id int64) (*User, error)
    Create(ctx context.Context, u *User) (*User, error)
    List(ctx context.Context) ([]*User, error)
}
```

The interface lives in its own package or sub-package. It does not import `pgx` or any database package — that keeps the interface dependency-free.

### Production implementation (pgx)

```go
// internal/repository/postgres/user.go
package postgres

import (
    "context"
    "github.com/jackc/pgx/v5/pgxpool"
    "yourapp/internal/repository"
)

type userRepo struct {
    pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) repository.UserRepository {
    return &userRepo{pool: pool}
}

func (r *userRepo) GetByID(ctx context.Context, id int64) (*repository.User, error) {
    var u repository.User
    err := r.pool.QueryRow(ctx,
        `SELECT id, email, name FROM users WHERE id = $1`, id,
    ).Scan(&u.ID, &u.Email, &u.Name)
    if err != nil {
        return nil, err  // wrap with fmt.Errorf("userRepo.GetByID: %w", err) in production
    }
    return &u, nil
}
```

### Test double (in-memory)

```go
// internal/repository/memory/user.go
package memory

import (
    "context"
    "sync"
    "yourapp/internal/repository"
)

type userRepo struct {
    mu   sync.RWMutex
    data map[int64]*repository.User
    seq  int64
}

func NewUserRepository() repository.UserRepository {
    return &userRepo{data: make(map[int64]*repository.User)}
}

func (r *userRepo) GetByID(_ context.Context, id int64) (*repository.User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    u, ok := r.data[id]
    if !ok {
        return nil, repository.ErrNotFound
    }
    return u, nil
}
```

This in-memory implementation is injected in tests. No database, no Docker, no network. Service layer tests run in sub-millisecond time.

---

## golang-migrate: schema migration workflow

Schema migrations are versioned SQL files that track how your database schema evolves over time. `golang-migrate` is the standard tool in the Go ecosystem.

### File naming convention
```
migrations/
  000001_create_users.up.sql    ← applied when migrating up
  000001_create_users.down.sql  ← applied when rolling back
  000002_add_user_role.up.sql
  000002_add_user_role.down.sql
```

### CLI workflow
```bash
# Install
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Create a new migration
migrate create -ext sql -dir migrations -seq add_user_role

# Apply all pending migrations
migrate -path migrations -database "postgres://..." up

# Roll back the last migration
migrate -path migrations -database "postgres://..." down 1

# Check current version
migrate -path migrations -database "postgres://..." version
```

### Embedded migrations (run at startup)

Embedding migrations in the binary and running them at startup is the modern Go pattern — no external tool needed in production:

```go
import (
    "embed"
    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/source/iofs"
    _ "github.com/golang-migrate/migrate/v4/database/postgres"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func runMigrations(dsn string) error {
    d, err := iofs.New(migrationsFS, "migrations")
    if err != nil { return err }
    m, err := migrate.NewWithSourceInstance("iofs", d, dsn)
    if err != nil { return err }
    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return err
    }
    return nil
}
```

Call `runMigrations` before starting the HTTP server. This ensures the schema is always in sync with the binary version.

### Why migrations belong in source control
Migrations are code. They must be:
- Reviewed in pull requests (schema changes affect every microservice using the same database)
- Versioned alongside the application code that depends on them
- Idempotent when possible (use `CREATE TABLE IF NOT EXISTS`)
- Never edited after being merged — add a new migration instead

---

## Returning engineer: what changed since 1.16–1.18

**`pgx/v5` (2022) changed the API significantly from v4**: if your old code used `pgx/v4`, the v5 migration requires updating imports from `github.com/jackc/pgx/v4` to `v5`, and the `pgtype` API was completely rewritten. The `Scan` interface changed — custom types no longer implement `pgtype.BinaryDecoder`/`pgtype.TextDecoder`; they implement `pgtype.Scanner`. Plan a migration if you have custom pgtype wrappers.

**`sqlc` emerged as the preferred query approach**: in 2018-2019, the dominant options were GORM (full ORM) or `sqlx` (light enhancement to `database/sql`). By 2022-2024, `sqlc` (generates type-safe Go from `.sql` files) became the go-to for teams that want SQL control without manual scanning boilerplate. The repository pattern pairs well with `sqlc` — `sqlc` generates the implementation, you define the interface.

**`embed.FS` for migrations**: the `//go:embed` directive (Go 1.16) made it practical to embed SQL migration files directly in the binary. Before 1.16, embedding required third-party tools like `go-bindata`. Most new codebases now use embedded migrations.

**`pgxpool.Pool` replaces direct `pgx.Conn` in services**: old code that acquired a `pgx.Conn` directly and held it is a pool misuse pattern. Always use `pgxpool.Pool.Acquire(ctx)` if you need a connection for multiple operations, and `defer conn.Release()`.

---

## Key concepts to memorize
- `database/sql` is the abstraction layer; `pgx` is the Postgres-specific driver with richer native features
- Always set all four pool settings: `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime`, `ConnMaxIdleTime`
- `MaxOpenConns = 0` (zero value) means unlimited — this will exhaust Postgres `max_connections` under load
- The repository interface decouples business logic from the database — it makes testing possible without Postgres
- Implement two concrete types: one using `pgxpool`, one using an in-memory `map` for tests
- Migrations are code: version control them, never edit after merge, use `golang-migrate` with embedded FS
- `pgx/v5` has a different API than v4 — type-check your existing pgtype code if upgrading

---

## Common mistakes

**1. Zero-value connection pool (no SetMaxOpenConns)**
Skipping `SetMaxOpenConns` is the most common production database outage cause. Under traffic spikes, Go will open thousands of connections until Postgres refuses them all. Set `MaxOpenConns` based on `max_connections / replicas * 0.8`.

**2. Not wrapping errors with context**
```go
// Bad — error message is "no rows in result set" — which query? which ID?
return nil, err

// Good — errors are navigable
return nil, fmt.Errorf("userRepo.GetByID id=%d: %w", id, err)
```

**3. Repository methods that accept `*pgxpool.Pool` directly**
If a handler or service function accepts `*pgxpool.Pool` instead of the repository interface, you cannot swap in a test double. Keep `pgxpool.Pool` confined to the constructor of the concrete repository type.

**4. Running migrations inside a request handler**
Migrations are a startup concern, not a request-time concern. Never call `migrate.Up()` in a request path — it locks the schema migration table and will block concurrent requests.

**5. Ignoring `pgconn.PgError` for constraint violations**
```go
// Check for unique constraint violation (error code 23505)
var pgErr *pgconn.PgError
if errors.As(err, &pgErr) && pgErr.Code == "23505" {
    return nil, ErrEmailAlreadyExists
}
```
Without this, unique constraint violations surface as generic 500 errors instead of 409 Conflict.

---

## Check your understanding

1. Your Postgres instance has `max_connections = 100` and you run 4 replicas of your Go service. What should you set `MaxOpenConns` to on each replica? Explain the reasoning.
2. You have `userRepo.GetByID` returning `pgx.ErrNoRows` when a user is not found. Your handler converts this to a 500 error. Fix the flow end-to-end: repository, service, and handler layers.
3. A new engineer modifies migration `000003_add_index.up.sql` instead of creating `000004_add_index_fix.up.sql`. What goes wrong for environments that have already run migration 3?
