package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// Using the verified bedrockagentcore package from Day 1.
// Replace the comments below with actual SDK calls.

const region = "us-east-1"

type ARNs struct {
	GatewayExecutionRoleARN string `json:"gatewayExecutionRoleARN"`
	LambdaExecutionRoleARN  string `json:"lambdaExecutionRoleARN"`
}

func main() {
	ctx := context.Background()

	arnsData, err := os.ReadFile("arns.json")
	if err != nil {
		log.Fatalf("read arns.json: %v", err)
	}
	var arns ARNs
	if err := json.Unmarshal(arnsData, &arns); err != nil {
		log.Fatalf("parse arns.json: %v", err)
	}

	_, err = awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	// Step A: Re-deploy the HR Lambda (same as Day 1)
	fmt.Println("Step A: Deploy hr-tool Lambda (same as Day 1)")
	// go run cmd/day01-gateway/main.go (Lambda deploy portion)

	// Step B: Create Gateway with OpenAPI spec
	//
	// Read the OpenAPI spec:
	// specBytes, err := os.ReadFile("../aws/openapi/hr-api-spec.yaml")
	//
	// Create Gateway with spec:
	// createGWOut, err := gatewayClient.CreateGateway(ctx, &bedrockagentcore.CreateGatewayInput{
	//     Name:              aws.String("bgw-day02-gateway"),
	//     ExecutionRoleArn:  aws.String(arns.GatewayExecutionRoleARN),
	//     OpenApiSpecification: aws.String(string(specBytes)), // verify field name
	// })
	//
	// Step C: Wire the OpenAPI spec to the Lambda backend
	// (The spec defines the interface; the Lambda provides the implementation)
	//
	// _, err = gatewayClient.CreateGatewayTarget(ctx, &bedrockagentcore.CreateGatewayTargetInput{
	//     GatewayIdentifier: aws.String(gatewayID),
	//     Name:              aws.String("bgw-hr-openapi-target"),
	//     TargetConfiguration: &bedrockagentcore.TargetConfiguration{
	//         Lambda: &bedrockagentcore.LambdaTargetConfig{
	//             LambdaArn: aws.String(lambdaARN),
	//         },
	//     },
	// })
	//
	// Step D: Create agent with dynamic tool discovery
	// Instead of listing tools statically, set the agent to discover via Gateway.
	// (Verify the exact agent config field that enables dynamic MCP discovery)
	//
	// Step E: Invoke agent — ask it to look up employee E001 and list Engineering dept
	// Watch it call tools/list first, then tools/call

	fmt.Println("Fill in Steps B-E using verified bedrockagentcore SDK.")
	fmt.Printf("Execution role: %s\n", arns.GatewayExecutionRoleARN)
}
