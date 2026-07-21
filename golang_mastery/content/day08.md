# Day 8 — Gin Middleware

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives
- Describe the `gin.HandlerFunc` signature and how it relates to `http.HandlerFunc`
- Explain the middleware chain execution order, including what happens before and after `c.Next()`
- Use `c.Abort()` family methods to short-circuit the chain and understand when the chain resumes
- Implement a stateless JWT auth middleware that generates, signs, and validates tokens
- Implement a token bucket rate limiter and understand why it is the right default choice
- Understand what Recovery middleware does and what you must NOT let it hide

---

## Core mental model: middleware is a stack

A Gin middleware is a `gin.HandlerFunc` — the same type as a route handler. The router does not distinguish between them. When you call `r.Use(middleware)`, you are prepending a handler to the chain for every subsequent route. When Gin handles a request, it executes the chain in order, each handler yielding to the next via `c.Next()`.

Think of it as a call stack where each frame can choose to call `Next()` (descend deeper) or `Abort()` (unwind immediately). Code before `c.Next()` is the entry path; code after `c.Next()` is the exit path — it runs after all deeper handlers complete. This mirrors how `defer` works, but explicit.

The analogy: airport security layers. Each gate checks something (boarding pass, ID, bag scan). A passenger who fails at any gate does not proceed to the next one — the chain is aborted. Passengers who pass all gates reach the gate and board (the route handler runs). On the way back, each layer can do cleanup (stamp the passport, log the passenger).

---

## Middleware chain execution order

```
c.Next()  ─────────────────────────────────────────────────────►

  ┌──────────────────────┐
  │   Middleware A       │
  │  ┌───────────────┐   │
  │  │  pre-code A   │   │  ← runs first
  │  └──────┬────────┘   │
  │         │ c.Next()   │
  │  ┌──────▼────────┐   │
  │  │  Middleware B  │  │
  │  │ ┌───────────┐  │  │
  │  │ │ pre-code B│  │  │  ← runs second
  │  │ └─────┬─────┘  │  │
  │  │       │c.Next()│  │
  │  │ ┌─────▼─────┐  │  │
  │  │ │  HANDLER  │  │  │  ← route handler runs
  │  │ └─────┬─────┘  │  │
  │  │ ┌─────▼─────┐  │  │
  │  │ │post-code B│  │  │  ← runs third (exit path)
  │  │ └───────────┘  │  │
  │  └───────┬────────┘   │
  │  ┌───────▼────────┐   │
  │  │  post-code A   │   │  ← runs last (exit path)
  │  └────────────────┘   │
  └──────────────────────┘

  Abort() short-circuit (e.g., in Middleware B):

  ┌──────────────────────┐
  │   Middleware A       │
  │  ┌───────────────┐   │
  │  │  pre-code A   │   │
  │  └──────┬────────┘   │
  │         │ c.Next()   │
  │  ┌──────▼────────┐   │
  │  │  Middleware B  │  │
  │  │ ┌───────────┐  │  │
  │  │ │ pre-code B│  │  │
  │  │ │ c.Abort() │  │  │  ← ABORT: chain stops here
  │  │ │ c.JSON()  │  │  │  ← writes response
  │  │ └───────────┘  │  │
  │  └───────┬────────┘   │
  │  ┌───────▼────────┐   │
  │  │  post-code A   │   │  ← still runs (exit path of A)
  │  └────────────────┘   │
  └──────────────────────┘
  (HANDLER and post-code B do NOT run)
```

Key insight from the diagram: `Abort()` prevents handlers **deeper** in the chain from running, but it does **not** skip the post-code (after `c.Next()`) of handlers that have already been entered. This is correct and intentional — cleanup code in higher layers still runs.

---

## c.Next() and c.Abort() mechanics

Gin implements the chain as a `[]HandlersChain` (a slice of `HandlerFunc`) and an index pointer `c.index`. `c.Next()` increments the index and calls the next handler. `c.Abort()` sets the index to `abortIndex` (a sentinel value of 63), causing the loop to stop calling handlers.

```go
// Inside gin.Context
func (c *Context) Next() {
    c.index++
    for c.index < int8(len(c.handlers)) {
        c.handlers[c.index](c)
        c.index++
    }
}

func (c *Context) Abort() {
    c.index = abortIndex  // 63
}
```

Calling `c.Abort()` without writing a response leaves the client hanging — always pair `Abort()` with a response write:

```go
// Good
c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})

// Bad — aborts the chain but writes nothing
c.Abort()
```

`c.IsAborted()` returns true if the chain was aborted — useful in post-processing middleware that wants to skip work if an error already occurred.

---

## JWT auth middleware: the full lifecycle

JSON Web Tokens have three phases: **generate** (at login), **sign** (private key / shared secret), **validate** (on every protected request).

### Token structure
```
header.payload.signature
  │        │        └─ HMAC-SHA256(base64(header)+"."+base64(payload), secret)
  │        └── {"sub":"user123","exp":1720000000,"role":"admin"}
  └────────── {"alg":"HS256","typ":"JWT"}
```

### Generate and sign (at login)
```go
import "github.com/golang-jwt/jwt/v5"

type Claims struct {
    UserID string `json:"sub"`
    Role   string `json:"role"`
    jwt.RegisteredClaims
}

func generateToken(userID, role string, secret []byte) (string, error) {
    claims := Claims{
        UserID: userID,
        Role:   role,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(secret)
}
```

### Validate and extract (in middleware)
```go
func JWTMiddleware(secret []byte) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if !strings.HasPrefix(authHeader, "Bearer ") {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
            return
        }
        tokenStr := strings.TrimPrefix(authHeader, "Bearer ")

        claims := &Claims{}
        token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
            if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
            }
            return secret, nil
        })
        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
            return
        }

        // Store claims in context for downstream handlers
        c.Set("claims", claims)
        c.Next()
    }
}
```

Critical: always verify the signing method in the `keyFunc`. Without this check, an attacker can craft a token with `"alg": "none"` that bypasses signature verification.

### Downstream access
```go
func protectedHandler(c *gin.Context) {
    claims, _ := c.Get("claims")
    userClaims := claims.(*Claims)
    c.JSON(200, gin.H{"user": userClaims.UserID})
}
```

---

## Token bucket rate limiting

The token bucket algorithm is the right default for HTTP rate limiting:

- A bucket holds up to `capacity` tokens
- Tokens refill at a constant rate (`rate` tokens per second)
- Each request consumes one token
- If the bucket is empty, the request is rejected (HTTP 429)

Why token bucket over fixed window: fixed windows allow bursts at window boundaries (double the rate briefly). Token bucket smooths bursts while allowing short-term spikes up to `capacity`.

```go
import "golang.org/x/time/rate"

func RateLimiter(r rate.Limit, burst int) gin.HandlerFunc {
    limiter := rate.NewLimiter(r, burst)
    return func(c *gin.Context) {
        if !limiter.Allow() {
            c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
                "error": "rate limit exceeded",
            })
            return
        }
        c.Next()
    }
}

// Usage: 10 requests/sec, burst up to 20
r.Use(RateLimiter(10, 20))
```

Per-user rate limiting requires a map of limiters keyed by user ID or IP address — add a `sync.Mutex` or use `sync.Map`, and add TTL-based eviction to prevent memory leaks.

---

## Recovery middleware

Recovery catches panics anywhere in the handler chain, recovers the goroutine, and returns a 500 response instead of crashing the process:

```go
r.Use(gin.Recovery()) // built-in

// Production: use a structured version
r.Use(gin.CustomRecovery(func(c *gin.Context, recovered any) {
    // Log the panic with stack trace to your structured logger
    log.Error("panic recovered", "error", recovered, "stack", debug.Stack())
    c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
        "error": "internal server error",
    })
}))
```

What Recovery hides: panics in your business logic that indicate data corruption, logic errors, or invalid assumptions. A panic is almost always a bug. Recovery prevents downtime but it must not substitute for fixing the bug. Log every recovered panic with a full stack trace and treat it as a P1 incident.

---

## Returning engineer: what changed since 1.16–1.18

**`github.com/golang-jwt/jwt/v5` replaced `dgrijalva/jwt-go`**: the original `dgrijalva/jwt-go` is unmaintained and archived. The community fork moved to `golang-jwt/jwt` and the v5 API changed how registered claims are embedded — `StandardClaims` was replaced by `RegisteredClaims`. If you have old JWT code, update the embed and the expiry check API.

**`golang.org/x/time/rate` is now the canonical rate limiter**: it was available in 2018 but underused. It is now standard in production Go services. The API uses `rate.Limit` (a float64 of tokens/second) and `burst` (bucket capacity).

**Structured middleware logging with `log/slog`**: Go 1.21's `log/slog` makes it straightforward to write middleware that emits structured JSON logs without a third-party library. In new codebases you will see `slog.InfoContext(c.Request.Context(), "request", ...)` in logging middleware instead of `logrus` or manual `log.Printf`.

**`c.Next()` is optional in terminal handlers**: a common question. If your middleware never calls `c.Next()`, the chain does not advance past that point. This is intentional for early-exit middleware (auth, rate limiting) but a bug if done accidentally in a middleware that should pass through.

---

## Key concepts to memorize
- Gin middleware is `gin.HandlerFunc` — the same type as route handlers; position in the chain is the only difference
- Code before `c.Next()` = entry path (pre-processing); code after `c.Next()` = exit path (post-processing)
- `c.Abort()` prevents deeper handlers from running, but does NOT skip exit-path code in already-entered handlers
- Always pair `c.Abort()` with a response write — naked `Abort()` leaves the client hanging
- JWT: always validate the signing algorithm in the `keyFunc` — the "alg: none" attack is real
- Token bucket smooths bursts; fixed window does not — prefer token bucket for production rate limiting
- Recovery middleware prevents crashes but must not hide bugs — log every panic with a stack trace

---

## Common mistakes

**1. Not calling c.Next() in pass-through middleware**
If middleware should execute the rest of the chain (logging, metrics, tracing), forgetting `c.Next()` silently drops all downstream handlers. The request returns 200 with an empty body. Always audit middleware for the `c.Next()` call.

**2. Writing a response and then calling c.Next()**
```go
c.JSON(200, data)
c.Next()  // deeper handlers may write again — double-write
```
After writing a response, either call `c.Abort()` or `return`. Writing and then continuing the chain leads to headers-already-sent panics or garbled responses.

**3. Skipping the algorithm check in JWT validation**
```go
// DANGEROUS — "alg: none" attack
token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
    return secret, nil
})

// SAFE — verify HMAC
token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
    if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
        return nil, fmt.Errorf("unexpected alg %v", t.Header["alg"])
    }
    return secret, nil
})
```

**4. One global rate limiter for all users**
A global limiter means a single heavy user can exhaust the budget for everyone. Implement per-user or per-IP limiters with `sync.Map[string]*rate.Limiter` and TTL eviction.

**5. Swallowing panic details in Recovery**
`gin.Recovery()` logs the panic to stderr but does not include the stack trace in the response or a structured log system. Always use `gin.CustomRecovery` and emit the full stack trace to your log aggregator (Datadog, Loki, CloudWatch).

---

## Check your understanding

1. Draw the execution order for this chain: `Logger → Auth → RateLimit → Handler`. Now add `c.Abort()` in the Auth middleware. Which functions still run and in what order?
2. A user reports they can see each other's data intermittently. You look at the JWT middleware and find it calls `c.Set("claims", claims)`. What race condition might exist with per-user rate limiting using a shared `*rate.Limiter` map, and how do you fix it?
3. Why is it insufficient to just check `token.Valid == true` after `jwt.ParseWithClaims`, without also checking the returned `err`?
