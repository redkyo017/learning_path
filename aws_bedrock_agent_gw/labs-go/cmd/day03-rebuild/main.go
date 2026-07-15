package main

// Closed-book rebuild. See scenario.md for requirements.
// Build the complete Gateway + agent system from memory.
// You have 2 hours. No peeking at prior code.

import (
	"context"
	"log"

	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}
	_ = clients

	// Your implementation here.
}
