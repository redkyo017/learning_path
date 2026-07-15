package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrock"
	s3svc "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// EvalCase is one test case in the evaluation dataset.
type EvalCase struct {
	Input             EvalInput `json:"input"`
	ReferenceResponse string    `json:"referenceResponse"`
}

type EvalInput struct {
	Prompt string `json:"prompt"`
}

const (
	region     = "us-east-1"
	bucketName = "bgw-eval-data"
	datasetKey = "day04/eval-dataset.jsonl"
)

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("awsclient.New: %v", err)
	}

	agentID := os.Getenv("BGW_AGENT_ID")
	if agentID == "" {
		log.Fatal("BGW_AGENT_ID env var is required")
	}
	agentAliasID := os.Getenv("BGW_AGENT_ALIAS_ID")
	if agentAliasID == "" {
		log.Fatal("BGW_AGENT_ALIAS_ID env var is required")
	}
	evalRoleARN := os.Getenv("BGW_EVAL_ROLE_ARN")
	if evalRoleARN == "" {
		log.Fatal("BGW_EVAL_ROLE_ARN env var is required")
	}

	// Step A: Create S3 bucket for evaluation data and results.
	fmt.Printf("Step A: ensuring S3 bucket %q exists...\n", bucketName)
	if err := createBucket(ctx, clients.S3, bucketName); err != nil {
		log.Fatalf("createBucket: %v", err)
	}
	fmt.Println("  bucket ready.")

	// Step B: Upload 5-case evaluation dataset.
	fmt.Printf("Step B: uploading evaluation dataset to s3://%s/%s...\n", bucketName, datasetKey)
	dataset := goodDataset()
	if err := uploadDataset(ctx, clients.S3, bucketName, datasetKey, dataset); err != nil {
		log.Fatalf("uploadDataset: %v", err)
	}
	fmt.Printf("  uploaded %d cases.\n", len(dataset))

	// Step C: Run baseline evaluation job.
	fmt.Println("Step C: submitting baseline evaluation job...")
	baselineARN := runEvaluationJob(
		ctx,
		clients.Bedrock,
		"bgw-eval-baseline",
		agentID, agentAliasID,
		bucketName, datasetKey,
		bucketName, "day04/results/baseline/",
		evalRoleARN,
	)
	fmt.Printf("  baseline job ARN: %s\n", baselineARN)
	baselineScores := waitAndReadResults(ctx, clients.Bedrock, baselineARN)
	fmt.Printf("  baseline scores: %v\n", baselineScores)

	// Step D: Regression lab — run second job to demonstrate score degradation.
	if strings.EqualFold(os.Getenv("BGW_RUN"), "regression") {
		fmt.Println("Step D: regression mode — submitting regression evaluation job...")
		regressionARN := runEvaluationJob(
			ctx,
			clients.Bedrock,
			"bgw-eval-regression",
			agentID, agentAliasID,
			bucketName, datasetKey,
			bucketName, "day04/results/regression/",
			evalRoleARN,
		)
		fmt.Printf("  regression job ARN: %s\n", regressionARN)
		regressionScores := waitAndReadResults(ctx, clients.Bedrock, regressionARN)
		fmt.Printf("  regression scores: %v\n", regressionScores)

		fmt.Println("Score comparison (baseline vs regression):")
		for metric, baseVal := range baselineScores {
			regVal := regressionScores[metric]
			diff := regVal - baseVal
			fmt.Printf("  %s: baseline=%.3f  regression=%.3f  delta=%.3f\n", metric, baseVal, regVal, diff)
		}
	}
}

// goodDataset returns 5 HR-domain evaluation test cases.
func goodDataset() []EvalCase {
	return []EvalCase{
		{
			Input:             EvalInput{Prompt: "What department does employee E001 work in?"},
			ReferenceResponse: "Engineering",
		},
		{
			Input:             EvalInput{Prompt: "How many people are in the Finance department?"},
			ReferenceResponse: "The Finance department has 12 employees",
		},
		{
			Input:             EvalInput{Prompt: "Who manages the Engineering department?"},
			ReferenceResponse: "Carol White manages the Engineering department",
		},
		{
			Input:             EvalInput{Prompt: "What is the email address of employee E002?"},
			ReferenceResponse: "bob@example.com",
		},
		{
			Input:             EvalInput{Prompt: "What is the job title of employee E001?"},
			ReferenceResponse: "Staff Engineer",
		},
	}
}

// createBucket ensures the named S3 bucket exists in us-east-1.
// BucketAlreadyOwnedByYou is treated as non-fatal.
func createBucket(ctx context.Context, client *s3svc.Client, bucket string) error {
	// For us-east-1 CreateBucket must NOT include a CreateBucketConfiguration —
	// omitting it means us-east-1 (the S3 default). Other regions need LocationConstraint.
	_, err := client.CreateBucket(ctx, &s3svc.CreateBucketInput{
		Bucket: aws.String(bucket),
	})
	if err != nil {
		var owned *types.BucketAlreadyOwnedByYou
		if errors.As(err, &owned) {
			return nil // bucket already exists and we own it — fine
		}
		return fmt.Errorf("CreateBucket %q: %w", bucket, err)
	}
	return nil
}

// uploadDataset encodes cases as JSONL and uploads to S3.
func uploadDataset(ctx context.Context, client *s3svc.Client, bucket, key string, cases []EvalCase) error {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	for _, c := range cases {
		if err := enc.Encode(c); err != nil {
			return fmt.Errorf("encode eval case: %w", err)
		}
	}
	_, err := client.PutObject(ctx, &s3svc.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: aws.String("application/x-ndjson"),
	})
	if err != nil {
		return fmt.Errorf("PutObject s3://%s/%s: %w", bucket, key, err)
	}
	return nil
}

// runEvaluationJob submits a Bedrock evaluation job.
//
// NOTE: The actual SDK call is left as a commented stub because the exact
// field names of bedrock.CreateEvaluationJobInput must be verified by the
// learner on Day 4 before running:
//
//	go doc github.com/aws/aws-sdk-go-v2/service/bedrock.CreateEvaluationJobInput
//
// Pattern (fill in with verified field names):
//
//	out, err := client.CreateEvaluationJob(ctx, &bedrock.CreateEvaluationJobInput{
//	    JobName: aws.String(jobName),
//	    RoleArn: aws.String(roleARN),
//	    EvaluationConfig: &bedrock.EvaluationConfig{
//	        Automated: &bedrock.AutomatedEvaluationConfig{
//	            DatasetMetricConfigs: []bedrock.EvaluationDatasetMetricConfig{{
//	                TaskType: bedrock.EvaluationTaskTypeQuestionAndAnswer, // verify enum
//	                Dataset: &bedrock.EvaluationDataset{
//	                    Name: aws.String(jobName + "-dataset"),
//	                    DatasetLocation: &bedrock.EvaluationDatasetLocation{
//	                        S3Uri: aws.String("s3://" + inputBucket + "/" + inputKey),
//	                    },
//	                },
//	                MetricNames: []string{"Builtin.Relevance", "Builtin.Coherence"},
//	            }},
//	        },
//	    },
//	    InferenceConfig: &bedrock.EvaluationInferenceConfig{
//	        Models: []bedrock.EvaluationModelConfig{{
//	            BedrockModel: &bedrock.EvaluationBedrockModel{
//	                ModelIdentifier: aws.String("arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"),
//	                InferenceParams:  aws.String(`{"maxTokens":512,"temperature":0}`),
//	            },
//	        }},
//	    },
//	    OutputDataConfig: &bedrock.EvaluationOutputDataConfig{
//	        S3Uri: aws.String("s3://" + outputBucket + "/" + outputPrefix),
//	    },
//	})
//	if err != nil { log.Fatalf("CreateEvaluationJob %s: %v", jobName, err) }
//	return *out.JobArn
func runEvaluationJob(
	ctx context.Context,
	client *bedrock.Client,
	jobName, agentID, agentAliasID string,
	inputBucket, inputKey string,
	outputBucket, outputPrefix string,
	roleARN string,
) string {
	fmt.Printf("runEvaluationJob(%s): verify bedrock.CreateEvaluationJobInput field names first\n", jobName)

	// Suppress unused-variable warnings for parameters used only in the stub above.
	_ = ctx
	_ = client
	_ = agentID
	_ = agentAliasID
	_ = inputBucket
	_ = inputKey
	_ = outputBucket
	_ = outputPrefix
	_ = roleARN

	return "pending-arn-" + jobName
}

// waitAndReadResults polls for evaluation job completion and returns metric scores.
//
// Polling pattern (fill in after verifying GetEvaluationJob field names):
//
//	for {
//	    out, err := client.GetEvaluationJob(ctx, &bedrock.GetEvaluationJobInput{
//	        JobIdentifier: aws.String(jobARN),
//	    })
//	    if err != nil { log.Fatalf("GetEvaluationJob: %v", err) }
//	    status := out.Status  // verify field name
//	    if status == bedrock.EvaluationJobStatusCompleted {  // verify enum value
//	        // parse out.OutputDataConfig.S3Uri, download results from S3, return scores
//	        break
//	    }
//	    fmt.Printf("  job status: %v — waiting 30s...\n", status)
//	    time.Sleep(30 * time.Second)
//	}
func waitAndReadResults(ctx context.Context, client *bedrock.Client, jobARN string) map[string]float64 {
	_ = ctx
	_ = client
	_ = jobARN
	_ = time.Second // prevent unused-import error until stub is filled in

	fmt.Printf("waitAndReadResults(%s): stub not yet implemented — fill in GetEvaluationJob polling loop\n", jobARN)
	return map[string]float64{"Relevance": 0.0, "Coherence": 0.0}
}
