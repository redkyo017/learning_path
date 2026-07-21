package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/yourname/golang-mastery/phase2-rest/internal/model"
)

type PostgresTaskRepository struct {
	db *sql.DB
}

func NewPostgresTaskRepository(db *sql.DB) *PostgresTaskRepository {
	return &PostgresTaskRepository{db: db}
}

func OpenPostgres(dsn string) (*sql.DB, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping: %w", err)
	}
	return db, nil
}

func (r *PostgresTaskRepository) List(ctx context.Context) ([]model.Task, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, title, done, created_at FROM tasks ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(&t.ID, &t.Title, &t.Done, &t.CreatedAt); err != nil {
			return nil, err
		}
		tasks = append(tasks, t)
	}
	return tasks, rows.Err()
}

func (r *PostgresTaskRepository) Get(ctx context.Context, id string) (model.Task, error) {
	var t model.Task
	err := r.db.QueryRowContext(ctx,
		`SELECT id, title, done, created_at FROM tasks WHERE id = $1`, id).
		Scan(&t.ID, &t.Title, &t.Done, &t.CreatedAt)
	if err == sql.ErrNoRows {
		return model.Task{}, ErrNotFound
	}
	return t, err
}

func (r *PostgresTaskRepository) Create(ctx context.Context, title string) (model.Task, error) {
	t := model.Task{
		ID:        fmt.Sprintf("task-%d", time.Now().UnixNano()),
		Title:     title,
		CreatedAt: time.Now(),
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO tasks (id, title, done, created_at) VALUES ($1,$2,$3,$4)`,
		t.ID, t.Title, t.Done, t.CreatedAt)
	return t, err
}

func (r *PostgresTaskRepository) Complete(ctx context.Context, id string) (model.Task, error) {
	_, err := r.db.ExecContext(ctx,
		`UPDATE tasks SET done=TRUE WHERE id=$1`, id)
	if err != nil {
		return model.Task{}, err
	}
	return r.Get(ctx, id)
}
