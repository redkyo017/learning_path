# Day 2 — Generics

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Write a generic function with type parameters and explain what the compiler does with it
- Write a custom interface constraint and explain the difference between a type set and a behavior contract
- Apply type inference and know when you need to write explicit type arguments
- Make a principled judgment: generics vs `interface{}` vs an interface type — for a given problem, which tool fits?
- Implement a typed generic cache and a `Result[T]` type from memory

---

## Generics are for algorithms and containers; interfaces are for behavior contracts

Generics arrived in Go 1.18 with a deliberately narrow scope. Before you write
a single type parameter, internalize this distinction: **generics parametrize
over types; interfaces parametrize over behavior**. Confusing these two
produces code that is harder to read than either the pre-generic or pure-interface
approach.

Think of an algorithm like `Map(slice, transform)`. Its implementation is
identical regardless of whether the slice holds `int`, `string`, or `User`. The
only thing that varies is the type — not any specific operation on the type.
This is the sweet spot for generics: the algorithm is type-agnostic and the
compiler enforces type safety at each call site. No `interface{}`, no
type assertions, no runtime panics from a wrong cast.

Now think of an `http.Handler`. What varies across implementations is *behavior*:
different handlers respond to requests differently. `ServeHTTP` is the contract.
You don't write `Handler[RequestType]` — you write an interface because the
point is polymorphism of *behavior*, not parametrization of *type*. Generics
would be the wrong tool here.

The rule of thumb: if you're writing a container (cache, queue, result wrapper)
or an algorithm that is uniform across types (sort, filter, reduce, find), reach
for generics. If you're writing a plugin point, a dependency seam, or a set of
related behaviors (io.Reader, http.Handler, database.Repository), reach for an
interface. When in doubt, start with interfaces — they are cheaper to understand
at a glance.

---

## Type parameters and constraints

The syntax for a generic function:

```go
func Map[T, U any](s []T, f func(T) U) []U {
    result := make([]U, len(s))
    for i, v := range s {
        result[i] = f(v)
    }
    return result
}
```

`[T, U any]` is the *type parameter list*. `T` and `U` are type parameters (by
convention, single uppercase letters, but any name works). `any` is the
*constraint* — it means "T can be any type." Constraints are interface types.

For a generic type (struct):

```go
type Cache[K comparable, V any] struct {
    mu    sync.RWMutex
    items map[K]V
}
```

`comparable` is a built-in constraint that means "K can be used as a map key"
(i.e., supports `==` and `!=`). Maps require comparable keys — this constraint
is enforced at compile time.

### Built-in constraints

| Constraint | What it means |
|---|---|
| `any` | No restriction; equivalent to `interface{}` |
| `comparable` | Supports `==` and `!=`; can be a map key or in a set |
| `cmp.Ordered` | Supports `<`, `<=`, `>`, `>=` (numbers and strings) — from `cmp` package |

### Custom interface constraints

A constraint is just an interface. But Go 1.18 extended interface syntax to
support *type sets*:

```go
type Number interface {
    int | int64 | float64
}

func Sum[T Number](s []T) T {
    var total T
    for _, v := range s {
        total += v
    }
    return total
}
```

The `int | int64 | float64` is a *union element* — it defines a set of types
that satisfy the constraint. Only those types can be passed as `T`. This is
**not** a behavior contract (no method names) — it's a type enumeration.

You can combine type sets with method requirements:

```go
type Stringer interface {
    ~string | fmt.Stringer   // either an underlying string type OR implements Stringer
}
```

The `~` prefix means "underlying type": `~string` matches not just `string` but
any named type whose underlying type is `string` (e.g., `type UserID string`).

---

## Type inference

In most cases you don't need to write explicit type arguments:

```go
nums := []int{1, 2, 3}
doubled := Map(nums, func(n int) int { return n * 2 })  // T=int, U=int inferred
```

The compiler infers `T` and `U` from the argument types. You must write explicit
type arguments only when inference is ambiguous or impossible:

```go
// Inference fails — no argument gives the compiler enough to infer T
result := make[int]()  // hypothetical; you'd need to write it explicitly

// Real case where explicit args are needed:
v := Zero[float64]()   // func Zero[T any]() T — returns zero value of T
```

If the compiler says "cannot infer T", add the type argument explicitly.

---

## Generics vs interface{} vs interfaces — the decision table

This is the most important judgment in Go generics. Getting it wrong produces
either unreadable generic soup or the old `interface{}` type-assertion minefield.

| Situation | Best tool | Why |
|---|---|---|
| Algorithm uniform over types (map, filter, reduce, min, max) | Generic function | Compile-time type safety, no assertions |
| Typed container (cache, set, queue, result wrapper) | Generic type | Preserves type at every call site |
| Plugin point / dependency injection (repository, handler, logger) | Interface | Polymorphism of behavior, easy to mock |
| Arbitrary data at runtime (JSON unmarshaling, `any` value) | `interface{}` / `any` | Type not known until runtime; generics can't help |
| Sorting with a comparator | `slices.SortFunc` with `cmp.Ordered` or custom func | Stdlib already does this |
| Multiple concrete types sharing an operation with **different logic** | Interface | Behavior differs; generics would require type switches |
| Function that works on all types but needs to know the concrete type at runtime | Reflection | Last resort; generics don't help here |

**The smell test:** if your generic function body contains a `switch v := any(x).(type)` type switch, you've used the wrong tool. Generics are not a replacement for interfaces when behavior differs by type.

---

## Real patterns: Map, Filter, Reduce

```go
// Map transforms each element.
func Map[T, U any](s []T, f func(T) U) []U { ... }

// Filter returns elements where f returns true.
func Filter[T any](s []T, f func(T) bool) []T { ... }

// Reduce folds to a single value.
func Reduce[T, U any](s []T, init U, f func(U, T) U) U { ... }
```

These are the foundational generic utilities. In practice, the `slices` package
(Day 3) handles most slice manipulation — you won't write `Map/Filter` in
production code as often as you might think. But writing them yourself is the
clearest way to understand how generics work.

---

## Real pattern: typed cache

```go
type Cache[K comparable, V any] struct {
    mu    sync.RWMutex
    items map[K]V
}

func NewCache[K comparable, V any]() *Cache[K, V] {
    return &Cache[K, V]{items: make(map[K]V)}
}

func (c *Cache[K, V]) Set(key K, value V) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.items[key]
    return v, ok
}
```

Usage: `c := NewCache[string, *User]()`. The compiler ensures you never
accidentally store an `int` in a cache declared as `Cache[string, *User]`. The
pre-generics approach used `map[string]interface{}` and required a type
assertion on every `Get`.

---

## Real pattern: Result[T]

`Result[T]` is a typed wrapper for operations that either succeed with a value
or fail with an error. It is useful when you want to collect results from
concurrent workers without a separate error channel:

```go
type Result[T any] struct {
    value T
    err   error
}

func Ok[T any](v T) Result[T]        { return Result[T]{value: v} }
func Err[T any](err error) Result[T] { return Result[T]{err: err} }

func (r Result[T]) IsOk() bool         { return r.err == nil }
func (r Result[T]) Value() T           { return r.value }
func (r Result[T]) Error() error       { return r.err }
func (r Result[T]) Unwrap() (T, error) { return r.value, r.err }
```

This pattern is popular for pipeline stages where each stage emits
`chan Result[T]` rather than a pair of `(chan T, chan error)`.

---

## Returning engineer: what changed since 1.16–1.18

**Generics were not in 1.16.** They shipped in 1.18. If you were on 1.18 right
before moving to management, you may have read the blog posts but likely didn't
write production generics code. The mental model in this file is the foundation.

**`interface{}` vs `any`:** Since 1.18, `any` is an alias for `interface{}`.
They are identical. New code should use `any` — it reads more naturally and
signals "no constraint." If you see `interface{}` in code review, it's probably
old code; it still works but is discouraged.

**`comparable` constraint vs `interface{}` map keys:** You may have written
`map[interface{}]V` for flexible map keys. Do not do this with generics. Use
`comparable` as the key constraint — it is correct and efficient.

**The `constraints` package was removed from `golang.org/x/exp`:** Early generics
tutorials (2021–2022) used `golang.org/x/exp/constraints` for types like
`constraints.Ordered`. This was pulled back into the stdlib as `cmp.Ordered`
in Go 1.21. Do not add `golang.org/x/exp` as a dependency just for constraints.

**Type sets in interfaces are new syntax:** If you see `interface { int | float64 }`
in a constraint position, this is valid Go 1.18+ syntax. It is *not* valid
outside a constraint (you can't use a type-set interface as a function parameter
type directly). The compiler will tell you if you try.

**Why generics in Go are not Java/C++ generics:** Go generics use "GC shapes"
for instantiation, meaning the compiler may share the same machine code for
multiple instantiations of a generic function (particularly for pointer types).
They are not always zero-overhead. For hot paths, benchmark before committing.

---

## Key concepts to memorize

- Type parameter list goes in square brackets: `func F[T any](v T) T`
- `any` = no constraint; `comparable` = map-key-safe; `cmp.Ordered` = supports `<`/`>`
- Type inference works from argument types; explicit args needed only when ambiguous
- Constraints are interface types — they can include type sets (`int | float64`) and method sets
- `~T` means "underlying type is T" — matches named types built on T
- `interface{}` and `any` are identical aliases since Go 1.18
- Do not use `golang.org/x/exp/constraints` — use `cmp.Ordered` from stdlib (1.21+)
- Generic type method receivers: `func (c *Cache[K, V]) Get(key K) (V, bool)`
- A type switch inside a generic function is a code smell — use interfaces instead
- `Result[T]` pattern eliminates the parallel value/error channel anti-pattern

---

## Common mistakes

**1. Reaching for generics when an interface is clearer.**
Why it happens: generics feel modern and powerful after reading about them.
But `http.Handler`, `io.Reader`, `sort.Interface` — all of these are *correct*
as interfaces because they describe contracts on behavior, not type identity.
A generic `Handler[T]` that does nothing with `T` is strictly worse.

**2. Writing a type switch inside a generic function.**
Why it happens: the engineer wants one function that handles `int` and `string`
differently. That's not what generics are for — use an interface with a method.
`switch any(v).(type)` inside a generic function means the generic is doing
nothing except wrapping a runtime type dispatch.

**3. Forgetting the `~` prefix for underlying-type constraints.**
Why it happens: `int | string` as a constraint does not match `type MyInt int`.
If you want to match all types whose underlying type is `int`, write `~int`.
The compiler won't error on `int` — it will just silently reject `MyInt` as a
type argument.

**4. Treating `comparable` as "supports ordering."**
Why it happens: the name sounds related to `cmp.Compare`. `comparable` only
means equality (`==`/`!=`). For `<`/`>` ordering, use `cmp.Ordered`. A struct
type is `comparable` if all its fields are comparable; it is not `cmp.Ordered`.

**5. Not running benchmarks before claiming "generics are faster than interface{}."**
Why it happens: the blog posts say generics avoid boxing. That's true for inline
pointer cases, but Go's GC shape optimization means multiple instantiations
may share code paths. The performance difference is measurable but not always
dramatic. Correctness first, benchmark if it matters.

---

## Check your understanding

1. You want a function `Keys[K comparable, V any](m map[K]V) []K` that returns
   all keys of any map. Write the signature. Can you call it as `Keys(myMap)`
   without type arguments? Why or why not?
2. You have a `Repository` interface with `Save(ctx, entity)` and `Find(ctx, id)`.
   A junior engineer proposes making it `Repository[T any]` so it can store any
   entity type. What is wrong with this suggestion and what should they do instead?
3. A constraint is written as `interface { ~int | ~string }`. Write a type that
   satisfies this constraint but is not `int` or `string` itself.

(answers are in the code — run the lab to verify)
