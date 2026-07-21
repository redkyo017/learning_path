package server

import (
	"context"
	"fmt"
	"sync"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
)

type TaskServer struct {
	taskv1.UnimplementedTaskServiceServer
	mu    sync.RWMutex
	tasks map[string]*taskv1.Task
	seq   int
}

func NewTaskServer() *TaskServer {
	return &TaskServer{tasks: make(map[string]*taskv1.Task)}
}

func (s *TaskServer) ListTasks(_ context.Context, _ *taskv1.ListTasksRequest) (*taskv1.ListTasksResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	tasks := make([]*taskv1.Task, 0, len(s.tasks))
	for _, t := range s.tasks {
		tasks = append(tasks, t)
	}
	return &taskv1.ListTasksResponse{Tasks: tasks}, nil
}

func (s *TaskServer) GetTask(_ context.Context, req *taskv1.GetTaskRequest) (*taskv1.GetTaskResponse, error) {
	if req.Id == "" {
		return nil, status.Error(codes.InvalidArgument, "id is required")
	}
	s.mu.RLock()
	t, ok := s.tasks[req.Id]
	s.mu.RUnlock()
	if !ok {
		return nil, status.Errorf(codes.NotFound, "task %q not found", req.Id)
	}
	return &taskv1.GetTaskResponse{Task: t}, nil
}

func (s *TaskServer) CreateTask(_ context.Context, req *taskv1.CreateTaskRequest) (*taskv1.CreateTaskResponse, error) {
	if req.Title == "" {
		return nil, status.Error(codes.InvalidArgument, "title is required")
	}
	s.mu.Lock()
	s.seq++
	t := &taskv1.Task{
		Id:        fmt.Sprintf("task-%d", s.seq),
		Title:     req.Title,
		CreatedAt: timestamppb.New(time.Now()),
	}
	s.tasks[t.Id] = t
	s.mu.Unlock()
	return &taskv1.CreateTaskResponse{Task: t}, nil
}

func (s *TaskServer) CompleteTask(_ context.Context, req *taskv1.CompleteTaskRequest) (*taskv1.CompleteTaskResponse, error) {
	if req.Id == "" {
		return nil, status.Error(codes.InvalidArgument, "id is required")
	}
	s.mu.Lock()
	t, ok := s.tasks[req.Id]
	if ok {
		t.Done = true
	}
	s.mu.Unlock()
	if !ok {
		return nil, status.Errorf(codes.NotFound, "task %q not found", req.Id)
	}
	return &taskv1.CompleteTaskResponse{Task: t}, nil
}

// StreamTasks streams all tasks to the client one by one (added Day 14).
func (s *TaskServer) StreamTasks(
	_ *taskv1.StreamTasksRequest,
	stream taskv1.TaskService_StreamTasksServer,
) error {
	s.mu.RLock()
	tasks := make([]*taskv1.Task, 0, len(s.tasks))
	for _, t := range s.tasks {
		tasks = append(tasks, t)
	}
	s.mu.RUnlock()

	for _, t := range tasks {
		// Check if client disconnected before each send
		select {
		case <-stream.Context().Done():
			return stream.Context().Err()
		default:
		}
		if err := stream.Send(t); err != nil {
			return err
		}
	}
	return nil
}
