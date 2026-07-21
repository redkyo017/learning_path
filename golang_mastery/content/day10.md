# Day 10 — Testing in Go

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Write idiomatic table-driven tests and explain why Go adopted this pattern over test classes
- Test HTTP handlers in isolation with `httptest.NewRecorder` without starting a real server
- Mock dependencies via Go interfaces and explain why this is preferable to mock generation tools
- Understand when `testcontainers-go` is appropriate vs when interface mocking is sufficient
- Write benchmark tests with correct `b.N` loop and `b.ResetTimer` usage
- Explain what the `-race` flag detects and why it must be part of your CI pipeline

---

## Core mental model: if you can't mock it with an interface, your abstraction boundary is wrong

In Go, mocking is not a testing framework — it is a design consequence. If a function accepts a concrete type (a `*pgxpool.Pool`, a `*http.Client`, a `*os.File`), you cannot substitute a test double without changing the function signature. The function is untestable in isolation.

If the function accepts an interface instead, you can pass anything that satisfies the interface — including a hand-written struct with hardcoded return values. This forces good design: narrow interfaces, explicit dependencies, single responsibilities.

The analogy: a socket outlet is an interface. Any appliance with the right plug can use it. If your lamp is hardwired to the wall (concrete type), you cannot test it without the wall. Define the socket (interface), and you can test the lamp with a battery pack (test double).

When you find yourself reaching for a heavy mocking library, first ask: why can't I write a simple struct that satisfies this interface? The answer is usually that the interface is too large or the dependency is too concrete.

---

## Table-driven tests: the Go idiom

Go has no test classes, no `setUp`/`tearDown`, and no annotations. The community converged on a single pattern: a slice of anonymous structs, one entry per test case.

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name    string
        a, b    int
        want    int
    }{
        {"both positive", 2, 3, 5},
        {"negative numbers", -1, -3, -4},
        {"zero", 0, 0, 0},
        {"overflow-safe", math.MaxInt32, 1, math.MaxInt32 + 1},
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            got := Add(tc.a, tc.b)
            if got != tc.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tc.a, tc.b, got, tc.want)
            }
        })
    }
}
```

Why `t.Run`: each case becomes a sub-test with its own name. You can run a single case with `go test -run TestAdd/zero`. Failures are isolated — one failing case does not stop others from running.

Why not `t.Fatal` in the loop directly: `t.Fatal` calls `runtime.Goexit()` which exits the goroutine. Inside `t.Run`, the goroutine is the sub-test goroutine, so only the sub-test stops. In the outer test, it would stop the entire loop. Use `t.Run` to safely isolate.

Why this pattern beats xUnit-style: no shared test state leaks between cases, the entire test specification is readable at a glance in the struct literal, and adding a new case requires one line.

---

## httptest.NewRecorder: testing handlers without a server

`httptest.NewRecorder` implements `http.ResponseWriter` backed by an in-memory buffer. `httptest.NewRequest` creates an `*http.Request`. Together they let you call a handler function directly without starting a TCP listener:

```go
func TestCreateUserHandler(t *testing.T) {
    tests := []struct {
        name       string
        body       string
        wantStatus int
        wantBody   string
    }{
        {
            name:       "valid request",
            body:       `{"name":"Alice","email":"alice@example.com"}`,
            wantStatus: http.StatusCreated,
            wantBody:   `"id"`,
        },
        {
            name:       "missing email",
            body:       `{"name":"Alice"}`,
            wantStatus: http.StatusBadRequest,
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            // Arrange
            repo := memory.NewUserRepository()     // in-memory double
            handler := NewUserHandler(repo)
            body := strings.NewReader(tc.body)

            req := httptest.NewRequest(http.MethodPost, "/users", body)
            req.Header.Set("Content-Type", "application/json")
            w := httptest.NewRecorder()

            // Act
            handler.CreateUser(w, req)  // call directly, no server needed

            // Assert
            res := w.Result()
            if res.StatusCode != tc.wantStatus {
                t.Errorf("status = %d, want %d", res.StatusCode, tc.wantStatus)
            }
            if tc.wantBody != "" {
                body, _ := io.ReadAll(res.Body)
                if !strings.Contains(string(body), tc.wantBody) {
                    t.Errorf("body %q does not contain %q", body, tc.wantBody)
                }
            }
        })
    }
}
```

For Gin handlers, use `httptest` with the engine, not with the handler function directly — Gin handlers depend on `*gin.Context` which is populated by the engine's routing:

```go
// Testing a Gin handler
r := gin.New()
r.POST("/users", handler.CreateUser)

req := httptest.NewRequest(http.MethodPost, "/users", body)
w := httptest.NewRecorder()
r.ServeHTTP(w, req)  // let Gin route and populate gin.Context
```

---

## Mocking via interfaces

Write a minimal interface that captures only what your code needs from a dependency. Then write a test double that satisfies it:

```go
// The interface — only what the handler needs
type UserRepository interface {
    GetByID(ctx context.Context, id int64) (*User, error)
    Create(ctx context.Context, u *User) (*User, error)
}

// A hand-written mock for tests
type mockUserRepository struct {
    getByIDFunc func(ctx context.Context, id int64) (*User, error)
    createFunc  func(ctx context.Context, u *User) (*User, error)
}

func (m *mockUserRepository) GetByID(ctx context.Context, id int64) (*User, error) {
    return m.getByIDFunc(ctx, id)
}

func (m *mockUserRepository) Create(ctx context.Context, u *User) (*User, error) {
    return m.createFunc(ctx, u)
}

// In the test
mock := &mockUserRepository{
    getByIDFunc: func(_ context.Context, id int64) (*User, error) {
        if id == 1 {
            return &User{ID: 1, Name: "Alice"}, nil
        }
        return nil, ErrNotFound
    },
}
handler := NewUserHandler(mock)
```

When hand-written mocks become tedious (many methods), use `github.com/stretchr/testify/mock` or `go.uber.org/mock/mockgen` (formerly `golang/mock`). `mockgen` generates the struct from the interface definition.

### Unit test vs integration test decision matrix

| | Unit test | Integration test |
|---|---|---|
| What you test | Business logic, handler routing, validation, error mapping | Database queries, migration state, external service contracts |
| Tools | `testing`, `httptest`, interface mock | `testcontainers-go`, real database, real HTTP calls |
| When to use | All business rules, all error paths, all validation logic | Repository layer, migrations, third-party client behavior |
| Run speed | Milliseconds | Seconds (container start) |
| Run in CI | Every commit, every PR | Every PR, nightly, or in a separate stage |
| Isolation | Complete (no I/O) | Partial (real DB, mocked externals) |
| Good for | "Does the handler return 401 when the token is missing?" | "Does GetByID return ErrNotFound for non-existent rows?" |
| Bad for | "Does the SQL query use the correct index?" | "Does the handler correctly call the repository?" |

The split is not 70/30 or 80/20 — it depends on where the risk lives. Business logic risk → unit tests. Data access risk → integration tests.

---

## testcontainers-go: integration tests with real databases

`testcontainers-go` starts Docker containers in test setup and tears them down on cleanup. Use it for testing the repository layer against a real Postgres instance:

```go
import (
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func TestUserRepository_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    ctx := context.Background()

    pgContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:16-alpine"),
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections"),
        ),
    )
    if err != nil { t.Fatal(err) }
    t.Cleanup(func() { pgContainer.Terminate(ctx) })

    dsn, _ := pgContainer.ConnectionString(ctx, "sslmode=disable")
    pool, _ := pgxpool.New(ctx, dsn)

    // Run migrations
    runMigrations(dsn)

    repo := postgres.NewUserRepository(pool)

    // Now test the real SQL
    user, err := repo.Create(ctx, &User{Name: "Alice", Email: "alice@test.com"})
    require.NoError(t, err)
    require.NotZero(t, user.ID)

    found, err := repo.GetByID(ctx, user.ID)
    require.NoError(t, err)
    require.Equal(t, "Alice", found.Name)
}
```

Guard integration tests with `testing.Short()` and run them with `go test -run Integration ./...` or in a separate CI stage. Never mix integration tests into the fast unit test loop.

---

## Benchmark tests

Benchmarks measure performance. They follow the `BenchmarkXxx(b *testing.B)` convention:

```go
func BenchmarkJSONMarshal(b *testing.B) {
    user := User{ID: 1, Name: "Alice", Email: "alice@example.com"}

    b.ResetTimer() // discard setup time from the measurement
    for i := 0; i < b.N; i++ {
        _, err := json.Marshal(user)
        if err != nil {
            b.Fatal(err)
        }
    }
}
```

`b.N` is set by the test runner — it increases until the benchmark runs for at least 1 second (by default). Never hardcode a loop count; always use `b.N`.

`b.ResetTimer()` discards time spent in setup (creating test fixtures, opening connections) so the benchmark measures only the code under test.

Run with: `go test -bench=. -benchmem ./...`

Output:
```
BenchmarkJSONMarshal-8    5234291    229 ns/op    112 B/op    3 allocs/op
                    ^           ^         ^              ^              ^
                    cores    iterations  ns per op  bytes/op    allocs/op
```

`-benchmem` is essential — it shows allocations. A function that allocates on every call is a GC pressure source. The goal is often zero allocs for hot paths.

---

## The -race flag

Go's race detector instruments memory accesses at compile time and reports concurrent reads and writes to the same memory location without synchronization:

```bash
go test -race ./...
go run -race main.go
```

A race condition detected looks like:
```
==================
WARNING: DATA RACE
Write at 0x00c000124020 by goroutine 8:
  main.incrementCounter()
      /app/counter.go:12 +0x44

Previous read at 0x00c000124020 by goroutine 7:
  main.readCounter()
      /app/counter.go:18 +0x38
==================
```

The race detector has ~5-10x CPU overhead and ~5-10x memory overhead. This is acceptable for CI and staging — never for production binaries. The overhead means it will not slow your test suite in a meaningful way relative to test correctness.

The race detector only catches races that occur during the test run — it is not a static analysis tool. You must exercise the concurrent code paths. This is why integration tests with concurrent requests are valuable: they trigger races that unit tests miss.

Add `-race` to your CI `go test` command permanently. A race condition found in CI is a bug found early; a race condition found in production is an incident.

---

## Returning engineer: what changed since 1.16–1.18

**`testing.T.Cleanup`** (Go 1.14, but widely adopted after 1.16): replaced manual `defer` for teardown. `t.Cleanup(func() { ... })` registers a function that runs when the test ends, in LIFO order. Cleaner than `defer` in `TestMain` and composable across helpers.

**`testcontainers-go` is now the standard**: in 2018-2019, integration tests either used `docker-compose up` as a CI prerequisite or hand-rolled Docker SDK calls. `testcontainers-go` (and its typed modules like `testcontainers-go/modules/postgres`) made container-per-test the default Go pattern by 2022.

**`go.uber.org/mock` replaces `golang/mock`**: Google's original `golang/mock` (`gomock`) was migrated to Uber's maintenance under `go.uber.org/mock`. The import path changed. Same API, different module path. If your old code imports `github.com/golang/mock`, update to `go.uber.org/mock`.

**`require` vs `assert` from testify**: you likely used `github.com/stretchr/testify` before. The distinction matters now: `require.NoError` calls `t.FailNow()` (stops the test immediately), while `assert.NoError` calls `t.Fail()` (marks failure, continues). Use `require` for preconditions whose failure makes subsequent assertions meaningless.

**Fuzzing is built in** (Go 1.18): `func FuzzXxx(f *testing.F)` with `f.Add(seed)` and `f.Fuzz(func(t *testing.T, data string) {...})`. Not covered in this day but worth knowing — the `go test -fuzz` flag runs the fuzzer continuously against corpus inputs.

---

## Key concepts to memorize
- Table-driven tests: slice of anonymous structs + `t.Run` per case — the Go standard, not a framework
- `httptest.NewRecorder()` implements `http.ResponseWriter` in memory — no server required
- For Gin handlers, call `engine.ServeHTTP(recorder, request)` to let Gin populate `gin.Context`
- Mocking in Go = writing a struct that satisfies an interface — if you need a library, check the interface first
- `testcontainers-go` for repository layer tests against real Postgres — guard with `testing.Short()`
- `b.ResetTimer()` discards setup time; `b.N` is the loop count — never hardcode it
- `-race` flag detects concurrent memory access violations — add to CI permanently; not for production binaries

---

## Common mistakes

**1. Testing through the database when the interface exists**
If you have a `UserRepository` interface, your handler tests should use the in-memory mock — not a real database. Testing through the database in handler tests is slow, brittle (test data management), and tests the wrong layer. Integration tests belong in the repository layer tests, not the handler layer tests.

**2. Benchmarking with setup inside the loop**
```go
// Bad — measures setup + function under test
for i := 0; i < b.N; i++ {
    data := buildLargeStruct()  // setup work measured
    process(data)
}

// Good
data := buildLargeStruct()
b.ResetTimer()
for i := 0; i < b.N; i++ {
    process(data)
}
```

**3. Not parallelizing independent sub-tests**
```go
for _, tc := range tests {
    tc := tc  // capture range variable (Go < 1.22)
    t.Run(tc.name, func(t *testing.T) {
        t.Parallel()
        // ...
    })
}
```
`t.Parallel()` inside `t.Run` runs that sub-test concurrently with other parallel sub-tests. For CPU-bound tests this reduces wall time significantly. For Go 1.22+ the loop variable capture (`tc := tc`) is no longer needed due to the loop variable fix.

**4. Interface too large to mock easily**
If your mock implements 20 methods but only 2 are called by the code under test, the interface is too large. Apply the Interface Segregation Principle: split into smaller interfaces, one per use case. `io.Reader` has one method for a reason.

**5. Skipping `-race` in CI because it slows tests**
The 5x slowdown is the cost of correctness. A race condition in production means data corruption, incorrect responses, or crashes under concurrent load. No benchmark justifies skipping `-race` in CI.

---

## Check your understanding

1. You have a `PaymentService` struct that directly constructs a `*stripe.Client`. Why is this untestable, and what change would make it testable without modifying the test itself?
2. Your handler test calls `handler.CreateUser(w, req)` directly. The handler uses `c.Param("id")` — a Gin context method. What goes wrong and how do you fix the test?
3. `go test -bench=. -benchmem` reports `10000 B/op` for a function you expected to be zero-allocation. Name two tools or techniques you would use to find where the allocation is happening.
