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
