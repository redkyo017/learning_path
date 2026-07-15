package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	bedrockagentruntime "github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

const (
	region   = "us-east-1"
	memoryID = "bgw-demo-user-001"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: day04-memory [create-agent|session1|session2|teardown]")
		os.Exit(1)
	}

	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	gatewayID := os.Getenv("BGW_GATEWAY_ID")

	switch os.Args[1] {
	case "create-agent":
		createMemoryAgent(gatewayID)
	case "session1":
		runSession(ctx, clients.AgentRuntime, "session-001",
			"Look up employee E001. Tell me their name, department, and what makes them notable.")
	case "session2":
		runSession(ctx, clients.AgentRuntime, "session-002",
			"What did we discuss in our last conversation? Summarise what you remember about the employee we looked at.")
	case "teardown":
		teardown()
	default:
		fmt.Println("usage: day04-memory [create-agent|session1|session2|teardown]")
		os.Exit(1)
	}
}

func createMemoryAgent(gatewayID string) {
	fmt.Printf("Creating memory agent wired to gateway: %s\n", gatewayID)
	fmt.Println("Fill in with verified CreateAgent SDK call after running:")
	fmt.Println("  go doc github.com/aws/aws-sdk-go-v2/service/bedrockagent.CreateAgentInput | grep -i memory")
	fmt.Println()
	fmt.Println("Pattern for enabling memory (verify field names first):")
	fmt.Println("  MemoryConfiguration: &bedrockagent.MemoryConfiguration{")
	fmt.Println("      EnabledMemoryTypes: []bedrockagent.MemoryType{bedrockagent.MemoryTypeSessionSummary},")
	fmt.Println("      StorageDays:        aws.Int32(30),")
	fmt.Println("  }")
	fmt.Println()
	fmt.Println("After creating the agent, export:")
	fmt.Println("  export BGW_MEMORY_AGENT_ID=<agent-id>")
	fmt.Println("  export BGW_MEMORY_AGENT_ALIAS_ID=<alias-id>")

	// Full CreateAgent pattern with memory (verify field names from go doc):
	// out, err := client.CreateAgent(ctx, &bedrockagent.CreateAgentInput{
	//     AgentName:       aws.String("bgw-memory-agent"),
	//     FoundationModel: aws.String("anthropic.claude-3-haiku-20240307-v1:0"),
	//     Description:     aws.String("Memory-enabled HR agent for Day 4 lab"),
	//     Instruction:     aws.String("You are an HR assistant with access to employee and department information via tools."),
	//     MemoryConfiguration: &bedrockagent.MemoryConfiguration{
	//         EnabledMemoryTypes: []bedrockagent.MemoryType{bedrockagent.MemoryTypeSessionSummary},
	//         StorageDays:        aws.Int32(30),
	//     },
	// })
	// Then: PrepareAgent + CreateAgentAlias (same as Days 1-3 pattern)
}

func runSession(ctx context.Context, client *bedrockagentruntime.Client, sessionSuffix, prompt string) {
	agentID := os.Getenv("BGW_MEMORY_AGENT_ID")
	if agentID == "" {
		log.Fatal("BGW_MEMORY_AGENT_ID env var required")
	}
	agentAliasID := os.Getenv("BGW_MEMORY_AGENT_ALIAS_ID")
	if agentAliasID == "" {
		log.Fatal("BGW_MEMORY_AGENT_ALIAS_ID env var required")
	}

	sessionID := memoryID + "-" + sessionSuffix

	fmt.Printf("=== Session: %s ===\n", sessionID)
	fmt.Printf("Prompt: %s\n", prompt)

	_ = aws.String(memoryID)

	// Verify MemoryId field name from:
	//   go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime.InvokeAgentInput | grep -i memory
	//
	// out, err := client.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
	//     AgentId:      aws.String(agentID),
	//     AgentAliasId: aws.String(agentAliasID),
	//     SessionId:    aws.String(sessionID),
	//     InputText:    aws.String(prompt),
	//     MemoryId:     aws.String(memoryID),
	//     EnableTrace:  aws.Bool(true),
	// })
	// if err != nil { log.Fatalf("InvokeAgent: %v", err) }
	// stream := out.GetStream()
	// defer stream.Close()
	// for event := range stream.Events() {
	//     switch v := event.(type) {
	//     case *bedrockagentruntime.InvokeAgentResponseStreamMemberChunk:
	//         fmt.Print(string(v.Value.Bytes))
	//     }
	// }
	// fmt.Println()

	fmt.Printf("Session %s: fill in InvokeAgent call after verifying MemoryId field name.\n", sessionSuffix)

	if sessionSuffix == "session-002" {
		fmt.Println("If session2 agent says it does not remember prior conversations, check:")
		fmt.Println("  1. MemoryId was not set on session1 invocation")
		fmt.Println("  2. Agent was not created with MemoryConfiguration enabled")
		fmt.Println("  3. Insufficient time between sessions (wait 60-120s for summary generation)")
	}

	_ = ctx
	_ = client
	_ = agentID
	_ = agentAliasID
	_ = sessionID
}

func teardown() {
	fmt.Println("Teardown: delete bgw-memory-agent via bedrockagent.DeleteAgent")
	fmt.Println("Then run full Day 4 teardown:")
	fmt.Println("  aws bedrock-agent list-agents --query 'agentSummaries[?contains(agentName,`bgw-`)].agentId'")
	fmt.Println("  (delete each listed agent)")
}
