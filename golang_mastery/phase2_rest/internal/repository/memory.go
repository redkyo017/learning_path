package repository

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

var ErrNotFound = fmt.Errorf("task not found")

type MemoryTaskRepository struct {
	mu    sync.RWMutex
	tasks map[string]model.Task
	seq   int
}

func NewMemoryTaskRepository() *MemoryTaskRepository {
	return &MemoryTaskRepository{tasks: make(map[string]model.Task)}
}

func (r *MemoryTaskRepository) List(_ context.Context) ([]model.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]model.Task, 0, len(r.tasks))
	for _, t := range r.tasks {
		out = append(out, t)
	}
	return out, nil
}

func (r *MemoryTaskRepository) Get(_ context.Context, id string) (model.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.tasks[id]
	if !ok {
		return model.Task{}, ErrNotFound
	}
	return t, nil
}

func (r *MemoryTaskRepository) Create(_ context.Context, title string) (model.Task, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.seq++
	t := model.Task{
		ID:        fmt.Sprintf("task-%d", r.seq),
		Title:     title,
		CreatedAt: time.Now(),
	}
	r.tasks[t.ID] = t
	return t, nil
}

func (r *MemoryTaskRepository) Complete(_ context.Context, id string) (model.Task, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	t, ok := r.tasks[id]
	if !ok {
		return model.Task{}, ErrNotFound
	}
	t.Done = true
	r.tasks[id] = t
	return t, nil
}
