package awsclient

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrock"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagent"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
	s3svc "github.com/aws/aws-sdk-go-v2/service/s3"
)

type Clients struct {
	IAM          *iam.Client
	Lambda       *lambda.Client
	Bedrock      *bedrock.Client
	BedrockAgent *bedrockagent.Client
	AgentRuntime *bedrockagentruntime.Client
	S3           *s3svc.Client
}

func New(ctx context.Context, region string) (*Clients, error) {
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &Clients{
		IAM:          iam.NewFromConfig(cfg),
		Lambda:       lambda.NewFromConfig(cfg),
		Bedrock:      bedrock.NewFromConfig(cfg),
		BedrockAgent: bedrockagent.NewFromConfig(cfg),
		AgentRuntime: bedrockagentruntime.NewFromConfig(cfg),
		S3:           s3svc.NewFromConfig(cfg),
	}, nil
}
