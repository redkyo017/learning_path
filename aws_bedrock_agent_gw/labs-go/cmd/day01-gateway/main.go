package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	lambdasvc "github.com/aws/aws-sdk-go-v2/service/lambda"
	"github.com/aws/aws-sdk-go-v2/service/lambda/types"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// NOTE: Replace the Gateway SDK calls below with the actual package after
// completing Task 2 Step 1 (package discovery). The pattern shown here
// follows aws-sdk-go-v2 conventions. Exact method names must be verified
// against: go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentcore
//
// Stub types for Gateway operations — replace with real imports after discovery:
// import "github.com/aws/aws-sdk-go-v2/service/bedrockagentcore"

const region = "us-east-1"

type ARNs struct {
	GatewayExecutionRoleARN string `json:"gatewayExecutionRoleARN"`
	LambdaExecutionRoleARN  string `json:"lambdaExecutionRoleARN"`
}

func main() {
	ctx := context.Background()

	// Load ARNs written by day01-iam
	arnsData, err := os.ReadFile("arns.json")
	if err != nil {
		log.Fatalf("read arns.json (run day01-iam first): %v", err)
	}
	var arns ARNs
	if err := json.Unmarshal(arnsData, &arns); err != nil {
		log.Fatalf("parse arns.json: %v", err)
	}

	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	// Step A: Deploy the Lambda tool
	lambdaARN, err := deployLambda(ctx, clients.Lambda, arns.LambdaExecutionRoleARN)
	if err != nil {
		log.Fatalf("deploy lambda: %v", err)
	}
	fmt.Printf("Lambda ARN: %s\n", lambdaARN)

	// Step B: Create the Gateway
	// REPLACE these stub calls with real bedrockagentcore calls after package discovery.
	// Pattern to follow:
	//
	// gatewayClient := bedrockagentcore.NewFromConfig(cfg)
	//
	// createGWOut, err := gatewayClient.CreateGateway(ctx, &bedrockagentcore.CreateGatewayInput{
	//     Name:             aws.String("bgw-day01-gateway"),
	//     ExecutionRoleArn: aws.String(arns.GatewayExecutionRoleARN),
	//     Description:      aws.String("Day 1 learning gateway"),
	// })
	// if err != nil { log.Fatalf("CreateGateway: %v", err) }
	// gatewayID := *createGWOut.GatewayId
	// fmt.Printf("Gateway ID: %s\n", gatewayID)
	//
	// Step C: Register Lambda-backed tool in the Gateway
	//
	// _, err = gatewayClient.CreateGatewayTarget(ctx, &bedrockagentcore.CreateGatewayTargetInput{
	//     GatewayIdentifier: aws.String(gatewayID),
	//     Name:              aws.String("bgw-hr-tool"),
	//     TargetConfiguration: &bedrockagentcore.TargetConfiguration{
	//         Lambda: &bedrockagentcore.LambdaTargetConfig{
	//             LambdaArn: aws.String(lambdaARN),
	//         },
	//     },
	// })
	//
	// Step D: Create a Bedrock Inline Agent pointing at the Gateway
	// (Use bedrockagent.CreateAgent + bedrockagent.PrepareAgent)
	// Wire the gateway endpoint as an action group or MCP server endpoint.
	//
	// Fill in Steps B–D once you have verified the exact API shape.
	// The Lambda is deployed and ready; the IAM trust chain is set up.
	// Everything above this comment is known-good code.

	_ = lambdaARN // remove once gateway steps are filled in
	fmt.Println("Lambda deployed. Complete Steps B-D using the verified SDK package.")
}

func deployLambda(ctx context.Context, client *lambdasvc.Client, executionRoleARN string) (string, error) {
	zipBytes, err := os.ReadFile("../aws/lambda/hr-tool/function.zip")
	if err != nil {
		// Check zip is actually valid
		return "", fmt.Errorf("read function.zip (run build step first): %w", err)
	}
	if err := validateZip(zipBytes); err != nil {
		return "", fmt.Errorf("invalid zip: %w", err)
	}

	out, err := client.CreateFunction(ctx, &lambdasvc.CreateFunctionInput{
		FunctionName: aws.String("bgw-hr-tool"),
		Runtime:      types.RuntimeProvidedal2023,
		Handler:      aws.String("bootstrap"),
		Role:         aws.String(executionRoleARN),
		Code: &types.FunctionCode{
			ZipFile: zipBytes,
		},
		Description: aws.String("AgentCore Gateway mastery — HR tool"),
		Timeout:     aws.Int32(30),
		MemorySize:  aws.Int32(128),
	})
	if err != nil {
		return "", fmt.Errorf("CreateFunction: %w", err)
	}

	// Wait for Lambda to become active
	waiter := lambdasvc.NewFunctionActiveV2Waiter(client)
	if err := waiter.Wait(ctx, &lambdasvc.GetFunctionInput{
		FunctionName: aws.String("bgw-hr-tool"),
	}, 2*time.Minute); err != nil {
		return "", fmt.Errorf("lambda activation timeout: %w", err)
	}

	return *out.FunctionArn, nil
}

func validateZip(data []byte) error {
	r, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return err
	}
	for _, f := range r.File {
		if f.Name == "bootstrap" {
			return nil
		}
	}
	return fmt.Errorf("bootstrap binary not found in zip")
}
