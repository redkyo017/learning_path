package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/iam/types"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	accountID := mustGetAccountID()

	gatewayRoleARN, err := createRole(ctx, clients.IAM,
		"bgw-gateway-execution-role",
		gatewayTrustPolicy(accountID),
		gatewayPermissionsPolicy(),
		"bgw-gateway-execution-policy",
	)
	if err != nil {
		log.Fatalf("create gateway execution role: %v", err)
	}
	fmt.Printf("Gateway execution role ARN: %s\n", gatewayRoleARN)

	lambdaRoleARN, err := createRole(ctx, clients.IAM,
		"bgw-lambda-execution-role",
		lambdaTrustPolicy(),
		lambdaPermissionsPolicy(),
		"bgw-lambda-execution-policy",
	)
	if err != nil {
		log.Fatalf("create lambda execution role: %v", err)
	}
	fmt.Printf("Lambda execution role ARN: %s\n", lambdaRoleARN)

	// Write ARNs to a local file so other programs can read them
	out := map[string]string{
		"gatewayExecutionRoleARN": gatewayRoleARN,
		"lambdaExecutionRoleARN":  lambdaRoleARN,
	}
	data, _ := json.MarshalIndent(out, "", "  ")
	if err := os.WriteFile("arns.json", data, 0600); err != nil {
		log.Fatalf("write arns.json: %v", err)
	}
	fmt.Println("ARNs written to arns.json")
}

func createRole(ctx context.Context, iamClient *iam.Client, roleName, trustPolicy, permissionsPolicy, policyName string) (string, error) {
	createOut, err := iamClient.CreateRole(ctx, &iam.CreateRoleInput{
		RoleName:                 aws.String(roleName),
		AssumeRolePolicyDocument: aws.String(trustPolicy),
		Description:              aws.String("AgentCore Gateway mastery lab — " + roleName),
		Tags: []types.Tag{
			{Key: aws.String("project"), Value: aws.String("bgw-mastery")},
		},
	})
	if err != nil {
		return "", fmt.Errorf("CreateRole %s: %w", roleName, err)
	}
	roleARN := *createOut.Role.Arn

	_, err = iamClient.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:       aws.String(roleName),
		PolicyName:     aws.String(policyName),
		PolicyDocument: aws.String(permissionsPolicy),
	})
	if err != nil {
		return "", fmt.Errorf("PutRolePolicy %s: %w", roleName, err)
	}

	// IAM propagation delay — role must exist before it can be assumed
	fmt.Printf("Waiting 10s for IAM propagation of %s...\n", roleName)
	time.Sleep(10 * time.Second)

	return roleARN, nil
}

func mustGetAccountID() string {
	id := os.Getenv("AWS_ACCOUNT_ID")
	if id == "" {
		log.Fatal("AWS_ACCOUNT_ID env var required (run: aws sts get-caller-identity --query Account --output text)")
	}
	return id
}

func gatewayTrustPolicy(accountID string) string {
	return fmt.Sprintf(`{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "bedrock.amazonaws.com"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {"aws:SourceAccount": "%s"}
    }
  }]
}`, accountID)
}

func gatewayPermissionsPolicy() string {
	return `{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["lambda:InvokeFunction"],
      "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ApplyGuardrail"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "arn:aws:logs:us-east-1:*:log-group:/aws/bedrock/*"
    }
  ]
}`
}

func lambdaTrustPolicy() string {
	return `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}`
}

func lambdaPermissionsPolicy() string {
	return `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
    "Resource": "arn:aws:logs:us-east-1:*:log-group:/aws/lambda/bgw-*"
  }]
}`
}
