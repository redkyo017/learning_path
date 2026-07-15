package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// This program deliberately breaks the IAM trust chain at each of the 3 layers.
// For each breakage: run the agent invocation, observe the error, then fix it.
// The goal is to memorise what each failure mode looks like in CloudWatch.

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	if len(os.Args) < 2 {
		fmt.Println("usage: day01-failure-lab [break-layer1|break-layer2|break-layer3|fix-all]")
		os.Exit(1)
	}
	switch os.Args[1] {
	case "break-layer1":
		breakLayer1(ctx, clients.IAM)
	case "break-layer2":
		breakLayer2(ctx, clients.IAM)
	case "break-layer3":
		breakLayer3(ctx, clients.IAM)
	case "fix-all":
		fixAll(ctx, clients.IAM)
	default:
		fmt.Println("usage: day01-failure-lab [break-layer1|break-layer2|break-layer3|fix-all]")
		os.Exit(1)
	}
}

// Layer 1 break: remove caller's permission to invoke the Gateway
func breakLayer1(ctx context.Context, iamClient *iam.Client) {
	_, err := iamClient.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:   aws.String("bgw-gateway-execution-role"),
		PolicyName: aws.String("bgw-gateway-execution-policy"),
		PolicyDocument: aws.String(`{
  "Version": "2012-10-17",
  "Statement": [{"Effect": "Deny", "Action": "*", "Resource": "*"}]
}`),
	})
	if err != nil {
		log.Fatalf("break layer 1: %v", err)
	}
	fmt.Println("Layer 1 broken: execution role now denies all actions.")
	fmt.Println("Now invoke the agent and observe the error in CloudWatch.")
	fmt.Println("Expected: agent reports tool execution failure; Gateway CloudWatch shows AccessDenied calling Lambda.")
}

// Layer 2 break: corrupt the trust policy so bedrock.amazonaws.com can't assume the role
func breakLayer2(ctx context.Context, iamClient *iam.Client) {
	_, err := iamClient.UpdateAssumeRolePolicy(ctx, &iam.UpdateAssumeRolePolicyInput{
		RoleName: aws.String("bgw-gateway-execution-role"),
		PolicyDocument: aws.String(`{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}`),
	})
	if err != nil {
		log.Fatalf("break layer 2: %v", err)
	}
	fmt.Println("Layer 2 broken: trust policy now only allows ec2.amazonaws.com (not bedrock).")
	fmt.Println("Now invoke the agent and observe the error.")
	fmt.Println("Expected: Gateway cannot assume execution role → agent gets tool unavailable error.")
}

// Layer 3 break: remove Lambda resource policy so execution role can't invoke it
func breakLayer3(ctx context.Context, iamClient *iam.Client) {
	// Restrict execution role to only invoke non-existent functions
	_, err := iamClient.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:   aws.String("bgw-gateway-execution-role"),
		PolicyName: aws.String("bgw-gateway-execution-policy"),
		PolicyDocument: aws.String(`{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-NONEXISTENT"
  }]
}`),
	})
	if err != nil {
		log.Fatalf("break layer 3: %v", err)
	}
	fmt.Println("Layer 3 broken: execution role can only invoke bgw-NONEXISTENT (does not exist).")
	fmt.Println("Now invoke the agent and observe the error.")
	fmt.Println("Expected: Lambda invocation fails; looks identical to Layer 2 failure from agent perspective.")
	fmt.Println("Key insight: open CloudWatch logs for BOTH Gateway and Lambda to pinpoint which layer failed.")
}

// Restore all IAM to working state
func fixAll(ctx context.Context, iamClient *iam.Client) {
	// Restore execution role trust policy
	accountID := os.Getenv("AWS_ACCOUNT_ID")
	if accountID == "" {
		log.Fatal("AWS_ACCOUNT_ID env var required")
	}
	trustPolicy := fmt.Sprintf(`{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "bedrock.amazonaws.com"},
    "Action": "sts:AssumeRole",
    "Condition": {"StringEquals": {"aws:SourceAccount": "%s"}}
  }]
}`, accountID)
	_, err := iamClient.UpdateAssumeRolePolicy(ctx, &iam.UpdateAssumeRolePolicyInput{
		RoleName:       aws.String("bgw-gateway-execution-role"),
		PolicyDocument: aws.String(trustPolicy),
	})
	if err != nil {
		log.Fatalf("restore trust policy: %v", err)
	}

	// Restore permissions policy
	permissionsPolicy := `{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect":"Allow","Action":["lambda:InvokeFunction"],"Resource":"arn:aws:lambda:us-east-1:*:function:bgw-*"},
    {"Effect":"Allow","Action":["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream","bedrock:ApplyGuardrail"],"Resource":"*"},
    {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:us-east-1:*:log-group:/aws/bedrock/*"}
  ]
}`
	_, err = iamClient.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:       aws.String("bgw-gateway-execution-role"),
		PolicyName:     aws.String("bgw-gateway-execution-policy"),
		PolicyDocument: aws.String(permissionsPolicy),
	})
	if err != nil {
		log.Fatalf("restore permissions policy: %v", err)
	}

	fmt.Println("All IAM restored to working state. Re-run agent invocation to confirm.")
}
