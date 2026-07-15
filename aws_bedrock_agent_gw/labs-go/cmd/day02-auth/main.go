package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	secretsmanager "github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

// This program:
// 1. Adds a ticketing HTTP tool to the existing Gateway with API-key auth mediation
// 2. Creates a second agent that shares the same Gateway as the first agent
// Key insight: both agents get tool updates when the Gateway is updated — zero redeployment

const region = "us-east-1"

func main() {
	ctx := context.Background()

	gatewayID := os.Getenv("BGW_GATEWAY_ID")
	if gatewayID == "" {
		log.Fatal("BGW_GATEWAY_ID env var required — set to the Day 2 gateway ID")
	}

	// Step A: Verify the API key secret exists
	smClient := secretsmanager.NewFromConfig(mustLoadConfig(ctx))
	_, err := smClient.DescribeSecret(ctx, &secretsmanager.DescribeSecretInput{
		SecretId: aws.String("bgw-external-api-key"),
	})
	if err != nil {
		log.Fatalf("secret bgw-external-api-key not found: %v", err)
	}
	fmt.Println("Secret bgw-external-api-key confirmed.")

	_ = gatewayID

	// Step B: Add ticketing HTTP tool with API-key auth
	// The Gateway will inject the API key from Secrets Manager into each request.
	// The agent never sees the key.
	//
	// _, err = gatewayClient.CreateGatewayTarget(ctx, &bedrockagentcore.CreateGatewayTargetInput{
	//     GatewayIdentifier: aws.String(gatewayID),
	//     Name:              aws.String("bgw-ticketing-tool"),
	//     Description:       aws.String("Create and query support tickets in the ticketing system."),
	//     TargetConfiguration: &bedrockagentcore.TargetConfiguration{
	//         Http: &bedrockagentcore.HttpTargetConfig{
	//             BaseUrl: aws.String("https://httpbin.org"), // public test endpoint
	//             AuthConfiguration: &bedrockagentcore.AuthConfiguration{
	//                 Type: "apiKey",
	//                 SecretArn: aws.String("arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:bgw-external-api-key"),
	//                 HeaderName: aws.String("X-API-Key"),
	//             },
	//         },
	//     },
	// })
	//
	// Step C: Create a second Bedrock agent pointing at the SAME gateway endpoint
	// This demonstrates multi-agent tool sharing — one gateway, multiple agents.
	//
	// secondAgentOut, err := clients.BedrockAgent.CreateAgent(ctx, &bedrockagent.CreateAgentInput{
	//     AgentName: aws.String("bgw-specialist-agent"),
	//     ...same gateway endpoint as first agent...
	// })
	//
	// Step D: Invoke both agents — verify both can call HR and ticketing tools
	// Both agents should see all 3 tools (getEmployee, listDepartment, ticketing)
	// without any change to agent configuration.

	fmt.Println("Fill in Steps B-D. Gateway ID:", gatewayID)
}

func mustLoadConfig(ctx context.Context) aws.Config {
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		log.Fatalf("load aws config: %v", err)
	}
	return cfg
}
