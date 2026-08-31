# WSO2 Mastery Phase 2 — API Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author all content and lab files for Phase 2 (Days 16–30): Go reverse proxy with JWT validation, subscription enforcement, and token-bucket throttle — the gateway side of the WSO2 stack.

**Architecture:** Each 3-day block produces three day `.md` files and three lab directories. Days 16–27 build a Go API Gateway incrementally (middleware chain → JWT validation → subscription check → throttle). Day 28–30 produce a GW log4j2 debug playbook mirroring Phase 1's IS playbook.

**Tech Stack:** Go 1.22+, `github.com/golang-jwt/jwt/v5`, `net/http/httputil` (reverse proxy), standard `net/http`. Local Docker. No external WSO2 instance needed for most labs.

**Spec:** `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`

## Global Constraints

- No `git commit`, `git add`, `git push`, `git status`, `git log`, or `git diff` in any subagent dispatch.
- No real credentials, AWS account IDs, or tokens in any file — use placeholder comments.
- No `terraform apply` or live cloud commands — labs are authored, not run.
- Every exercise ships with Hint + Solution sketch — never a bare question.
- Every lab directory ships with: `README.md`, Go source file(s), `SOLUTION.md`, `teardown.md`.
- WSO2 APIM Universal GW source: `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0`
- WSO2 APIM ACP source: `/Users/hunghan/Downloads/wso2am-acp-4.7.0`
- Each lab day is STANDALONE — all functions/types must be defined in the same file.

---

### Task 0: Scaffold Phase 2 directories

**Files:**
- Create: `wso2_mastery/content/phase2/` (`.gitkeep`)
- Create: `wso2_mastery/labs/phase2/` (`.gitkeep`)

- [ ] **Step 1:** Create `wso2_mastery/content/phase2/.gitkeep`
- [ ] **Step 2:** Create `wso2_mastery/labs/phase2/.gitkeep`

---

### Task 1: Days 16–18 — Synapse Mediation Engine + Go Handler Chain

**Files:**
- Create: `content/phase2/day16.md`, `day17.md`, `day18.md`
- Create: `labs/phase2/day16/README.md` (source reading — no Go)
- Create: `labs/phase2/day17/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase2/day18/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Produces: `labs/phase2/day18/main.go` — a Go reverse proxy with a middleware chain. Task 2 adds JWT validation middleware to this chain.

- [ ] **Step 1: Write content/phase2/day16.md** covering:
  - What Synapse is: WSO2's mediation engine inside the gateway. Processes messages through a sequence of handlers (mediators). NOT a traditional HTTP reverse proxy — it has a message context model.
  - WSO2 source reading: `SynapseMessageContext.java`, `AbstractMediator.java`, `APIAuthenticationHandler.java`
  - Key insight: the gateway handler chain runs BEFORE the backend call. Each handler can short-circuit (return 401/429) or pass to the next handler.
  - Handler execution order in WSO2 GW: APIAuthenticationHandler → ThrottleHandler → AnalyticsHandler → backend
  - The Go equivalent: `http.Handler` middleware chain using the standard `func(next http.Handler) http.Handler` pattern
  - Exercises (3): (1) Find in source which handler short-circuits a 401 — Hint: APIAuthenticationHandler.handleRequest; (2) What is the WSO2 message context equivalent in Go? — Hint: `*http.Request` + context.Context; (3) Draw the handler chain for a valid API call — Hint: Auth → Throttle → Analytics → backend

- [ ] **Step 2: Write content/phase2/day17.md** covering:
  - Building a Go reverse proxy: `net/http/httputil.ReverseProxy`
  - How `ReverseProxy` works: `Director` func modifies the request, `ModifyResponse` handles the response
  - Adding a middleware chain: define `type Middleware func(http.Handler) http.Handler`, chain with `Chain(handler, m1, m2, m3)`
  - Request ID header: add `X-Request-ID` to every proxied request (correlation)
  - WSO2 GW adds: `activityid` header to upstream requests (maps to correlation ID)
  - Exercises (3): (1) Write a logging middleware that logs method, path, duration — Hint: record time.Now() before calling next, log after; (2) Write a `Chain` function that applies middlewares right-to-left — Hint: iterate in reverse; (3) What does `ReverseProxy.Director` do if you want to rewrite the host header? — Hint: `req.Host = target.Host`

- [ ] **Step 3: Write content/phase2/day18.md** covering:
  - Combining reverse proxy + middleware chain into a working gateway skeleton
  - Request flow: client → middleware chain → ReverseProxy → backend
  - Graceful shutdown: `http.Server.Shutdown(ctx)` with OS signal handling
  - Health check endpoint at `/health` that doesn't go through the middleware chain
  - WSO2 GW health check path: `GET /services/Version` (note for production reference)
  - Exercises (3): (1) Add a recovery middleware that catches panics and returns 500 — Hint: `defer func() { if r := recover(); r != nil { ... } }()`; (2) Add the `activityid` header to every proxied request — Hint: Director func; (3) Implement graceful shutdown — Hint: listen for `os.Interrupt` via `signal.NotifyContext`

- [ ] **Step 4: Write labs/phase2/day16/README.md** — source walk: find `APIAuthenticationHandler.java` in `wso2am-universal-gw-4.7.0`; find the `handleRequest` method; identify which Java class short-circuits with a 401 vs passes to the next handler.

- [ ] **Step 5: Write labs/phase2/day17/main.go** — minimal Go reverse proxy with a middleware chain:

```go
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"time"
)

type Middleware func(http.Handler) http.Handler

// Chain applies middlewares in order: Chain(h, m1, m2) → m1(m2(h))
func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("request", "method", r.Method, "path", r.URL.Path, "duration_ms", time.Since(start).Milliseconds())
	})
}

func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Request-ID") == "" {
			r.Header.Set("X-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
		}
		next.ServeHTTP(w, r)
	})
}

func newReverseProxy(target string) *httputil.ReverseProxy {
	u, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(u)
	original := proxy.Director
	proxy.Director = func(req *http.Request) {
		original(req)
		req.Host = u.Host
		// WSO2 GW sets activityid on upstream requests for correlation
		req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
	}
	return proxy
}

func main() {
	backendURL := os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://localhost:8080"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "9090"
	}

	proxy := newReverseProxy(backendURL)
	gateway := Chain(proxy, requestIDMiddleware, loggingMiddleware)

	mux := http.NewServeMux()
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"UP"}`)
	}))
	mux.Handle("/", gateway)

	srv := &http.Server{Addr: ":" + port, Handler: mux}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go func() {
		slog.Info("gateway starting", "port", port, "backend", backendURL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "err", err)
		}
	}()
	<-ctx.Done()
	slog.Info("shutting down")
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(shutCtx)
}
```

- [ ] **Step 6: Write labs/phase2/day17/README.md** — run with `BACKEND_URL=http://httpbin.org go run main.go`, test with curl, observe slog output.
- [ ] **Step 7: Write labs/phase2/day17/SOLUTION.md** — show Chain applied right-to-left: m1(m2(h)) means m1 runs first, m2 runs second.
- [ ] **Step 8: Write labs/phase2/day17/teardown.md** — `Ctrl+C`, no containers.

- [ ] **Step 9: Write labs/phase2/day18/main.go** — extend day17 with:
  - Recovery middleware (catches panics, returns 500)
  - Graceful shutdown already in day17 (keep it)
  - `activityid` set in Director (already in day17 — demonstrate it's there)
  - A simple mock backend handler at `/mock` for testing without an external backend

- [ ] **Step 10: Write day18 README, SOLUTION.md, teardown.md** following day17 pattern.

- [ ] **Step 11: Verify** — all files exist, exercises have hints+solutions, lab dirs complete.

---

### Task 2: Days 19–21 — JWT Validation Middleware

**Files:**
- Create: `content/phase2/day19.md`, `day20.md`, `day21.md`
- Create: `labs/phase2/day19/README.md` (source reading)
- Create: `labs/phase2/day20/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase2/day21/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase2/day18/main.go` — gateway with middleware chain (copy pattern).
- Produces: `labs/phase2/day21/main.go` — gateway with JWT validation middleware using JWKS endpoint. Task 3 adds subscription check middleware.

- [ ] **Step 1: Write content/phase2/day19.md** covering:
  - WSO2 GW JWT validation source: `JWTValidator.java`, `JWTValidatorImpl.java`
  - Validation steps WSO2 GW performs: (1) extract Bearer token, (2) decode header to get `kid`, (3) fetch public key from JWKS by kid, (4) verify signature, (5) check `exp`, (6) check `iss`, (7) extract subscription claims
  - JWKS caching: WSO2 GW caches the JWKS response — key rotation requires cache invalidation
  - WSO2 claim the GW uses for subscription: `http://wso2.org/claims/applicationname`, `http://wso2.org/claims/subscriber`
  - Exercises (3) with hints+solutions

- [ ] **Step 2: Write content/phase2/day20.md** covering:
  - Building a JWKS-backed JWT validator in Go: fetch `/oauth2/jwks`, parse the JWK, build an RSA public key
  - Caching the parsed public key in a `sync.Map` keyed by `kid`
  - The `kid` rotation problem: if the gateway caches the key and IS rotates it, validation fails — solution: on validation failure, re-fetch JWKS once before returning 401
  - Exercises (3) with hints+solutions

- [ ] **Step 3: Write content/phase2/day21.md** covering:
  - Wiring the JWT validator into the middleware chain
  - Adding the validated claims to the request context (typed context key)
  - What to do when JWKS endpoint is unreachable: fail open vs fail closed — WSO2 GW fails closed (401)
  - End-to-end test: Go KM from Phase 1 issues a JWT, Go gateway validates it
  - Exercises (3) with hints+solutions

- [ ] **Step 4: Write labs/phase2/day19/README.md** — find `JWTValidatorImpl.java` in `wso2am-universal-gw-4.7.0`; trace the `validateToken` method; identify which step WSO2 uses to get the public key.

- [ ] **Step 5: Write labs/phase2/day20/main.go** — standalone gateway + JWKS-backed JWT validation middleware:

```go
package main

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type WSO2Claims struct {
	jwt.RegisteredClaims
	Subscriber      string `json:"http://wso2.org/claims/subscriber"`
	ApplicationName string `json:"http://wso2.org/claims/applicationname"`
	ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
	APIVersion      string `json:"http://wso2.org/claims/version"`
	KeyType         string `json:"http://wso2.org/claims/keytype"`
}

type claimsKey struct{}

var jwksCache sync.Map // kid → *rsa.PublicKey

func fetchPublicKey(jwksURL, kid string) (*rsa.PublicKey, error) {
	resp, err := http.Get(jwksURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var set struct {
		Keys []struct {
			Kid string `json:"kid"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, err
	}
	for _, k := range set.Keys {
		if k.Kid == kid {
			nBytes, _ := base64.RawURLEncoding.DecodeString(k.N)
			eBytes, _ := base64.RawURLEncoding.DecodeString(k.E)
			pub := &rsa.PublicKey{
				N: new(big.Int).SetBytes(nBytes),
				E: int(new(big.Int).SetBytes(eBytes).Int64()),
			}
			jwksCache.Store(kid, pub)
			return pub, nil
		}
	}
	return nil, fmt.Errorf("kid %q not found in JWKS", kid)
}

func jwtValidationMiddleware(jwksURL string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenStr := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if tokenStr == "" {
				http.Error(w, `{"error":"missing_token"}`, http.StatusUnauthorized)
				return
			}
			// Parse without verification first to get the kid
			unverified, _, err := jwt.NewParser().ParseUnverified(tokenStr, &WSO2Claims{})
			if err != nil {
				http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
				return
			}
			kid, _ := unverified.Header["kid"].(string)

			// Try cached key, re-fetch on failure (handles key rotation)
			pub, _ := jwksCache.Load(kid)
			if pub == nil {
				pub, err = fetchPublicKey(jwksURL, kid)
				if err != nil {
					http.Error(w, `{"error":"jwks_unavailable"}`, http.StatusUnauthorized)
					return
				}
			}

			token, err := jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
				if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
					return nil, fmt.Errorf("unexpected alg: %v", t.Header["alg"])
				}
				return pub.(*rsa.PublicKey), nil
			})
			if err != nil {
				// Key may have rotated — re-fetch once
				newPub, ferr := fetchPublicKey(jwksURL, kid)
				if ferr != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
				token, err = jwt.ParseWithClaims(tokenStr, &WSO2Claims{}, func(t *jwt.Token) (any, error) {
					return newPub, nil
				})
				if err != nil {
					http.Error(w, `{"error":"invalid_token"}`, http.StatusUnauthorized)
					return
				}
			}

			claims := token.Claims.(*WSO2Claims)
			ctx := context.WithValue(r.Context(), claimsKey{}, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
```

- [ ] **Step 6: Write day20 README** — run the Phase 1 Go KM alongside this gateway; test end-to-end.
- [ ] **Step 7: Write day20 SOLUTION.md, teardown.md**.

- [ ] **Step 8: Write labs/phase2/day21/main.go** — wire `jwtValidationMiddleware` into the full gateway chain from day18. Add a `/api/info` endpoint that returns the claims from context to show validation is working.

- [ ] **Step 9: Write day21 README, SOLUTION.md, teardown.md** — README includes docker-compose that starts both the Phase 1 KM and this gateway.

- [ ] **Step 10: Verify** — all files exist, exercises have hints+solutions, lab dirs complete.

---

### Task 3: Days 22–24 — Subscription Enforcement

**Files:**
- Create: `content/phase2/day22.md`, `day23.md`, `day24.md`
- Create: `labs/phase2/day22/README.md` (source reading)
- Create: `labs/phase2/day23/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase2/day24/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase2/day21/main.go` — gateway with JWT validation.
- Produces: `labs/phase2/day24/main.go` — gateway with subscription check middleware. Task 4 adds throttle middleware.

- [ ] **Step 1: Write content/phase2/day22.md** covering:
  - WSO2 GW subscription validation: after JWT validation, the GW checks the `applicationname` claim against its local subscription data store
  - WSO2 source: `APIKeyValidationService.java`, `SubscriptionDataStore.java`
  - Data sync: CP pushes subscription data to GW via event hub (JMS topics); GW holds an in-memory store
  - What's in the subscription store: {applicationName, apiName, apiVersion, subscriptionTier, keyType}
  - Exercises (3) with hints+solutions

- [ ] **Step 2: Write content/phase2/day23.md** covering:
  - Building the subscription store in Go: `map[string]SubscriptionRecord` (keyed by applicationName+apiName)
  - Subscription middleware: read claims from context, look up subscription, reject with 403 if not found
  - Simulating CP→GW data sync: a `/admin/subscriptions` endpoint to add/remove subscriptions at runtime
  - Exercises (3) with hints+solutions

- [ ] **Step 3: Write content/phase2/day24.md** covering:
  - End-to-end: JWT validation + subscription check
  - What WSO2 GW returns for a valid JWT but no subscription: 403 with `{"code":"900908","message":"Resource forbidden"}`
  - The subscription tier from the JWT claim maps to throttle policy (preview for Task 4)
  - Exercises (3) with hints+solutions

- [ ] **Step 4: Write labs/phase2/day22/README.md** — find `SubscriptionDataStore.java` in the GW source; find the method that checks if an application is subscribed; identify the data structure it uses.

- [ ] **Step 5: Write labs/phase2/day23/main.go** — gateway with subscription middleware:

```go
type SubscriptionRecord struct {
	ApplicationName string
	APIName         string
	SubscriptionTier string
	KeyType         string
}

// subscriptionStore: key = "appName::apiName"
var subscriptionStore sync.Map

func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
			if !ok || claims == nil {
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`, http.StatusForbidden)
				return
			}
			key := claims.ApplicationName + "::" + apiName
			if _, found := subscriptionStore.Load(key); !found {
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`, http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
```

- [ ] **Step 6: Write labs/phase2/day23 README, SOLUTION.md, teardown.md**.

- [ ] **Step 7: Write labs/phase2/day24/main.go** — full gateway: JWT validation + subscription check + `/admin/subscriptions` POST endpoint + `/api/hello` protected route.

- [ ] **Step 8: Write day24 README, SOLUTION.md, teardown.md**.

- [ ] **Step 9: Verify** — exercises have hints+solutions, lab dirs complete.

---

### Task 4: Days 25–27 — Throttle + Traffic Manager Client

**Files:**
- Create: `content/phase2/day25.md`, `day26.md`, `day27.md`
- Create: `labs/phase2/day25/README.md` (source reading)
- Create: `labs/phase2/day26/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase2/day27/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase2/day24/main.go` — gateway with subscription check.
- Produces: `labs/phase2/day27/main.go` — gateway with token-bucket throttle middleware and a mock TM client. Task 5 adds GW debug patterns.

- [ ] **Step 1: Write content/phase2/day25.md** covering:
  - WSO2 Traffic Manager: a separate process that holds throttle policy execution plans
  - WSO2 GW throttle flow: GW has a local counter; when it breaches, it sends a throttle event to TM; TM makes the global decision
  - WSO2 source: `ThrottleHandler.java`, `GlobalThrottleEngineClient.java`
  - Throttle tiers in WSO2: Gold (5000/min), Silver (2000/min), Bronze (1000/min), Unlimited
  - Token bucket algorithm: capacity C, refill rate R — on each request consume 1 token; if bucket empty, return 429
  - Exercises (3) with hints+solutions

- [ ] **Step 2: Write content/phase2/day26.md** covering:
  - Implementing a token-bucket throttle middleware in Go
  - Per-application buckets: keyed by `claims.ApplicationName`
  - The `golang.org/x/time/rate` package: `rate.NewLimiter(r, b)`, `limiter.Allow()`
  - WSO2 GW 429 response format: `{"code":"900801","message":"Application level throttle limit exceeded"}`
  - Exercises (3) with hints+solutions

- [ ] **Step 3: Write content/phase2/day27.md** covering:
  - The TM client in production: GW sends throttle events to TM via HTTP; TM maintains global counts across GW replicas
  - In a single-replica setup (your company's dev): the local bucket is sufficient
  - In a multi-replica ECS Fargate setup: need a shared store (Redis or the TM) for accurate global throttling
  - Mock TM client: accepts throttle events, logs them, always returns "not throttled" (for lab purposes)
  - Exercises (3) with hints+solutions

- [ ] **Step 4: Write labs/phase2/day25/README.md** — find `ThrottleHandler.java` in GW source; find the method that calls the TM; identify the data sent in the throttle event.

- [ ] **Step 5: Write labs/phase2/day26/main.go** — gateway with per-application token-bucket throttle:

```go
import "golang.org/x/time/rate"

// throttleLimiters: appName → *rate.Limiter
var throttleLimiters sync.Map

func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
	key := appName + "::" + tier
	if l, ok := throttleLimiters.Load(key); ok {
		return l.(*rate.Limiter)
	}
	// Map tier to requests/second
	rps := map[string]rate.Limit{
		"Gold":      rate.Limit(5000.0 / 60),
		"Silver":    rate.Limit(2000.0 / 60),
		"Bronze":    rate.Limit(1000.0 / 60),
		"Unlimited": rate.Inf,
	}
	r, ok := rps[tier]
	if !ok {
		r = rate.Limit(10) // default conservative
	}
	l := rate.NewLimiter(r, int(r*60)) // burst = 1 minute worth
	throttleLimiters.Store(key, l)
	return l
}

func throttleMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
		if !ok {
			next.ServeHTTP(w, r)
			return
		}
		limiter := getOrCreateLimiter(claims.ApplicationName, claims.ApplicationTier)
		if !limiter.Allow() {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			fmt.Fprint(w, `{"code":"900801","message":"Application level throttle limit exceeded"}`)
			return
		}
		next.ServeHTTP(w, r)
	})
}
```

- [ ] **Step 6: Write day26 README, SOLUTION.md, teardown.md**. README: `go get golang.org/x/time/rate`.

- [ ] **Step 7: Write labs/phase2/day27/main.go** — complete gateway: JWT + subscription + throttle + mock TM client (an HTTP handler that accepts POST `/throttle/data` and logs it).

- [ ] **Step 8: Write day27 README, SOLUTION.md, teardown.md**.

- [ ] **Step 9: Verify** — exercises have hints+solutions, lab dirs complete.

---

### Task 5: Days 28–30 — GW log4j2 Debug Patterns + Playbook

**Files:**
- Create: `content/phase2/day28.md`, `day29.md`, `day30.md`
- Create: `labs/phase2/day28/README.md`, `SOLUTION.md`, `teardown.md` (source reading)
- Create: `labs/phase2/day29/log_samples/`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase2/day30/playbook.md`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Produces: `labs/phase2/day30/playbook.md` — GW debug runbook (mirror of IS playbook from Phase 1 Day 15).

- [ ] **Step 1: Write content/phase2/day28.md** covering:
  - GW log4j2 config location: `wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties`
  - The 5 GW-specific loggers to enable for debugging:
    ```properties
    logger.org-wso2-carbon-apimgt-gateway.name=org.wso2.carbon.apimgt.gateway
    logger.org-wso2-carbon-apimgt-gateway.level=DEBUG
    logger.org-wso2-carbon-apimgt-gateway-handlers-security.name=org.wso2.carbon.apimgt.gateway.handlers.security
    logger.org-wso2-carbon-apimgt-gateway-handlers-security.level=DEBUG
    logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.name=org.wso2.carbon.apimgt.gateway.handlers.throttling
    logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.level=DEBUG
    ```
  - Exercises (3) with hints+solutions

- [ ] **Step 2: Write content/phase2/day29.md** covering:
  - GW log line patterns (6 patterns to memorize):
    1. JWT validation success: `DEBUG {JWTValidator} - JWT token validated successfully for application: [app]`
    2. JWT validation failure (expired): `WARN {JWTValidator} - JWT token validation failed: Token expired`
    3. JWT validation failure (bad sig): `WARN {JWTValidator} - JWT token validation failed: Signature verification failed`
    4. Subscription not found: `WARN {APIAuthenticationHandler} - API subscription not found for application: [app]`
    5. Throttle limit exceeded: `WARN {ThrottleHandler} - Request throttled for application: [app], tier: [tier]`
    6. JWKS key not found: `WARN {JWTValidator} - Public key not found for kid: [kid]`
  - Exercises (3) with hints+solutions

- [ ] **Step 3: Write content/phase2/day30.md** covering:
  - Phase 2 capstone: "given a 401/403/429 from the gateway, trace it in 3 minutes"
  - ECS Fargate GW debugging: pull logs from CloudWatch, filter by correlation ID (`activityid`)
  - The IS-GW split in production: IS logs show token issuance problems; GW logs show validation/subscription/throttle problems
  - Phase 2 completion recap table
  - Exercises (3) with hints+solutions

- [ ] **Step 4: Write labs/phase2/day28/README.md, SOLUTION.md, teardown.md** — source reading: find the 5 GW loggers in the checkout.

- [ ] **Step 5: Write labs/phase2/day29/** — synthetic log file + analysis:
  - `log_samples/gw_failure.log` — 20 realistic lines covering: JWT validation success, then an expired-token 401, then a subscription-not-found 403, then a throttle 429
  - `README.md`: "Given gw_failure.log, answer: (1) which request succeeded? (2) what was the failure reason for the 401? (3) which app hit the subscription wall? (4) which tier was throttled?"
  - `SOLUTION.md`: answers quoting specific log lines
  - `teardown.md`

- [ ] **Step 6: Write labs/phase2/day30/playbook.md** — GW debug runbook:

```markdown
# WSO2 GW Debug Playbook — Phase 2

## First-response checklist (401/403/429 from gateway)
- [ ] Check GW is UP: `curl https://<gw-host>:8243/health`
- [ ] Enable DEBUG logging: update GW log4j2.properties with security + throttling loggers
- [ ] Pull GW logs: `docker logs <container> 2>&1 | grep -E "(ERROR|WARN|DEBUG.*JWT|DEBUG.*throttl)"`
- [ ] Get correlation ID from the error response header: `activityid`
- [ ] Search GW logs: `grep <activityid> wso2carbon.log`
- [ ] If nothing in GW logs: check IS logs — token may have failed at issuance

## GW error decision tree
```
4xx from gateway
├── 401 Unauthorized
│   ├── "Token expired" in logs → token TTL exceeded (issue new token)
│   ├── "Signature verification failed" → JWKS kid mismatch (IS key rotated?)
│   ├── "Public key not found for kid" → GW JWKS cache stale → restart GW or clear cache
│   └── No GW logs at all → token never reached GW (check client, ALB, network)
├── 403 Forbidden
│   ├── "subscription not found" → app not subscribed to this API in CP
│   └── "keytype SANDBOX vs PRODUCTION" → using sandbox key against production endpoint
└── 429 Too Many Requests
    ├── "Application level throttle limit exceeded" → app tier breached
    └── "API level throttle limit exceeded" → API-wide limit breached (affects all apps)
```

## Key log patterns
| Pattern | Meaning | Action |
|---|---|---|
| `WARN {JWTValidator} - JWT token validation failed: Token expired` | Token TTL exceeded | Client must issue a new token |
| `WARN {JWTValidator} - Signature verification failed` | Key mismatch or tampered JWT | Check JWKS kid; check if IS restarted |
| `WARN {JWTValidator} - Public key not found for kid` | GW JWKS cache stale | Restart GW container or hit JWKS refresh endpoint |
| `WARN {APIAuthenticationHandler} - API subscription not found` | App not subscribed | Register subscription in CP admin UI |
| `WARN {ThrottleHandler} - Request throttled` | Tier limit hit | Wait for bucket refill; or upgrade subscription tier |

## IS vs GW log split
| Symptom | Check first | Secondary check |
|---|---|---|
| Token never issued | IS logs (`OAuthClientAuthn`, `OAuth2`) | N/A |
| Token issued but 401 at GW | GW logs (`JWTValidator`) | IS logs for key rotation |
| Token valid but 403 | GW logs (`APIAuthenticationHandler`) | CP subscription data |
| Intermittent 429 | GW logs (`ThrottleHandler`) | TM logs for global counter |

## ECS Fargate GW gotchas
- GW log4j2 changes require ECS task restart — no hot-reload in containerised deployments.
- `activityid` header: set by client or ALB; carried through all GW logs for that request.
- GW health path: `GET /services/Version` (legacy) or `GET /health` (custom endpoint).
- JWKS URL config: `[apim.jwt]` section in `deployment.toml` → `jwks_url`.
```

- [ ] **Step 7: Write day30 README, SOLUTION.md, teardown.md** — README: run the Day 27 gateway, generate some errors, use the playbook to diagnose them.

- [ ] **Step 8: Verify** — exercises have hints+solutions, log_samples file has all 4 scenarios, playbook.md exists and complete.

---

## Self-Review Checklist

- [ ] Every exercise in every day file has `**Hint:**` and `**Solution sketch:**`.
- [ ] Every lab directory has README.md, source file(s) or log file, SOLUTION.md, teardown.md.
- [ ] No real credentials, AWS account IDs, or secrets in any file.
- [ ] No `git commit`, `git add`, or `git status` commands in any step.
- [ ] Day file structure matches the skeleton from the spec.
- [ ] Go code imports `golang.org/x/time/rate` in Task 4 labs.
- [ ] `labs/phase2/day30/playbook.md` exists with the full GW decision tree.
- [ ] Content in `content/phase2/` is in `phase2/` subdirectory, not `phase1/`.
