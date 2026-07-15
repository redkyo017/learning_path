package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	iamtypes "github.com/aws/aws-sdk-go-v2/service/iam/types"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

const (
	region             = "us-east-1"
	restrictedRoleName = "bgw-restricted-execution-role"
	fullRoleName       = "bgw-full-execution-role"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: day04-policy [setup-roles|verify-policy|teardown]")
		os.Exit(1)
	}

	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	accountID := os.Getenv("AWS_ACCOUNT_ID")

	switch os.Args[1] {
	case "setup-roles":
		if accountID == "" {
			log.Fatal("AWS_ACCOUNT_ID required")
		}
		setupRoles(ctx, clients.IAM, accountID)
	case "verify-policy":
		verifyPolicyEnforcement()
	case "teardown":
		teardownRoles(ctx, clients.IAM)
	default:
		fmt.Println("usage: day04-policy [setup-roles|verify-policy|teardown]")
		os.Exit(1)
	}
}

func setupRoles(ctx context.Context, iamClient *iam.Client, accountID string) {
	trustPolicy := bedrockTrustPolicy(accountID)

	createRole(ctx, iamClient,
		restrictedRoleName,
		trustPolicy,
		restrictedPermPolicy(),
		"bgw-restricted-policy",
	)

	createRole(ctx, iamClient,
		fullRoleName,
		trustPolicy,
		fullPermPolicy(),
		"bgw-full-policy",
	)

	restrictedARN := getRoleARN(ctx, iamClient, restrictedRoleName)
	fullARN := getRoleARN(ctx, iamClient, fullRoleName)

	fmt.Printf("Restricted role ARN: %s\n", restrictedARN)
	fmt.Printf("Full role ARN:       %s\n", fullARN)
	fmt.Println()
	fmt.Println("Next: create two agents via the bedrockagentcore SDK,")
	fmt.Println("      each using the respective execution role ARN above.")
	fmt.Println("      Then run: day04-policy verify-policy")
}

func verifyPolicyEnforcement() {
	// Agent-to-agent identity pattern (conceptual):
	// Sub-agent Lambda verifies the calling agent's ARN before processing:
	//
	// callerARN := extractCallerARN(ctx)
	// allowedCallers := []string{"arn:aws:bedrock:us-east-1:ACCOUNT:agent/SUPERVISOR-ID"}
	// if !contains(allowedCallers, callerARN) {
	//     return errorResponse("caller identity not authorised"), nil
	// }
	//
	// Verify exact mechanism for caller ARN propagation:
	//   go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime.InvokeAgentInput

	fmt.Println("Policy verification steps:")
	fmt.Println()
	fmt.Println("1. Invoke Agent A (restricted role) with: 'Check the deployment status of service bgw-deploy'")
	fmt.Println("   Expected: AccessDenied error (ticketing/deploy tool blocked by IAM)")
	fmt.Println("   Observe: CloudWatch logs for Gateway show AccessDenied calling bgw-ticketing-tool")
	fmt.Println()
	fmt.Println("2. Invoke Agent B (full role) with the same prompt")
	fmt.Println("   Expected: agent successfully calls the ticketing/deploy tool")
	fmt.Println()
	fmt.Println("3. Invoke Agent A with: 'What department does E001 work in?'")
	fmt.Println("   Expected: succeeds (HR tool is allowed)")
	fmt.Println()
	fmt.Println("Key insight: the policy enforcement happens at IAM level before Lambda is invoked.")
	fmt.Println("The agent prompt cannot override it — 'please call the ticketing tool' still gets denied.")
}

func createRole(ctx context.Context, iamClient *iam.Client, roleName, trustPolicy, permPolicy, policyName string) {
	_, err := iamClient.CreateRole(ctx, &iam.CreateRoleInput{
		RoleName:                 aws.String(roleName),
		AssumeRolePolicyDocument: aws.String(trustPolicy),
		Description:              aws.String("AgentCore Gateway mastery lab — " + roleName),
		Tags: []iamtypes.Tag{
			{Key: aws.String("project"), Value: aws.String("bgw-mastery")},
		},
	})
	if err != nil {
		log.Fatalf("CreateRole %s: %v", roleName, err)
	}

	_, err = iamClient.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:       aws.String(roleName),
		PolicyName:     aws.String(policyName),
		PolicyDocument: aws.String(permPolicy),
	})
	if err != nil {
		log.Fatalf("PutRolePolicy %s: %v", roleName, err)
	}
}

func getRoleARN(ctx context.Context, iamClient *iam.Client, roleName string) string {
	out, err := iamClient.GetRole(ctx, &iam.GetRoleInput{
		RoleName: aws.String(roleName),
	})
	if err != nil {
		log.Fatalf("GetRole %s: %v", roleName, err)
	}
	return *out.Role.Arn
}

func teardownRoles(ctx context.Context, iamClient *iam.Client) {
	for _, r := range []struct{ role, policy string }{
		{restrictedRoleName, "bgw-restricted-policy"},
		{fullRoleName, "bgw-full-policy"},
	} {
		_, _ = iamClient.DeleteRolePolicy(ctx, &iam.DeleteRolePolicyInput{
			RoleName:   aws.String(r.role),
			PolicyName: aws.String(r.policy),
		})
		_, _ = iamClient.DeleteRole(ctx, &iam.DeleteRoleInput{
			RoleName: aws.String(r.role),
		})
		fmt.Printf("Deleted role: %s\n", r.role)
	}
}

func bedrockTrustPolicy(accountID string) string {
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

func restrictedPermPolicy() string {
	return `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-hr-tool"
  }]
}`
}

func fullPermPolicy() string {
	return `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-*"
  }]
}`
}
