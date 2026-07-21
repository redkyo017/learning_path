# Day 7 — Gin Fundamentals

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Explain what Gin adds over stdlib `net/http` and why those additions matter at scale
- Use router groups to organize routes with shared prefix and middleware
- Distinguish path parameters from query parameters and extract both correctly
- Validate incoming JSON with `ShouldBindJSON` and struct tags, handling validation errors explicitly
- Configure a production-safe `gin.New()` setup versus the opinionated `gin.Default()`

---

## Core mental model: Gin is a thin layer over net/http

Gin satisfies `http.Handler`. Its `gin.Engine` has a `ServeHTTP(http.ResponseWriter, *http.Request)` method. You can pass `engine` anywhere that accepts `http.Handler` — including `http.Server.Handler`. This means everything you learned on Day 6 remains true: the HTTP lifecycle is unchanged, the request still arrives via `net.Listener`, and Go still spawns a goroutine per connection.

What Gin adds on top of that foundation is a radix trie router (fast path matching with parameter extraction), a request-scoped context object (`gin.Context`) that bundles the stdlib writer and request into one convenient value, and a binding/validation subsystem that decodes and validates JSON, form data, and query strings in a single call.

The analogy: stdlib `net/http` is the engine block. Gin is the dashboard and gearbox. The engine block still drives everything — you are just working with better controls. When Gin does something surprising, the first place to look is the underlying `http.Handler` behavior.

---

## gin.Engine: the entry point

```go
// gin.Default() — pre-wires Logger and Recovery middleware
r := gin.Default()

// gin.New() — bare engine, no middleware
r := gin.New()
r.Use(gin.Logger())
r.Use(gin.Recovery())
```

`gin.Default()` is convenient for getting started but hides what middleware is running. In production, use `gin.New()` and add middleware explicitly so nothing runs silently. The Logger middleware writes to stdout — replace it with a structured logger (zap, slog) before going to production.

---

## The radix trie router

Stdlib `ServeMux` is a map lookup with longest-prefix semantics. Gin uses a compressed radix trie (patricia trie) per HTTP method. This means:

- Path parameter extraction is built in: `/users/:id` captures `id` without allocation overhead
- Wildcard routes: `/static/*filepath` captures everything after the prefix
- Method-based routing is first-class: `GET /users` and `POST /users` are different entries in different tries
- Conflicts are detected at startup (panics), not at request time — fail fast

Performance: for most APIs, the trie vs map difference is irrelevant. The real win is ergonomics — path parameters without a third-party router.

---

## gin.Context: the request envelope

`gin.Context` wraps `http.ResponseWriter` and `*http.Request` and adds Gin-specific helpers. It is request-scoped and passed by pointer throughout the handler chain.

### gin.Context methods vs stdlib equivalents

| Task | gin.Context | stdlib net/http |
|---|---|---|
| Read path param | `c.Param("id")` | `r.PathValue("id")` (Go 1.22+) |
| Read query param | `c.Query("page")` | `r.URL.Query().Get("page")` |
| Read query with default | `c.DefaultQuery("page", "1")` | Manual: `if v == "" { v = "1" }` |
| Bind JSON body | `c.ShouldBindJSON(&dto)` | `json.NewDecoder(r.Body).Decode(&dto)` + manual validation |
| Write JSON response | `c.JSON(200, obj)` | `w.Header().Set("Content-Type", "application/json")` + `json.NewEncoder(w).Encode(obj)` |
| Write status + JSON | `c.AbortWithStatusJSON(400, err)` | `w.WriteHeader(400)` + `json.Encode` |
| Get request context | `c.Request.Context()` | `r.Context()` |
| Store request-scoped value | `c.Set("key", val)` | `r = r.WithContext(context.WithValue(...))` |
| Retrieve stored value | `c.Get("key")` | `r.Context().Value("key")` |
| Stream response | `c.Stream(...)` | Manual `http.Flusher` |

Key detail: `c.Set` / `c.Get` store values in a `map[string]any` on the `gin.Context`, not in `r.Context()`. If you pass `c.Request` to a downstream function that reads from `r.Context()`, values set via `c.Set` will not be there. Use `c.Request.Context()` for propagating values to non-Gin code.

---

## Router groups

Groups let you attach a shared prefix and shared middleware to a set of routes:

```go
v1 := r.Group("/api/v1")
{
    v1.GET("/users", listUsers)
    v1.POST("/users", createUser)

    // nested group inherits /api/v1 prefix, adds /admin prefix
    admin := v1.Group("/admin", requireAdmin)
    {
        admin.DELETE("/users/:id", deleteUser)
    }
}
```

The curly braces are a Go scope block — purely cosmetic to make the nesting visible. Groups do not add overhead; they are resolved at startup into trie entries.

Use groups to:
- Version your API (`/v1`, `/v2`)
- Apply authentication middleware to a subset of routes
- Apply rate limiting to a subset of routes

---

## Path parameters vs query parameters

```
GET /users/42?include=posts&page=2
         ^^              ^^^^^^^^^
     path param         query params
```

```go
r.GET("/users/:id", func(c *gin.Context) {
    id     := c.Param("id")               // "42"
    include := c.Query("include")          // "posts"
    page    := c.DefaultQuery("page", "1") // "2"
})
```

Path parameters are part of the resource identity — they identify which resource. Query parameters are modifiers — they filter, paginate, or reshape the response. If removing the parameter would change which resource you are addressing, it is a path parameter. If it changes how the resource is presented, it is a query parameter.

---

## ShouldBindJSON and validation

Gin integrates the `go-playground/validator` package. Struct tags declare validation rules, and `ShouldBindJSON` runs both JSON decoding and validation in one call:

```go
type CreateUserRequest struct {
    Name  string `json:"name"  binding:"required,min=2,max=100"`
    Email string `json:"email" binding:"required,email"`
    Age   int    `json:"age"   binding:"omitempty,gte=0,lte=130"`
}

func createUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        // err is a validator.ValidationErrors — check type if you need field-level detail
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    // req is valid and populated
}
```

`ShouldBindJSON` vs `BindJSON`:
- `ShouldBindJSON` returns the error; **you decide what to do with it**
- `BindJSON` calls `c.AbortWithError(400, err)` automatically on failure — less control, harder to customize the error shape

Always use `ShouldBind*` variants in production. The `Bind*` variants are training-wheels helpers.

---

## AbortWithStatusJSON and the error flow

When a handler or middleware wants to stop the chain and return an error response:

```go
c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
    "error": "invalid token",
    "code":  "AUTH_REQUIRED",
})
// nothing after this line in the current handler runs
// handlers further down the chain do NOT run
return
```

`AbortWithStatusJSON` calls `Abort()` internally (sets an index flag that prevents `c.Next()` from advancing) and then writes the JSON response. The `return` after it is a Go idiom — it is not strictly required for the Abort to take effect, but it makes the intent explicit and prevents accidental code running after the error path.

---

## gin.New vs gin.Default: what to use

| | `gin.Default()` | `gin.New()` |
|---|---|---|
| Logger middleware | Included (stdout) | Not included |
| Recovery middleware | Included | Not included |
| Suitable for | Local development | Production (add your own) |
| Risk | Silent stdout logging in prod | Panics crash without Recovery |

Production pattern:

```go
r := gin.New()
r.Use(ginzap.Ginzap(zapLogger, time.RFC3339, true))   // structured logging
r.Use(ginzap.RecoveryWithZap(zapLogger, true))          // structured panic recovery
r.Use(otelgin.Middleware("my-service"))                 // tracing
```

---

## Returning engineer: what changed since 1.16–1.18

You likely used `github.com/gin-gonic/gin` at v1.7 or earlier. Gin v1.9 (2023) and the current v1.10 line brought several changes worth knowing:

- **`binding:"required"` on pointer fields**: behavior around zero values and omitempty was tightened — a struct with `binding:"required"` on an `int` field now correctly rejects zero as valid when the field is absent from JSON, not when it is explicitly zero. This was a longstanding footgun.
- **`c.FullPath()`**: returns the registered route pattern (e.g., `/users/:id`), not the resolved path. Useful for metrics labels so you do not create unbounded cardinality by logging `/users/1`, `/users/2`, etc.
- **`gin.H` is just `map[string]any`**: this was always true but the alias was undocumented. You can use either; `gin.H` is more readable for one-off response bodies.
- **Removal of `MustBindWith` deprecations**: if your old code used `c.MustBindWith`, replace with `c.ShouldBindWith` plus explicit error handling.
- **`net/http` 1.22 overlaps Gin's value**: stdlib's new `{wildcard}` and method routing in 1.22 mean simple APIs no longer need Gin just for routing. Gin still wins on binding, validation, and middleware ergonomics.

---

## Key concepts to memorize
- `gin.Engine` implements `http.Handler` — Gin is a router + context wrapper over stdlib, not a replacement
- `gin.New()` is the production constructor; `gin.Default()` adds Logger and Recovery automatically
- `c.Param("key")` for path parameters; `c.Query("key")` for query parameters
- `ShouldBindJSON` returns an error; `BindJSON` aborts automatically — use `ShouldBind*` in production
- `c.Set` / `c.Get` store in `gin.Context`, NOT in `r.Context()` — non-Gin code won't see them
- `c.FullPath()` returns the route pattern (`/users/:id`), not the resolved URL — use it for metrics
- `AbortWithStatusJSON` stops chain execution and writes the response atomically

---

## Common mistakes

**1. Using BindJSON instead of ShouldBindJSON**
`BindJSON` writes a 400 and calls `c.Abort()` for you. If your error handling middleware runs after the handler, it will never see the error because `Abort` has already written the response. Always use `ShouldBindJSON` and write the response yourself.

**2. Registering routes after starting the server**
Gin builds the trie at route registration time, not at request time. Registering routes after `r.Run()` is a data race. All routes must be registered before the server starts.

**3. Calling c.JSON and then returning without abort**
```go
c.JSON(200, result)
// forgot return — handler continues running
doSomethingElse() // this still runs
```
After `c.JSON`, the response headers are committed. Writing again will fail silently. Always `return` after writing a response.

**4. Unbounded cardinality in logging request paths**
Logging `r.URL.Path` directly for metrics creates a unique label per user ID. Use `c.FullPath()` for the route pattern label.

**5. Ignoring the Content-Type check in ShouldBindJSON**
`ShouldBindJSON` only binds JSON. If the client sends `Content-Type: application/x-www-form-urlencoded`, it will fail or bind nothing. Use `ShouldBind` (without JSON suffix) to have Gin auto-detect based on Content-Type, or be explicit about what your endpoint accepts.

---

## Check your understanding

1. `gin.Default()` and `gin.New()` both return a `*gin.Engine`. What middleware does `gin.Default()` add, and why would you replace it in production?
2. You have a route `GET /orders/:orderID/items/:itemID`. Write the handler code to extract both path parameters and return them as JSON.
3. `c.Set("userID", 42)` is called in an auth middleware. A downstream service function accepts `context.Context` and reads the user ID via `ctx.Value("userID")`. Will it find the value? Explain why or why not and how to fix it.
