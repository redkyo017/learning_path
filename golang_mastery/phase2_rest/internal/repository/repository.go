package repository

import (
	"context"

	"github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

// TaskRepository is the interface the handler depends on.
// Concrete implementations: PostgresTaskRepository (prod), MemoryTaskRepository (tests).
type TaskRepository interface {
	List(ctx context.Context) ([]model.Task, error)
	Get(ctx context.Context, id string) (model.Task, error)
	Create(ctx context.Context, title string) (model.Task, error)
	Complete(ctx context.Context, id string) (model.Task, error)
}
