package handler_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/yourname/golang-mastery/phase2-rest/internal/handler"
	"github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
	"github.com/yourname/golang-mastery/phase2-rest/internal/model"
	"github.com/yourname/golang-mastery/phase2-rest/internal/repository"
)

func setupRouter() (*gin.Engine, *repository.MemoryTaskRepository) {
	gin.SetMode(gin.TestMode)
	repo := repository.NewMemoryTaskRepository()
	h := handler.NewTaskHandler(repo)
	r := gin.New()
	r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	v1 := r.Group("/api/v1")
	v1.Use(middleware.Auth())
	v1.GET("/tasks", h.List)
	v1.POST("/tasks", h.Create)
	v1.GET("/tasks/:id", h.Get)
	v1.PATCH("/tasks/:id/complete", h.Complete)
	return r, repo
}

func authHeader() string {
	token, _ := middleware.GenerateToken("user1")
	return "Bearer " + token
}

func TestTaskEndpoints(t *testing.T) {
	r, _ := setupRouter()

	var createdID string

	tests := []struct {
		name       string
		method     string
		path       string
		body       string
		wantStatus int
		check      func(t *testing.T, body []byte)
	}{
		{
			name: "create task",
			method: http.MethodPost, path: "/api/v1/tasks",
			body: `{"title":"buy milk"}`, wantStatus: http.StatusCreated,
			check: func(t *testing.T, body []byte) {
				var task model.Task
				json.Unmarshal(body, &task)
				if task.ID == "" {
					t.Error("expected ID")
				}
				createdID = task.ID
			},
		},
		{
			name: "create empty title",
			method: http.MethodPost, path: "/api/v1/tasks",
			body: `{}`, wantStatus: http.StatusBadRequest,
		},
		{
			name: "list tasks",
			method: http.MethodGet, path: "/api/v1/tasks",
			wantStatus: http.StatusOK,
			check: func(t *testing.T, body []byte) {
				var tasks []model.Task
				json.Unmarshal(body, &tasks)
				if len(tasks) == 0 {
					t.Error("expected at least one task")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var bodyReader *bytes.Reader
			if tt.body != "" {
				bodyReader = bytes.NewReader([]byte(tt.body))
			} else {
				bodyReader = bytes.NewReader(nil)
			}
			w := httptest.NewRecorder()
			req, _ := http.NewRequest(tt.method, tt.path, bodyReader)
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("Authorization", authHeader())
			r.ServeHTTP(w, req)
			if w.Code != tt.wantStatus {
				t.Errorf("status = %d, want %d (body: %s)",
					w.Code, tt.wantStatus, w.Body.String())
			}
			if tt.check != nil {
				tt.check(t, w.Body.Bytes())
			}
		})
	}

	// get by id — depends on createdID from first test
	if createdID != "" {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet,
			fmt.Sprintf("/api/v1/tasks/%s", createdID), nil)
		req.Header.Set("Authorization", authHeader())
		r.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Errorf("get by id status = %d, want 200", w.Code)
		}
	}
}

func TestAuthRequired(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.Auth())
	h := handler.NewTaskHandler(repository.NewMemoryTaskRepository())
	r.GET("/api/v1/tasks", h.List)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestAuthValid(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.Auth())
	h := handler.NewTaskHandler(repository.NewMemoryTaskRepository())
	r.GET("/api/v1/tasks", h.List)

	token, _ := middleware.GenerateToken("user1")
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", w.Code)
	}
}

func BenchmarkCreateTask(b *testing.B) {
	r, _ := setupRouter()
	token, _ := middleware.GenerateToken("bench-user")
	auth := "Bearer " + token

	b.ResetTimer()
	for range b.N {
		body := bytes.NewReader([]byte(`{"title":"bench task"}`))
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodPost, "/api/v1/tasks", body)
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", auth)
		r.ServeHTTP(w, req)
	}
}
