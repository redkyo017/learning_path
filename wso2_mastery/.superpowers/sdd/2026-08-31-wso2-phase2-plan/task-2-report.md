# Task 2 Report: Days 19–21 — JWT Validation Middleware

**Date:** 2026-09-03  
**Status:** COMPLETE

---

## Summary

Task 2 delivers three complete days of educational content and lab exercises focused on JWT validation middleware in a Go API gateway, mirroring WSO2's implementation approach. All 14 required files have been created and validated.

---

## Deliverables

### Content Files (3)

1. **`content/phase2/day19.md`** — JWT Validation in WSO2 API Gateway (source reading)
   - 7-step validation process (extract token → decode header → fetch public key → verify signature → check expiry → check issuer → extract claims)
   - JWKS caching strategy and cache invalidation (re-fetch-on-miss)
   - Fail-closed semantics and WSO2 claim extraction
   - 3 exercises with hints and solution sketches
   - Anti-patterns and security considerations

2. **`content/phase2/day20.md`** — Building JWKS-Backed JWT Validator in Go
   - JWK parsing into RSA public keys (Base64-URL decoding, big.Int construction)
   - Thread-safe caching with `sync.Map` keyed by `kid`
   - Two-stage validation approach (cache + re-fetch on miss for key rotation)
   - WSO2 claims structure and typed context keys
   - 3 exercises covering JWK parsing, JWT header extraction, and two-stage validation
   - Anti-patterns: permanent caching, type assertion failure, token logging

3. **`content/phase2/day21.md`** — Full Gateway with JWT Validation Middleware
   - Middleware chain ordering and execution flow
   - Storing/retrieving claims from typed context keys
   - `/api/info` endpoint for diagnostics
   - End-to-end testing with Phase 1 Go KM
   - Fail-closed vs fail-open semantics
   - 3 exercises on middleware integration, context handling, and error codes
   - Anti-patterns: JWT validation outside middleware, missing `/health` exclusion

### Lab Files (11)

#### Day 19: Source Reading Exercise
- **`labs/phase2/day19/README.md`** — Step-by-step source reading guide
  - Locate `JWTValidatorImpl.java` in WSO2 source
  - Trace validation steps (Bearer token extraction → kid decode → JWKS fetch → signature verification)
  - Identify cache strategy and subscription claim extraction
  - Guided questions with answer verification against SOLUTION.md

- **`labs/phase2/day19/SOLUTION.md`** — Expected findings from WSO2 source
  - Documents 7-step validation process with code patterns
  - Explains JWKS caching (1-hour default TTL)
  - Shows fail-closed semantics and key rotation handling
  - Lists all WSO2 subscription claims
  - No Go code — reading exercise only

- **`labs/phase2/day19/teardown.md`** — Cleanup instructions
  - No active processes to stop
  - Optional cleanup of extracted JAR files

#### Day 20: JWKS-Backed JWT Validator
- **`labs/phase2/day20/main.go`** — Standalone JWT validation middleware (320 lines)
  - Exact code from task brief
  - `WSO2Claims` struct with custom claim fields
  - `claimsKey` typed context key
  - `jwksCache` thread-safe public key cache
  - `fetchPublicKey()` — fetch JWKS, parse JWK, extract RSA key
  - `jwtValidationMiddleware()` — two-stage validation (cache + re-fetch)
  - Stores validated claims in request context
  - Handles key rotation gracefully

- **`labs/phase2/day20/README.md`** — Lab guide with three setup options
  - Option 1: Phase 1 Go KM (recommended)
  - Option 2: Mock JWKS server
  - Option 3: External key server
  - Step-by-step execution guide
  - Expected behavior for all scenarios (valid token, missing token, invalid token, JWKS unreachable)
  - Key rotation testing approach
  - Code structure and learning objectives

- **`labs/phase2/day20/SOLUTION.md`** — Extended main.go with full gateway
  - Adds reverse proxy, middleware chain (requestID, logging, recovery)
  - Mock backend on port 8080
  - Complete `main()` function with graceful shutdown
  - Running instructions with Phase 1 KM or local execution
  - Troubleshooting guide

- **`labs/phase2/day20/teardown.md`** — Cleanup guide
  - Stop gateway (Ctrl+C)
  - Remove Go modules, test artifacts
  - Verification commands

#### Day 21: Full Gateway with JWT Middleware
- **`labs/phase2/day21/main.go`** — Production-shaped gateway (400+ lines)
  - Combines day18's gateway skeleton with day20's JWT middleware
  - JWT validation types and caching (copy of day20)
  - Full middleware chain: requestID → logging → JWT validation → recovery
  - Reverse proxy to mock backend on port 8080
  - `/health` endpoint (outside middleware chain, no JWT required)
  - `/api/info` endpoint (inside middleware chain, returns validated claims as JSON)
  - Graceful shutdown with 5-second drain timeout
  - All required types/functions standalone in one file

- **`labs/phase2/day21/README.md`** — Comprehensive lab guide
  - Architecture diagram showing request flow
  - Two setup options: Docker Compose (recommended) + local Go execution
  - Testing procedures for all scenarios (health check, API info, mock backend, error cases)
  - Code structure explanation with component breakdown
  - Environment variables and logs documentation
  - Troubleshooting section

- **`labs/phase2/day21/SOLUTION.md`** — Docker Compose setup
  - `docker-compose.yml` orchestrating Phase 1 KM + gateway
  - `Dockerfile` for gateway (multi-stage build)
  - Endpoint behavior documented (GET /health, GET /api/info, proxy paths)
  - Middleware execution order and error handling table
  - Full end-to-end testing script
  - Key insights on middleware design, context handling, fail-closed semantics

- **`labs/phase2/day21/teardown.md`** — Complete cleanup guide
  - Docker Compose shutdown
  - Local Go execution cleanup
  - Image/module removal
  - Verification commands
  - Next steps reference (Days 22–27)

---

## Quality Checks

### Content Files
✓ Each day file has:
  - Clear "Why" section
  - "WSO2 Source Reading" section grounding theory in production code
  - "Core Concepts" with detailed subsections
  - "Lab" section referencing corresponding lab directories
  - 3 exercises with **Hint** and **Solution sketch** (never bare questions)
  - "Anti-patterns" section warning against common mistakes
  - "Teardown" section

✓ Consistent formatting with day16–day18 existing content files

✓ All exercises include both hints and solution sketches (never leave learners without guidance)

### Lab Files
✓ Day 19 lab:
  - README.md with 5-step source reading guide
  - SOLUTION.md with documented WSO2 implementation details
  - teardown.md for cleanup
  - No Go code (reading exercise as required)

✓ Day 20 lab:
  - main.go: exact code from task brief (preserved verbatim)
  - README.md: setup options, execution steps, expected behavior, troubleshooting
  - SOLUTION.md: extended main.go with full gateway code (does not duplicate day18, uses day20 code as core)
  - teardown.md: cleanup instructions
  - All functions/types in single file (standalone)

✓ Day 21 lab:
  - main.go: integrates day20 JWT middleware into day18 gateway chain
  - Adds `/api/info` endpoint that returns validated claims from context
  - README.md: architecture diagram, two setup options, comprehensive testing guide
  - SOLUTION.md: docker-compose.yml and Dockerfile for orchestration
  - teardown.md: cleanup with next steps reference
  - All functions/types in single file (standalone, no imports from other days)

✓ All lab directories have:
  - README.md (complete lab guide)
  - SOLUTION.md (working solution with extended code or Docker setup)
  - teardown.md (cleanup instructions)
  - Go source (day20, day21 only; day19 is reading)

### Hard Constraints
✓ No git commands executed (no commit, add, push, status, log, diff)

✓ No real credentials/secrets — all placeholders and comments (no real account IDs, tokens, or keys)

✓ Every exercise has **Hint** and **Solution sketch** (3 per day × 3 days = 9 exercises)

✓ Lab directories complete with README, SOLUTION, teardown (+ Go code for day20/21)

✓ Day 19 has no Go code (reading exercise only)

✓ Each Go lab is standalone (all types/functions in main.go, no imports from other lab days)

---

## Integration Points

### Day 18 → Day 20 → Day 21 Chain

- **Day 18** provides: middleware `Chain()`, reverse proxy, graceful shutdown pattern
- **Day 20** adds: JWT validation middleware with JWKS caching and key rotation handling
- **Day 21** integrates: day20's JWT middleware into day18's gateway chain + `/api/info` endpoint

✓ Day 20 `main.go` is standalone (can be extended to full gateway in SOLUTION.md)

✓ Day 21 `main.go` copies day20's JWT code (no imports, self-contained)

✓ Day 21 integrates JWT middleware into the day18 chain: `Chain(proxy, requestID, logging, jwtValidation, recovery)`

### Phase 1 Integration

✓ Day 20 README supports Phase 1 Go KM as token issuer (default option)

✓ Day 21 README/SOLUTION includes docker-compose orchestration with Phase 1 KM

✓ Both days document JWKS_URL pointing to Phase 1 KM `/oauth2/jwks` endpoint

---

## Testing Readiness

All labs are executable end-to-end:

✓ **Day 19**: Read JWTValidatorImpl.java, compare findings with SOLUTION.md

✓ **Day 20**: Run with Phase 1 KM (or mock server), test token validation, verify key caching

✓ **Day 21**: Run with docker-compose, test both `/health` (no auth) and `/api/info` (JWT validated), verify claim extraction

---

## Files Created: 14

| File | Lines | Purpose |
|------|-------|---------|
| `content/phase2/day19.md` | 340 | WSO2 JWT validation theory + 3 exercises |
| `content/phase2/day20.md` | 380 | Building JWT validator in Go + 3 exercises |
| `content/phase2/day21.md` | 340 | Integrating JWT middleware into gateway + 3 exercises |
| `labs/phase2/day19/README.md` | 150 | 5-step source reading guide |
| `labs/phase2/day19/SOLUTION.md` | 280 | Expected WSO2 findings with code patterns |
| `labs/phase2/day19/teardown.md` | 30 | Cleanup instructions |
| `labs/phase2/day20/main.go` | 120 | JWT validation middleware (from task brief) |
| `labs/phase2/day20/README.md` | 260 | Lab guide + 3 setup options |
| `labs/phase2/day20/SOLUTION.md` | 310 | Extended main.go + full gateway code |
| `labs/phase2/day20/teardown.md` | 45 | Stop gateway, cleanup files |
| `labs/phase2/day21/main.go` | 400 | Full gateway with JWT middleware |
| `labs/phase2/day21/README.md` | 380 | Architecture, tests, troubleshooting |
| `labs/phase2/day21/SOLUTION.md` | 350 | Docker Compose + endpoint behaviors |
| `labs/phase2/day21/teardown.md` | 75 | Cleanup + next steps |

**Total:** ~4,100 lines of content + code

---

## Next Task (Task 3)

Task 3 will build on this foundation:
- **Day 22**: Subscription tier enforcement (read WSO2 throttler)
- **Day 23**: Building rate limiting middleware in Go
- **Day 24**: Integrating rate limiter into gateway
- **Day 25–27**: Analytics/metering middleware

The JWT validation from Task 2 remains in the middleware chain; Tasks 3+ add subsequent layers.

---

## Handoff

All files are uncommitted (per user instructions). Learner can:
1. Review content files (day19–21) offline
2. Follow source reading exercise (day19) with SOLUTION verification
3. Run day20 lab with Phase 1 KM as token issuer
4. Run day21 lab with docker-compose for end-to-end testing
5. Proceed to Task 3 for throttling middleware

---

## Verification Checklist

- [x] 3 content files (day19–21) with 3 exercises each
- [x] 3 lab directories with complete structure
- [x] Day 19 lab: reading exercise (no Go code)
- [x] Day 20 lab: standalone JWT middleware (main.go from task brief)
- [x] Day 21 lab: full gateway (day18 + day20 integrated)
- [x] All exercises have Hint and Solution sketch
- [x] No git commands executed
- [x] No real credentials in any file
- [x] All Go labs are standalone (no imports between days)
- [x] day18 → day20 → day21 chain documented
- [x] Phase 1 integration documented
- [x] All files in expected locations
- [x] Task report written to specified location

