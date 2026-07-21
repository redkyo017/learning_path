package handler

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

// StdlibTaskHandler demonstrates a handler using only net/http.
// Day 7 will replace this with Gin.
type StdlibTaskHandler struct {
	mu    sync.RWMutex
	tasks map[string]model.Task
}

func NewStdlibTaskHandler() *StdlibTaskHandler {
	return &StdlibTaskHandler{tasks: make(map[string]model.Task)}
}

func (h *StdlibTaskHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.list(w, r)
	case http.MethodPost:
		h.create(w, r)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (h *StdlibTaskHandler) list(w http.ResponseWriter, r *http.Request) {
	h.mu.RLock()
	tasks := make([]model.Task, 0, len(h.tasks))
	for _, t := range h.tasks {
		tasks = append(tasks, t)
	}
	h.mu.RUnlock()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tasks)
}

func (h *StdlibTaskHandler) create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if req.Title == "" {
		http.Error(w, "title required", http.StatusBadRequest)
		return
	}
	t := model.Task{
		ID:        time.Now().Format("20060102150405.000"),
		Title:     req.Title,
		CreatedAt: time.Now(),
	}
	h.mu.Lock()
	h.tasks[t.ID] = t
	h.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(t)
}
