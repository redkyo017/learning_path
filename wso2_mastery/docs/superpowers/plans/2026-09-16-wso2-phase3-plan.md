# WSO2 Mastery Phase 3 — Control Plane + Event Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author all content and lab files for Phase 3 (Days 31–45): Go Control Plane REST API with lifecycle management, subscription management, event-driven sync to the Gateway via Go channels + SSE, ECS Fargate Terraform modules, and a full Docker Compose smoke test.

**Architecture:** Five 3-day blocks: Days 31–33 build a Go Control Plane (API registry CRUD + lifecycle state machine); Days 34–36 add subscription + application management with a GW validation endpoint; Days 37–39 add a Go channel event bus with SSE streaming so the Phase 2 Gateway subscribes to CP state changes; Days 40–42 write Terraform HCL for ECS Fargate (authored only, not applied); Days 43–45 wire all four Go services in Docker Compose, run a smoke test script, and write a personal runbook. Each Go lab file is STANDALONE — all types and functions in the same file.

**Tech Stack:** Go 1.22+, `net/http`, `encoding/json`, `sync.RWMutex`, `crypto/rand`. Terraform ≥1.5 (HCL only). Docker Compose v2. No external Go dependencies added in Phase 3 — Go channels replace JMS for the event bus.

**Spec:** `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`

## Global Constraints

- No `git commit`, `git add`, `git push`, `git status`, `git log`, or `git diff` in any subagent dispatch.
- No real credentials, AWS account IDs, or tokens in any file — use placeholder comments (`# TODO: replace with real value`).
- No `terraform apply` or live cloud commands — labs are authored, not run.
- Every exercise ships with **Hint** + **Solution sketch** — never a bare question.
- Every Go lab directory ships with: `README.md`, `main.go`, `SOLUTION.md`, `teardown.md`.
- Every Terraform lab directory ships with: `README.md`, `main.tf`, `variables.tf`, `outputs.tf`, `teardown.md`.
- WSO2 APIM ACP source: `/Users/hunghan/Downloads/wso2am-acp-4.7.0`
- Each Go lab file is STANDALONE — all types and functions defined in the same file; no imports from other lab days.

---

### Task 0: Scaffold Phase 3 directories

**Files:**
- Create: `wso2_mastery/content/phase3/.gitkeep`
- Create: `wso2_mastery/labs/phase3/.gitkeep`

- [ ] **Step 1:** Create `wso2_mastery/content/phase3/.gitkeep` (empty file)
- [ ] **Step 2:** Create `wso2_mastery/labs/phase3/.gitkeep` (empty file)

---

### Task 1: Days 31–33 — API Lifecycle + Publisher Flow

**Files:**
- Create: `content/phase3/day31.md`, `day32.md`, `day33.md`
- Create: `labs/phase3/day31/README.md` (source reading — no Go)
- Create: `labs/phase3/day32/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase3/day33/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: nothing — first Phase 3 task.
- Produces: `labs/phase3/day33/main.go` — HTTP server on `:8082` with endpoints: `POST /apis`, `GET /apis`, `GET /apis/{id}`, `DELETE /apis/{id}`, `POST /apis/{id}/lifecycle`, `GET /apis/{id}/policies`, `PUT /apis/{id}/tiers`, `GET /health`. Task 3 adds `/events` SSE and `/admin/sync` to this server.

- [ ] **Step 1: Write content/phase3/day31.md** covering:
  - **Why this matters:** The Control Plane is the single source of truth for all API metadata. Understanding how WSO2 models API lifecycle tells you exactly which component to debug when an API isn't reachable at the gateway.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APIProviderImpl.java"` — focus on `addAPI()` (creates entry in DB) and `changeLifeCycleStatus()` (transitions state and fires a notification event).
  - **Key insight:** WSO2 API lifecycle is a state machine defined in `APILifeCycle.xml`. Transitions: CREATED → PUBLISHED → DEPRECATED → RETIRED. An API must be PUBLISHED before the GW routes traffic to it. The GW only learns about the publish via an event fired by `changeLifeCycleStatus`.
  - **Core concepts:** Publisher flow end-to-end: publisher portal → `POST /apis` → insert into `AM_API` table → `changeLifeCycleStatus(PUBLISHED)` → `NotificationsPublisher` fires event → GW receives event and activates the route. The `context` field (e.g. `/petstore/v1`) is what the GW uses for routing — it is not the API name.
  - **Exercises** (3):
    1. In `APIProviderImpl.java`, which method fires the notification after a publish? — **Hint:** search for `NotificationsPublisher` inside `changeLifeCycleStatus` — **Solution sketch:** `changeLifeCycleStatus` calls `notificationsPublisher.publishNotification()` after updating the DB status row.
    2. What is the difference between `APIProvider.addAPI()` and `changeLifeCycleStatus()`? — **Hint:** one creates, one transitions — **Solution sketch:** `addAPI()` inserts metadata (name, context, version, endpoint URL) in CREATED state; `changeLifeCycleStatus()` moves an existing record to PUBLISHED/DEPRECATED/RETIRED.
    3. WSO2 blocks publishing an API with no endpoint — where is that validation? — **Hint:** look for `validateAPI()` in `APIProviderImpl` — **Solution sketch:** `validateAPI()` is called before `addAPI()` and checks that endpoint URLs are non-null; publishing without a backend URL returns a validation error.
  - **Anti-patterns:** (1) Calling the GW before publishing — GW ignores CREATED-state APIs; (2) Assuming "deployed to GW" = "published" — deploying a revision is separate from the lifecycle transition; (3) Skipping endpoint validation — WSO2 rejects publish if `backendUrl` is empty.

- [ ] **Step 2: Write content/phase3/day32.md** covering:
  - **Why this matters:** Building the CP API registry forces you to encode every WSO2 design decision in Go — the state machine, the validation rules, the response shapes.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APIConsumerImpl.java"` — find `getAPI(id)`; note it returns a full API object including `status` and `availableTiers`.
  - **Core concepts:** `LifecycleStatus` as a typed string; `validTransitions` map mirrors `APILifeCycle.xml`; API struct: `{ID, Name, Context, Version, BackendURL, Status, AllowedTiers, CreatedAt}`; CRUD with `sync.RWMutex` over `map[string]*API`; lifecycle endpoint validates the transition before applying; cannot publish with empty `AllowedTiers`.
  - **Lab:** `labs/phase3/day32/` — run the CP registry, create an API via curl, publish it, verify status changes.
  - **Exercises** (3):
    1. Add a `PUT /apis/{id}` endpoint that updates Name and BackendURL but not Status or Context — **Hint:** read the body into a patch struct; only overwrite non-empty fields — **Solution sketch:** `if body.Name != "" { api.Name = body.Name }`.
    2. What HTTP status should `POST /apis/{id}/lifecycle` return when the transition is invalid (e.g. CREATED→RETIRED)? — **Hint:** it is a client error, not a server error — **Solution sketch:** 400 Bad Request with a message like `"invalid transition: CREATED → RETIRED"`.
    3. Two goroutines call `POST /apis` concurrently — why is `sync.RWMutex` not enough for the write path? — **Hint:** a write lock is needed for the write path specifically — **Solution sketch:** `RWMutex.Lock()` (not `RLock()`) is used inside `createAPI`; `RLock` is only for reads; the code is correct as written.
  - **Anti-patterns:** (1) Using a plain `map` without a mutex — concurrent HTTP handlers cause data races; (2) Returning the old status before updating — always return the updated struct; (3) Generating IDs with `time.Now().UnixNano()` — collisions are possible under load; use `crypto/rand` or a UUID.

- [ ] **Step 3: Write content/phase3/day33.md** covering:
  - **Why this matters:** The tier/policy attachment bridges CP and GW — the GW reads allowed tiers from the CP to decide which subscription tiers are valid for a given API context.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "AbstractAPIManager.java"` — find `getAPI()` and look at how `availableTiers` is populated from the `AM_POLICY_SUBSCRIPTION` table join.
  - **Core concepts:** `GET /apis/{id}/policies` returns `AllowedTiers` as policy objects with descriptions; `PUT /apis/{id}/tiers` updates the tier list; a PUBLISHED API rejects tier changes (must deprecate first — mirrors WSO2 workflow).
  - **Exercises** (3):
    1. `PUT /apis/{id}/tiers` on a PUBLISHED API — what status code and why? — **Hint:** this is a business rule violation, not a missing resource — **Solution sketch:** 400 Bad Request with `"deprecate the API before changing tiers"`.
    2. Add a `DELETE /apis/{id}/tiers/{tier}` endpoint to remove one tier — **Hint:** filter the slice — **Solution sketch:** `newTiers := []string{}; for _, t := range api.AllowedTiers { if t != tier { newTiers = append(newTiers, t) } }`.
    3. `GET /apis/{id}/policies` returns `[]Policy` with a `description` field — where does WSO2 store the tier description in production? — **Hint:** find `AM_POLICY_SUBSCRIPTION` — **Solution sketch:** `AM_POLICY_SUBSCRIPTION.DESCRIPTION` column; the default tiers are seeded at install time.
  - **Anti-patterns:** (1) Allowing tier list changes while PUBLISHED without locking — a GW might use the old tier list between the change and the next event sync; (2) Returning `null` for an empty tier list instead of `[]` — JSON null breaks GW deserialisation.

- [ ] **Step 4: Write labs/phase3/day31/README.md** — source walk:
  ```
  # Day 31 — Source Reading Lab

  Goal: Trace the API lifecycle state machine in WSO2 APIM ACP source.

  ## Step 1: Find APIProviderImpl
  find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APIProviderImpl.java" | head -3

  ## Step 2: Trace lifecycle transition
  grep -n "changeLifeCycleStatus\|NotificationsPublisher\|validateAPI" <path> | head -20

  ## Step 3: Find the state machine config
  find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "APILifeCycle.xml"

  Answer in your "why" log:
  1. List the 4 lifecycle states and the allowed transitions between them.
  2. What does WSO2 validate before allowing CREATED→PUBLISHED?
  3. What event class does changeLifeCycleStatus fire, and what arguments does it pass?
  ```

- [ ] **Step 5: Write labs/phase3/day32/main.go**:

```go
package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"strings"
	"sync"
	"time"
)

type LifecycleStatus string

const (
	StatusCreated    LifecycleStatus = "CREATED"
	StatusPublished  LifecycleStatus = "PUBLISHED"
	StatusDeprecated LifecycleStatus = "DEPRECATED"
	StatusRetired    LifecycleStatus = "RETIRED"
)

// validTransitions mirrors WSO2 APILifeCycle.xml
var validTransitions = map[LifecycleStatus][]LifecycleStatus{
	StatusCreated:    {StatusPublished},
	StatusPublished:  {StatusDeprecated},
	StatusDeprecated: {StatusRetired},
}

type API struct {
	ID           string          `json:"id"`
	Name         string          `json:"name"`
	Context      string          `json:"context"`    // e.g. "/petstore/v1" — used by GW for routing
	Version      string          `json:"version"`
	BackendURL   string          `json:"backendUrl"`
	Status       LifecycleStatus `json:"status"`
	AllowedTiers []string        `json:"allowedTiers"` // Bronze, Silver, Gold, Unlimited
	CreatedAt    time.Time       `json:"createdAt"`
}

type Registry struct {
	mu   sync.RWMutex
	apis map[string]*API
}

func NewRegistry() *Registry { return &Registry{apis: make(map[string]*API)} }

func newID() string { return fmt.Sprintf("%08x", rand.Uint32()) }

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func (r *Registry) createAPI(w http.ResponseWriter, req *http.Request) {
	var body struct {
		Name       string   `json:"name"`
		Context    string   `json:"context"`
		Version    string   `json:"version"`
		BackendURL string   `json:"backendUrl"`
		Tiers      []string `json:"allowedTiers"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.Context == "" || body.BackendURL == "" {
		http.Error(w, `{"error":"context and backendUrl are required"}`, http.StatusBadRequest)
		return
	}
	api := &API{
		ID: newID(), Name: body.Name, Context: body.Context,
		Version: body.Version, BackendURL: body.BackendURL,
		Status: StatusCreated, AllowedTiers: body.Tiers, CreatedAt: time.Now().UTC(),
	}
	r.mu.Lock()
	r.apis[api.ID] = api
	r.mu.Unlock()
	writeJSON(w, http.StatusCreated, api)
}

func (r *Registry) listAPIs(w http.ResponseWriter, _ *http.Request) {
	r.mu.RLock()
	list := make([]*API, 0, len(r.apis))
	for _, a := range r.apis {
		list = append(list, a)
	}
	r.mu.RUnlock()
	writeJSON(w, http.StatusOK, list)
}

func (r *Registry) getAPI(w http.ResponseWriter, id string) {
	r.mu.RLock()
	api, ok := r.apis[id]
	r.mu.RUnlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, api)
}

func (r *Registry) deleteAPI(w http.ResponseWriter, id string) {
	r.mu.Lock()
	_, ok := r.apis[id]
	if ok {
		delete(r.apis, id)
	}
	r.mu.Unlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (r *Registry) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
	var body struct {
		Action string `json:"action"` // Publish, Deprecate, Retire
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	actionToStatus := map[string]LifecycleStatus{
		"Publish":   StatusPublished,
		"Deprecate": StatusDeprecated,
		"Retire":    StatusRetired,
	}
	target, ok := actionToStatus[body.Action]
	if !ok {
		http.Error(w, fmt.Sprintf(`{"error":"unknown action %q"}`, body.Action), http.StatusBadRequest)
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	api, ok := r.apis[id]
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	if body.Action == "Publish" && len(api.AllowedTiers) == 0 {
		http.Error(w, `{"error":"cannot publish API with no allowed tiers"}`, http.StatusBadRequest)
		return
	}
	allowed := validTransitions[api.Status]
	valid := false
	for _, s := range allowed {
		if s == target {
			valid = true
			break
		}
	}
	if !valid {
		http.Error(w, fmt.Sprintf(`{"error":"invalid transition: %s → %s"}`, api.Status, target), http.StatusBadRequest)
		return
	}
	api.Status = target
	writeJSON(w, http.StatusOK, api)
}

func main() {
	reg := NewRegistry()
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})
	mux.HandleFunc("/apis", func(w http.ResponseWriter, req *http.Request) {
		switch req.Method {
		case http.MethodPost:
			reg.createAPI(w, req)
		case http.MethodGet:
			reg.listAPIs(w, req)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	mux.HandleFunc("/apis/", func(w http.ResponseWriter, req *http.Request) {
		parts := strings.Split(strings.Trim(req.URL.Path, "/"), "/")
		// parts[0]="apis", parts[1]="{id}", parts[2]=optional sub-resource
		if len(parts) < 2 {
			http.Error(w, "bad path", http.StatusBadRequest)
			return
		}
		id := parts[1]
		if len(parts) == 3 && parts[2] == "lifecycle" && req.Method == http.MethodPost {
			reg.transitionLifecycle(w, id, req)
			return
		}
		switch req.Method {
		case http.MethodGet:
			reg.getAPI(w, id)
		case http.MethodDelete:
			reg.deleteAPI(w, id)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	fmt.Println("WSO2 CP — API Registry listening on :8082")
	http.ListenAndServe(":8082", mux)
}
```

- [ ] **Step 6: Write labs/phase3/day32/README.md** — run `go run main.go`; test with:
  ```bash
  # Create API
  curl -s -X POST http://localhost:8082/apis \
    -H 'Content-Type: application/json' \
    -d '{"name":"PetStore","context":"/petstore/v1","version":"1.0","backendUrl":"http://backend:9000","allowedTiers":["Gold","Silver"]}'
  # Publish (copy {id} from response)
  curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
    -H 'Content-Type: application/json' -d '{"action":"Publish"}'
  # Try invalid transition PUBLISHED → CREATED (expect 400)
  curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
    -H 'Content-Type: application/json' -d '{"action":"Publish"}'
  ```

- [ ] **Step 7: Write labs/phase3/day32/SOLUTION.md** — show that the state machine rejects PUBLISHED→CREATED and that publishing with no tiers returns 400; explain the `validTransitions` map design.
- [ ] **Step 8: Write labs/phase3/day32/teardown.md** — `Ctrl+C`, no containers to stop.

- [ ] **Step 9: Write labs/phase3/day33/main.go** — standalone file containing all Day 32 code PLUS:
  - `tierDescription(tier string) string` helper (Bronze=1000 req/min, Silver=2000, Gold=5000, Unlimited=no limit)
  - `GET /apis/{id}/policies` handler: reads `AllowedTiers` from the API, returns `[]Policy{Name, Description}`
  - `PUT /apis/{id}/tiers` handler: updates `AllowedTiers`; returns 400 if API is PUBLISHED

  Add inside the `/apis/` mux handler (before the method switch), after id extraction:
  ```go
  if len(parts) == 3 && parts[2] == "policies" && req.Method == http.MethodGet {
      reg.mu.RLock()
      api, ok := reg.apis[id]
      reg.mu.RUnlock()
      if !ok { http.Error(w, "not found", http.StatusNotFound); return }
      type Policy struct {
          Name        string `json:"name"`
          Description string `json:"description"`
      }
      policies := make([]Policy, len(api.AllowedTiers))
      for i, t := range api.AllowedTiers {
          policies[i] = Policy{Name: t, Description: tierDescription(t)}
      }
      writeJSON(w, http.StatusOK, policies)
      return
  }
  if len(parts) == 3 && parts[2] == "tiers" && req.Method == http.MethodPut {
      var body struct{ Tiers []string `json:"tiers"` }
      if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
          http.Error(w, "bad request", http.StatusBadRequest); return
      }
      reg.mu.Lock()
      api, ok := reg.apis[id]
      if ok && api.Status == StatusPublished {
          reg.mu.Unlock()
          http.Error(w, `{"error":"deprecate the API before changing tiers"}`, http.StatusBadRequest)
          return
      }
      if ok { api.AllowedTiers = body.Tiers }
      reg.mu.Unlock()
      if !ok { http.Error(w, "not found", http.StatusNotFound); return }
      reg.mu.RLock()
      a := reg.apis[id]
      reg.mu.RUnlock()
      writeJSON(w, http.StatusOK, a)
      return
  }
  ```

- [ ] **Step 10: Write labs/phase3/day33 README, SOLUTION.md, teardown.md**.
- [ ] **Step 11: Verify** — all files exist, all 3 day files have 3 exercises with Hint + Solution sketch, lab dirs complete.

---

### Task 2: Days 34–36 — Subscription Management

**Files:**
- Create: `content/phase3/day34.md`, `day35.md`, `day36.md`
- Create: `labs/phase3/day34/README.md` (source reading — no Go)
- Create: `labs/phase3/day35/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase3/day36/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: Day 32/33 concepts (API ID, context, AllowedTiers — referenced in subscription records).
- Produces: `labs/phase3/day36/main.go` — HTTP server on `:8083` with: `POST /applications`, `GET /applications/{id}`, `POST /subscriptions`, `GET /subscriptions?appId={id}`, `POST /admin/apis` (register API context), `GET /subscriptions/validate?consumerKey=...&apiContext=...&tier=...`. Task 3 wires this store into the unified CP event bus.

- [ ] **Step 1: Write content/phase3/day34.md** covering:
  - **Why this matters:** The triple (Application, API, Subscription Tier) is the access control unit in WSO2. Every token issued by IS carries an `applicationname` claim; the GW looks up the subscription using that claim. A missing subscription → 403, even for a valid JWT.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "ApiMgtDAO.java"` — find `addSubscription()` and `getSubscriptionsByAPI()`; look for the `AM_SUBSCRIPTION` table reference.
  - **Key insight:** WSO2 stores Application (consumer app) and Subscription (app-to-API mapping) as separate tables. An app can subscribe to many APIs; an API can have many subscribers. The `AM_SUBSCRIPTION` triple: `APP_ID`, `API_ID`, `TIER_ID`. Subscription status can be UNBLOCKED (active) or BLOCKED (admin-disabled).
  - **Core concepts:** Application model `{id, name, consumerKey, consumerSecret, owner, callbackURL}`; Subscription model `{id, appId, apiId, tier, status, createdAt}`. The `consumerKey` is what the IS uses to identify the application when issuing a JWT; the JWT carries `applicationname`, not the `consumerKey`.
  - **Exercises** (3):
    1. In `ApiMgtDAO.java`, what columns does `addSubscription()` insert into `AM_SUBSCRIPTION`? — **Hint:** search for `INSERT INTO AM_SUBSCRIPTION` — **Solution sketch:** APP_ID, API_ID, TIER_ID, STATUS (default UNBLOCKED), CREATED_BY, CREATED_TIME.
    2. What is the difference between `getSubscriptionsByAPI()` and `getSubscriptionsByOwner()`? — **Hint:** one is for the publisher, one for the consumer — **Solution sketch:** `getSubscriptionsByAPI` lists all apps subscribed to one API (publisher view); `getSubscriptionsByOwner` lists all APIs a user's apps are subscribed to (consumer view).
    3. How does the GW know an application's subscription tier at request time? — **Hint:** the JWT carries a tier claim — **Solution sketch:** the IS embeds `http://wso2.org/claims/applicationtier` in the JWT at token issuance; the GW reads it from the token without calling the CP.
  - **Anti-patterns:** (1) Calling the CP on every request to validate the subscription — the GW caches subscription data locally; (2) Confusing the application `consumerKey` with the JWT `sub` claim — they serve different lookup purposes; (3) Blocking a subscription at the DB level but not propagating that change to the GW event stream.

- [ ] **Step 2: Write content/phase3/day35.md** covering:
  - **Core concepts:** Building the Go application + subscription store. Application endpoint generates `consumerKey`/`consumerSecret` using `crypto/rand` — mirrors WSO2's `ApplicationRegistrationWorkflowExecutor`. Two in-memory indexes: `apps map[string]*Application` (by ID) and `byKey map[string]*Application` (by consumerKey) for O(1) validation lookup.
  - **WSO2 source reading:** `grep -n "generateConsumerSecret\|generateClientId" <ApiMgtDAO path>` — observe that WSO2 generates these via `OAuthAdminServiceImpl`, not in the DAO directly.
  - **Exercises** (3):
    1. Add a `DELETE /subscriptions/{id}` endpoint that sets `Status = BLOCKED` rather than deleting the record — **Hint:** WSO2 soft-deletes subscriptions — **Solution sketch:** find the sub by ID, set `sub.Status = SubBlocked`, return 200 with the updated sub.
    2. Two applications subscribe to the same API — how does the store prevent duplicate subscriptions? — **Hint:** check the subIdx before inserting — **Solution sketch:** scan `subIdx[appID]`; if a sub with the same `APIID` already exists, return 409 Conflict.
    3. Why does the subscription store use two maps (`apps` by ID and `byKey` by consumerKey) instead of one? — **Hint:** consider the two different lookup patterns — **Solution sketch:** creation/retrieval uses ID; validation uses consumerKey. Two maps give O(1) for both without a linear scan.
  - **Anti-patterns:** (1) Using a single map — forces O(n) scan on validation; (2) Not generating cryptographically random consumerKey — `math/rand` is predictable; use `crypto/rand`; (3) Returning the `consumerSecret` in GET responses — expose it only at creation time.

- [ ] **Step 3: Write content/phase3/day36.md** covering:
  - **Why this matters:** `GET /subscriptions/validate` is the endpoint the Phase 2 GW subscription middleware calls when its local cache misses. Understanding this endpoint's contract is essential for debugging 403s.
  - **Core concepts:** Validation lookup: `consumerKey → Application → subIdx[appID] → find APIID match → check tier + UNBLOCKED status`. Response contract: `{"valid":true,"tier":"Gold","appName":"PetApp","appId":"abc"}` or `{"valid":false,"reason":"subscription_not_found"}`. Always 200; never 404 — the GW expects a structured response, not an HTTP error.
  - **The `/admin/apis` registration endpoint:** bridges the subscription store (which knows API IDs) with the GW (which knows API contexts like `/petstore/v1`). The CP registers `{apiId, apiContext}` pairs so validation can resolve context → ID.
  - **Exercises** (3):
    1. The GW calls validate with a `consumerKey` that belongs to a BLOCKED subscription — what should the response be? — **Hint:** valid:false, not an error — **Solution sketch:** `{"valid":false,"reason":"subscription_blocked"}`.
    2. A BLOCKED subscription is later unblocked — what extra step ensures the GW picks up the change? — **Hint:** the GW caches subscription data — **Solution sketch:** the CP must emit a `SUBSCRIPTION_UPDATED` event so the GW invalidates its cache for that app+API pair.
    3. Why does the validate endpoint return 200 even when the subscription is not found, instead of 404? — **Hint:** think about how the GW handles the response — **Solution sketch:** the GW deserialises the JSON body regardless of status; a 404 would require the GW to handle two different response shapes. A uniform 200 with `valid:false` keeps the GW's code simple.
  - **Anti-patterns:** (1) Returning HTTP 404 for a missing subscription — breaks GW deserialisation; (2) Not indexing by consumerKey — O(n) scans fail under load; (3) Allowing a tier mismatch to silently return `valid:true` — always check tier equality.

- [ ] **Step 4: Write labs/phase3/day34/README.md** — source walk:
  ```
  # Day 34 — Source Reading Lab

  Goal: Trace the subscription data model in WSO2 APIM ACP source.

  ## Step 1: Find ApiMgtDAO
  find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "ApiMgtDAO.java" | head -3

  ## Step 2: Find subscription operations
  grep -n "addSubscription\|getSubscriptions\|AM_SUBSCRIPTION" <path> | head -20

  ## Step 3: Find the Application DAO operations
  grep -n "addApplication\|getApplicationsByOwner\|generateConsumer" <path> | head -10

  Answer in your "why" log:
  1. What columns does AM_SUBSCRIPTION hold?
  2. What is the difference between TIER_ID in AM_SUBSCRIPTION and AM_POLICY_SUBSCRIPTION?
  3. How does ApiMgtDAO.getSubscriptionsByAPI() differ from getSubscriptionsByOwner()?
  ```

- [ ] **Step 5: Write labs/phase3/day35/main.go** — application + subscription manager:

```go
package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

type Application struct {
	ID             string    `json:"id"`
	Name           string    `json:"name"`
	ConsumerKey    string    `json:"consumerKey"`
	ConsumerSecret string    `json:"consumerSecret"`
	Owner          string    `json:"owner"`
	CallbackURL    string    `json:"callbackUrl"`
	CreatedAt      time.Time `json:"createdAt"`
}

type SubscriptionStatus string

const (
	SubUnblocked SubscriptionStatus = "UNBLOCKED"
	SubBlocked   SubscriptionStatus = "BLOCKED"
)

type Subscription struct {
	ID        string             `json:"id"`
	AppID     string             `json:"appId"`
	APIID     string             `json:"apiId"`
	Tier      string             `json:"tier"`
	Status    SubscriptionStatus `json:"status"`
	CreatedAt time.Time          `json:"createdAt"`
}

type Store struct {
	mu     sync.RWMutex
	apps   map[string]*Application   // id → app
	byKey  map[string]*Application   // consumerKey → app
	subs   map[string]*Subscription  // id → sub
	subIdx map[string][]*Subscription // appId → []sub
}

func NewStore() *Store {
	return &Store{
		apps:   make(map[string]*Application),
		byKey:  make(map[string]*Application),
		subs:   make(map[string]*Subscription),
		subIdx: make(map[string][]*Subscription),
	}
}

func newID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func newKey() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func (s *Store) createApp(w http.ResponseWriter, req *http.Request) {
	var body struct {
		Name        string `json:"name"`
		Owner       string `json:"owner"`
		CallbackURL string `json:"callbackUrl"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}
	app := &Application{
		ID: newID(), Name: body.Name, Owner: body.Owner,
		ConsumerKey: newKey(), ConsumerSecret: newKey(),
		CallbackURL: body.CallbackURL, CreatedAt: time.Now().UTC(),
	}
	s.mu.Lock()
	s.apps[app.ID] = app
	s.byKey[app.ConsumerKey] = app
	s.mu.Unlock()
	writeJSON(w, http.StatusCreated, app)
}

func (s *Store) getApp(w http.ResponseWriter, id string) {
	s.mu.RLock()
	app, ok := s.apps[id]
	s.mu.RUnlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	// Do not re-expose consumerSecret on GET
	safe := *app
	safe.ConsumerSecret = "***"
	writeJSON(w, http.StatusOK, &safe)
}

func (s *Store) createSub(w http.ResponseWriter, req *http.Request) {
	var body struct {
		AppID string `json:"appId"`
		APIID string `json:"apiId"`
		Tier  string `json:"tier"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.AppID == "" || body.APIID == "" || body.Tier == "" {
		http.Error(w, "appId, apiId, and tier are required", http.StatusBadRequest)
		return
	}
	sub := &Subscription{
		ID: newID(), AppID: body.AppID, APIID: body.APIID,
		Tier: body.Tier, Status: SubUnblocked, CreatedAt: time.Now().UTC(),
	}
	s.mu.Lock()
	s.subs[sub.ID] = sub
	s.subIdx[sub.AppID] = append(s.subIdx[sub.AppID], sub)
	s.mu.Unlock()
	writeJSON(w, http.StatusCreated, sub)
}

func (s *Store) listSubs(w http.ResponseWriter, req *http.Request) {
	appID := req.URL.Query().Get("appId")
	s.mu.RLock()
	list := s.subIdx[appID]
	if list == nil {
		list = []*Subscription{}
	}
	s.mu.RUnlock()
	writeJSON(w, http.StatusOK, list)
}

func main() {
	store := NewStore()
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})
	mux.HandleFunc("/applications", func(w http.ResponseWriter, req *http.Request) {
		if req.Method == http.MethodPost {
			store.createApp(w, req)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	mux.HandleFunc("/applications/", func(w http.ResponseWriter, req *http.Request) {
		id := strings.TrimPrefix(req.URL.Path, "/applications/")
		if req.Method == http.MethodGet {
			store.getApp(w, id)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	mux.HandleFunc("/subscriptions", func(w http.ResponseWriter, req *http.Request) {
		switch req.Method {
		case http.MethodPost:
			store.createSub(w, req)
		case http.MethodGet:
			store.listSubs(w, req)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	fmt.Println("WSO2 CP — Subscription Manager listening on :8083")
	http.ListenAndServe(":8083", mux)
}
```

- [ ] **Step 6: Write labs/phase3/day35/README.md** — run `go run main.go`; test with:
  ```bash
  # Create app
  curl -s -X POST http://localhost:8083/applications \
    -H 'Content-Type: application/json' \
    -d '{"name":"PetApp","owner":"alice"}'
  # Subscribe (copy appId from above)
  curl -s -X POST http://localhost:8083/subscriptions \
    -H 'Content-Type: application/json' \
    -d '{"appId":"{appId}","apiId":"dummy-api-id","tier":"Gold"}'
  # List subscriptions
  curl -s "http://localhost:8083/subscriptions?appId={appId}"
  ```
- [ ] **Step 7: Write labs/phase3/day35/SOLUTION.md** — explain the two-map design; show duplicate-subscription detection.
- [ ] **Step 8: Write labs/phase3/day35/teardown.md** — `Ctrl+C`, no containers.

- [ ] **Step 9: Write labs/phase3/day36/main.go** — standalone file containing all Day 35 code PLUS:
  - Add `apiContextMap map[string]string` field to `Store` (apiContext → apiID)
  - `POST /admin/apis` handler to register `{apiId, apiContext}` pairs
  - `GET /subscriptions/validate` handler:

  ```go
  func (s *Store) validateSub(w http.ResponseWriter, req *http.Request) {
      q := req.URL.Query()
      consumerKey, apiContext, tier := q.Get("consumerKey"), q.Get("apiContext"), q.Get("tier")
      if consumerKey == "" || apiContext == "" {
          http.Error(w, "consumerKey and apiContext required", http.StatusBadRequest)
          return
      }
      s.mu.RLock()
      defer s.mu.RUnlock()
      app, ok := s.byKey[consumerKey]
      if !ok {
          writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "application_not_found"})
          return
      }
      apiID := s.apiContextMap[apiContext]
      for _, sub := range s.subIdx[app.ID] {
          if sub.APIID == apiID && (tier == "" || sub.Tier == tier) && sub.Status == SubUnblocked {
              writeJSON(w, http.StatusOK, map[string]any{
                  "valid": true, "tier": sub.Tier,
                  "appName": app.Name, "appId": app.ID,
              })
              return
          }
      }
      writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_not_found"})
  }
  ```

  Add in `NewStore()`: `apiContextMap: make(map[string]string)`.
  Add handler: `POST /admin/apis` decodes `{apiId, apiContext}` and writes `s.apiContextMap[body.APIContext] = body.APIID` under the write lock.
  Add route: `mux.HandleFunc("/subscriptions/validate", ...)` for GET only.

- [ ] **Step 10: Write labs/phase3/day36/README.md** — register an API, create an app, subscribe, then validate:
  ```bash
  curl -s -X POST http://localhost:8083/admin/apis \
    -d '{"apiId":"abc123","apiContext":"/petstore/v1"}'
  curl -s "http://localhost:8083/subscriptions/validate?consumerKey={key}&apiContext=/petstore/v1&tier=Gold"
  ```
- [ ] **Step 11: Write labs/phase3/day36/SOLUTION.md, teardown.md**.
- [ ] **Step 12: Verify** — all files exist, exercises have Hint + Solution sketch, validation endpoint returns 200 in all cases (not 404 for missing subscription).

---

### Task 3: Days 37–39 — Event Hub + Go Channel Event Bus + SSE

**Files:**
- Create: `content/phase3/day37.md`, `day38.md`, `day39.md`
- Create: `labs/phase3/day37/README.md` (source reading — no Go)
- Create: `labs/phase3/day38/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase3/day39/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase3/day33/main.go` (API registry) and `labs/phase3/day36/main.go` (subscription store) — Day 39 integrates all three into one unified CP.
- Produces: `labs/phase3/day39/main.go` — unified CP server on `:8082` that includes all Day 33 + Day 36 endpoints, publishes events on every lifecycle change + subscription create, and exposes `GET /events` (SSE) + `GET /admin/sync`. Task 5 uses this as the `cp` service in Docker Compose.

- [ ] **Step 1: Write content/phase3/day37.md** covering:
  - **Why this matters:** The event hub is what keeps the GW in sync with the CP. If it breaks, the GW routes traffic based on stale data — one of the most common "API works sometimes" bugs in production.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "EventHub.java"` and `find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "JMSMessagePublisher.java"`. Look for JMS topic names: `notification`, `keymanager`, `throttle-data`, `token-revocation`.
  - **Key insight:** WSO2's event hub uses JMS (Apache ActiveMQ). The CP publishes to JMS topics; each GW instance subscribes. On GW startup: (1) call `getSyncData()` for a full CP state dump; (2) subscribe to JMS topics for incremental updates. Go channels replace JMS; SSE replaces the JMS subscription protocol.
  - **Event payload shapes in WSO2:** API_CREATE `{apiName, apiContext, apiVersion, apiStatus}`; SUBSCRIPTIONS_CREATE `{applicationName, apiName, subscriptionTier, keyType}`; API_LIFECYCLE_CHANGE `{apiName, apiContext, oldStatus, newStatus}`.
  - **Exercises** (3):
    1. WSO2 uses JMS for event sync — name two production failure modes specific to JMS that Go channels avoid — **Hint:** think about durability and broker availability — **Solution sketch:** (a) JMS broker outage stops all event delivery; Go channels are in-process. (b) JMS messages can queue up if the broker is slow; Go channels are bounded and drop when full.
    2. The GW calls `getSyncData()` at startup before subscribing to events — why is this ordering critical? — **Hint:** think about events fired during the gap — **Solution sketch:** without initial sync, events fired before the GW subscribes are lost; `getSyncData` gives the full current state so the GW is correct even if it missed events during startup.
    3. List the 4 JMS topic names WSO2 uses for event sync and what each carries — **Hint:** check `EventHub.java` constants — **Solution sketch:** `notification` (API lifecycle + subscription changes), `keymanager` (key manager config), `throttle-data` (throttle policy updates), `token-revocation` (revoked token list).
  - **Anti-patterns:** (1) Subscribing to events without an initial full sync — works until the GW restarts; (2) Using unbuffered channels — Publish blocks if any subscriber is slow; always use buffered channels; (3) Forgetting to drain old events from the channel when a subscriber reconnects — reconnect should re-sync from `/admin/sync`, not replay buffered events.

- [ ] **Step 2: Write content/phase3/day38.md** covering:
  - **Core concepts:** `EventBus` struct: `map[EventType][]chan Event` for type-specific subscribers + `[]chan Event` for all-events subscribers. `Subscribe(EventType)` returns a buffered read channel + unsubscribe func. `SubscribeAll()` for the SSE endpoint. `Publish(Event)` is non-blocking — drops events if subscriber buffer is full and logs a warning (mirrors WSO2's behavior with slow consumers).
  - **Why non-blocking publish matters:** if `Publish` blocks, one slow GW subscriber stalls all other operations on the CP. WSO2 uses a separate thread per JMS topic sender; Go's equivalent is a non-blocking channel send.
  - **Exercises** (3):
    1. Write a test that shows a `SubscribeAll` subscriber receives events for all types — **Hint:** publish `EventAPIPublished` and `EventSubCreated`; assert both arrive — **Solution sketch:** `ch, _ := bus.SubscribeAll(); bus.Publish(e1); bus.Publish(e2); assert <-ch == e1; assert <-ch == e2`.
    2. The buffer is full — `Publish` drops the event and logs. In a production incident, what does "events dropped" in the log mean for the GW? — **Hint:** the GW has a stale cache — **Solution sketch:** the GW missed state changes; it may serve 403s for valid subscriptions or route to deprecated APIs. Recovery: restart the GW to trigger a full re-sync from `/admin/sync`.
    3. Add a `PublishAsync(Event)` method that sends the event in a goroutine instead of dropping — when would you use it? — **Hint:** think about throughput vs latency — **Solution sketch:** `go func() { ch <- e }()` — useful when event delivery is more important than throughput; risks goroutine leak if the subscriber never drains.

- [ ] **Step 3: Write content/phase3/day39.md** covering:
  - **Server-Sent Events (SSE) protocol:** `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`. Each event: `data: <json>\n\n`. Requires `http.Flusher` to flush each event immediately. The GW uses a `bufio.Scanner` to read lines from the SSE stream.
  - **Initial sync + SSE reconnect pattern:** GW calls `GET /admin/sync` → gets full API + subscription snapshot → then connects to `GET /events` SSE. If the SSE connection drops, GW re-syncs from `/admin/sync` and reconnects. This is the same pattern WSO2 GW uses with JMS.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "*.java" | xargs grep -l "getSyncData\|syncData" 2>/dev/null | head -5`
  - **Exercises** (3):
    1. The GW connects to `/events` and immediately disconnects — what Go mechanism closes the SSE goroutine? — **Hint:** `r.Context().Done()` — **Solution sketch:** `<-r.Context().Done()` in the select case triggers when the client disconnects; the handler returns, the `defer unsubscribe()` runs.
    2. Two GW replicas connect to `/events` — does each get all events? — **Hint:** each calls `SubscribeAll()` independently — **Solution sketch:** yes — each GW gets its own buffered channel from `SubscribeAll()`; events are broadcast to all active channels.
    3. The GW parses SSE lines with `bufio.Scanner` — write the parsing loop — **Hint:** SSE lines start with `data: ` — **Solution sketch:** `for scanner.Scan() { line := scanner.Text(); if strings.HasPrefix(line, "data: ") { data := strings.TrimPrefix(line, "data: "); json.Unmarshal([]byte(data), &event) } }`.
  - **Anti-patterns:** (1) Not setting `Cache-Control: no-cache` — proxies buffer SSE responses; (2) Blocking `Publish` inside an HTTP handler — use the non-blocking EventBus; (3) Not calling `flusher.Flush()` after each event — events batch up and the GW sees long delays.

- [ ] **Step 4: Write labs/phase3/day37/README.md** — source walk:
  ```
  # Day 37 — Source Reading Lab

  Goal: Trace the WSO2 event hub and JMS topic structure.

  ## Step 1: Find EventHub
  find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "EventHub.java" | head -3

  ## Step 2: Find JMS topic names
  grep -rn "\"notification\"\|\"keymanager\"\|\"throttle-data\"\|\"token-revocation\"" \
    /Users/hunghan/Downloads/wso2am-acp-4.7.0 --include="*.java" | head -20

  ## Step 3: Find the GW initial sync
  find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "*.java" | \
    xargs grep -l "getSyncData\|fullSync\|syncData" 2>/dev/null | head -5

  Answer in your "why" log:
  1. List the 4 JMS topic names and what each carries.
  2. What payload does the notification topic send when an API is published?
  3. What class in the GW handles the JMS subscription on startup?
  ```

- [ ] **Step 5: Write labs/phase3/day38/main.go** — standalone event bus demonstration:

```go
package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

type EventType string

const (
	EventAPICreated    EventType = "API_CREATED"
	EventAPIPublished  EventType = "API_PUBLISHED"
	EventAPIDeprecated EventType = "API_DEPRECATED"
	EventAPIRetired    EventType = "API_RETIRED"
	EventSubCreated    EventType = "SUBSCRIPTION_CREATED"
	EventSubRemoved    EventType = "SUBSCRIPTION_REMOVED"
)

type Event struct {
	Type      EventType       `json:"type"`
	Timestamp time.Time       `json:"timestamp"`
	Payload   json.RawMessage `json:"payload"`
}

func NewEvent(et EventType, payload any) Event {
	raw, _ := json.Marshal(payload)
	return Event{Type: et, Timestamp: time.Now().UTC(), Payload: raw}
}

const subBufSize = 32

type EventBus struct {
	mu     sync.RWMutex
	subs   map[EventType][]chan Event
	allSub []chan Event
}

func NewEventBus() *EventBus {
	return &EventBus{subs: make(map[EventType][]chan Event)}
}

func (b *EventBus) Subscribe(et EventType) (<-chan Event, func()) {
	ch := make(chan Event, subBufSize)
	b.mu.Lock()
	b.subs[et] = append(b.subs[et], ch)
	b.mu.Unlock()
	return ch, func() {
		b.mu.Lock()
		chs := b.subs[et]
		for i, c := range chs {
			if c == ch {
				b.subs[et] = append(chs[:i], chs[i+1:]...)
				break
			}
		}
		b.mu.Unlock()
	}
}

func (b *EventBus) SubscribeAll() (<-chan Event, func()) {
	ch := make(chan Event, subBufSize)
	b.mu.Lock()
	b.allSub = append(b.allSub, ch)
	b.mu.Unlock()
	return ch, func() {
		b.mu.Lock()
		for i, c := range b.allSub {
			if c == ch {
				b.allSub = append(b.allSub[:i], b.allSub[i+1:]...)
				break
			}
		}
		b.mu.Unlock()
	}
}

// Publish is non-blocking: drops and logs if a subscriber's buffer is full.
func (b *EventBus) Publish(e Event) {
	b.mu.RLock()
	typed := make([]chan Event, len(b.subs[e.Type]))
	copy(typed, b.subs[e.Type])
	all := make([]chan Event, len(b.allSub))
	copy(all, b.allSub)
	b.mu.RUnlock()
	for _, ch := range append(typed, all...) {
		select {
		case ch <- e:
		default:
			slog.Warn("event bus: buffer full, dropping event", "type", e.Type)
		}
	}
}

func main() {
	bus := NewEventBus()

	// Simulated GW subscriber: listens for API_PUBLISHED events only
	apiCh, unsub := bus.Subscribe(EventAPIPublished)
	defer unsub()

	go func() {
		for e := range apiCh {
			var payload map[string]any
			json.Unmarshal(e.Payload, &payload)
			slog.Info("GW received API_PUBLISHED", "context", payload["context"], "version", payload["version"])
		}
	}()

	// All-events subscriber (simulates SSE streaming goroutine)
	allCh, unsubAll := bus.SubscribeAll()
	defer unsubAll()

	go func() {
		for e := range allCh {
			slog.Info("SSE stream", "type", e.Type)
		}
	}()

	// Simulate CP publishing
	bus.Publish(NewEvent(EventAPIPublished, map[string]any{
		"id": "abc123", "name": "PetStore", "context": "/petstore/v1", "version": "1.0",
		"tiers": []string{"Gold", "Silver"},
	}))
	bus.Publish(NewEvent(EventSubCreated, map[string]any{
		"apiId": "abc123", "appName": "PetApp", "tier": "Gold",
	}))

	time.Sleep(100 * time.Millisecond)
	fmt.Println("Event bus demo complete.")
}
```

- [ ] **Step 6: Write labs/phase3/day38/README.md** — `go run main.go`; observe that the GW subscriber only receives `API_PUBLISHED` (not `SUBSCRIPTION_CREATED`), while the SSE subscriber receives both.
- [ ] **Step 7: Write labs/phase3/day38/SOLUTION.md** — explain why `SubscribeAll` receives both events; explain non-blocking send and what "buffer full" means.
- [ ] **Step 8: Write labs/phase3/day38/teardown.md** — `Ctrl+C`, no containers.

- [ ] **Step 9: Write labs/phase3/day39/main.go** — unified Control Plane (all Day 33 + Day 36 code + EventBus + SSE + admin/sync). The file contains a `ControlPlane` struct that holds `*Registry`, `*Store` (from Day 36), and `*EventBus`. Every lifecycle transition and subscription create calls `cp.bus.Publish(...)`. Key additions:

```go
// ── ControlPlane wiring ───────────────────────────────────────────────────

type ControlPlane struct {
	reg  *Registry
	subs *Store
	bus  *EventBus
}

func NewControlPlane() *ControlPlane {
	return &ControlPlane{
		reg:  NewRegistry(),
		subs: NewStore(),
		bus:  NewEventBus(),
	}
}

// toEventType maps LifecycleStatus → EventType for bus publication.
func toEventType(s LifecycleStatus) EventType {
	switch s {
	case StatusPublished:  return EventAPIPublished
	case StatusDeprecated: return EventAPIDeprecated
	case StatusRetired:    return EventAPIRetired
	default:               return EventAPICreated
	}
}

// GET /events — SSE endpoint; each CP event streams as "data: <json>\n\n"
func (cp *ControlPlane) eventsSSE(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	events, unsubscribe := cp.bus.SubscribeAll()
	defer unsubscribe()
	for {
		select {
		case e := <-events:
			data, _ := json.Marshal(e)
			fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		case <-r.Context().Done():
			return
		}
	}
}

// GET /admin/sync — returns all PUBLISHED APIs + all UNBLOCKED subscriptions
// GW calls this on startup before connecting to /events
func (cp *ControlPlane) adminSync(w http.ResponseWriter, _ *http.Request) {
	cp.reg.mu.RLock()
	apis := make([]*API, 0)
	for _, a := range cp.reg.apis {
		if a.Status == StatusPublished {
			apis = append(apis, a)
		}
	}
	cp.reg.mu.RUnlock()

	cp.subs.mu.RLock()
	allSubs := make([]*Subscription, 0)
	for _, sub := range cp.subs.subs {
		if sub.Status == SubUnblocked {
			allSubs = append(allSubs, sub)
		}
	}
	cp.subs.mu.RUnlock()

	writeJSON(w, http.StatusOK, map[string]any{"apis": apis, "subscriptions": allSubs})
}
```

The `transitionLifecycle` and `createSub` methods call `cp.bus.Publish(...)` after each successful state change (same logic as Day 33/36 but with event emission added).

- [ ] **Step 10: Write labs/phase3/day39/README.md** — two-terminal test:
  ```bash
  # Terminal 1
  go run main.go
  # Terminal 2
  curl -N http://localhost:8082/events
  # Terminal 3 — create + publish API, watch Terminal 2
  API=$(curl -s -X POST http://localhost:8082/apis \
    -H 'Content-Type: application/json' \
    -d '{"name":"PetStore","context":"/petstore/v1","version":"1.0","backendUrl":"http://backend","allowedTiers":["Gold"]}')
  ID=$(echo $API | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
  curl -s -X POST http://localhost:8082/apis/$ID/lifecycle \
    -H 'Content-Type: application/json' -d '{"action":"Publish"}'
  ```
- [ ] **Step 11: Write labs/phase3/day39/SOLUTION.md** — show the SSE event payload for API_PUBLISHED; explain why `/admin/sync` only returns PUBLISHED APIs.
- [ ] **Step 12: Write labs/phase3/day39/teardown.md** — `Ctrl+C`, no containers.
- [ ] **Step 13: Verify** — SSE response has `Content-Type: text/event-stream`; `adminSync` returns only PUBLISHED APIs; exercises have hints+solutions.

---

### Task 4: Days 40–42 — ECS Fargate Deployment Patterns

**Files:**
- Create: `content/phase3/day40.md`, `day41.md`, `day42.md`
- Create: `labs/phase3/day40/main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `teardown.md`
- Create: `labs/phase3/day41/main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `teardown.md`
- Create: `labs/phase3/day42/main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `teardown.md`

**Interfaces:**
- Consumes: nothing (infra-only, independent of Go code).
- Produces: `labs/phase3/day42/` — complete `terraform validate`-passing HCL for ECS Fargate CP + GW + IS + TM with IAM, SGs, ALB, and autoscaling. Task 5 references this topology in the runbook.

- [ ] **Step 1: Write content/phase3/day40.md** covering:
  - **Why this matters:** Your company runs all four WSO2 components on ECS Fargate. Knowing the deployment topology tells you which task to restart when event sync breaks, and which CloudWatch log group to tail for each failure mode.
  - **The 4-service Fargate topology:** Control Plane (port 9443), Universal Gateway (8243/8280), IS as 3rd-party KM (port 9443 — separate task), Traffic Manager (port 9443 — separate task with different SG). Each is an independent ECS service with its own task definition.
  - **ECS Fargate vs Docker Compose:** No localhost. Each task gets its own ENI and private IP. Services communicate via AWS Cloud Map DNS names: `cp.wso2.internal`, `gw.wso2.internal`, `is.wso2.internal`. Any WSO2 config that hardcodes `localhost` breaks immediately.
  - **CloudWatch log groups:** `/ecs/{env}/wso2-cp`, `/ecs/{env}/wso2-gw`, `/ecs/{env}/wso2-is`, `/ecs/{env}/wso2-tm`. Always filter by `activityid` (correlation ID) across groups when debugging a single request.
  - **Exercises** (3):
    1. The GW calls `https://cp.wso2.internal:9443/...` — what AWS service resolves this DNS name? — **Hint:** Cloud Map — **Solution sketch:** AWS Cloud Map registers each ECS service under a private namespace; Route 53 resolves `*.wso2.internal` within the VPC.
    2. What startup order must ECS enforce: IS → CP → GW → TM, or can some start in parallel? — **Hint:** CP needs IS for key manager config; GW needs CP for initial sync — **Solution sketch:** IS first (no deps); CP and TM can start after IS; GW last (needs both CP and IS).
    3. A container restarts — does ECS Fargate reuse the same ENI? — **Hint:** task replacement vs in-place restart — **Solution sketch:** No. ECS Fargate creates a new task with a new ENI on restart; Cloud Map updates the DNS record automatically via ECS service discovery.
  - **Anti-patterns:** (1) Running CP and IS as the same ECS service — they have different scaling profiles; (2) Using public subnets for CP/IS — they should be private, behind the ALB or with no public exposure; (3) Hardcoding private IPs — Cloud Map DNS is the right abstraction.

- [ ] **Step 2: Write content/phase3/day41.md** covering:
  - **ALB configuration for WSO2 GW:** One public ALB in front of GW only. CP, IS, and TM are internal (no public ALB). ALB listener on 443 → target group on port 8243 (HTTPS). Health check path: `/services/Version`.
  - **Container networking:** VPC with 2 private subnets + 2 public subnets (for ALB only). All ECS tasks in private subnets. NAT gateway for outbound traffic (ECR pulls, Secrets Manager calls).
  - **WSO2 health check paths:** GW: `/services/Version`; CP: `/services/Version`; IS: `/oauth2/token` (HEAD request); TM: `/services/Version`. These are the real WSO2 paths — not `/health`.
  - **Exercises** (3):
    1. Why is there no ALB in front of the CP? — **Hint:** who calls the CP? — **Solution sketch:** only internal services (GW, TM) call the CP; it needs no public exposure. An internal NLB could be added for cross-VPC CP access.
    2. The GW ALB health check fails — list 3 possible causes. — **Hint:** container, network, config — **Solution sketch:** (a) GW container not started yet (startPeriod too short); (b) SG on GW doesn't allow ALB SG on port 8243; (c) WSO2 GW startup takes >90s and the health check times out.
    3. ECS service discovery registers the GW at `gw.wso2.internal:8243` — why not at the ALB DNS name? — **Hint:** IS and CP need to call the GW directly, not through the ALB — **Solution sketch:** Cloud Map gives direct container IP routing; ALB adds latency and is for external clients only.

- [ ] **Step 3: Write content/phase3/day42.md** covering:
  - **IAM roles:** Execution role = pulls ECR images + CloudWatch logs; Task role = runtime AWS permissions (Secrets Manager reads for WSO2 keystore passwords). These are separate roles — principle of least privilege.
  - **Security group rules:** ALB SG → GW SG (8243); GW SG → CP SG (9443, event hub); GW SG → IS SG (9443, JWKS); CP SG → IS SG (9443, key manager config); GW SG → TM SG (9611/9711, throttle events).
  - **ECS autoscaling:** Target tracking on `ECSServiceAverageCPUUtilization` at 60%, min 1, max 4. CP and IS stay at fixed 1 replica (they hold state; horizontal scaling requires shared DB — out of scope). GW and TM scale horizontally.
  - **Exercises** (3):
    1. Why do CP and IS use fixed replicas while GW scales? — **Hint:** think about in-memory state — **Solution sketch:** CP holds the API registry in-memory (Day 32 Go lab); IS holds the token store. Scaling them requires shared external state (Redis, DB). GW is stateless (just validates and proxies) so it scales freely.
    2. The GW autoscaling fires at 60% CPU — what load pattern triggers this? — **Hint:** JWT validation is CPU-intensive (RSA verify) — **Solution sketch:** RSA JWT verification (used in Days 20-21) is computationally expensive; sustained high API traffic drives CPU up. 60% leaves headroom for burst before a new task is healthy.
    3. Write the Terraform `aws_appautoscaling_policy` `scale_in_cooldown` value and explain why it's longer than `scale_out_cooldown` — **Hint:** scale-in aggressiveness — **Solution sketch:** `scale_in_cooldown = 300, scale_out_cooldown = 60`. Scale out fast to handle spikes; scale in slowly to avoid flapping under variable load.
  - **Anti-patterns:** (1) Same SG for CP and IS — they need separate SGs for least-privilege rules; (2) Giving the ECS execution role secretsmanager access instead of the task role — execution role is only needed for container startup; (3) Setting autoscaling min to 0 — a cold-start ECS task takes 60-90s for WSO2 to be healthy.

- [ ] **Step 4: Write labs/phase3/day40/main.tf** — ECS cluster + CP + IS task definitions:

```hcl
# Day 40 Lab — ECS Cluster + Control Plane + IS Task Definitions
# AUTHORED LAB — do NOT run terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecs_cluster" "wso2" {
  name = "${var.environment}-wso2"
  setting { name = "containerInsights"; value = "enabled" }
}

resource "aws_ecs_cluster_capacity_providers" "wso2" {
  cluster_name       = aws_ecs_cluster.wso2.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-wso2-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_basic" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-wso2-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "task_secrets" {
  name = "wso2-secrets-read"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.environment}/wso2/*"
      # TODO: replace var.aws_account_id with your account ID in variables.tf
    }]
  })
}

resource "aws_ecs_task_definition" "cp" {
  family                   = "${var.environment}-wso2-cp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-cp"
    image     = var.image_uri_cp
    essential = true
    portMappings = [
      { containerPort = 9443, protocol = "tcp" },
      { containerPort = 9611, protocol = "tcp" },
      { containerPort = 9711, protocol = "tcp" }
    ]
    environment = [{ name = "WSO2_ENV", value = var.environment }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/wso2-cp"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf https://localhost:9443/services/Version || exit 1"]
      interval    = 30; timeout = 5; retries = 3; startPeriod = 120
    }
  }])
}

resource "aws_ecs_task_definition" "is" {
  family                   = "${var.environment}-wso2-is"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-is"
    image     = var.image_uri_is
    essential = true
    portMappings = [
      { containerPort = 9443, protocol = "tcp" },
      { containerPort = 9763, protocol = "tcp" }
    ]
    environment = [{ name = "WSO2_ENV", value = var.environment }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/wso2-is"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf -X HEAD https://localhost:9443/oauth2/token || exit 1"]
      interval    = 30; timeout = 5; retries = 3; startPeriod = 120
    }
  }])
}
```

- [ ] **Step 5: Write labs/phase3/day40/variables.tf**:

```hcl
variable "environment"    { type = string; default = "dev" }
variable "aws_region"     { type = string; default = "ap-southeast-1" }
variable "aws_account_id" { type = string; default = "TODO_REPLACE_WITH_YOUR_ACCOUNT_ID" }
variable "image_uri_cp"   { type = string; default = "TODO_REPLACE:wso2-cp:latest" }
variable "image_uri_is"   { type = string; default = "TODO_REPLACE:wso2-is:latest" }
```

- [ ] **Step 6: Write labs/phase3/day40/outputs.tf**:

```hcl
output "cluster_arn"     { value = aws_ecs_cluster.wso2.arn }
output "cp_task_def_arn" { value = aws_ecs_task_definition.cp.arn }
output "is_task_def_arn" { value = aws_ecs_task_definition.is.arn }
```

- [ ] **Step 7: Write labs/phase3/day40/README.md** — study focus: CP ports (9443/9611/9711), IS health check path `/oauth2/token`, why startPeriod is 120s for WSO2. Study exercise: "why is the task role different from the execution role?"
- [ ] **Step 8: Write labs/phase3/day40/teardown.md** — "Authored lab — no resources created. Nothing to tear down."

- [ ] **Step 9: Write labs/phase3/day41/main.tf** — standalone HCL containing all Day 40 resources PLUS GW + TM task definitions + ALB:

Include all Day 40 resources verbatim, then add:

```hcl
# ── GW Task Definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "gw" {
  family                   = "${var.environment}-wso2-gw"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-gw"
    image     = var.image_uri_gw
    essential = true
    portMappings = [
      { containerPort = 8280, protocol = "tcp" },
      { containerPort = 8243, protocol = "tcp" }
    ]
    environment = [
      { name = "WSO2_CP_URL", value = "https://cp.wso2.internal:9443" },
      { name = "WSO2_IS_URL", value = "https://is.wso2.internal:9443" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/wso2-gw"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf https://localhost:8243/services/Version || exit 1"]
      interval    = 30; timeout = 5; retries = 3; startPeriod = 90
    }
  }])
}

# ── TM Task Definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "tm" {
  family                   = "${var.environment}-wso2-tm"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-tm"
    image     = var.image_uri_tm
    essential = true
    portMappings = [
      { containerPort = 9611, protocol = "tcp" },
      { containerPort = 9711, protocol = "tcp" },
      { containerPort = 9443, protocol = "tcp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/wso2-tm"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ── ALB for GW ───────────────────────────────────────────────────────────────

resource "aws_lb" "gw" {
  name               = "${var.environment}-wso2-gw"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "gw_https" {
  load_balancer_arn = aws_lb.gw.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn # TODO: replace in variables.tf

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gw.arn
  }
}

resource "aws_lb_target_group" "gw" {
  name        = "${var.environment}-wso2-gw"
  port        = 8243
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/services/Version"
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_security_group" "alb" {
  name   = "${var.environment}-wso2-alb"
  vpc_id = var.vpc_id
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0;   to_port = 0;   protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}
```

- [ ] **Step 10: Write day41 variables.tf** — all Day 40 variables PLUS `image_uri_gw`, `image_uri_tm`, `vpc_id`, `public_subnet_ids`, `acm_certificate_arn` (all with `TODO` defaults).
- [ ] **Step 11: Write day41 outputs.tf** — all Day 40 outputs PLUS `alb_dns_name`, `gw_task_def_arn`, `tm_task_def_arn`.
- [ ] **Step 12: Write day41 README.md, teardown.md**.

- [ ] **Step 13: Write labs/phase3/day42/main.tf** — standalone HCL with all Day 41 resources PLUS SGs + ECS autoscaling:

Add after the `aws_security_group.alb` resource:

```hcl
resource "aws_security_group" "gw" {
  name   = "${var.environment}-wso2-gw"
  vpc_id = var.vpc_id
  ingress { from_port = 8243; to_port = 8243; protocol = "tcp"; security_groups = [aws_security_group.alb.id] }
  ingress { from_port = 8280; to_port = 8280; protocol = "tcp"; security_groups = [aws_security_group.alb.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "cp" {
  name   = "${var.environment}-wso2-cp"
  vpc_id = var.vpc_id
  ingress { from_port = 9443; to_port = 9443; protocol = "tcp"; security_groups = [aws_security_group.gw.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "is" {
  name   = "${var.environment}-wso2-is"
  vpc_id = var.vpc_id
  ingress { from_port = 9443; to_port = 9443; protocol = "tcp"
            security_groups = [aws_security_group.gw.id, aws_security_group.cp.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "tm" {
  name   = "${var.environment}-wso2-tm"
  vpc_id = var.vpc_id
  ingress { from_port = 9611; to_port = 9711; protocol = "tcp"; security_groups = [aws_security_group.gw.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
}

# ── ECS Autoscaling (GW only — CP and IS stay at fixed 1 replica) ─────────────

resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${var.environment}-wso2-gw"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "${var.environment}-wso2-gw-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

- [ ] **Step 14: Write day42 variables.tf, outputs.tf** (add `vpc_id` if not already in Day 41 variables).
- [ ] **Step 15: Write day42 README.md, teardown.md**.
- [ ] **Step 16: Verify** — all 3 Terraform lab dirs have main.tf, variables.tf, outputs.tf, README.md, teardown.md; grep confirms no real AWS account IDs (`grep -r "[0-9]\{12\}" labs/phase3/day4*/` should find only `TODO_REPLACE` placeholders).

---

### Task 5: Days 43–45 — End-to-End Integration + Smoke Test

**Files:**
- Create: `content/phase3/day43.md`, `day44.md`, `day45.md`
- Create: `labs/phase3/day43/docker-compose.yml`, `README.md`, `teardown.md`
- Create: `labs/phase3/day44/smoke_test.sh`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase3/day45/runbook.md`, `README.md`, `teardown.md`

**Interfaces:**
- Consumes: `labs/phase3/day39/main.go` (unified CP on :8082), `labs/phase2/day27/main.go` (GW on :9090), Phase 1 IS server.
- Produces: `labs/phase3/day44/smoke_test.sh` — runnable end-to-end test. `labs/phase3/day45/runbook.md` — Phase 4 starting point for production debug chapter.

- [ ] **Step 1: Write content/phase3/day43.md** covering:
  - **Why this matters:** Running all four services together is where theory becomes engineering. Most WSO2 production bugs are integration bugs — one service misconfigured to point at the wrong port, wrong hostname, or wrong API path.
  - **Docker Compose as a local ECS analogue:** Each Compose service gets its own IP; no localhost shortcuts. Service names (`cp`, `gw`, `is`) map to Cloud Map DNS names in ECS (`cp.wso2.internal`). `depends_on + condition: service_healthy` models the IS→CP→GW startup order.
  - **Service startup order:** IS first (no deps; others need JWKS). CP after IS (key manager config). GW last (needs CP for initial sync via `/admin/sync` and IS for JWKS). TM can start in parallel with CP.
  - **Exercises** (3):
    1. The GW container starts before the CP is healthy — what failure do you see in GW logs? — **Hint:** initial sync call fails — **Solution sketch:** GW logs a connection error on `/admin/sync`; it may enter a crash loop or start with an empty subscription cache, causing 403s for all requests until CP is healthy and the GW retries.
    2. Write the `depends_on` block that ensures the GW waits for both `cp` and `is` to pass their health checks — **Hint:** `condition: service_healthy` — **Solution sketch:** `depends_on: { cp: { condition: service_healthy }, is: { condition: service_healthy } }`.
    3. In ECS Fargate, there is no `depends_on` — how does WSO2 handle this in production? — **Hint:** retry loops — **Solution sketch:** each WSO2 component has startup retry logic; the GW retries the CP event hub connection with exponential backoff. In ECS, you set a `startPeriod` on health checks to allow time for dependency startup.
  - **Anti-patterns:** (1) Starting GW before CP — GW initial sync fails and it runs with empty caches; (2) Exposing CP on a public Docker port — CP is internal; expose only GW; (3) Using `restart: always` without health checks — a crashing container will loop forever without diagnostics.

- [ ] **Step 2: Write content/phase3/day44.md** covering:
  - **End-to-end flow recap:** (1) CP creates + publishes API → fires `API_PUBLISHED` SSE event; (2) GW receives event and registers the API route; (3) App created + subscribed in CP → fires `SUBSCRIPTION_CREATED` SSE event; (4) GW updates subscription cache; (5) IS issues JWT with `applicationname` claim; (6) GW validates JWT + checks subscription cache → 200.
  - **Smoke test as a diagnostic tool:** run it after every production deployment. Which step fails tells you which service has a problem: step 1 fail → CP down; step 6 fail → IS down; step 7 fail → GW JWT or subscription issue.
  - **Exercises** (3):
    1. The smoke test returns 403 on step 7 — list the 3 most likely root causes in order. — **Hint:** GW subscription cache miss, wrong tier, blocked subscription — **Solution sketch:** (a) GW hasn't received the `SUBSCRIPTION_CREATED` SSE event yet (timing); (b) subscription tier in the JWT doesn't match the tier in the subscription store; (c) the subscription exists but is BLOCKED.
    2. Modify the smoke test to also verify the GW returns the correct backend response body. — **Hint:** `curl -s` returns the body — **Solution sketch:** `BODY=$(curl -sf -H "Authorization: Bearer $TOKEN" "$GW/smoke/v1/hello"); [ "$BODY" = "hello from backend" ] || { echo "FAIL: wrong body"; exit 1; }`.
    3. The smoke test passes locally but fails in production after deployment — name 2 prod-specific causes. — **Hint:** networking, TLS — **Solution sketch:** (a) Production GW has TLS; the smoke test uses HTTP. (b) Production IS returns a JWT with a different `iss` claim that the GW rejects.

- [ ] **Step 3: Write content/phase3/day45.md** covering:
  - **Phase 3 completion recap table:** all 15 days with Go/Terraform deliverable per block.
  - **3 key design decisions and why WSO2 made them:**
    1. Why does the GW cache subscription data locally instead of calling the CP per request? → latency — per-request CP calls would add 5-50ms per API call; local cache keeps validation under 1ms.
    2. Why does WSO2 use JMS for event sync instead of HTTP polling? → reliability — JMS is durable (messages survive broker restart); HTTP polling can miss rapid state changes between polls.
    3. Why does ECS give each WSO2 component a separate task definition instead of running all in one container? → independent scaling and failure isolation — a GW crash doesn't take down the CP.
  - **Phase 4 preview:** distributed tracing (correlation IDs across all four services), custom extension points (Go Key Manager adapter, custom mediator), failure mode catalog, and the production runbook.
  - **Exercises** (3 reflection questions):
    1. You added an API to the CP but the GW still returns 404 — trace the problem using the Day 39 `/events` SSE endpoint. — **Hint:** `curl -N http://localhost:8082/events` before triggering the lifecycle change — **Solution sketch:** if no `API_PUBLISHED` event appears in the SSE stream after the lifecycle transition, the CP's EventBus isn't wired to the transition handler; if the event appears but the GW still 404s, the GW SSE subscriber isn't applying the event.
    2. In production, the event sync works but the GW has stale data after a CP restart — why, and how do you fix it? — **Hint:** CP restarts with empty in-memory state — **Solution sketch:** the CP's in-memory registry is wiped on restart. Fix: the CP needs a persistent store (DB) so it rebuilds state on restart. In our Go lab, this is a known limitation — the Day 45 runbook flags it as a Phase 4 follow-up.
    3. Your company's CP and IS run on different ECS clusters — what changes in the GW config? — **Hint:** DNS names and SGs — **Solution sketch:** the GW's `WSO2_CP_URL` and `WSO2_IS_URL` env vars point at the appropriate Cloud Map DNS names for each cluster; the GW SG must allow outbound to both CP and IS SGs across the clusters (VPC peering or Transit Gateway required for cross-cluster communication).
  - **Anti-patterns:** (1) Treating Phase 3's in-memory CP as production-ready — it loses all state on restart; (2) Not running the smoke test after every deployment — silent failures accumulate; (3) Assuming SUBSCRIPTION_CREATED events are always received before the first API call — there's always a race window; the GW should fall back to calling the CP validate endpoint on a cache miss.

- [ ] **Step 4: Write labs/phase3/day43/docker-compose.yml**:

```yaml
# Day 43 Lab — Docker Compose: four WSO2 Go services
# Prerequisites: build Dockerfiles in each lab dir first
# Do NOT run terraform apply — local Docker integration only

version: "3.9"

services:
  # Identity Server (Phase 1 Go KM — add Dockerfile to labs/phase1/day15/)
  is:
    build:
      context: ../../../labs/phase1/day15
      # TODO: add a Dockerfile to labs/phase1/day15/ that runs: go run main.go
    image: wso2-is-go:local
    ports:
      - "8080:8080"
    environment:
      PORT: "8080"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

  # Control Plane (Phase 3 Day 39 unified CP)
  cp:
    build:
      context: ../../../labs/phase3/day39
      # TODO: add a Dockerfile to labs/phase3/day39/ that runs: go run main.go
    image: wso2-cp-go:local
    ports:
      - "8082:8082"
    depends_on:
      is:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8082/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

  # Universal Gateway (Phase 2 Day 27 GW)
  gw:
    build:
      context: ../../../labs/phase2/day27
      # TODO: add a Dockerfile to labs/phase2/day27/ that runs: go run main.go
    image: wso2-gw-go:local
    ports:
      - "9090:9090"
    environment:
      PORT: "9090"
      BACKEND_URL: "http://backend:8000"
      JWKS_URL: "http://is:8080/oauth2/jwks"
      CP_URL: "http://cp:8082"
    depends_on:
      cp:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:9090/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

  # Mock backend (returns a fixed response)
  backend:
    image: hashicorp/http-echo:latest
    command: ["-text=hello from backend", "-listen=:8000"]
    ports:
      - "8000:8000"
```

- [ ] **Step 5: Write labs/phase3/day43/README.md** — step-by-step: add Dockerfiles to Phase 1/2/3 lab dirs (`FROM golang:1.22-alpine; WORKDIR /app; COPY main.go .; RUN go mod init lab && go mod tidy; CMD ["go","run","main.go"]`); then `docker compose up --build`; expected: all 4 services healthy.
- [ ] **Step 6: Write labs/phase3/day43/teardown.md** — `docker compose down`.

- [ ] **Step 7: Write labs/phase3/day44/smoke_test.sh**:

```bash
#!/usr/bin/env bash
# Phase 3 smoke test — end-to-end validation of CP → GW → IS integration
# Prerequisites: docker compose up (from labs/phase3/day43/)
# Usage: bash smoke_test.sh
set -euo pipefail

CP="http://localhost:8082"
IS="http://localhost:8080"
GW="http://localhost:9090"

echo "=== Phase 3 Smoke Test ==="

# Step 1: Create + publish API in CP
echo "[1] Create API..."
API=$(curl -sf -X POST "$CP/apis" \
  -H 'Content-Type: application/json' \
  -d '{"name":"SmokeAPI","context":"/smoke/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}')
API_ID=$(echo "$API" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$API_ID" ] && { echo "FAIL: could not create API"; exit 1; }
echo "  Created: $API_ID"

echo "[2] Publish API..."
curl -sf -X POST "$CP/apis/$API_ID/lifecycle" \
  -H 'Content-Type: application/json' -d '{"action":"Publish"}' > /dev/null
echo "  Published."

# Step 2: Create application + subscription
echo "[3] Create application..."
APP=$(curl -sf -X POST "$CP/applications" \
  -H 'Content-Type: application/json' \
  -d '{"name":"SmokeApp","owner":"tester"}')
APP_ID=$(echo "$APP"    | grep -o '"id":"[^"]*"'          | head -1 | cut -d'"' -f4)
KEY=$(echo "$APP"       | grep -o '"consumerKey":"[^"]*"'  | cut -d'"' -f4)
echo "  App: $APP_ID  Key: $KEY"

echo "[4] Subscribe app to API (Gold tier)..."
curl -sf -X POST "$CP/subscriptions" \
  -H 'Content-Type: application/json' \
  -d "{\"appId\":\"$APP_ID\",\"apiId\":\"$API_ID\",\"tier\":\"Gold\"}" > /dev/null
echo "  Subscribed."

echo "[5] Register API context for validate endpoint..."
curl -sf -X POST "$CP/admin/apis" \
  -H 'Content-Type: application/json' \
  -d "{\"apiId\":\"$API_ID\",\"apiContext\":\"/smoke/v1\"}" > /dev/null || true
echo "  Done."

# Step 3: Get JWT from IS
echo "[6] Obtain JWT from IS..."
TOKEN_RESP=$(curl -sf -X POST "$IS/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=${KEY}&client_secret=unused&scope=default")
ACCESS_TOKEN=$(echo "$TOKEN_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
[ -z "$ACCESS_TOKEN" ] && { echo "FAIL: IS did not return access_token"; exit 1; }
echo "  Token: ${ACCESS_TOKEN:0:30}..."

# Step 4: Call GW
echo "[7] Call API through GW..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$GW/smoke/v1/hello" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  echo "  PASS — GW returned 200"
else
  echo "  FAIL — GW returned $HTTP_CODE"
  exit 1
fi

echo ""
echo "=== ALL STEPS PASSED ==="
```

- [ ] **Step 8: Write labs/phase3/day44/README.md** — prerequisites, how to run (`chmod +x smoke_test.sh && ./smoke_test.sh`), what each step tests, what failure at each step means.
- [ ] **Step 9: Write labs/phase3/day44/SOLUTION.md** — explain the failure diagnostic mapping: step 1 fail = CP down; step 6 fail = IS down; step 7 fail = GW JWT or subscription issue; show `curl -N http://localhost:8082/events` trick to watch events fire in real time.
- [ ] **Step 10: Write labs/phase3/day44/teardown.md** — `docker compose down` from `labs/phase3/day43/`.

- [ ] **Step 11: Write labs/phase3/day45/runbook.md**:

```markdown
# WSO2 Control Plane + Event Sync — Phase 3 Runbook

## Topology (Docker Compose / local)

```
Client → GW :9090 ─── JWT validate ──→ IS :8080 (/oauth2/jwks)
                  ├── subscribe check → CP :8082 (/subscriptions/validate)
                  └── backend :8000

CP :8082 → SSE /events ──→ GW subscribes on startup
CP :8082 → /admin/sync ──→ GW calls on startup (initial load)
```

## CP API quick reference

| Endpoint | Method | What it does |
|---|---|---|
| `/apis` | POST | Create API (CREATED state) |
| `/apis/{id}/lifecycle` | POST `{"action":"Publish"}` | Publish API |
| `/apis/{id}/policies` | GET | List allowed tiers |
| `/apis/{id}/tiers` | PUT `{"tiers":[...]}` | Update tiers (CREATED/DEPRECATED only) |
| `/applications` | POST | Create consumer app |
| `/subscriptions` | POST | Subscribe app to API |
| `/subscriptions/validate` | GET `?consumerKey=...&apiContext=...` | GW validation check |
| `/admin/apis` | POST `{"apiId","apiContext"}` | Register API context for validate |
| `/admin/sync` | GET | Full CP state for GW initial load |
| `/events` | GET (SSE) | Stream CP events to GW subscribers |
| `/health` | GET | Health check |

## Event types

| Type | Fired when | Key payload fields |
|---|---|---|
| `API_PUBLISHED` | Lifecycle → PUBLISHED | `id, context, version, tiers` |
| `API_DEPRECATED` | Lifecycle → DEPRECATED | `id, context` |
| `SUBSCRIPTION_CREATED` | New UNBLOCKED subscription | `appId, apiId, tier` |
| `SUBSCRIPTION_REMOVED` | Subscription blocked/deleted | `appId, apiId` |

## Event sync failure checklist

- [ ] GW returns 403 for a published API → check SSE: `curl -N http://cp:8082/events` before re-publishing
- [ ] GW returns 403 for a valid subscription → check SSE for `SUBSCRIPTION_CREATED` event
- [ ] Events not flowing → confirm `Content-Type: text/event-stream` on `/events`; check SG/network between GW and CP
- [ ] GW just restarted → GW must call `/admin/sync` on startup; check GW logs for sync errors

## Production ECS Fargate checklist (from Day 42)

- [ ] All tasks in private subnets; ALB in public subnets (GW only)
- [ ] SGs: ALB → GW (8243); GW → CP (9443); GW → IS (9443); GW → TM (9611-9711); CP → IS (9443)
- [ ] IAM execution role ≠ task role; task role has `secretsmanager:GetSecretValue` only
- [ ] Health check paths: GW `/services/Version`, IS `/oauth2/token` (HEAD), CP `/services/Version`
- [ ] CloudWatch log groups: `/ecs/{env}/wso2-{cp,gw,is,tm}` — grep by `activityid` for request tracing
- [ ] GW autoscaling: target 60% CPU, min 1, max 4; scale_out_cooldown 60s, scale_in_cooldown 300s

## Known limitations of the Phase 3 Go CP (carry into Phase 4)

- **In-memory state:** CP loses all APIs + subscriptions on restart. Phase 4: add persistence.
- **No authentication on CP endpoints:** anyone can create/publish APIs. Phase 4: add auth middleware.
- **SSE reconnect:** GW must reconnect to `/events` if the connection drops. Phase 4: add reconnect with re-sync.
```

- [ ] **Step 12: Write labs/phase3/day45/README.md** — "Review day: run the smoke test one more time, read the runbook, and write 3 entries in your 'why' log (one per key design decision from the day45.md content file). No new code."
- [ ] **Step 13: Write labs/phase3/day45/teardown.md** — `docker compose down` from `labs/phase3/day43/`.
- [ ] **Step 14: Verify** — `smoke_test.sh` is executable (`-rwxr-xr-x`), runbook.md exists, day45 has no Go code (review only), all content files in `content/phase3/`.

---

## Self-Review Checklist

- [ ] Every exercise in every day file (day31–day45) has `**Hint:**` and `**Solution sketch:**`.
- [ ] Every Go lab (day32, day33, day35, day36, day38, day39, day43-area, day44) has `main.go`/`docker-compose.yml`/`smoke_test.sh` + `README.md` + `SOLUTION.md` + `teardown.md`.
- [ ] Source-reading labs (day31, day34, day37) have `README.md` with `find`/`grep` commands only.
- [ ] Every Terraform lab (day40, day41, day42) has `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `teardown.md`.
- [ ] No real AWS account IDs — grep confirms: `grep -r "[0-9]\{12\}" labs/phase3/` finds only `TODO_REPLACE_WITH_YOUR_ACCOUNT_ID`.
- [ ] No real credentials, tokens, or secrets in any file.
- [ ] No `git commit`, `git add`, `git status`, `git log`, or `git diff` commands anywhere in the plan.
- [ ] Day 39 SSE endpoint has `Content-Type: text/event-stream` header.
- [ ] `smoke_test.sh` README instructs `chmod +x smoke_test.sh`.
- [ ] All content files are in `content/phase3/` subdirectory (not `content/phase2/`).
- [ ] `labs/phase3/day45/runbook.md` exists with Known Limitations section.
- [ ] Day 43 `docker-compose.yml` has `TODO` comments on `build.context` — no real image URIs hardcoded.
