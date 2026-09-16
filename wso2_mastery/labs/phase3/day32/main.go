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
