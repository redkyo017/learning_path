# Day 3 — Modern Stdlib

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Use `slices.SortFunc`, `slices.Contains`, `slices.Index`, `slices.Compact`, and `slices.Clone` correctly
- Use the `maps` package to copy, delete, and iterate maps safely
- Use `cmp.Compare` and `cmp.Or` as composable comparison primitives
- Configure a `slog.Logger` with JSON and text handlers, set log levels, and write structured key-value pairs
- Build and inspect a multi-level error chain using `fmt.Errorf("%w")`, `errors.Is`, `errors.As`, and `errors.Unwrap`

---

## The stdlib grew up — most third-party utility packages are now redundant

For years, Go's standard library left a gap: no generic slice utilities, no
structured logging, no map helpers. The ecosystem filled this gap with packages
like `github.com/samber/lo` for slice operations, `go.uber.org/zap` and
`github.com/rs/zerolog` for structured logging, and hand-rolled error types
because `pkg/errors` was the only ergonomic option.

Go 1.21 landed `slices`, `maps`, and `cmp` — three packages that replace the
most common third-party utility dependencies. Go 1.21 also landed `log/slog`,
the long-awaited structured logging package with JSON/text handlers, log levels,
and a handler interface for custom backends. Coupled with `errors.Is`/`As`
(available since Go 1.13), the stdlib now covers the full utility surface that
most services need.

Think of this as a platform maturation moment — similar to how Go's HTTP client
replaced the need for third-party HTTP libraries, or how `context` replaced
bespoke cancellation plumbing. The lesson is not "never use third-party
packages" — it's "check the stdlib first, because it may already have the right
solution."

---

## The slices package

Go 1.21 introduced `slices` (package path `slices`). It contains generic
implementations of the most common slice operations. You no longer need to
write sort comparators using `sort.Slice` with index-based closures.

### Sorting

```go
import "slices"
import "cmp"

type Person struct{ Name string; Age int }

people := []Person{{"Charlie", 35}, {"Alice", 30}, {"Bob", 25}}

// Old way (Go 1.16):
// sort.Slice(people, func(i, j int) bool { return people[i].Age < people[j].Age })

// New way (Go 1.21):
slices.SortFunc(people, func(a, b Person) int {
    return cmp.Compare(a.Age, b.Age)
})
// people is now sorted by age ascending

// Multi-key sort: age primary, name secondary
slices.SortFunc(people, func(a, b Person) int {
    if n := cmp.Compare(a.Age, b.Age); n != 0 {
        return n
    }
    return cmp.Compare(a.Name, b.Name)
})
```

The comparator returns an `int`: negative if `a < b`, zero if equal, positive if
`a > b`. This is the standard three-way comparison contract from the `cmp` package.

### Searching and contains

```go
names := []string{"alice", "bob", "charlie"}

// Contains (linear scan, works on unsorted slices):
found := slices.Contains(names, "bob")   // true

// Index (returns -1 if not found):
idx := slices.Index(names, "charlie")    // 2

// IndexFunc (predicate-based):
idx = slices.IndexFunc(names, func(s string) bool { return len(s) > 5 })
// idx = 2 ("charlie" is len 7)

// BinarySearch (sorted slice only — returns index, found):
slices.Sort(names)
i, found := slices.BinarySearch(names, "bob")  // i=1, found=true
```

### Deduplication and compaction

```go
nums := []int{1, 1, 2, 3, 3, 3, 4}
slices.Sort(nums)
compact := slices.Compact(nums)   // [1 2 3 4] — removes adjacent duplicates
// NOTE: must sort first; Compact only removes consecutive duplicates
```

### Safe cloning and equality

```go
original := []int{1, 2, 3}
copy := slices.Clone(original)      // independent copy; original is unchanged
equal := slices.Equal(original, copy)  // true
```

### Key functions reference

| Function | Description |
|---|---|
| `slices.Sort(s)` | Sort in place (requires `cmp.Ordered` elements) |
| `slices.SortFunc(s, cmp)` | Sort in place with custom comparator |
| `slices.SortStableFunc(s, cmp)` | Stable sort (preserves equal elements' order) |
| `slices.Contains(s, v)` | Linear search; returns bool |
| `slices.Index(s, v)` | Index of first occurrence; -1 if absent |
| `slices.IndexFunc(s, f)` | Index of first element where f returns true |
| `slices.BinarySearch(s, v)` | Binary search on sorted slice |
| `slices.Compact(s)` | Remove adjacent duplicates (sort first) |
| `slices.Clone(s)` | Shallow copy |
| `slices.Equal(a, b)` | Element-wise equality |
| `slices.Reverse(s)` | In-place reverse |
| `slices.Max(s)` / `slices.Min(s)` | Max/min of a slice |
| `slices.Delete(s, i, j)` | Remove elements [i:j) |
| `slices.Insert(s, i, v...)` | Insert at index |

---

## The maps package

The `maps` package (also 1.21) provides generic utilities for maps.

```go
import "maps"

src := map[string]int{"a": 1, "b": 2}

// Clone — independent copy
dst := maps.Clone(src)

// Copy — merge src into dst (dst keys win on collision)
extra := map[string]int{"b": 99, "c": 3}
maps.Copy(dst, extra)  // dst is now {"a":1, "b":99, "c":3}

// Delete by predicate — remove all pairs where f returns true
maps.DeleteFunc(dst, func(k string, v int) bool { return v > 2 })

// Keys iteration (returns iter.Seq[K] — use range or collect manually)
for k := range maps.Keys(src) {
    fmt.Println(k)
}

// Equal — true if both maps have the same key-value pairs
maps.Equal(src, dst)
```

Common pattern: get sorted keys of a map (maps deliberately have no order):

```go
keys := slices.Collect(maps.Keys(src))
slices.Sort(keys)
for _, k := range keys {
    fmt.Printf("%s: %d\n", k, src[k])
}
```

---

## The cmp package

`cmp` provides two functions that compose with everything:

```go
import "cmp"

// Compare: three-way comparison
cmp.Compare(1, 2)    // -1
cmp.Compare(2, 2)    //  0
cmp.Compare(3, 2)    //  1

// Or: return first non-zero comparison result (for multi-key sorts)
result := cmp.Or(
    cmp.Compare(a.LastName, b.LastName),
    cmp.Compare(a.FirstName, b.FirstName),
    cmp.Compare(a.Age, b.Age),
)
```

`cmp.Or` is the idiomatic way to write multi-key comparators without nested `if`
chains.

---

## slog: structured logging

`log/slog` (Go 1.21) is the new standard structured logger. It replaces the old
`log` package for any production service.

### The two built-in handlers

```go
import "log/slog"
import "os"

// JSON handler — use in production (machine-parseable)
jsonLogger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

// Text handler — use in development (human-readable)
textLogger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
    Level: slog.LevelDebug,
}))

// Set the global default logger
slog.SetDefault(jsonLogger)
```

### Writing log lines

```go
// Key-value pairs as alternating args (fastest, no alloc for ≤5 attrs):
logger.Info("request received", "method", "GET", "path", "/api/tasks", "status", 200)

// Typed attributes (explicit type, better for large structured logs):
logger.Info("request received",
    slog.String("method", "GET"),
    slog.String("path", "/api/tasks"),
    slog.Int("status", 200),
    slog.Duration("latency", 42*time.Millisecond),
)

// Groups — nest related attributes:
logger.Info("db query",
    slog.Group("db",
        slog.String("query", "SELECT * FROM tasks"),
        slog.Int("rows", 5),
        slog.Duration("duration", 3*time.Millisecond),
    ),
)
// JSON: {"msg":"db query","db":{"query":"SELECT...","rows":5,"duration":"3ms"}}
```

### Log levels

| Level | Value | Use for |
|---|---|---|
| `slog.LevelDebug` | -4 | Internal state during development |
| `slog.LevelInfo` | 0 | Normal operational events |
| `slog.LevelWarn` | 4 | Unexpected but recoverable situations |
| `slog.LevelError` | 8 | Errors requiring attention |

Set minimum level via `HandlerOptions.Level`. Logs below the minimum are
**discarded before attribute evaluation** — this is important: key-value
arguments are not evaluated if the level is filtered out.

### Logger with context

```go
// WithContext — attach context to a logger instance for request tracing:
reqLogger := logger.With("request_id", "abc-123", "user_id", "u-456")
reqLogger.Info("processing")   // every line from reqLogger includes request_id + user_id
```

### Custom handler interface

If you need to write to a third-party system (Datadog, Cloud Logging, etc.),
implement `slog.Handler`:

```go
type Handler interface {
    Enabled(ctx context.Context, level Level) bool
    Handle(ctx context.Context, r Record) error
    WithAttrs(attrs []Attr) Handler
    WithGroup(name string) Handler
}
```

Most third-party logging libraries now provide an `slog.Handler` adapter.

---

## Error wrapping: Is, As, Unwrap

Go 1.13 introduced structured error wrapping. If you still write
`if err == ErrNotFound`, you are doing it wrong — that breaks as soon as any
layer wraps the error.

### Wrapping errors

```go
var ErrNotFound = errors.New("not found")

type ResourceError struct {
    ID  string
    Err error
}

func (e *ResourceError) Error() string { return fmt.Sprintf("resource %q: %v", e.ID, e.Err) }
func (e *ResourceError) Unwrap() error { return e.Err }  // exposes the chain

func fetchResource(id string) error {
    // %w wraps the error so errors.Is / errors.As can unwrap it
    return fmt.Errorf("fetchResource: %w", &ResourceError{ID: id, Err: ErrNotFound})
}
```

### errors.Is — identity check through the chain

```go
err := fetchResource("item-42")

errors.Is(err, ErrNotFound)  // true — unwraps through fmt.Errorf and ResourceError
err == ErrNotFound           // false — err is a *fmt.wrapError, not ErrNotFound directly
```

`errors.Is` unwraps the chain depth-first until it finds a matching value or
exhausts the chain. A type can customize matching by implementing `Is(target error) bool`.

### errors.As — type extraction through the chain

```go
var re *ResourceError
if errors.As(err, &re) {
    fmt.Println("failed resource ID:", re.ID)
}
```

`errors.As` unwraps the chain until it finds a value assignable to the target
pointer type. Use this when you need the structured data out of a wrapped error.

### errors.Unwrap — one level at a time

```go
inner := errors.Unwrap(err)  // steps one level; returns nil if no Unwrap method
```

You rarely call `Unwrap` directly — `errors.Is` and `errors.As` do it for you
recursively.

### errors.Join (Go 1.20)

```go
// Combine multiple errors into one:
err := errors.Join(err1, err2, err3)
// errors.Is(err, err1) == true
// err.Error() returns all messages joined with "\n"
```

---

## Migration table: old pattern → new idiom

| Old pattern | New idiom | Package |
|---|---|---|
| `sort.Slice(s, func(i,j int) bool { ... })` | `slices.SortFunc(s, func(a,b T) int { ... })` | `slices` |
| `sort.Search(n, func(i int) bool { ... })` | `slices.BinarySearch(s, target)` | `slices` |
| Manual dedup loop | `slices.Sort(s); slices.Compact(s)` | `slices` |
| `make([]T, len(src)); copy(dst, src)` | `slices.Clone(src)` | `slices` |
| `for k := range m {}` to get keys | `maps.Keys(m)` + `slices.Collect` | `maps` |
| `if err == ErrNotFound` | `errors.Is(err, ErrNotFound)` | `errors` |
| `err.(*MyError)` type assertion | `errors.As(err, &target)` | `errors` |
| `log.Printf("msg key=%v", val)` | `slog.Info("msg", "key", val)` | `log/slog` |
| `github.com/samber/lo` for slice ops | `slices` package | stdlib 1.21 |
| `github.com/pkg/errors` for wrapping | `fmt.Errorf("%w", err)` | stdlib 1.13 |
| `go.uber.org/zap` / `zerolog` for JSON logs | `log/slog` + `NewJSONHandler` | stdlib 1.21 |

---

## Returning engineer: what changed since 1.16–1.18

**The `slices`, `maps`, and `cmp` packages did not exist in 1.16–1.18.** If you
have a helper package called `util/` with slice functions (`Contains`, `Map`,
`Filter`) you wrote before generics — delete it. The stdlib covers all of it
now.

**`slog` did not exist.** You almost certainly used `log.Printf` or a
third-party logger. For any new service, use `slog`. For existing services, the
migration path is: create an `slog.Handler` that wraps your existing logger if
you need both to coexist during migration.

**`errors.Is`/`As` shipped in 1.13** — so you may or may not have adopted this.
Check your old code for `err == ErrXxx` (sentinel comparisons) and
`err.(*MyType)` type assertions. Both break under error wrapping. Replace with
`errors.Is` and `errors.As`.

**`fmt.Errorf("%w", err)` wrapping is 1.13.** The `%w` verb (not `%v`) creates
a wrapping error that `errors.Is`/`As` can unwrap. If you see `%v` in error
strings, the error is not wrapped — it's just formatted as text.

**`errors.Join` is 1.20.** New to you. Use it when you need to collect multiple
errors from concurrent operations (e.g., a worker pool where each worker can
fail independently).

**`sort.Slice` still works** but is deprecated in spirit — prefer `slices.SortFunc`
for new code. The reason is ergonomics and type safety: the old comparator gives
you indices and you must index into the slice yourself, which is error-prone.

---

## Key concepts to memorize

- `slices.SortFunc` comparator returns `int` (negative/zero/positive), not `bool`
- `slices.Compact` requires the slice to be sorted first — it only removes adjacent duplicates
- `slices.Contains` does linear scan; `slices.BinarySearch` requires sorted input
- `maps.Clone` is a shallow copy — nested pointers/slices are shared
- `cmp.Compare(a, b)` returns -1/0/1; use it to build multi-key comparators with `cmp.Or`
- `slog.New(handler)` creates a logger; `slog.SetDefault(logger)` sets the package-level default
- JSON handler goes to stdout; text handler goes to stderr (convention for production)
- `slog.With(key, val)` returns a new logger with permanent attributes — use for request-scoped loggers
- `%w` in `fmt.Errorf` wraps; `%v` formats as string only (unrecoverable by `errors.As`)
- `errors.Is` checks identity through the chain; `errors.As` extracts a typed error from the chain
- `errors.Join` (1.20) combines multiple errors; `errors.Is(joined, target)` works as expected

---

## Common mistakes

**1. Using `slices.Compact` without sorting first.**
Why it happens: the name suggests "deduplicate," which implies global uniqueness.
But `Compact` only removes *adjacent* duplicates, like `uniq` in Unix.
`[]int{1, 2, 1}` after `Compact` is `[]int{1, 2, 1}` — unchanged.
Fix: always `slices.Sort` before `slices.Compact`.

**2. Using `%v` instead of `%w` when wrapping errors.**
Why it happens: they look similar and both format the error message.
But `fmt.Errorf("db error: %v", err)` produces a plain string — `errors.Is`
cannot unwrap it. `fmt.Errorf("db error: %w", err)` wraps the original error
and preserves the chain.

**3. Comparing errors with `==` instead of `errors.Is`.**
Why it happens: it worked before wrapping was idiomatic. It still works when
the error is returned directly (no wrapping), which makes the bug intermittent
and hard to trace. Any middleware or repository layer that wraps errors will
break `==` comparisons silently.

**4. Treating `slog.With` as mutating the original logger.**
Why it happens: in some APIs, `With` is a mutation. In `slog`, `logger.With()`
returns a *new* logger with the extra attributes — the original is unchanged.
Always assign: `reqLogger := logger.With("request_id", id)`.

**5. Using alternating key-value pairs with non-string keys.**
Why it happens: `slog.Info("msg", someIntVar, "value", 42)` compiles but
produces a malformed log line because the key should be a string.
`go vet` will catch this. Always use string literals or `slog.String(...)`,
`slog.Int(...)`, etc. as keys.

---

## Check your understanding

1. You have `people := []Person{{"Bob", 25}, {"Alice", 30}, {"Alice", 22}}`.
   Write the `slices.SortFunc` call to sort by Name ascending, then Age ascending
   as a tiebreaker. What is the resulting order?
2. An error returned from your repository is:
   `fmt.Errorf("postgres: %w", &QueryError{Table: "tasks", Err: ErrNotFound})`.
   Write the code to check if this error is `ErrNotFound` AND extract the
   `QueryError` struct from it. Which function do you use for each?
3. You are building a request handler. You want every log line written inside
   that handler to include `request_id` and `user_id` without passing them to
   every function call. What `slog` pattern do you use?

(answers are in the code — run the lab to verify)
