# AWS Bedrock AgentCore Gateway — 3-Day Mastery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, operate, and master AWS Bedrock AgentCore Gateway through hands-on Go labs — from IAM foundations to production-hardened multi-agent systems with guardrails, X-Ray tracing, and auth mediation.

**Architecture:** SDK-first, IAM-upfront. Every AWS resource is provisioned via `aws-sdk-go-v2` in Go. Zero console creation. Each day builds on the previous: Day 1 establishes the IAM trust chain and first working tool; Day 2 adds OpenAPI-driven tool registration and enterprise auth; Day 3 adds guardrails, observability, and a timed closed-book rebuild.

**Tech Stack:** Go 1.22+, `aws-sdk-go-v2`, `bedrockagent`, `bedrockagentruntime`, `bedrock` (guardrails), `bedrockagentcore` (Gateway — verify package name on Day 1 primer), `iam`, `lambda`, AWS X-Ray SDK for Go.

## Global Constraints

- Go 1.22+ required (`go version` must be ≥ 1.22)
- `aws-sdk-go-v2` only — never `aws-sdk-go` (v1)
- AWS region: `us-east-1` throughout (Bedrock AgentCore availability)
- Zero console creation — all resources provisioned via Go SDK
- Go only — no Python; do not adapt Python examples
- Clean up all AWS resources at end of each day (see teardown steps) to avoid ongoing costs
- Resource names are prefixed `bgw-` to make cleanup unambiguous: `bgw-execution-role`, `bgw-gateway`, etc.
- `bedrockagentcore` SDK package name: **verify on Day 1 primer before writing any Gateway code** (see Task 2 step 1)

---

## Task 0: Project Scaffold

**Files:**
- Create: `aws_bedrock_agent_gw/README.md`
- Create: `aws_bedrock_agent_gw/content/README.md`
- Create: `aws_bedrock_agent_gw/labs-go/go.mod`
- Create: `aws_bedrock_agent_gw/labs-go/internal/awsclient/config.go`

**Interfaces:**
- Produces: `awsclient.New(ctx, region) (*Clients, error)` — shared AWS client struct used by all lab commands

- [ ] **Step 1: Create top-level README**

`aws_bedrock_agent_gw/README.md`:
```markdown
# AWS Bedrock AgentCore Gateway — 3-Day Mastery

Entry point for the 3-day aggressive learning plan. Goal: production-grade
proficiency with AgentCore Gateway as an enterprise tool registry.

## Where everything lives

| Path | What it is |
|---|---|
| `docs/superpowers/specs/2026-07-14-bedrock-agentcore-gateway-mastery-design.md` | Design spec — purpose, strategy, mistakes table, success criteria |
| `docs/superpowers/plans/2026-07-14-bedrock-agentcore-gateway-mastery-plan.md` | This execution plan — follow it task by task |
| `content/dayNN.md` | Theory layer — read BEFORE each day's hands-on labs |
| `labs-go/cmd/day*/` | Go lab programs — one directory per lab exercise |
| `aws/iam/` | IAM policy JSON files |
| `aws/lambda/` | Lambda function source code |
| `aws/openapi/` | OpenAPI spec files for Day 2 tool registration |

## Daily rhythm (6–8 hrs)

1. **Primer** (30 min) — read the day's content doc + relevant SDK source
2. **Core lab** (2.5 hrs) — build the day's main exercise
3. **Failure lab** (1 hr) — break things deliberately, read errors
4. Break (15 min)
5. **Extend** (1.5 hrs) — wire the day's feature into the prior day's work
6. **Teach-it-back** (30 min) — write one explanation as if briefing an on-call teammate
7. **Journal + teardown** (20 min) — reflect; run teardown to avoid AWS costs

## Start here

`content/day01.md`, then `labs-go/cmd/day01-iam/main.go`.
```

- [ ] **Step 2: Create content navigation**

`aws_bedrock_agent_gw/content/README.md`:
```markdown
# Content — Theory Layer

Read the relevant day file BEFORE its hands-on lab. Each file covers
concepts, best practices, architecture diagrams, and exercise questions.
Do not skip: the lab code will make much more sense after the theory.

| File | Day | Theme |
|------|-----|-------|
| day01.md | Day 1 | MCP protocol, IAM trust chain, Gateway fundamentals |
| day02.md | Day 2 | OpenAPI tool schemas, auth mediation, multi-agent patterns |
| day03.md | Day 3 | Guardrails, X-Ray tracing, production hardening |
```

- [ ] **Step 3: Initialise Go module**

```bash
cd aws_bedrock_agent_gw/labs-go
go mod init github.com/hunghan/bedrock-gateway-mastery
```

Then add dependencies:
```bash
go get github.com/aws/aws-sdk-go-v2/config@latest
go get github.com/aws/aws-sdk-go-v2/service/iam@latest
go get github.com/aws/aws-sdk-go-v2/service/lambda@latest
go get github.com/aws/aws-sdk-go-v2/service/bedrock@latest
go get github.com/aws/aws-sdk-go-v2/service/bedrockagent@latest
go get github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime@latest
go get github.com/aws/aws-lambda-go/lambda@latest
```

Note: `bedrockagentcore` is added in Task 2 after the package name is verified.

Expected: `go.mod` and `go.sum` are populated with no errors.

- [ ] **Step 4: Write shared AWS client**

`aws_bedrock_agent_gw/labs-go/internal/awsclient/config.go`:
```go
package awsclient

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrock"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagent"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
)

type Clients struct {
	IAM          *iam.Client
	Lambda       *lambda.Client
	Bedrock      *bedrock.Client
	BedrockAgent *bedrockagent.Client
	AgentRuntime *bedrockagentruntime.Client
}

func New(ctx context.Context, region string) (*Clients, error) {
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &Clients{
		IAM:          iam.NewFromConfig(cfg),
		Lambda:       lambda.NewFromConfig(cfg),
		Bedrock:      bedrock.NewFromConfig(cfg),
		BedrockAgent: bedrockagent.NewFromConfig(cfg),
		AgentRuntime: bedrockagentruntime.NewFromConfig(cfg),
	}, nil
}
```

- [ ] **Step 5: Verify it compiles**

```bash
cd aws_bedrock_agent_gw/labs-go
go build ./internal/awsclient/...
```

Expected: no output (clean compile).

---

## Day 1 — Gateway Foundations

---

### Task 1: Day 1 Theory — `content/day01.md`

**Files:**
- Create: `aws_bedrock_agent_gw/content/day01.md`

**Interfaces:**
- Produces: understanding of MCP, IAM 3-party chain, Gateway vs action groups — prerequisite for Task 2

- [ ] **Step 1: Write content/day01.md**

`aws_bedrock_agent_gw/content/day01.md`:
```markdown
# Day 1 — Gateway Fundamentals

Read this before touching any lab code. Budget: 30 minutes.

---

## 1. What is MCP (Model Context Protocol)?

MCP is a protocol that standardises how AI agents discover and call tools.
Think of it as HTTP for agent-tool communication: it defines a request/response
format so any MCP-compatible agent can call any MCP-compatible tool server,
regardless of language or cloud.

**Client/server model:**
- **MCP client** — the agent (calls tools)
- **MCP server** — exposes tools (responds to tool calls)

**Two-phase interaction:**
1. **Discovery** — client calls `tools/list` → server returns a list of tool
   descriptions and their input schemas
2. **Invocation** — client calls `tools/call` with tool name + arguments →
   server executes and returns the result

The discovery phase is what makes Gateway powerful: agents dynamically learn
what tools are available rather than having them hardcoded.

---

## 2. What is AgentCore Gateway?

AgentCore Gateway is a **managed MCP server** hosted by AWS. You:
1. Define tools (backed by Lambda, HTTP endpoints, or AWS services)
2. Register them in a Gateway
3. Point your Bedrock agents at the Gateway endpoint

The Gateway handles:
- **Tool registry** — stores all tool definitions; agents query it at runtime
- **Auth mediation** — holds credentials for downstream APIs; agents never
  see secrets
- **MCP protocol** — translates agent tool calls into actual API invocations
- **Observability** — logs all tool invocations; integrates with X-Ray

**Why Gateway instead of action groups?**

| | Action Groups (old) | AgentCore Gateway (new) |
|---|---|---|
| Scope | Per-agent | Centralized registry |
| Tool updates | Redeploy agent | Update Gateway; all agents see it |
| Auth | Agent holds secrets | Gateway holds secrets |
| Multi-agent | Copy config to each agent | Share one Gateway |
| Protocol | Bedrock-proprietary | MCP (open standard) |

If you have 5 agents that all need to call your HR API, with action groups you
configure that 5 times. With Gateway you configure it once.

---

## 3. The IAM Trust Chain — 3 Parties

This is the most important concept to internalise before writing any code.
Getting any one of these wrong causes opaque errors that waste hours.

```
┌─────────────────────────────────────────────────┐
│  Party 1: Caller Identity                        │
│  (the IAM entity calling the Gateway — could be  │
│   your IAM user, a Lambda role, or an agent)     │
│                                                   │
│  Required permission:                             │
│    bedrock-agentcore:InvokeGateway (verify name) │
└────────────────────┬────────────────────────────┘
                     │ calls Gateway endpoint
                     ▼
┌─────────────────────────────────────────────────┐
│  Party 2: Gateway Execution Role                 │
│  (IAM role the Gateway ASSUMES to call           │
│   downstream APIs on behalf of the agent)        │
│                                                   │
│  Trust policy principal: bedrock.amazonaws.com   │
│  Required permission: lambda:InvokeFunction,     │
│    execute-api:Invoke (for HTTP tools), etc.     │
└────────────────────┬────────────────────────────┘
                     │ invokes
                     ▼
┌─────────────────────────────────────────────────┐
│  Party 3: Downstream API / Lambda                │
│  (the actual tool — Lambda function, REST API)   │
│                                                   │
│  Lambda: resource policy must allow              │
│    lambda:InvokeFunction from the execution role │
└─────────────────────────────────────────────────┘
```

**The failure pattern:** If Party 1 can't call the Gateway → 403 on Gateway
invocation. If Party 2 can't call Lambda → the Gateway gets a 403 calling
Lambda, which surfaces as a tool execution error in the agent response. If
Party 3's Lambda resource policy is wrong → same symptom as Party 2 failure.
They look identical from the agent's perspective. You must inspect CloudWatch
logs at each layer to pinpoint which party failed.

---

## 4. Key Terms

| Term | Definition |
|------|-----------|
| Gateway | The managed MCP server instance |
| Gateway Target | A single tool registered in the Gateway (backed by Lambda or HTTP) |
| Execution Role | IAM role Party 2 — the Gateway assumes this to call tools |
| Inline Agent | A Bedrock agent defined entirely in code, not in the console |
| MCP endpoint | The URL your agent points to for tool discovery and calls |
| Foundation Model (FM) | The LLM powering the agent reasoning (e.g. Claude 3 Sonnet) |

---

## 5. Exercise Questions

Answer these after the day's labs. If you can't answer them without notes,
re-read the relevant section.

1. In the IAM trust chain, which party holds the downstream API credentials?
2. An agent gets a tool execution error but the Lambda function logs show no
   invocation at all. Which IAM layer failed?
3. What is the difference between `tools/list` and `tools/call` in MCP?
4. Why does Gateway make tool updates easier than action groups for a
   10-agent system?
5. What does the trust policy principal `bedrock.amazonaws.com` mean, and
   why does Party 2's role need it?
```

---

### Task 2: IAM Foundation — 3-Layer Trust Chain

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day01-iam/main.go`
- Create: `aws_bedrock_agent_gw/aws/iam/gateway-execution-trust.json`
- Create: `aws_bedrock_agent_gw/aws/iam/gateway-execution-permissions.json`
- Create: `aws_bedrock_agent_gw/aws/iam/lambda-execution-trust.json`
- Create: `aws_bedrock_agent_gw/aws/iam/lambda-execution-permissions.json`

**Interfaces:**
- Produces:
  - `GatewayExecutionRoleARN` (string) — used in Task 3 `CreateGateway`
  - `LambdaExecutionRoleARN` (string) — used in Task 3 Lambda deployment

- [ ] **Step 1: Discover the exact AgentCore Gateway SDK package**

This is the Day 1 primer step. Before writing any Gateway code, run:

```bash
# Check if bedrockagentcore package exists in the SDK
go list -m github.com/aws/aws-sdk-go-v2/service/bedrockagentcore@latest 2>&1

# Check AWS CLI for agentcore commands
aws bedrock-agentcore help 2>&1 | head -30

# List all available bedrock-related SDK packages
curl -s "https://proxy.golang.org/github.com/aws/aws-sdk-go-v2/service/@v/list" 2>/dev/null | grep bedrock
```

Record the exact package name. If `bedrockagentcore` exists, add it:
```bash
go get github.com/aws/aws-sdk-go-v2/service/bedrockagentcore@latest
```

Then add the client to `internal/awsclient/config.go` (import + field + constructor line), following the same pattern as the existing clients.

- [ ] **Step 2: Write IAM policy JSON files**

`aws_bedrock_agent_gw/aws/iam/gateway-execution-trust.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "bedrock.amazonaws.com"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "aws:SourceAccount": "${ACCOUNT_ID}"
      }
    }
  }]
}
```

`aws_bedrock_agent_gw/aws/iam/gateway-execution-permissions.json`:
```json
{
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
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:*:log-group:/aws/bedrock/*"
    }
  ]
}
```

`aws_bedrock_agent_gw/aws/iam/lambda-execution-trust.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
```

`aws_bedrock_agent_gw/aws/iam/lambda-execution-permissions.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource": "arn:aws:logs:us-east-1:*:log-group:/aws/lambda/bgw-*"
  }]
}
```

- [ ] **Step 3: Write the IAM setup program**

`aws_bedrock_agent_gw/labs-go/cmd/day01-iam/main.go`:
```go
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
```

- [ ] **Step 4: Run and verify**

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
cd aws_bedrock_agent_gw/labs-go
go run cmd/day01-iam/main.go
```

Expected output:
```
Waiting 10s for IAM propagation of bgw-gateway-execution-role...
Gateway execution role ARN: arn:aws:iam::123456789012:role/bgw-gateway-execution-role
Waiting 10s for IAM propagation of bgw-lambda-execution-role...
Lambda execution role ARN: arn:aws:iam::123456789012:role/bgw-lambda-execution-role
ARNs written to arns.json
```

Verify with AWS CLI:
```bash
aws iam get-role --role-name bgw-gateway-execution-role --query 'Role.Arn' --output text
aws iam get-role --role-name bgw-lambda-execution-role --query 'Role.Arn' --output text
```

---

### Task 3: Lambda Tool + Gateway Creation + Agent Wiring

**Files:**
- Create: `aws_bedrock_agent_gw/aws/lambda/hr-tool/main.go`
- Create: `aws_bedrock_agent_gw/aws/lambda/hr-tool/go.mod`
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day01-gateway/main.go`

**Interfaces:**
- Consumes: `arns.json` from Task 2 (GatewayExecutionRoleARN, LambdaExecutionRoleARN)
- Produces: working agent invocation that calls a tool via the Gateway; `gateway-ids.json` with GatewayID and AgentID for Task 4

- [ ] **Step 1: Write the Lambda tool function**

This simulates a simple enterprise HR lookup API. It is the "downstream" tool the Gateway will expose.

`aws_bedrock_agent_gw/aws/lambda/hr-tool/go.mod`:
```
module github.com/hunghan/bgw-hr-tool

go 1.22

require github.com/aws/aws-lambda-go v1.47.0
```

`aws_bedrock_agent_gw/aws/lambda/hr-tool/main.go`:
```go
package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/lambda"
)

// MCPToolRequest is the shape AgentCore Gateway sends to a Lambda tool.
// Verify exact field names in Gateway docs during Day 1 primer.
type MCPToolRequest struct {
	ToolName   string          `json:"toolName"`
	Parameters json.RawMessage `json:"parameters"`
}

type MCPToolResponse struct {
	Content []ContentBlock `json:"content"`
}

type ContentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type GetEmployeeParams struct {
	EmployeeID string `json:"employeeId"`
}

type GetDepartmentParams struct {
	Department string `json:"department"`
}

func handler(ctx context.Context, req MCPToolRequest) (MCPToolResponse, error) {
	switch req.ToolName {
	case "getEmployee":
		var p GetEmployeeParams
		if err := json.Unmarshal(req.Parameters, &p); err != nil {
			return errorResponse(fmt.Sprintf("invalid params: %v", err)), nil
		}
		employee := map[string]string{
			"E001": `{"id":"E001","name":"Alice Smith","department":"Engineering","title":"Staff Engineer","email":"alice@example.com"}`,
			"E002": `{"id":"E002","name":"Bob Jones","department":"Finance","title":"Analyst","email":"bob@example.com"}`,
		}
		if rec, ok := employee[p.EmployeeID]; ok {
			return textResponse(rec), nil
		}
		return textResponse(fmt.Sprintf(`{"error":"employee %s not found"}`, p.EmployeeID)), nil

	case "listDepartment":
		var p GetDepartmentParams
		if err := json.Unmarshal(req.Parameters, &p); err != nil {
			return errorResponse(fmt.Sprintf("invalid params: %v", err)), nil
		}
		return textResponse(fmt.Sprintf(`{"department":"%s","headcount":12,"manager":"Carol White"}`, p.Department)), nil

	default:
		return errorResponse(fmt.Sprintf("unknown tool: %s", req.ToolName)), nil
	}
}

func textResponse(text string) MCPToolResponse {
	return MCPToolResponse{Content: []ContentBlock{{Type: "text", Text: text}}}
}

func errorResponse(msg string) MCPToolResponse {
	return MCPToolResponse{Content: []ContentBlock{{Type: "text", Text: `{"error":"` + msg + `"}`}}}
}

func main() {
	lambda.Start(handler)
}
```

- [ ] **Step 2: Build and zip the Lambda**

```bash
cd aws_bedrock_agent_gw/aws/lambda/hr-tool
GOOS=linux GOARCH=amd64 go build -o bootstrap .
zip function.zip bootstrap
```

Expected: `function.zip` created, ~3 MB.

- [ ] **Step 3: Write the Gateway creation + agent wiring program**

`aws_bedrock_agent_gw/labs-go/cmd/day01-gateway/main.go`:
```go
package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	lambdasvc "github.com/aws/aws-sdk-go-v2/service/lambda"
	"github.com/aws/aws-sdk-go-v2/service/lambda/types"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// NOTE: Replace the Gateway SDK calls below with the actual package after
// completing Task 2 Step 1 (package discovery). The pattern shown here
// follows aws-sdk-go-v2 conventions. Exact method names must be verified
// against: go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentcore
//
// Stub types for Gateway operations — replace with real imports after discovery:
// import "github.com/aws/aws-sdk-go-v2/service/bedrockagentcore"

const region = "us-east-1"

type ARNs struct {
	GatewayExecutionRoleARN string `json:"gatewayExecutionRoleARN"`
	LambdaExecutionRoleARN  string `json:"lambdaExecutionRoleARN"`
}

func main() {
	ctx := context.Background()

	// Load ARNs written by day01-iam
	arnsData, err := os.ReadFile("arns.json")
	if err != nil {
		log.Fatalf("read arns.json (run day01-iam first): %v", err)
	}
	var arns ARNs
	if err := json.Unmarshal(arnsData, &arns); err != nil {
		log.Fatalf("parse arns.json: %v", err)
	}

	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	// Step A: Deploy the Lambda tool
	lambdaARN, err := deployLambda(ctx, clients.Lambda, arns.LambdaExecutionRoleARN)
	if err != nil {
		log.Fatalf("deploy lambda: %v", err)
	}
	fmt.Printf("Lambda ARN: %s\n", lambdaARN)

	// Step B: Create the Gateway
	// REPLACE these stub calls with real bedrockagentcore calls after package discovery.
	// Pattern to follow:
	//
	// gatewayClient := bedrockagentcore.NewFromConfig(cfg)
	//
	// createGWOut, err := gatewayClient.CreateGateway(ctx, &bedrockagentcore.CreateGatewayInput{
	//     Name:             aws.String("bgw-day01-gateway"),
	//     ExecutionRoleArn: aws.String(arns.GatewayExecutionRoleARN),
	//     Description:      aws.String("Day 1 learning gateway"),
	// })
	// if err != nil { log.Fatalf("CreateGateway: %v", err) }
	// gatewayID := *createGWOut.GatewayId
	// fmt.Printf("Gateway ID: %s\n", gatewayID)
	//
	// Step C: Register Lambda-backed tool in the Gateway
	//
	// _, err = gatewayClient.CreateGatewayTarget(ctx, &bedrockagentcore.CreateGatewayTargetInput{
	//     GatewayIdentifier: aws.String(gatewayID),
	//     Name:              aws.String("bgw-hr-tool"),
	//     TargetConfiguration: &bedrockagentcore.TargetConfiguration{
	//         Lambda: &bedrockagentcore.LambdaTargetConfig{
	//             LambdaArn: aws.String(lambdaARN),
	//         },
	//     },
	// })
	//
	// Step D: Create a Bedrock Inline Agent pointing at the Gateway
	// (Use bedrockagent.CreateAgent + bedrockagent.PrepareAgent)
	// Wire the gateway endpoint as an action group or MCP server endpoint.
	//
	// Fill in Steps B–D once you have verified the exact API shape.
	// The Lambda is deployed and ready; the IAM trust chain is set up.
	// Everything above this comment is known-good code.

	_ = lambdaARN // remove once gateway steps are filled in
	fmt.Println("Lambda deployed. Complete Steps B-D using the verified SDK package.")
}

func deployLambda(ctx context.Context, client *lambdasvc.Client, executionRoleARN string) (string, error) {
	zipBytes, err := os.ReadFile("../aws/lambda/hr-tool/function.zip")
	if err != nil {
		// Check zip is actually valid
		return "", fmt.Errorf("read function.zip (run build step first): %w", err)
	}
	if err := validateZip(zipBytes); err != nil {
		return "", fmt.Errorf("invalid zip: %w", err)
	}

	out, err := client.CreateFunction(ctx, &lambdasvc.CreateFunctionInput{
		FunctionName: aws.String("bgw-hr-tool"),
		Runtime:      types.RuntimeProvidedal2023,
		Handler:      aws.String("bootstrap"),
		Role:         aws.String(executionRoleARN),
		Code: &types.FunctionCode{
			ZipFile: zipBytes,
		},
		Description: aws.String("AgentCore Gateway mastery — HR tool"),
		Timeout:     aws.Int32(30),
		MemorySize:  aws.Int32(128),
	})
	if err != nil {
		return "", fmt.Errorf("CreateFunction: %w", err)
	}

	// Wait for Lambda to become active
	waiter := lambdasvc.NewFunctionActiveV2Waiter(client)
	if err := waiter.Wait(ctx, &lambdasvc.GetFunctionConfigurationInput{
		FunctionName: aws.String("bgw-hr-tool"),
	}, 2*time.Minute); err != nil {
		return "", fmt.Errorf("lambda activation timeout: %w", err)
	}

	return *out.FunctionArn, nil
}

func validateZip(data []byte) error {
	r, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return err
	}
	for _, f := range r.File {
		if f.Name == "bootstrap" {
			return nil
		}
	}
	return fmt.Errorf("bootstrap binary not found in zip")
}
```

- [ ] **Step 4: Fill in Gateway + Agent steps using verified SDK**

After completing Task 2 Step 1, replace the stub comments in `day01-gateway/main.go` with real `bedrockagentcore` calls for `CreateGateway`, `CreateGatewayTarget`, and agent wiring.

Refer to:
- `go doc github.com/aws/aws-sdk-go-v2/service/bedrockagentcore`
- AWS Bedrock AgentCore developer guide — Gateway section

- [ ] **Step 5: Run end-to-end and verify**

```bash
cd aws_bedrock_agent_gw/labs-go
go run cmd/day01-gateway/main.go
```

Expected: Lambda deployed, Gateway created with one tool, agent successfully invoked and returns an HR lookup result.

Verify Lambda is deployed:
```bash
aws lambda get-function --function-name bgw-hr-tool --query 'Configuration.State'
# Expected: "Active"
```

Verify Gateway exists (adjust CLI command based on Day 1 primer discovery):
```bash
aws bedrock-agentcore list-gateways 2>&1
```

---

### Task 4: Failure Lab + HTTP Tool Extension

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day01-failure-lab/main.go`

**Interfaces:**
- Consumes: running Gateway from Task 3
- Produces: documented understanding of each IAM failure mode; Gateway with 2 tools (Lambda + HTTP)

- [ ] **Step 1: Write the failure lab program**

`aws_bedrock_agent_gw/labs-go/cmd/day01-failure-lab/main.go`:
```go
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
```

- [ ] **Step 2: Run the failure lab — Layer 1**

```bash
go run cmd/day01-failure-lab/main.go break-layer1
# Then invoke the agent (use the invocation command from Task 3 Step 5)
# Open CloudWatch: /aws/bedrock/agents/ log group
# Record the exact error message in your journal
go run cmd/day01-failure-lab/main.go fix-all
# Re-invoke agent to confirm recovery
```

- [ ] **Step 3: Run the failure lab — Layer 2**

```bash
go run cmd/day01-failure-lab/main.go break-layer2
# Invoke agent, read error
# Note: error looks different from Layer 1 — Gateway can't assume the role
go run cmd/day01-failure-lab/main.go fix-all
```

- [ ] **Step 4: Run the failure lab — Layer 3**

```bash
go run cmd/day01-failure-lab/main.go break-layer3
# Invoke agent, read error
# Compare this error vs Layer 2 error — they look similar from agent perspective
# Open BOTH /aws/bedrock/agents/ AND /aws/lambda/ log groups to distinguish them
go run cmd/day01-failure-lab/main.go fix-all
```

- [ ] **Step 5: Add HTTP-backed tool to the Gateway**

Using the verified `bedrockagentcore` SDK from Task 2 Step 1, add a second tool backed by an HTTP endpoint. The endpoint can be a `httptest.Server` for learning purposes:

```go
// In a new file: cmd/day01-http-tool/main.go
// Start a local HTTP server (for local testing) or deploy an API Gateway URL
// Then call CreateGatewayTarget with HTTP target configuration:
//
// _, err = gatewayClient.CreateGatewayTarget(ctx, &bedrockagentcore.CreateGatewayTargetInput{
//     GatewayIdentifier: aws.String(gatewayID),
//     Name:              aws.String("bgw-ticketing-http-tool"),
//     TargetConfiguration: &bedrockagentcore.TargetConfiguration{
//         Http: &bedrockagentcore.HttpTargetConfig{
//             BaseUrl: aws.String("https://your-api-gateway-url/prod"),
//             // Auth is handled by Gateway — see Day 2 for auth config
//         },
//     },
// })
//
// After adding, invoke the agent and ask it to use the ticketing tool.
// Verify both tools appear in the Gateway's tool list.
```

- [ ] **Step 6: Teach-it-back — write the journal entry**

In your journal (`journal.md` in the project root), write:

> "What problem does AgentCore Gateway solve that raw Lambda action groups don't?
> Explain the IAM trust chain. What does each of the 3 failure modes look like and
> how do you distinguish Layer 2 from Layer 3 failures?"

Write this without looking at your notes. If you get stuck, that's the signal to re-read.

- [ ] **Step 7: Day 1 teardown**

```bash
# Delete Lambda
aws lambda delete-function --function-name bgw-hr-tool

# Delete Gateway and its targets (use verified CLI command from Day 1 primer)
aws bedrock-agentcore delete-gateway --gateway-identifier <gateway-id>

# Delete IAM roles and policies
aws iam delete-role-policy --role-name bgw-gateway-execution-role --policy-name bgw-gateway-execution-policy
aws iam delete-role --role-name bgw-gateway-execution-role
aws iam delete-role-policy --role-name bgw-lambda-execution-role --policy-name bgw-lambda-execution-policy
aws iam delete-role --role-name bgw-lambda-execution-role
```

---

## Day 2 — Gateway Intelligence

---

### Task 5: Day 2 Theory — `content/day02.md`

**Files:**
- Create: `aws_bedrock_agent_gw/content/day02.md`

- [ ] **Step 1: Write content/day02.md**

`aws_bedrock_agent_gw/content/day02.md`:
```markdown
# Day 2 — Gateway Intelligence

Read this before the Day 2 labs. Budget: 30 minutes.

---

## 1. OpenAPI Schema Quality = Agent Reasoning Quality

The `description` field in your OpenAPI schema is the only information the
agent uses to decide whether and how to call a tool. The agent never reads
your Lambda code. It reads descriptions.

**Bad description (causes misuse):**
```yaml
/employee:
  get:
    summary: Get employee
    description: Returns employee data.
    parameters:
      - name: id
        description: The ID.
```

**Good description (reliable agent behaviour):**
```yaml
/employee/{employeeId}:
  get:
    summary: Look up a single employee by their unique employee ID
    description: >
      Returns the full employee record including name, department, title,
      and email for the employee matching the given ID. Use this when the
      user asks about a specific person and you have their employee ID.
      Do NOT use this for department-level queries — use /department instead.
    parameters:
      - name: employeeId
        in: path
        description: >
          The unique employee identifier, always in format E followed by
          3 digits (e.g. E001, E042). Never a name — only an ID.
        required: true
```

**Rules:**
1. **Describe the tool's purpose and when to use it** — and when NOT to use it
2. **Describe every parameter precisely** — type, format, valid values, what it represents
3. **Describe what the tool returns** — the agent uses this to parse the response
4. **One tool, one job** — a tool that does multiple things forces the agent to guess

---

## 2. Multi-Agent Tool Sharing Patterns

Gateway is a shared resource. Multiple agents can point at the same Gateway.
This is the key enterprise pattern: centralise tool management, not agent management.

**Supervisor + specialist pattern:**
```
Supervisor Agent
├── calls Gateway → HR tool (get employee, list department)
├── calls Gateway → Ticketing tool (create ticket, get ticket status)
└── delegates sub-tasks to:
    ├── HR Specialist Agent (also uses Gateway)
    └── Ticketing Specialist Agent (also uses Gateway)
```

All agents point at the same Gateway endpoint. Tool updates in the Gateway
propagate to all agents immediately — no agent redeployment needed.

**When to use separate Gateways:**
- Different teams own different tool sets with separate SLAs
- Compliance requires strict tool-set isolation between agent classes
- Otherwise: one Gateway per domain (HR tools, Finance tools, etc.)

---

## 3. Auth Mediation Patterns

The agent should NEVER hold credentials. The Gateway holds them and proxies
all authenticated requests. Three patterns, by credential type:

**Pattern A — IAM (for AWS Lambda tools):**
No explicit credential needed. The Gateway's execution role (`bedrock.amazonaws.com`
trust) invokes Lambda via IAM. This is what Day 1 used.

**Pattern B — API Key (for external REST APIs):**
```
Gateway Target Config:
  credentialProvider:
    type: apiKey
    secretArn: arn:aws:secretsmanager:...:bgw-external-api-key
    headerName: X-API-Key
```
The Gateway reads the API key from Secrets Manager and injects it as a header.
The agent sends the request; the key is added transparently.

**Pattern C — OAuth2 Client Credentials (for enterprise SSO-protected APIs):**
```
Gateway Target Config:
  credentialProvider:
    type: oauth2ClientCredentials
    clientId: ...
    clientSecretArn: arn:aws:secretsmanager:...:bgw-oauth-secret
    tokenUrl: https://sso.corp.example.com/oauth/token
    scopes: [hr:read, hr:list]
```
Gateway obtains a token from the OAuth server before each tool call (or uses
a cached token if still valid). Agent never sees the token.

**The invariant:** agents are credential-free callers. If you find yourself
passing API keys or tokens through the agent's prompt or context, that is a
design error.

---

## 4. Dynamic Tool Discovery

Agents can discover what tools are available at runtime rather than having
them statically defined. Gateway supports this via the MCP `tools/list`
protocol call.

Static wiring: you tell the agent "these are your tools" at creation time.
Dynamic discovery: the agent calls `tools/list` on the Gateway at the start
of each session and builds its tool inventory on the fly.

Dynamic discovery means you can add a new tool to the Gateway today and
existing agents start using it tomorrow — without any agent config change.
This is the preferred enterprise pattern.

---

## 5. Exercise Questions

1. An agent is supposed to use the HR tool but keeps using the ticketing
   tool to look up employees. What is the most likely root cause?
2. Your company adds a new PTO balance API. You want all 8 existing agents
   to be able to call it by end of day, without redeploying any agent. What
   do you do?
3. What is the difference between Pattern B and Pattern C auth mediation?
   When would you choose C over B?
4. Why is dynamic tool discovery the preferred enterprise pattern over
   static tool wiring?
5. A tool description says "Returns employee data." An agent calls it with
   `employeeId: "Alice Smith"` instead of `employeeId: "E001"`. What do
   you fix and where?
```

---

### Task 6: OpenAPI Tool Registration + Dynamic Discovery

**Files:**
- Create: `aws_bedrock_agent_gw/aws/openapi/hr-api-spec.yaml`
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day02-openapi/main.go`

**Interfaces:**
- Consumes: Day 1 IAM setup (re-run `day01-iam` to recreate roles)
- Produces: Gateway with 2 tools registered via OpenAPI spec; working agent that discovers tools dynamically; `gateway-ids-day2.json`

- [ ] **Step 1: Re-create Day 1 IAM**

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
go run cmd/day01-iam/main.go
```

- [ ] **Step 2: Write the OpenAPI spec**

This spec represents an existing enterprise HR REST API. The Gateway will
read this spec and expose each endpoint as a separate MCP tool.

`aws_bedrock_agent_gw/aws/openapi/hr-api-spec.yaml`:
```yaml
openapi: "3.0.3"
info:
  title: Enterprise HR API
  version: "1.0.0"
  description: >
    Internal HR system API. Use getEmployee to look up a specific person by
    their unique employee ID. Use listDepartment to get headcount and manager
    for a department. All employee IDs follow the format E followed by 3 digits.

paths:
  /employee/{employeeId}:
    get:
      operationId: getEmployee
      summary: Look up a single employee by their unique employee ID
      description: >
        Returns name, department, title, and email for the employee matching
        the given ID. Use this when you need information about a specific person
        and you have their ID. Do NOT use for department-level queries.
      parameters:
        - name: employeeId
          in: path
          required: true
          description: >
            Unique employee identifier. Always in format E + 3 digits (e.g. E001).
            This is never a name or email address — only an ID string.
          schema:
            type: string
            pattern: "^E[0-9]{3}$"
            example: "E001"
      responses:
        "200":
          description: Employee record
          content:
            application/json:
              schema:
                type: object
                properties:
                  id:
                    type: string
                    description: Employee ID
                  name:
                    type: string
                    description: Full name
                  department:
                    type: string
                  title:
                    type: string
                  email:
                    type: string
        "404":
          description: Employee not found
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string

  /department/{department}/summary:
    get:
      operationId: listDepartment
      summary: Get headcount and manager for a department
      description: >
        Returns the total number of employees and the manager's name for the
        given department. Use this for department-level questions, not individual
        employee lookups. Department names are case-insensitive.
      parameters:
        - name: department
          in: path
          required: true
          description: >
            Department name, e.g. "Engineering", "Finance", "HR". Case-insensitive.
          schema:
            type: string
            example: "Engineering"
      responses:
        "200":
          description: Department summary
          content:
            application/json:
              schema:
                type: object
                properties:
                  department:
                    type: string
                  headcount:
                    type: integer
                  manager:
                    type: string
```

- [ ] **Step 3: Write the OpenAPI Gateway registration program**

`aws_bedrock_agent_gw/labs-go/cmd/day02-openapi/main.go`:
```go
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
```

- [ ] **Step 4: Run the failure lab — tool description quality**

After the Gateway is running:

1. **Vague description test:** Edit `hr-api-spec.yaml`, change `getEmployee` description to "Returns employee data." Update the Gateway. Ask the agent "Look up Alice Smith" — observe it passing `employeeId: "Alice Smith"` (wrong format).

2. **Precise description test:** Restore the full description. Update the Gateway. Ask the same question — observe the agent correctly responding it needs the employee ID, not the name.

3. Open X-Ray traces for both invocations. Compare the tool call parameters in the trace.

Record both errors and the trace difference in your journal.

- [ ] **Step 5: Verify**

```bash
# List tools in Gateway (use verified CLI command)
aws bedrock-agentcore list-gateway-targets --gateway-identifier <gateway-id>
# Expected: 2 tools (getEmployee, listDepartment)

# Invoke agent: "How many people are in Engineering and who is the manager?"
# Expected: agent calls listDepartment("Engineering"), returns headcount + manager
```

---

### Task 7: Auth Mediation + Multi-Agent Tool Sharing

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day02-auth/main.go`

**Interfaces:**
- Consumes: Gateway from Task 6
- Produces: Gateway with API-key auth configured for a simulated external API; second agent pointing at same Gateway

- [ ] **Step 1: Create a Secrets Manager secret for the API key**

```bash
aws secretsmanager create-secret \
  --name bgw-external-api-key \
  --secret-string '{"apiKey":"test-key-12345"}' \
  --region us-east-1
```

- [ ] **Step 2: Write the auth mediation program**

`aws_bedrock_agent_gw/labs-go/cmd/day02-auth/main.go`:
```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	secretsmanager "github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/hunghan/bedrock-gateway-mastery/internal/awsclient"
)

// This program:
// 1. Adds a ticketing HTTP tool to the existing Gateway with API-key auth mediation
// 2. Creates a second agent that shares the same Gateway as the first agent
// Key insight: both agents get tool updates when the Gateway is updated — zero redeployment

const region = "us-east-1"

func main() {
	ctx := context.Background()
	clients, err := awsclient.New(ctx, region)
	if err != nil {
		log.Fatalf("init clients: %v", err)
	}

	gatewayID := os.Getenv("BGW_GATEWAY_ID")
	if gatewayID == "" {
		log.Fatal("BGW_GATEWAY_ID env var required — set to the Day 2 gateway ID")
	}

	// Step A: Verify the API key secret exists
	smClient := secretsmanager.NewFromConfig(mustLoadConfig(ctx))
	_, err = smClient.DescribeSecret(ctx, &secretsmanager.DescribeSecretInput{
		SecretId: aws.String("bgw-external-api-key"),
	})
	if err != nil {
		log.Fatalf("secret bgw-external-api-key not found: %v", err)
	}
	fmt.Println("Secret bgw-external-api-key confirmed.")

	_ = clients
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
```

- [ ] **Step 3: Run and verify**

```bash
export BGW_GATEWAY_ID=<your-gateway-id>
go run cmd/day02-auth/main.go
```

Verify multi-agent sharing:
```bash
# Invoke agent 1 — "Create a support ticket for employee E001's laptop issue"
# Expected: agent 1 calls ticketing tool with API key injected by Gateway (agent never had it)

# Invoke agent 2 — "List the Engineering department"
# Expected: agent 2 calls HR tool, same Gateway, same tool registry
```

- [ ] **Step 4: Teach-it-back**

Write in journal.md:
> "How do you onboard a new enterprise REST API to the Gateway in under 30 minutes?
> Write the steps: OpenAPI spec → IAM → auth config → Gateway registration → test."

Write it as a runbook your team could follow.

- [ ] **Step 5: Day 2 teardown**

```bash
aws secretsmanager delete-secret --secret-id bgw-external-api-key --force-delete-without-recovery
aws lambda delete-function --function-name bgw-hr-tool
# Delete Gateway, agents, IAM roles using Day 1 teardown commands
```

---

## Day 3 — Production Gateway

---

### Task 8: Day 3 Theory — `content/day03.md`

**Files:**
- Create: `aws_bedrock_agent_gw/content/day03.md`

- [ ] **Step 1: Write content/day03.md**

`aws_bedrock_agent_gw/content/day03.md`:
```markdown
# Day 3 — Production Gateway

Read this before the Day 3 labs. Budget: 30 minutes.

---

## 1. Bedrock Guardrails

Guardrails are content filters applied to model inputs and outputs (and tool
outputs). They enforce compliance requirements before results reach the agent's
reasoning layer.

**Guardrail types:**

| Type | What it blocks/redacts | When to use |
|------|------------------------|-------------|
| Content filter | Violence, hate, sexual, self-harm content | All production deployments |
| PII redaction | Names, emails, phone numbers, SSN, addresses | Any tool that returns user data |
| Topic denial | Custom topics (e.g. "competitor products") | Brand/legal compliance |
| Word filter | Specific prohibited words | Compliance, profanity filtering |
| Grounding check | Hallucinations in tool-grounded responses | High-stakes outputs |

**Guardrails on tool outputs:**
When a tool returns data containing PII, guardrails redact it BEFORE the agent
reasons over it. This means the agent's reasoning trace is also PII-free —
important for audit logs.

```
Tool returns: {"name":"Alice Smith","email":"alice@example.com","salary":95000}
After PII guardrail: {"name":"[REDACTED]","email":"[REDACTED]","salary":95000}
Agent reasons over redacted version.
```

**IAM for guardrails:**
The entity applying the guardrail (agent or Gateway) must have `bedrock:ApplyGuardrail`
permission. This is already in the `bgw-gateway-execution-permissions.json` from Day 1.

---

## 2. X-Ray Tracing for Agent + Gateway Flows

X-Ray traces an agent invocation as a tree of spans:

```
Agent Invocation [root span]
├── Model invocation (reasoning step 1)
├── Tool call: getEmployee [child span]
│   ├── Gateway processing
│   ├── Lambda invocation [child span]
│   │   └── Lambda execution
│   └── Guardrail application [child span]
├── Model invocation (reasoning step 2)
└── Final response generation
```

**What to look for in traces:**
- **Latency hotspots:** which span takes longest? Lambda cold start? Model reasoning?
- **Tool call frequency:** is the agent calling the same tool multiple times? (Possible
  prompt engineering issue)
- **Guardrail hits:** what percentage of tool responses trigger PII redaction?
- **Error spans:** red spans indicate failures — click through to see the error message

**Enabling tracing:**
- On Bedrock Agents: set `enableTrace: true` in InvokeAgent request
- On Gateway: enabled by default when X-Ray is enabled for the account
- Requires IAM permission: `xray:PutTraceSegments`, `xray:PutTelemetryRecords`

**Key insight:** You cannot debug agent reasoning failures without traces. The agent's
reasoning steps are only visible in the trace — they don't appear in CloudWatch logs.

---

## 3. Rate Limiting and Throttling

**Two throttling layers:**

1. **Bedrock service limits:** requests-per-minute and tokens-per-minute per model,
   per region, per account. These are hard limits. Check current limits:
   `aws bedrock list-foundation-models` (limits shown separately in Service Quotas).

2. **Gateway-level throttling:** you set per-gateway and per-tool limits to protect
   downstream APIs from agent-driven traffic spikes.

**What happens when throttled:**
- Agent receives a `ThrottlingException` from Bedrock
- Agent reasoning loop retries (if retry is configured)
- If retries exhausted: agent returns "I was unable to complete this request due
  to service limits"

**Throttle error diagnosis in traces:**
Look for spans with `ThrottlingException`. The parent span tells you which layer
throttled: Bedrock model? Gateway? Downstream Lambda?

**Circuit breaker pattern:**
For production, configure Gateway to stop calling a downstream API if error rate
exceeds threshold (e.g. >50% failures in 60s). Protects downstream APIs from
cascading agent retry storms.

---

## 4. Production Deployment Checklist

Before going live with a Gateway-backed agent system:

- [ ] All IAM roles use least-privilege (specific ARNs, not `*` resources)
- [ ] Guardrails enabled for PII at minimum on all tools returning user data
- [ ] X-Ray tracing enabled on agents and Gateway
- [ ] CloudWatch alarms on: tool error rate, agent invocation latency P99, throttle rate
- [ ] Gateway throttling configured per-tool to protect downstream APIs
- [ ] All AWS resources tagged with `project`, `environment`, `team`
- [ ] Secrets in Secrets Manager (no credentials in environment variables or code)
- [ ] Bedrock model access requested and approved for the region
- [ ] Cost alert configured (Bedrock costs spike quickly under load)

---

## 5. Exercise Questions

1. An audit team asks: "Show me every employee record that was accessed by AI agents
   this month, with PII removed." What AWS services give you this, and what do you
   query?
2. Your agent is calling the HR tool 6 times per session instead of once. How do
   you diagnose this and what likely caused it?
3. A downstream API is returning errors 80% of the time due to a bug in a new
   deployment. Your agents are retrying aggressively, making the situation worse.
   What Gateway feature prevents this?
4. Why does enabling guardrails on tool OUTPUT matter more than enabling it on
   model OUTPUT for PII compliance?
5. You want to set a CloudWatch alarm that fires when the agent P99 latency exceeds
   5 seconds. Which X-Ray metric do you use?
```

---

### Task 9: Guardrails + X-Ray Tracing + Rate Limiting

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day03-production/main.go`

**Interfaces:**
- Consumes: re-created Day 2 Gateway + IAM from Tasks 2, 6
- Produces: production-hardened Gateway with guardrail, tracing, throttling; `production-ids.json`

- [ ] **Step 1: Create a Bedrock Guardrail**

```go
// In day03-production/main.go:
//
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
```

- [ ] **Step 2: Apply guardrail to the Gateway**

```go
// When creating/updating the Gateway, attach the guardrail:
//
// gatewayClient.UpdateGateway(ctx, &bedrockagentcore.UpdateGatewayInput{
//     GatewayIdentifier: aws.String(gatewayID),
//     GuardrailConfiguration: &bedrockagentcore.GuardrailConfiguration{
//         GuardrailId:      guardrailOut.GuardrailId,
//         GuardrailVersion: versionOut.Version,
//     },
// })
```

- [ ] **Step 3: Enable X-Ray tracing on the agent**

When invoking the agent, pass `enableTrace: true`:

```go
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
```

- [ ] **Step 4: Add Gateway throttling**

```go
// When creating the Gateway target, set throttling config:
//
// bedrockagentcore.CreateGatewayTargetInput{
//     ...
//     ThrottlingConfiguration: &bedrockagentcore.ThrottlingConfiguration{
//         RateLimit:   aws.Int32(10),  // max 10 calls/second to this tool
//         BurstLimit:  aws.Int32(20),  // burst up to 20
//     },
// }
```

- [ ] **Step 5: Write and run the full Day 3 production program**

`aws_bedrock_agent_gw/labs-go/cmd/day03-production/main.go`:
```go
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
```

- [ ] **Step 6: Invoke and verify guardrail + traces**

```bash
go run cmd/day03-production/main.go
```

Ask the agent: "Tell me everything about employee E001."

Expected:
- Response contains `[REDACTED]` for name and email fields (PII guardrail applied)
- X-Ray trace shows: model invocation → tool call → guardrail application span

View traces:
```bash
aws xray get-service-graph --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s) --region us-east-1
```

---

### Task 10: Failure Lab — Throttle, PII, Timeout

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day03-failure-lab/main.go`

**Interfaces:**
- Consumes: production Gateway from Task 9

- [ ] **Step 1: Write the Day 3 failure lab**

`aws_bedrock_agent_gw/labs-go/cmd/day03-failure-lab/main.go`:
```go
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
```

- [ ] **Step 2: Run throttle test**

```bash
export BGW_AGENT_ID=<your-agent-id>
export BGW_AGENT_ALIAS_ID=<your-alias-id>
go run cmd/day03-failure-lab/main.go throttle
```

Open X-Ray console → find throttled spans → note the error shape.

- [ ] **Step 3: Run PII test**

```bash
go run cmd/day03-failure-lab/main.go pii
```

Verify `[REDACTED]` in response. Check X-Ray trace for guardrail span.

---

### Task 11: Closed-Book Rebuild

**Files:**
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day03-rebuild/scenario.md`
- Create: `aws_bedrock_agent_gw/labs-go/cmd/day03-rebuild/main.go` (blank template)

**Interfaces:**
- Consumes: 3 days of knowledge — no notes allowed
- Produces: complete working Gateway + agent for the enterprise scenario, built in ≤2 hours

- [ ] **Step 1: Read the scenario (then put everything away)**

`aws_bedrock_agent_gw/labs-go/cmd/day03-rebuild/scenario.md`:
```markdown
# Closed-Book Rebuild Scenario

**Time limit:** 2 hours. No notes, no prior code, no spec.

## What you are building

An enterprise HR + ticketing agent powered by AgentCore Gateway.

**Requirements:**
1. A Gateway with 2 tools:
   - HR tool: employee lookup (Lambda-backed, by employee ID)
   - Ticketing tool: create and query support tickets (HTTP-backed)
2. Agents never hold credentials — Gateway mediates all auth
3. HR tool responses must have PII redacted (name, email) via guardrail
4. X-Ray tracing enabled — every invocation must be traceable
5. Both tools have rate limiting: max 5 req/s each
6. At least 2 Bedrock agents share the same Gateway
7. All resources tagged `project=bgw-rebuild`, `environment=lab`
8. All provisioning via Go SDK — no console

**Success criteria:**
- Ask agent 1: "What is the department of employee E001?" → correct answer, PII redacted in trace
- Ask agent 2: "Create a ticket for employee E002's laptop issue" → ticket created, no credentials in agent context
- Update the HR tool's rate limit to 10 req/s → both agents see the change immediately
- Tear down all resources in one pass

## Start

Open `main.go`, start the timer, build from memory.
```

- [ ] **Step 2: Write the blank template**

`aws_bedrock_agent_gw/labs-go/cmd/day03-rebuild/main.go`:
```go
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
```

- [ ] **Step 3: Execute the rebuild**

Start the timer. Build the complete system. Verify all 4 success criteria before stopping.

- [ ] **Step 4: Teach-it-back — final journal entry**

Write in `journal.md`:
> "3 Gateway design decisions every enterprise architect needs to make before day 1:
> 1. [Your answer]
> 2. [Your answer]
> 3. [Your answer]"

Write this from what you've learned, not from the content files.

- [ ] **Step 5: Final teardown**

```bash
# Delete all bgw- tagged resources in one sweep:
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=project,Values=bgw-mastery Key=project,Values=bgw-rebuild \
  --region us-east-1 \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text | tr '\t' '\n' | while read arn; do
    echo "Deleting: $arn"
    # Match ARN prefix to service and delete accordingly
    # Lambda: aws lambda delete-function --function-name <name>
    # IAM role: aws iam delete-role --role-name <name> (after detaching policies)
    # Gateway: aws bedrock-agentcore delete-gateway --gateway-identifier <id>
    # Bedrock agent: aws bedrock-agent delete-agent --agent-id <id>
    # Guardrail: aws bedrock delete-guardrail --guardrail-identifier <id>
    # Secret: aws secretsmanager delete-secret --secret-id <id> --force-delete-without-recovery
done
```

---

## Journal Prompts (Teach-It-Back Reference)

These are the exact questions for each day's teach-it-back. Write them without notes.

| Day | Prompt |
|-----|--------|
| Day 1 | What problem does AgentCore Gateway solve that raw Lambda action groups don't? Explain the 3-layer IAM trust chain and how you distinguish Layer 2 from Layer 3 failures. |
| Day 2 | How do you onboard a new enterprise REST API to the Gateway in under 30 minutes? Write it as a runbook. |
| Day 3 | Name 3 Gateway design decisions every enterprise architect needs to make before day 1, and explain why each matters. |
