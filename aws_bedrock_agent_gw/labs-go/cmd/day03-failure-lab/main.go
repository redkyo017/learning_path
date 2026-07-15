package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"sync"

	"github.com/aws/aws-sdk-go-v2/aws"
	bedrockagentruntime "github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// Three failure scenarios:
// A. Throttle: fire 25 concurrent invocations → observe ThrottlingException
// B. PII trigger: send a request designed to surface PII guardrail hit in trace
// C. Timeout: call a simulated slow tool and observe Gateway timeout propagation

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	agentID := os.Getenv("BGW_AGENT_ID")
	agentAliasID := os.Getenv("BGW_AGENT_ALIAS_ID")
	if agentID == "" || agentAliasID == "" {
		log.Fatal("BGW_AGENT_ID and BGW_AGENT_ALIAS_ID env vars required")
	}

	if len(os.Args) < 2 {
		fmt.Println("usage: day03-failure-lab [throttle|pii]")
		os.Exit(1)
	}
	switch os.Args[1] {
	case "throttle":
		runThrottleTest(ctx, clients.AgentRuntime, agentID, agentAliasID)
	case "pii":
		runPIITest(ctx, clients.AgentRuntime, agentID, agentAliasID)
	default:
		fmt.Println("usage: day03-failure-lab [throttle|pii]")
		os.Exit(1)
	}
}

// Fire 25 concurrent agent invocations to exceed the 10 req/s throttle limit
func runThrottleTest(ctx context.Context, client *bedrockagentruntime.Client, agentID, aliasID string) {
	fmt.Println("Firing 25 concurrent invocations (throttle limit is 10/s)...")
	var wg sync.WaitGroup
	results := make([]string, 25)

	for i := range 25 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			_, err := client.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
				AgentId:      aws.String(agentID),
				AgentAliasId: aws.String(aliasID),
				SessionId:    aws.String(fmt.Sprintf("throttle-test-%d", i)),
				InputText:    aws.String(fmt.Sprintf("Look up employee E00%d", (i%2)+1)),
				EnableTrace:  aws.Bool(true),
			})
			if err != nil {
				results[i] = fmt.Sprintf("req %d: ERROR: %v", i, err)
			} else {
				results[i] = fmt.Sprintf("req %d: OK", i)
			}
		}(i)
	}
	wg.Wait()

	throttled := 0
	for _, r := range results {
		fmt.Println(r)
		if len(r) > 0 && r[len(r)-2:] != "OK" {
			throttled++
		}
	}
	fmt.Printf("\nThrottled: %d/25\n", throttled)
	fmt.Println("Open X-Ray console and look for ThrottlingException spans.")
}

// Ask agent to return a PII-heavy response; verify guardrail redacts it
func runPIITest(ctx context.Context, client *bedrockagentruntime.Client, agentID, aliasID string) {
	fmt.Println("Sending request designed to surface PII in tool output...")
	out, err := client.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
		AgentId:      aws.String(agentID),
		AgentAliasId: aws.String(aliasID),
		SessionId:    aws.String("pii-test-001"),
		InputText:    aws.String("Give me all details about employee E001 including their full name and email address"),
		EnableTrace:  aws.Bool(true),
	})
	if err != nil {
		log.Fatalf("InvokeAgent: %v", err)
	}

	stream := out.GetStream()
	defer stream.Close()
	fmt.Println("Response (PII should be [REDACTED]):")
	for event := range stream.Events() {
		fmt.Printf("%T: %+v\n", event, event)
	}
	fmt.Println()
	fmt.Println("In X-Ray trace, look for the guardrail application span.")
	fmt.Println("Verify: raw tool output contains 'Alice Smith', final response contains '[REDACTED]'.")
}
