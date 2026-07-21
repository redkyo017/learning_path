package server_test

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
	"github.com/yourname/golang-mastery/phase3-grpc/internal/server"
)

func TestCreateAndGet(t *testing.T) {
	s := server.NewTaskServer()
	ctx := context.Background()

	resp, err := s.CreateTask(ctx, &taskv1.CreateTaskRequest{Title: "test"})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Task.Id == "" {
		t.Error("expected non-empty ID")
	}

	got, err := s.GetTask(ctx, &taskv1.GetTaskRequest{Id: resp.Task.Id})
	if err != nil {
		t.Fatal(err)
	}
	if got.Task.Title != "test" {
		t.Errorf("title = %q, want %q", got.Task.Title, "test")
	}
}

func TestCreateEmptyTitle(t *testing.T) {
	s := server.NewTaskServer()
	_, err := s.CreateTask(context.Background(), &taskv1.CreateTaskRequest{})
	st, _ := status.FromError(err)
	if st.Code() != codes.InvalidArgument {
		t.Errorf("code = %v, want InvalidArgument", st.Code())
	}
}

func TestGetNotFound(t *testing.T) {
	s := server.NewTaskServer()
	_, err := s.GetTask(context.Background(), &taskv1.GetTaskRequest{Id: "nonexistent"})
	st, _ := status.FromError(err)
	if st.Code() != codes.NotFound {
		t.Errorf("code = %v, want NotFound", st.Code())
	}
}
