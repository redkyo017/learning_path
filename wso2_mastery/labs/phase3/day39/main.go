package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"
)

// ── API Registry (from Day 33) ────────────────────────────────────────

type LifecycleStatus string

const (
	StatusCreated    LifecycleStatus = "CREATED"
	StatusPublished  LifecycleStatus = "PUBLISHED"
	StatusDeprecated LifecycleStatus = "DEPRECATED"
	StatusRetired    LifecycleStatus = "RETIRED"
)

var validTransitions = map[LifecycleStatus][]LifecycleStatus{
	StatusCreated:    {StatusPublished},
	StatusPublished:  {StatusDeprecated},
	StatusDeprecated: {StatusRetired},
}

type API struct {
	ID           string          `json:"id"`
	Name         string          `json:"name"`
	Context      string          `json:"context"`
	Version      string          `json:"version"`
	BackendURL   string          `json:"backendUrl"`
	Status       LifecycleStatus `json:"status"`
	AllowedTiers []string        `json:"allowedTiers"`
	CreatedAt    time.Time       `json:"createdAt"`
}

type Registry struct {
	mu   sync.RWMutex
	apis map[string]*API
}

func NewRegistry() *Registry { return &Registry{apis: make(map[string]*API)} }

// ── Subscription Store (from Day 35/36) ───────────────────────────────

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
	mu            sync.RWMutex
	apps          map[string]*Application
	byKey         map[string]*Application
	subs          map[string]*Subscription
	subIdx        map[string][]*Subscription
	apiContextMap map[string]string
}

func NewStore() *Store {
	return &Store{
		apps:          make(map[string]*Application),
		byKey:         make(map[string]*Application),
		subs:          make(map[string]*Subscription),
		subIdx:        make(map[string][]*Subscription),
		apiContextMap: make(map[string]string),
	}
}

// ── Event Bus (from Day 38) ───────────────────────────────────────────

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

// ── Unified Control Plane ─────────────────────────────────────────────

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

// Helper functions
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

func tierDescription(tier string) string {
	switch tier {
	case "Bronze":
		return "1000 requests per minute"
	case "Silver":
		return "2000 requests per minute"
	case "Gold":
		return "5000 requests per minute"
	case "Unlimited":
		return "No rate limit"
	default:
		return "Unknown tier"
	}
}

func toEventType(s LifecycleStatus) EventType {
	switch s {
	case StatusPublished:
		return EventAPIPublished
	case StatusDeprecated:
		return EventAPIDeprecated
	case StatusRetired:
		return EventAPIRetired
	default:
		return EventAPICreated
	}
}

// ── API Registry Handlers ─────────────────────────────────────────────

func (cp *ControlPlane) createAPI(w http.ResponseWriter, req *http.Request) {
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
	cp.reg.mu.Lock()
	cp.reg.apis[api.ID] = api
	cp.reg.mu.Unlock()

	// Publish event
	cp.bus.Publish(NewEvent(EventAPICreated, map[string]any{
		"id": api.ID, "name": api.Name, "context": api.Context,
		"version": api.Version, "status": api.Status,
	}))

	writeJSON(w, http.StatusCreated, api)
}

func (cp *ControlPlane) listAPIs(w http.ResponseWriter, _ *http.Request) {
	cp.reg.mu.RLock()
	list := make([]*API, 0, len(cp.reg.apis))
	for _, a := range cp.reg.apis {
		list = append(list, a)
	}
	cp.reg.mu.RUnlock()
	writeJSON(w, http.StatusOK, list)
}

func (cp *ControlPlane) getAPI(w http.ResponseWriter, id string) {
	cp.reg.mu.RLock()
	api, ok := cp.reg.apis[id]
	cp.reg.mu.RUnlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, api)
}

func (cp *ControlPlane) deleteAPI(w http.ResponseWriter, id string) {
	cp.reg.mu.Lock()
	_, ok := cp.reg.apis[id]
	if ok {
		delete(cp.reg.apis, id)
	}
	cp.reg.mu.Unlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (cp *ControlPlane) transitionLifecycle(w http.ResponseWriter, id string, req *http.Request) {
	var body struct {
		Action string `json:"action"`
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
	cp.reg.mu.Lock()
	defer cp.reg.mu.Unlock()
	api, ok := cp.reg.apis[id]
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
	oldStatus := api.Status
	api.Status = target

	// Publish event
	cp.bus.Publish(NewEvent(toEventType(target), map[string]any{
		"id": api.ID, "name": api.Name, "context": api.Context,
		"version": api.Version,
		"oldStatus": oldStatus, "newStatus": target,
		"tiers": api.AllowedTiers,
	}))

	writeJSON(w, http.StatusOK, api)
}

func (cp *ControlPlane) getPolicies(w http.ResponseWriter, id string) {
	cp.reg.mu.RLock()
	api, ok := cp.reg.apis[id]
	cp.reg.mu.RUnlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	type Policy struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	policies := make([]Policy, len(api.AllowedTiers))
	for i, t := range api.AllowedTiers {
		policies[i] = Policy{Name: t, Description: tierDescription(t)}
	}
	writeJSON(w, http.StatusOK, policies)
}

func (cp *ControlPlane) updateTiers(w http.ResponseWriter, id string, req *http.Request) {
	var body struct {
		Tiers []string `json:"tiers"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	cp.reg.mu.Lock()
	api, ok := cp.reg.apis[id]
	if ok && api.Status == StatusPublished {
		cp.reg.mu.Unlock()
		http.Error(w, `{"error":"deprecate the API before changing tiers"}`, http.StatusBadRequest)
		return
	}
	if ok {
		api.AllowedTiers = body.Tiers
	}
	cp.reg.mu.Unlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	cp.reg.mu.RLock()
	a := cp.reg.apis[id]
	cp.reg.mu.RUnlock()
	writeJSON(w, http.StatusOK, a)
}

// ── Subscription Store Handlers ───────────────────────────────────────

func (cp *ControlPlane) createApp(w http.ResponseWriter, req *http.Request) {
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
	cp.subs.mu.Lock()
	cp.subs.apps[app.ID] = app
	cp.subs.byKey[app.ConsumerKey] = app
	cp.subs.mu.Unlock()
	writeJSON(w, http.StatusCreated, app)
}

func (cp *ControlPlane) getApp(w http.ResponseWriter, id string) {
	cp.subs.mu.RLock()
	app, ok := cp.subs.apps[id]
	cp.subs.mu.RUnlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	safe := *app
	safe.ConsumerSecret = "***"
	writeJSON(w, http.StatusOK, &safe)
}

func (cp *ControlPlane) createSub(w http.ResponseWriter, req *http.Request) {
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
	cp.subs.mu.Lock()
	cp.subs.subs[sub.ID] = sub
	cp.subs.subIdx[sub.AppID] = append(cp.subs.subIdx[sub.AppID], sub)
	cp.subs.mu.Unlock()

	// Publish event
	cp.bus.Publish(NewEvent(EventSubCreated, map[string]any{
		"id": sub.ID, "appId": sub.AppID, "apiId": sub.APIID,
		"tier": sub.Tier, "status": sub.Status,
	}))

	writeJSON(w, http.StatusCreated, sub)
}

func (cp *ControlPlane) listSubs(w http.ResponseWriter, req *http.Request) {
	appID := req.URL.Query().Get("appId")
	cp.subs.mu.RLock()
	list := cp.subs.subIdx[appID]
	if list == nil {
		list = []*Subscription{}
	}
	cp.subs.mu.RUnlock()
	writeJSON(w, http.StatusOK, list)
}

func (cp *ControlPlane) registerAPI(w http.ResponseWriter, req *http.Request) {
	var body struct {
		APIID      string `json:"apiId"`
		APIContext string `json:"apiContext"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.APIID == "" || body.APIContext == "" {
		http.Error(w, "apiId and apiContext are required", http.StatusBadRequest)
		return
	}
	cp.subs.mu.Lock()
	cp.subs.apiContextMap[body.APIContext] = body.APIID
	cp.subs.mu.Unlock()
	writeJSON(w, http.StatusCreated, map[string]string{
		"apiId":      body.APIID,
		"apiContext": body.APIContext,
	})
}

func (cp *ControlPlane) validateSub(w http.ResponseWriter, req *http.Request) {
	q := req.URL.Query()
	consumerKey, apiContext, tier := q.Get("consumerKey"), q.Get("apiContext"), q.Get("tier")
	if consumerKey == "" || apiContext == "" {
		http.Error(w, "consumerKey and apiContext required", http.StatusBadRequest)
		return
	}
	cp.subs.mu.RLock()
	defer cp.subs.mu.RUnlock()

	app, ok := cp.subs.byKey[consumerKey]
	if !ok {
		writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "application_not_found"})
		return
	}

	apiID := cp.subs.apiContextMap[apiContext]
	if apiID == "" {
		writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "api_not_found"})
		return
	}

	for _, sub := range cp.subs.subIdx[app.ID] {
		if sub.APIID == apiID {
			if sub.Status != SubUnblocked {
				writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_blocked"})
				return
			}
			if tier != "" && sub.Tier != tier {
				writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "tier_mismatch"})
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{
				"valid":   true,
				"tier":    sub.Tier,
				"appName": app.Name,
				"appId":   app.ID,
			})
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_not_found"})
}

// ── Event Bus Handlers ────────────────────────────────────────────────

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

// ── HTTP Routing ──────────────────────────────────────────────────────

func main() {
	cp := NewControlPlane()
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})

	// APIs (Registry)
	mux.HandleFunc("/apis", func(w http.ResponseWriter, req *http.Request) {
		switch req.Method {
		case http.MethodPost:
			cp.createAPI(w, req)
		case http.MethodGet:
			cp.listAPIs(w, req)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/apis/", func(w http.ResponseWriter, req *http.Request) {
		parts := strings.Split(strings.Trim(req.URL.Path, "/"), "/")
		if len(parts) < 2 {
			http.Error(w, "bad path", http.StatusBadRequest)
			return
		}
		id := parts[1]

		if len(parts) == 3 && parts[2] == "policies" && req.Method == http.MethodGet {
			cp.getPolicies(w, id)
			return
		}

		if len(parts) == 3 && parts[2] == "tiers" && req.Method == http.MethodPut {
			cp.updateTiers(w, id, req)
			return
		}

		if len(parts) == 3 && parts[2] == "lifecycle" && req.Method == http.MethodPost {
			cp.transitionLifecycle(w, id, req)
			return
		}

		switch req.Method {
		case http.MethodGet:
			cp.getAPI(w, id)
		case http.MethodDelete:
			cp.deleteAPI(w, id)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Applications (Subscriptions)
	mux.HandleFunc("/applications", func(w http.ResponseWriter, req *http.Request) {
		if req.Method == http.MethodPost {
			cp.createApp(w, req)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/applications/", func(w http.ResponseWriter, req *http.Request) {
		id := strings.TrimPrefix(req.URL.Path, "/applications/")
		if req.Method == http.MethodGet {
			cp.getApp(w, id)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Subscriptions
	mux.HandleFunc("/subscriptions/validate", func(w http.ResponseWriter, req *http.Request) {
		if req.Method == http.MethodGet {
			cp.validateSub(w, req)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/subscriptions", func(w http.ResponseWriter, req *http.Request) {
		if req.Method == http.MethodPost {
			cp.createSub(w, req)
		} else if req.Method == http.MethodGet {
			cp.listSubs(w, req)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Admin
	mux.HandleFunc("/admin/", func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/admin/apis" && req.Method == http.MethodPost {
			cp.registerAPI(w, req)
		} else if req.URL.Path == "/admin/sync" && req.Method == http.MethodGet {
			cp.adminSync(w, req)
		} else {
			http.Error(w, "not found", http.StatusNotFound)
		}
	})

	// Events (SSE)
	mux.HandleFunc("/events", func(w http.ResponseWriter, req *http.Request) {
		if req.Method == http.MethodGet {
			cp.eventsSSE(w, req)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	fmt.Println("WSO2 CP — Unified Control Plane listening on :8082")
	http.ListenAndServe(":8082", mux)
}
