//go:build integration

package repository_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"

	"github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

func TestPostgresRepository(t *testing.T) {
	ctx := context.Background()

	// postgres.Run (testcontainers-go v0.32+) replaces the deprecated RunContainer.
	// BasicWaitStrategies waits for the "ready" log twice (Postgres restarts
	// once after initdb) plus the listening port.
	pgContainer, err := postgres.Run(ctx, "postgres:18-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		postgres.BasicWaitStrategies(),
	)
	testcontainers.CleanupContainer(t, pgContainer)
	if err != nil {
		t.Fatalf("start postgres: %v", err)
	}

	dsn, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	// Run migration manually for the test
	_, err = db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS tasks (
			id TEXT PRIMARY KEY,
			title TEXT NOT NULL,
			done BOOLEAN NOT NULL DEFAULT FALSE,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`)
	if err != nil {
		t.Fatal(err)
	}

	repo := repository.NewPostgresTaskRepository(db)

	t.Run("create and get", func(t *testing.T) {
		task, err := repo.Create(ctx, "integration test task")
		if err != nil {
			t.Fatal(err)
		}
		got, err := repo.Get(ctx, task.ID)
		if err != nil {
			t.Fatal(err)
		}
		if got.Title != "integration test task" {
			t.Errorf("title = %q, want %q", got.Title, "integration test task")
		}
	})

	t.Run("complete", func(t *testing.T) {
		task, _ := repo.Create(ctx, "to complete")
		done, err := repo.Complete(ctx, task.ID)
		if err != nil {
			t.Fatal(err)
		}
		if !done.Done {
			t.Error("expected done=true")
		}
	})

	t.Run("not found", func(t *testing.T) {
		_, err := repo.Get(ctx, "nonexistent")
		if !errors.Is(err, repository.ErrNotFound) {
			t.Errorf("expected ErrNotFound, got %v", err)
		}
	})
}
