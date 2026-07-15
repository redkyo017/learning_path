package main

import (
	"context"
	"fmt"
	"log"

	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// This program wires together:
// 1. Bedrock Guardrail (PII redaction)
// 2. Gateway with guardrail applied
// 3. Agent with X-Ray tracing enabled
// 4. Throttling on the HR tool
//
// Fill in each step using the verified bedrockagentcore and bedrock SDK packages.

// import "github.com/aws/aws-sdk-go-v2/service/bedrock"
//
// guardrailOut, err := clients.Bedrock.CreateGuardrail(ctx, &bedrock.CreateGuardrailInput{
//     Name:        aws.String("bgw-hr-guardrail"),
//     Description: aws.String("PII redaction for HR tool outputs"),
//     SensitiveInformationPolicyConfig: &types.SensitiveInformationPolicyConfig{
//         PiiEntitiesConfig: []types.GuardrailPiiEntityConfig{
//             {Type: types.GuardrailPiiEntityTypeName, Action: types.GuardrailSensitiveInformationActionAnonymize},
//             {Type: types.GuardrailPiiEntityTypeEmail, Action: types.GuardrailSensitiveInformationActionAnonymize},
//             {Type: types.GuardrailPiiEntityTypePhone, Action: types.GuardrailSensitiveInformationActionAnonymize},
//         },
//     },
//     BlockedInputMessaging:  aws.String("Input blocked by policy."),
//     BlockedOutputsMessaging: aws.String("Output blocked by policy."),
// })
//
// Then create a version:
// versionOut, err := clients.Bedrock.CreateGuardrailVersion(ctx, &bedrock.CreateGuardrailVersionInput{
//     GuardrailIdentifier: guardrailOut.GuardrailId,
// })
// guardrailARN := *guardrailOut.GuardrailArn
// guardrailVersion := *versionOut.Version

// When creating/updating the Gateway, attach the guardrail:
//
// gatewayClient.UpdateGateway(ctx, &bedrockagentcore.UpdateGatewayInput{
//     GatewayIdentifier: aws.String(gatewayID),
//     GuardrailConfiguration: &bedrockagentcore.GuardrailConfiguration{
//         GuardrailId:      guardrailOut.GuardrailId,
//         GuardrailVersion: versionOut.Version,
//     },
// })

// clients.AgentRuntime.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
//     AgentId:      aws.String(agentID),
//     AgentAliasId: aws.String(agentAliasID),
//     SessionId:    aws.String("session-001"),
//     InputText:    aws.String("Look up employee E001 and tell me their department"),
//     EnableTrace:  aws.Bool(true), // verify field name
// })
//
// Process the streaming response and extract trace events:
// for event := range output.GetStream().Events() {
//     switch v := event.(type) {
//     case *bedrockagentruntime.InvokeAgentResponseStreamMemberTrace:
//         fmt.Printf("TRACE: %+v\n", v.Value)
//     case *bedrockagentruntime.InvokeAgentResponseStreamMemberChunk:
//         fmt.Printf("RESPONSE: %s\n", string(v.Value.Bytes))
//     }
// }

// When creating the Gateway target, set throttling config:
//
// bedrockagentcore.CreateGatewayTargetInput{
//     ...
//     ThrottlingConfiguration: &bedrockagentcore.ThrottlingConfiguration{
//         RateLimit:   aws.Int32(10),  // max 10 calls/second to this tool
//         BurstLimit:  aws.Int32(20),  // burst up to 20
//     },
// }

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}
	_ = clients

	fmt.Println("Day 3 Production Lab")
	fmt.Println("Steps: createGuardrail → createGuardrailVersion → createGateway(withGuardrail) → createGatewayTarget(withThrottling) → invokeAgent(withTrace)")
	fmt.Println()
	fmt.Println("After each step, verify in the console (just for validation — never for creation).")
}
