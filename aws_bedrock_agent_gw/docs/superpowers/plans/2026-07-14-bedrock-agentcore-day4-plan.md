# AWS Bedrock AgentCore — Day 4 Full-Stack Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Gateway mastery to the full AgentCore stack — Evaluations, Identity/Policy enforcement, and Memory — so the learner can validate agent quality, govern tool access, and build stateful agents for enterprise workflows.

**Architecture:** Four tasks continuing the established pattern from Days 1–3. Evaluations uses S3 + Bedrock evaluation jobs to measure agent quality. Policy enforcement is implemented via IAM role-scoped Gateway tool access (the production mechanism) with a primer step to discover any higher-level AgentCore Policy API. Memory uses the `memoryId` + `MemoryConfiguration` pattern on Bedrock Agents. Runtime and Registry are orientation-only (no hands-on code).

**Tech Stack:** Go 1.22+, `aws-sdk-go-v2` (`bedrock`, `bedrockagent`, `bedrockagentruntime`, `s3`, `iam`), existing `internal/awsclient` shared client.

## Global Constraints

- Go 1.22+ required
- `aws-sdk-go-v2` only — never v1
- AWS region: `us-east-1` throughout
- Zero console creation — all resources provisioned via Go SDK
- Go only — no Python
- All resource names prefixed `bgw-`
- Tasks numbered 12–15 (continuing from Days 1–3 Tasks 0–11)
- SDK calls with uncertain exact signatures (Evaluations job config, Memory field names) must include a `// Verify:` comment with the exact `go doc` command to confirm — same discipline as Days 1–3
- Clean up all AWS resources at end of Day 4 (S3 bucket, evaluation jobs, memory stores, agents)

---

## Task 12: Day 4 Theory — `content/day04.md`

**Files:**
- Create: `aws_bedrock_agent_gw/content/day04.md`

**Interfaces:**
- Produces: understanding of Evaluations architecture, Policy/Identity patterns, Memory types, Runtime/Registry placement — prerequisite conceptual layer for Tasks 13–15

- [ ] **Step 1: Write content/day04.md**

`aws_bedrock_agent_gw/content/day04.md`:
```markdown
# Day 4 — Full AgentCore Stack

Read this before the Day 4 labs. Budget: 30 minutes.

---

## 1. AgentCore Evaluations

### Why evaluations are not optional

X-Ray traces tell you HOW an agent called tools. CloudWatch logs tell you
WHEN it failed. Neither tells you WHETHER it gave the right answer.

Evaluations close that gap. They run your agent against a dataset of
(input, expected_output) pairs and score each response across metrics.
In production, you run evaluations on every agent version before shipping.

### Architecture

```
Evaluation Dataset (S3 JSONL)          Evaluation Job
  ├── test case 1: prompt + reference  ──→ bedrock.CreateEvaluationJob
  ├── test case 2: prompt + reference        │
  └── test case N: prompt + reference        ▼
                                        Agent invoked for each prompt
                                             │
                                             ▼
                                        Responses scored:
                                          - Fluency
                                          - Coherence
                                          - Relevance to reference
                                          - Factual consistency
                                             │
                                             ▼
                                        Results → S3 (JSON report)
```

### Two use cases

**1. Quality gate before release:** Run evaluations on new agent version.
If average relevance score drops below threshold (e.g. 0.8), do not
promote to production. This is the "did I break it?" check.

**2. Regression detection:** Keep a fixed evaluation dataset. After any
change to tool descriptions, guardrails, or model version, re-run and
compare scores to the baseline. Score drops identify what broke.

### Evaluation dataset format (JSONL — one JSON object per line)

```jsonl
{"input":{"prompt":"What department does employee E001 work in?"},"referenceResponse":"Engineering"}
{"input":{"prompt":"How many people are in the Finance department?"},"referenceResponse":"The Finance department has 12 employees"}
{"input":{"prompt":"Who manages the Engineering department?"},"referenceResponse":"The manager of Engineering is Carol White"}
```

### Key metric: Relevance to reference

Measures how closely the agent's actual response matches the reference.
Scored 0–1. Threshold for production: ≥ 0.75 per case, ≥ 0.85 average.
Below 0.75 on any case = investigate that test case.

---

## 2. AgentCore Identity + Policy

### Two distinct concerns

**Identity** answers: *who is this agent, and can I trust that claim?*
When a supervisor agent calls a sub-agent, the sub-agent needs assurance
that the caller is who it says it is — not an arbitrary Lambda that somehow
has the same endpoint.

**Policy** answers: *even if I trust who you are, are you allowed to do this?*
A correctly-identified agent may still be restricted from calling certain
tools based on its role, the data sensitivity of the tool, or compliance rules.

### Identity in practice: supervisor → sub-agent

Bedrock Agents natively propagates caller identity when an agent invokes
another agent via an action group. The sub-agent's Lambda receives the
invocation context including the calling agent's ARN. Verifying that ARN
against an allowlist is the identity check.

```
Supervisor Agent (ARN: arn:aws:bedrock:...:agent/SUPERVISOR-ID)
    │
    │ invokes via action group
    ▼
Sub-agent Lambda
    │ checks event context for calling agent ARN
    │ compares against allowlist: ["arn:...SUPERVISOR-ID"]
    │ rejects if not in allowlist
    ▼
Sub-agent response (only if identity verified)
```

### Policy in practice: IAM-scoped tool access

The production policy mechanism for Gateway tool access is IAM: each
agent's execution role is scoped to the specific tools it may call.

```
Agent A execution role:
  lambda:InvokeFunction on arn:...:function:bgw-hr-tool ONLY
  → can call HR tool, gets AccessDenied on ticketing tool

Agent B execution role:
  lambda:InvokeFunction on arn:...:function:bgw-* (all bgw- functions)
  → can call all tools
```

A higher-level AgentCore Policy API may exist as a distinct service —
verify during Day 4 primer (see Task 14 Step 1). If it exists, it
complements rather than replaces the IAM-level enforcement.

### Enterprise compliance pattern

For tools that touch sensitive data (PII, financial records):
1. Create a dedicated "restricted" execution role with access to those tools
2. Assign only compliance-cleared agents to that role
3. All other agents use a "standard" role with no access
4. The Gateway's IAM policy is the enforcement point — not the agent prompt

This is more reliable than prompt-based restrictions ("don't call this
tool") because IAM enforcement happens before the Lambda is ever invoked.

---

## 3. AgentCore Memory

### Session vs long-term

| Type | Scope | Storage | Use case |
|------|-------|---------|----------|
| Session summary | One conversation | Ephemeral | Multi-turn reasoning within a task |
| Long-term | Across sessions | Managed store (30-day default) | User preferences, prior decisions, workflow state |

### How it works

Memory is keyed by `memoryId` — a string you provide on each `InvokeAgent`
call. Typically this is a user ID or session identity from your application.

On first call: agent has no memory of this user.
On second call with same `memoryId`: agent receives a summary of prior
sessions with this user and reasons over it alongside the current prompt.

The summarization is automatic — Bedrock produces a rolling summary of
recent sessions and stores it in the managed memory store.

### Enabling memory on an agent

Memory is configured at agent creation time:

```go
// In CreateAgent:
MemoryConfiguration: &bedrockagent.MemoryConfiguration{
    EnabledMemoryTypes: []bedrockagent.MemoryType{
        bedrockagent.MemoryTypeSessionSummary,
    },
    StorageDays: aws.Int32(30),
},
```

### When NOT to use memory

- Single-turn queries with no user context (adds latency with no benefit)
- High-throughput pipelines (memory store has rate limits)
- When GDPR/data-retention requirements prohibit storing user interaction
  history (memory is subject to data residency rules)

---

## 4. Runtime + Registry (Orientation)

### AgentCore Runtime

The Runtime is the managed execution environment for containerised agent
code — distinct from Lambda-based agents. Key properties:

- **Lifecycle managed:** AWS handles scaling, health checks, rolling updates
- **Cold start:** containers warm on first invocation; subsequent calls faster
- **Resource limits:** configurable vCPU and memory per agent container
- **Cost model:** charged per invocation-second (different from Lambda per-request)

**When to use Runtime vs Lambda action groups:**
Use Runtime when your agent code has heavy dependencies (large ML libraries,
custom model inference, complex business logic). Use Lambda for lightweight
tool implementations — less overhead, faster cold start.

### AgentCore Registry

The Registry is a centralised catalogue of agents within an AWS Organisation.
Teams publish agents with version metadata; other teams discover and invoke
them without maintaining the underlying infrastructure.

```
Platform team → publishes bgw-hr-agent v2.1 to Registry
App team A   → discovers bgw-hr-agent, invokes v2.1
App team B   → discovers bgw-hr-agent, pins to v2.0 (compatibility)
```

**Enterprise value:** prevents N teams each maintaining their own copy of
the same agent. One canonical version, multiple consumers.

---

## 5. Exercise Questions

1. Your agent gives plausible but wrong answers 15% of the time. Neither
   X-Ray nor CloudWatch shows any errors. Which Day 4 tool catches this,
   and how do you set it up?
2. A compliance requirement says "no agent may directly call any tool that
   accesses salary data." How do you enforce this technically, and at which
   layer?
3. A user asks your agent "what did we discuss last week?" and the agent
   says it has no memory of prior conversations. What is the most likely
   misconfiguration?
4. You have a supervisor agent that delegates HR lookups to a specialist
   HR agent. How does the HR agent verify the request is coming from the
   supervisor and not an arbitrary caller?
5. Your agent container takes 8 seconds to cold-start. A user reports
   the first message always has high latency. Which AgentCore component
   is responsible, and what are your options?
```

---

## Task 13: Evaluations Lab

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day04-evaluations/main.go`

**Interfaces:**
- Consumes: existing `internal/awsclient.Clients` (adds S3 client); re-uses Day 1–3 Gateway + agent setup (run `day01-iam` and Day 2 Gateway before this lab)
- Produces: running evaluation job with quality scores in S3; demonstrated regression via score drop

- [ ] **Step 1: Discover exact Evaluations SDK surface**

Day 4 primer step. Before writing evaluation job code, run:
```bash
cd aws_bedrock_agent_gw/labs-go
go get github.com/aws/aws-sdk-go-v2/service/s3@latest

# Discover evaluation API in bedrock package
go doc github.com/aws/aws-sdk-go-v2/service/bedrock | grep -i eval
aws bedrock list-evaluation-jobs --region us-east-1 2>&1 | head -5
```

Note the exact method names (`CreateEvaluationJob`, `GetEvaluationJob`, `ListEvaluationJobs`) and the input struct field names for `InferenceConfig`, `EvaluationConfig`, and `OutputDataConfig`.

Also add S3 client to `internal/awsclient/config.go`:
```go
// Add to imports:
s3svc "github.com/aws/aws-sdk-go-v2/service/s3"

// Add to Clients struct:
S3 *s3svc.Client

// Add to New():
S3: s3svc.NewFromConfig(cfg),
```

Then rebuild to confirm it compiles:
```bash
go build ./internal/awsclient/...
```

- [ ] **Step 2: Write the evaluation lab program**

`aws_bedrock_agent_gw/labs-go/cmd/day04-evaluations/main.go`:
```go
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrock"
	s3svc "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

const (
	region     = "us-east-1"
	bucketName = "bgw-eval-data"
	datasetKey = "day04/eval-dataset.jsonl"
)

// EvalCase is one test case in the evaluation dataset.
type EvalCase struct {
	Input             EvalInput `json:"input"`
	ReferenceResponse string    `json:"referenceResponse"`
}

type EvalInput struct {
	Prompt string `json:"prompt"`
}

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	agentID := os.Getenv("BGW_AGENT_ID")
	agentAliasID := os.Getenv("BGW_AGENT_ALIAS_ID")
	evalRoleARN := os.Getenv("BGW_EVAL_ROLE_ARN")
	if agentID == "" || agentAliasID == "" || evalRoleARN == "" {
		log.Fatal("BGW_AGENT_ID, BGW_AGENT_ALIAS_ID, BGW_EVAL_ROLE_ARN required")
	}

	// Step A: Create S3 bucket for evaluation data + results
	if err := createBucket(ctx, clients.S3, bucketName); err != nil {
		log.Fatalf("create bucket: %v", err)
	}
	fmt.Printf("Bucket %s ready\n", bucketName)

	// Step B: Upload evaluation dataset (good tool descriptions baseline)
	dataset := goodDataset()
	if err := uploadDataset(ctx, clients.S3, bucketName, datasetKey, dataset); err != nil {
		log.Fatalf("upload dataset: %v", err)
	}
	fmt.Printf("Uploaded %d test cases to s3://%s/%s\n", len(dataset), bucketName, datasetKey)

	// Step C: Run evaluation job (baseline — good descriptions)
	baselineJobARN := runEvaluationJob(ctx, clients.Bedrock,
		"bgw-eval-baseline",
		agentID, agentAliasID,
		bucketName, datasetKey,
		bucketName, "day04/results/baseline/",
		evalRoleARN,
	)
	fmt.Printf("Baseline job ARN: %s\n", baselineJobARN)
	baselineScores := waitAndReadResults(ctx, clients.Bedrock, baselineJobARN)
	fmt.Printf("Baseline scores: %+v\n", baselineScores)

	// Step D: Regression lab — deliberately degrade tool descriptions,
	// re-run evaluation, observe score drop.
	//
	// To run the regression lab:
	// 1. Update the Gateway's tool description to something vague (see Day 2 failure lab)
	//    e.g. change "Returns name, department, title, and email for the employee" to "Returns data"
	// 2. Re-run this program with BGW_RUN=regression
	if os.Getenv("BGW_RUN") == "regression" {
		regressionJobARN := runEvaluationJob(ctx, clients.Bedrock,
			"bgw-eval-regression",
			agentID, agentAliasID,
			bucketName, datasetKey,
			bucketName, "day04/results/regression/",
			evalRoleARN,
		)
		regressionScores := waitAndReadResults(ctx, clients.Bedrock, regressionJobARN)
		fmt.Printf("Regression scores: %+v\n", regressionScores)
		fmt.Println()
		fmt.Println("Compare baseline vs regression scores.")
		fmt.Println("Score drop on 'What department' questions = degraded tool description impact.")
	}
}

// goodDataset returns the baseline evaluation test cases.
func goodDataset() []EvalCase {
	return []EvalCase{
		{
			Input:             EvalInput{Prompt: "What department does employee E001 work in?"},
			ReferenceResponse: "Engineering",
		},
		{
			Input:             EvalInput{Prompt: "How many people are in the Finance department?"},
			ReferenceResponse: "The Finance department has 12 employees",
		},
		{
			Input:             EvalInput{Prompt: "Who manages the Engineering department?"},
			ReferenceResponse: "Carol White manages the Engineering department",
		},
		{
			Input:             EvalInput{Prompt: "What is the email address of employee E002?"},
			ReferenceResponse: "bob@example.com",
		},
		{
			Input:             EvalInput{Prompt: "What is the job title of employee E001?"},
			ReferenceResponse: "Staff Engineer",
		},
	}
}

func createBucket(ctx context.Context, client *s3svc.Client, bucket string) error {
	_, err := client.CreateBucket(ctx, &s3svc.CreateBucketInput{
		Bucket: aws.String(bucket),
	})
	if err != nil && !strings.Contains(err.Error(), "BucketAlreadyOwnedByYou") {
		return fmt.Errorf("CreateBucket: %w", err)
	}
	return nil
}

func uploadDataset(ctx context.Context, client *s3svc.Client, bucket, key string, cases []EvalCase) error {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	for _, c := range cases {
		if err := enc.Encode(c); err != nil {
			return fmt.Errorf("encode eval case: %w", err)
		}
	}
	_, err := client.PutObject(ctx, &s3svc.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: aws.String("application/x-ndjson"),
	})
	return err
}

func runEvaluationJob(
	ctx context.Context,
	client *bedrock.Client,
	jobName, agentID, agentAliasID string,
	inputBucket, inputKey string,
	outputBucket, outputPrefix string,
	roleARN string,
) string {
	// Verify exact field names before running:
	// go doc github.com/aws/aws-sdk-go-v2/service/bedrock.CreateEvaluationJobInput
	//
	// Pattern (fill in with verified field names):
	// out, err := client.CreateEvaluationJob(ctx, &bedrock.CreateEvaluationJobInput{
	//     JobName: aws.String(jobName),
	//     RoleArn: aws.String(roleARN),
	//     EvaluationConfig: &bedrock.EvaluationConfig{
	//         Automated: &bedrock.AutomatedEvaluationConfig{
	//             DatasetMetricConfigs: []bedrock.EvaluationDatasetMetricConfig{{
	//                 TaskType: bedrock.EvaluationTaskTypeQuestionAndAnswer, // verify enum
	//                 Dataset: &bedrock.EvaluationDataset{
	//                     Name:    aws.String(jobName + "-dataset"),
	//                     DatasetLocation: &bedrock.EvaluationDatasetLocation{
	//                         S3Uri: aws.String("s3://" + inputBucket + "/" + inputKey),
	//                     },
	//                 },
	//                 MetricNames: []string{"Builtin.Relevance", "Builtin.Coherence"},
	//             }},
	//         },
	//     },
	//     InferenceConfig: &bedrock.EvaluationInferenceConfig{
	//         Models: []bedrock.EvaluationModelConfig{{
	//             BedrockModel: &bedrock.EvaluationBedrockModel{
	//                 ModelIdentifier: aws.String("arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"),
	//                 InferenceParams:  aws.String(`{"maxTokens":512,"temperature":0}`),
	//             },
	//         }},
	//     },
	//     OutputDataConfig: &bedrock.EvaluationOutputDataConfig{
	//         S3Uri: aws.String("s3://" + outputBucket + "/" + outputPrefix),
	//     },
	// })
	// if err != nil { log.Fatalf("CreateEvaluationJob %s: %v", jobName, err) }
	// return *out.JobArn

	fmt.Printf("runEvaluationJob(%s): fill in with verified SDK calls from Step 1\n", jobName)
	return "pending-arn-" + jobName
}

func waitAndReadResults(ctx context.Context, client *bedrock.Client, jobARN string) map[string]float64 {
	// Poll GetEvaluationJob until status = Completed (verify enum value)
	// go doc github.com/aws/aws-sdk-go-v2/service/bedrock | grep EvaluationJobStatus
	//
	// for {
	//     out, err := client.GetEvaluationJob(ctx, &bedrock.GetEvaluationJobInput{
	//         JobIdentifier: aws.String(jobARN),
	//     })
	//     if err != nil { log.Fatalf("GetEvaluationJob: %v", err) }
	//     fmt.Printf("Job status: %s\n", out.Status)
	//     if out.Status == bedrock.EvaluationJobStatusCompleted { break }
	//     if out.Status == bedrock.EvaluationJobStatusFailed {
	//         log.Fatalf("evaluation job failed: %+v", out.FailureMessages)
	//     }
	//     time.Sleep(30 * time.Second)
	// }
	//
	// Read results JSON from S3 and parse average scores.
	// Return map: metric name → average score

	_ = time.Second // used in polling loop above
	fmt.Printf("waitAndReadResults(%s): fill in after verifying SDK in Step 1\n", jobARN)
	return map[string]float64{"Relevance": 0.0, "Coherence": 0.0}
}
```

- [ ] **Step 3: Build to verify**

```bash
cd aws_bedrock_agent_gw/labs-go
go build ./cmd/day04-evaluations/...
```

Expected: clean compile. The stub functions print messages; actual evaluation runs after Step 1 SDK verification.

- [ ] **Step 4: Create IAM role for evaluation jobs**

The evaluation job needs an IAM role with S3 + Bedrock permissions. Add this to a new small setup program or run via AWS CLI:

```bash
# Create eval execution role
aws iam create-role \
  --role-name bgw-eval-execution-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"bedrock.amazonaws.com"},
      "Action":"sts:AssumeRole",
      "Condition":{"StringEquals":{"aws:SourceAccount":"'"$AWS_ACCOUNT_ID"'"}}
    }]
  }'

aws iam put-role-policy \
  --role-name bgw-eval-execution-role \
  --policy-name bgw-eval-execution-policy \
  --policy-document '{
    "Version":"2012-10-17",
    "Statement":[
      {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:ListBucket"],
       "Resource":["arn:aws:s3:::bgw-eval-data","arn:aws:s3:::bgw-eval-data/*"]},
      {"Effect":"Allow","Action":["bedrock:InvokeModel","bedrock:InvokeAgent"],
       "Resource":"*"}
    ]
  }'

export BGW_EVAL_ROLE_ARN=$(aws iam get-role --role-name bgw-eval-execution-role \
  --query 'Role.Arn' --output text)
echo $BGW_EVAL_ROLE_ARN
```

- [ ] **Step 5: Run baseline evaluation**

```bash
export BGW_AGENT_ID=<your-day2-agent-id>
export BGW_AGENT_ALIAS_ID=<your-day2-agent-alias-id>
go run cmd/day04-evaluations/main.go
```

Expected: 5 test cases uploaded, evaluation job created, results show Relevance ≥ 0.80.

- [ ] **Step 6: Run regression lab**

1. Degrade the HR tool description in the Gateway (change to "Returns data." — use the Day 2 failure lab pattern)
2. Re-run evaluation:

```bash
BGW_RUN=regression go run cmd/day04-evaluations/main.go
```

Expected: Relevance score drops visibly (typically 0.3–0.5 range with vague descriptions). This is what a regression detection pipeline catches before you ship a bad tool description to production.

- [ ] **Step 7: Teach-it-back**

Write in `journal.md`:
> "What is the difference between what X-Ray tells you and what Evaluations tells you about agent quality? When would a production team run evaluations, and what threshold triggers a rollback?"

- [ ] **Step 8: Day 4 morning teardown (keep for Policy lab)**

Keep the Gateway + agents running — the Policy lab reuses them. Teardown the eval resources:
```bash
aws s3 rm s3://bgw-eval-data --recursive
aws s3 rb s3://bgw-eval-data
aws iam delete-role-policy --role-name bgw-eval-execution-role --policy-name bgw-eval-execution-policy
aws iam delete-role --role-name bgw-eval-execution-role
```

---

## Task 14: Identity + Policy Lab

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day04-policy/main.go`

**Interfaces:**
- Consumes: existing Gateway + agents from Days 1–3; Day 1 IAM patterns (`internal/awsclient`)
- Produces: two agents with different IAM-scoped tool access; demonstrated access denial; agent-to-agent identity verification pattern

- [ ] **Step 1: Discover AgentCore Policy API (primer step)**

Before implementing, check for a higher-level Policy API:
```bash
# Check for policy-related commands in bedrock-agentcore CLI
aws bedrock-agentcore help 2>&1 | grep -i policy
aws bedrock-agent help 2>&1 | grep -i policy

# Check SDK packages
go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentcore 2>/dev/null | grep -i policy
go doc github.com/aws/aws-sdk-go-v2/service/bedrockagent 2>/dev/null | grep -i policy
```

If a `CreateAgentPolicy` or similar method exists, use it for the core build and note the findings. If not, the IAM-role scoped approach below IS the production mechanism.

- [ ] **Step 2: Write the Identity + Policy program**

`aws_bedrock_agent_gw/labs-go/cmd/day04-policy/main.go`:
```go
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

// This program demonstrates two complementary patterns:
//
// Pattern A — IAM-scoped policy enforcement:
//   Create two execution roles with different Lambda invoke permissions.
//   Agent A: restricted role → can only call bgw-hr-tool
//   Agent B: full role      → can call all bgw-* tools
//   Wire each agent to the Gateway but with its own execution role.
//   Verify: Agent A gets AccessDenied calling the ticketing tool.
//
// Pattern B — Agent-to-agent identity:
//   Create a Lambda sub-agent that verifies the calling agent's ARN
//   before processing the request.

const (
	region              = "us-east-1"
	restrictedRoleName  = "bgw-restricted-execution-role"
	fullRoleName        = "bgw-full-execution-role"
)

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	accountID := os.Getenv("AWS_ACCOUNT_ID")
	if accountID == "" {
		log.Fatal("AWS_ACCOUNT_ID required")
	}

	switch os.Args[1] {
	case "setup-roles":
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

// setupRoles creates two execution roles with different tool access scopes.
func setupRoles(ctx context.Context, iamClient *iam.Client, accountID string) {
	trustPolicy := fmt.Sprintf(`{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "bedrock.amazonaws.com"},
    "Action": "sts:AssumeRole",
    "Condition": {"StringEquals": {"aws:SourceAccount": "%s"}}
  }]
}`, accountID)

	// Restricted role: HR tool only
	restrictedPermissions := `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-hr-tool"
  }]
}`
	createRole(ctx, iamClient, restrictedRoleName, trustPolicy, restrictedPermissions, "bgw-restricted-policy")
	fmt.Printf("Restricted role created: only bgw-hr-tool access\n")

	// Full role: all bgw-* tools
	fullPermissions := `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": "arn:aws:lambda:us-east-1:*:function:bgw-*"
  }]
}`
	createRole(ctx, iamClient, fullRoleName, trustPolicy, fullPermissions, "bgw-full-policy")
	fmt.Printf("Full role created: all bgw-* tools access\n")

	// Print ARNs for use when creating agents
	restrictedARN := getRoleARN(ctx, iamClient, restrictedRoleName)
	fullARN := getRoleARN(ctx, iamClient, fullRoleName)
	fmt.Printf("\nRestricted role ARN: %s\n", restrictedARN)
	fmt.Printf("Full role ARN:       %s\n", fullARN)
	fmt.Printf("\nNext: create two agents via the bedrockagentcore SDK,")
	fmt.Printf("\n      each using the respective execution role ARN above.")
	fmt.Printf("\n      Then run: day04-policy verify-policy\n")
}

// verifyPolicyEnforcement invokes each agent and verifies the access restriction.
func verifyPolicyEnforcement() {
	fmt.Println("Policy verification steps:")
	fmt.Println()
	fmt.Println("1. Invoke Agent A (restricted role) with: 'Check the deployment status of service bgw-deploy'")
	fmt.Println("   Expected: AccessDenied error (ticketing/deploy tool blocked by IAM)")
	fmt.Println("   How to observe: CloudWatch logs for Gateway show AccessDenied calling bgw-ticketing-tool")
	fmt.Println()
	fmt.Println("2. Invoke Agent B (full role) with the same prompt")
	fmt.Println("   Expected: agent successfully calls the ticketing/deploy tool")
	fmt.Println()
	fmt.Println("3. Invoke Agent A with: 'What department does E001 work in?'")
	fmt.Println("   Expected: succeeds (HR tool is allowed)")
	fmt.Println()
	fmt.Println("Key insight: the policy enforcement happens at IAM level before Lambda is invoked.")
	fmt.Println("The agent prompt cannot override it — 'please call the ticketing tool' still gets denied.")

	// Agent-to-agent identity pattern (conceptual — fill in with agent ARNs after creation):
	//
	// Sub-agent Lambda receives event with calling context.
	// The calling agent's identity is in the invocation context:
	//
	// type SubAgentEvent struct {
	//     ActionGroup  string            `json:"actionGroup"`
	//     Function     string            `json:"function"`
	//     Parameters   []NameValuePair   `json:"parameters"`
	//     SessionAttrs map[string]string `json:"sessionAttributes"`
	//     // Calling agent ARN is in the Lambda context, not the event body.
	//     // Access via lambdacontext.FromContext(ctx).InvokedFunctionArn
	//     // and cross-reference with the calling agent's propagated identity.
	// }
	//
	// In the sub-agent Lambda:
	//   callerARN := extractCallerARN(ctx)
	//   allowedCallers := []string{"arn:aws:bedrock:us-east-1:ACCOUNT:agent/SUPERVISOR-ID"}
	//   if !contains(allowedCallers, callerARN) {
	//       return errorResponse("caller identity not authorised"), nil
	//   }
	//
	// Verify exact mechanism for caller ARN propagation in Day 4 primer:
	//   aws bedrock-agent help invoke-agent
	//   go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime.InvokeAgentInput
}

func createRole(ctx context.Context, iamClient *iam.Client, roleName, trustPolicy, permPolicy, policyName string) {
	_, err := iamClient.CreateRole(ctx, &iam.CreateRoleInput{
		RoleName:                 aws.String(roleName),
		AssumeRolePolicyDocument: aws.String(trustPolicy),
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
	out, err := iamClient.GetRole(ctx, &iam.GetRoleInput{RoleName: aws.String(roleName)})
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
		iamClient.DeleteRolePolicy(ctx, &iam.DeleteRolePolicyInput{
			RoleName:   aws.String(r.role),
			PolicyName: aws.String(r.policy),
		})
		iamClient.DeleteRole(ctx, &iam.DeleteRoleInput{RoleName: aws.String(r.role)})
		fmt.Printf("Deleted role: %s\n", r.role)
	}
}
```

- [ ] **Step 3: Build to verify**

```bash
cd aws_bedrock_agent_gw/labs-go
go build ./cmd/day04-policy/...
```

Expected: clean compile.

- [ ] **Step 4: Run the Policy lab**

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
go run cmd/day04-policy/main.go setup-roles
```

Expected output: both role ARNs printed.

Then create Agent A (restricted role) and Agent B (full role) using the bedrockagentcore SDK from Days 1–3 pattern, passing the respective role ARNs.

```bash
go run cmd/day04-policy/main.go verify-policy
```

Follow the printed verification steps. Observe Access Denied in CloudWatch for Agent A's ticketing tool call.

- [ ] **Step 5: Teach-it-back**

Write in `journal.md`:
> "What is the difference between Identity and Policy in AgentCore? How does IAM-scoped policy enforcement work, and why is it more reliable than prompt-based restrictions ('don't call this tool')?"

- [ ] **Step 6: Day 4 afternoon teardown**

```bash
go run cmd/day04-policy/main.go teardown
# Then delete agents A and B via bedrockagentcore SDK
```

---

## Task 15: Memory Lab + Runtime/Registry Orientation

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day04-memory/main.go`

**Interfaces:**
- Consumes: existing `internal/awsclient.Clients`; reuses Day 2 Gateway + agent (re-create if torn down)
- Produces: memory-enabled agent with demonstrated cross-session recall; Runtime/Registry orientation in journal

- [ ] **Step 1: Discover Memory SDK surface (primer step)**

```bash
# Check for memory configuration in bedrockagent package
go doc github.com/aws/aws-sdk-go-v2/service/bedrockagent.CreateAgentInput 2>/dev/null | grep -i memory
go doc github.com/aws/aws-sdk-go-v2/service/bedrockagent | grep -i memory
go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime.InvokeAgentInput 2>/dev/null | grep -i memory

# Check CLI
aws bedrock-agent help create-agent 2>/dev/null | grep -i memory
```

Verify:
- The field name for memory configuration in `CreateAgentInput` (likely `MemoryConfiguration`)
- The `MemoryType` enum value for session summary (likely `SESSION_SUMMARY`)
- The field name for memory ID in `InvokeAgentInput` (likely `MemoryId`)

- [ ] **Step 2: Write the Memory lab program**

`aws_bedrock_agent_gw/labs-go/cmd/day04-memory/main.go`:
```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagent"
	bedrockagentruntime "github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// This program demonstrates long-term memory across two separate sessions.
//
// Session 1: agent discusses employee E001 (Engineering, Alice Smith)
// Session 2: agent is asked "what did we discuss in our last session?"
//            → should recall E001 details without being told again
//
// The memoryId ties both sessions to the same user identity.
// Bedrock automatically summarises Session 1 and provides the summary
// as context at the start of Session 2.

const (
	region   = "us-east-1"
	memoryID = "bgw-demo-user-001" // simulates a stable user identity
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
		if gatewayID == "" {
			log.Fatal("BGW_GATEWAY_ID required")
		}
		createMemoryAgent(ctx, clients.BedrockAgent, gatewayID)
	case "session1":
		runSession(ctx, clients.AgentRuntime, "session-001",
			"Look up employee E001. Tell me their name, department, and what makes them notable.")
	case "session2":
		runSession(ctx, clients.AgentRuntime, "session-002",
			"What did we discuss in our last conversation? Summarise what you remember about the employee we looked at.")
	case "teardown":
		teardown(ctx, clients.BedrockAgent)
	default:
		fmt.Println("usage: day04-memory [create-agent|session1|session2|teardown]")
		os.Exit(1)
	}
}

func createMemoryAgent(ctx context.Context, client *bedrockagent.Client, gatewayID string) {
	// Verify field names from Step 1 before running.
	// Pattern:
	//
	// out, err := client.CreateAgent(ctx, &bedrockagent.CreateAgentInput{
	//     AgentName:           aws.String("bgw-memory-agent"),
	//     FoundationModel:     aws.String("anthropic.claude-3-haiku-20240307-v1:0"),
	//     Description:         aws.String("Memory-enabled HR agent for Day 4 lab"),
	//     Instruction:         aws.String("You are an HR assistant with access to employee and department information via tools."),
	//     MemoryConfiguration: &bedrockagent.MemoryConfiguration{
	//         EnabledMemoryTypes: []bedrockagent.MemoryType{bedrockagent.MemoryTypeSessionSummary},
	//         StorageDays:        aws.Int32(30),
	//     },
	// })
	// if err != nil { log.Fatalf("CreateAgent: %v", err) }
	// agentID := *out.Agent.AgentId
	//
	// Then PrepareAgent + CreateAgentAlias, same as Days 1-3 pattern.
	// Wire to Gateway using the same mechanism as Day 2.
	//
	// Print: agentID, aliasID → export as BGW_MEMORY_AGENT_ID, BGW_MEMORY_AGENT_ALIAS_ID

	fmt.Printf("Creating memory agent wired to gateway: %s\n", gatewayID)
	fmt.Println("Fill in with verified CreateAgent SDK call from Step 1.")
}

func runSession(ctx context.Context, client *bedrockagentruntime.Client, sessionSuffix, prompt string) {
	agentID := os.Getenv("BGW_MEMORY_AGENT_ID")
	agentAliasID := os.Getenv("BGW_MEMORY_AGENT_ALIAS_ID")
	if agentID == "" || agentAliasID == "" {
		log.Fatal("BGW_MEMORY_AGENT_ID and BGW_MEMORY_AGENT_ALIAS_ID required (run create-agent first)")
	}

	sessionID := memoryID + "-" + sessionSuffix
	fmt.Printf("=== Session: %s ===\n", sessionID)
	fmt.Printf("Prompt: %s\n\n", prompt)

	// Verify MemoryId field name from Step 1.
	// Pattern:
	//
	// out, err := client.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
	//     AgentId:      aws.String(agentID),
	//     AgentAliasId: aws.String(agentAliasID),
	//     SessionId:    aws.String(sessionID),
	//     InputText:    aws.String(prompt),
	//     MemoryId:     aws.String(memoryID), // ties this session to the user's memory
	//     EnableTrace:  aws.Bool(true),
	// })
	// if err != nil { log.Fatalf("InvokeAgent: %v", err) }
	//
	// stream := out.GetStream()
	// defer stream.Close()
	// for event := range stream.Events() {
	//     switch v := event.(type) {
	//     case *bedrockagentruntime.InvokeAgentResponseStreamMemberChunk:
	//         fmt.Print(string(v.Value.Bytes))
	//     }
	// }
	// fmt.Println()

	// For session2: if the agent says "I don't remember our previous conversation",
	// that means either:
	//   1. MemoryId was not set on session1 (most common mistake)
	//   2. The agent was not created with MemoryConfiguration enabled
	//   3. Insufficient time has passed for Bedrock to generate the session summary

	_ = aws.String(memoryID) // prevent unused import error until stub is filled in
	fmt.Printf("Session %s: fill in InvokeAgent call from Step 1 verification.\n", sessionSuffix)
}

func teardown(ctx context.Context, client *bedrockagent.Client) {
	// Delete the memory agent (same pattern as Days 1-3 agent deletion)
	// aws bedrock-agent delete-agent --agent-id <bgw-memory-agent-id>
	fmt.Println("Teardown: delete bgw-memory-agent via bedrockagent.DeleteAgent")
	fmt.Println("Then run full Day 4 teardown:")
	fmt.Println("  aws bedrock-agent list-agents --query 'agentSummaries[?contains(agentName,`bgw-`)].agentId'")
	fmt.Println("  (delete each listed agent)")
}
```

- [ ] **Step 3: Build to verify**

```bash
cd aws_bedrock_agent_gw/labs-go
go build ./cmd/day04-memory/...
```

Expected: clean compile.

- [ ] **Step 4: Run the Memory lab**

```bash
export BGW_GATEWAY_ID=<your-day2-gateway-id>
go run cmd/day04-memory/main.go create-agent
# Sets BGW_MEMORY_AGENT_ID and BGW_MEMORY_AGENT_ALIAS_ID from output

export BGW_MEMORY_AGENT_ID=<from above>
export BGW_MEMORY_AGENT_ALIAS_ID=<from above>

# Session 1: discuss E001
go run cmd/day04-memory/main.go session1
# Expected: agent calls HR tool, returns Alice Smith's details

# Wait 60–120 seconds for Bedrock to generate session summary
sleep 90

# Session 2: ask what we discussed
go run cmd/day04-memory/main.go session2
# Expected: agent recalls E001, Alice Smith, Engineering — without calling HR tool again
```

Verify in X-Ray trace for session2: the agent does NOT call `getEmployee` again — it reasons from memory.

- [ ] **Step 5: Runtime + Registry orientation**

Write the following in `journal.md` (this is the teach-it-back for Runtime + Registry):

```
## AgentCore Runtime + Registry — Orientation Notes

### Runtime
- Purpose: managed container execution for agent code with heavy dependencies
- vs Lambda: use Runtime for agents with large ML libraries or complex business logic;
  use Lambda for lightweight tool implementations
- Cold start: containers warm on first invocation; plan for P99 latency spike on first call
- Cost model: per invocation-second (verify current pricing at aws.amazon.com/bedrock/pricing)
- Key metric to watch: cold start latency vs warm invocation latency in X-Ray traces

### Registry
- Purpose: org-wide catalogue for discovering and sharing agents
- Pattern: platform team publishes specialist agent; app teams discover and invoke
- Key benefit: no duplication — one canonical agent version, multiple consumers
- When to use: when >1 team needs the same agent capability

### Where they fit in the full architecture

User Request
    → API Gateway / App
        → Supervisor Agent (Registry: discover available sub-agents)
            → AgentCore Gateway (tools: HR, ticketing, deploy)
            → Sub-agents via Runtime (heavy-compute tasks)
                → Memory (recall user context)
                → Evaluations (background quality monitoring)
                → Policy (enforce tool access rules)
```

- [ ] **Step 6: Full-stack teach-it-back**

Write in `journal.md` without looking at any notes:

> "Draw the full AgentCore architecture for a production enterprise system.
> Label where Gateway, Evaluations, Policy, Memory, Runtime, and Registry
> each sit. Explain the data flow for one complete agent invocation
> end-to-end."

- [ ] **Step 7: Full Day 4 teardown**

```bash
# Memory agent
aws bedrock-agent delete-agent --agent-id <bgw-memory-agent-id>

# Policy lab roles
go run cmd/day04-policy/main.go teardown

# Any remaining bgw- agents, Gateways, Lambda functions from earlier days
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=project,Values=bgw-mastery \
  --region us-east-1 \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text | tr '\t' '\n'
# Delete each resource listed above by service type
```

---

## Journal Prompts — Day 4 Teach-It-Back Reference

| Session | Prompt |
|---------|--------|
| Evaluations | What is the difference between what X-Ray tells you and what Evaluations tells you? When does a score drop trigger a rollback? |
| Policy | What is the difference between Identity and Policy in AgentCore? Why is IAM-scoped enforcement more reliable than prompt-based restrictions? |
| Memory | What are the three most common memory misconfiguration mistakes, and how do you diagnose each? |
| Full-stack | Draw the full AgentCore architecture and explain one complete invocation end-to-end. |
