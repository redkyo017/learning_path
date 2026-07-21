package transcoder

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"

	taskv1 "github.com/yourname/golang-mastery/phase3-grpc/gen/task/v1"
)

// TaskTranscoder translates HTTP/JSON requests to gRPC calls on TaskService.
type TaskTranscoder struct {
	client taskv1.TaskServiceClient
}

func NewTaskTranscoder(grpcAddr string) (*TaskTranscoder, error) {
	conn, err := grpc.NewClient(grpcAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return nil, err
	}
	return &TaskTranscoder{client: taskv1.NewTaskServiceClient(conn)}, nil
}

func (t *TaskTranscoder) forwardAuth(c *gin.Context) metadata.MD {
	md := metadata.New(nil)
	if auth := c.GetHeader("Authorization"); auth != "" {
		md.Set("authorization", auth)
	}
	return md
}

func (t *TaskTranscoder) ListTasks(c *gin.Context) {
	ctx := metadata.NewOutgoingContext(c.Request.Context(), t.forwardAuth(c))
	resp, err := t.client.ListTasks(ctx, &taskv1.ListTasksRequest{})
	if err != nil {
		c.AbortWithStatusJSON(grpcStatusToHTTP(err), gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp.Tasks)
}

func (t *TaskTranscoder) CreateTask(c *gin.Context) {
	var req struct {
		Title string `json:"title" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx := metadata.NewOutgoingContext(c.Request.Context(), t.forwardAuth(c))
	resp, err := t.client.CreateTask(ctx, &taskv1.CreateTaskRequest{Title: req.Title})
	if err != nil {
		c.AbortWithStatusJSON(grpcStatusToHTTP(err), gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, resp.Task)
}
