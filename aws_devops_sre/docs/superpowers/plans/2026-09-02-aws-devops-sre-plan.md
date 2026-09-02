# AWS DevOps & SRE (CI/CD-First) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This plan authors a learning path, not an application.** Tasks produce Markdown content and Terraform/Go files that the *learner* will run later. Adapted from the standard writing-plans TDD shape per the repo's local `skill.md`: there are **no git steps** and **no `terraform apply` steps** in any task.

**Goal:** Author a complete 5-day, ~17-hour AWS DevOps/SRE learning path organized around the chain-of-custody model, with runnable-but-unrun Terraform labs, a shared Go artifact, and cost guardrails that keep the full week under ~$8.

**Architecture:** One Go service is built once on Day 1 and followed through PRODUCE → PROMOTE → REVERSE → substrate-swap → MEASURE. A zero-cost `labs/foundation/` stack (public-subnet VPC + ECR repo) is stood up on Day 1 and consumed by every subsequent lab through `terraform_remote_state`, so the same artifact really does travel the chain. Each day's lab is otherwise self-contained and fully destroyed at end of session.

**Tech Stack:** Terraform >= 1.5 (AWS provider ~> 5.0), Go 1.23 (arm64, `scratch` images), CodeBuild, CodePipeline V2, CodeConnections→GitHub, ECR, ECS Fargate, CodeDeploy, ALB, CloudWatch (alarms/logs/Synthetics), X-Ray, GitHub Actions + OIDC, `kind` + `kubectl`.

**Spec:** `aws_devops_sre/docs/superpowers/specs/2026-09-02-aws-devops-sre-design.md`

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec.

**Cost rules (binding on every lab):**
- **Zero NAT gateways, path-wide.** Fargate tasks run in public subnets with `assign_public_ip = true`. No VPC-attached CodeBuild.
- **ALB exists only in Day 3 and Day 5 labs.** Destroyed in teardown, verified by CLI check.
- **No EKS control plane.** Day 4 uses local `kind`. `labs/day04/eks/` Terraform is authored and explicitly marked never-applied.
- All CloudWatch log groups set to **1-day retention** (`retention_in_days = 1`).
- CodeBuild uses **`ARM_CONTAINER` / `BUILD_GENERAL1_SMALL`** (or Lambda compute where taught).
- Fargate tasks are **0.25 vCPU / 0.5 GB** (`cpu = "256"`, `memory = "512"`), `runtime_platform` arm64.
- Default region **us-east-1**.

**Authoring rules:**
- **No git commands in any task or dispatch** — no `git add`, `git commit`, `git push`, `git status`, `git log`, `git diff`. The learner owns all VCS.
- **Labs are authored, not run.** No `terraform apply`, no `terraform init`, no AWS CLI calls against real infrastructure, no `kind create cluster`, no `docker build`.
- **No real secrets, keys, tokens, account IDs, or GitHub usernames** in any file. Use placeholders (`<YOUR_GITHUB_USERNAME>`, `<YOUR_CONNECTION_ARN>`, `123456789012`) with fill-in comments. Ship `terraform.tfvars.example`, never `terraform.tfvars`.
- **CodeCommit must not appear** as a recommended option anywhere except in a "why this is unavailable to you" note.
- **Every exercise ships a hint AND a solution sketch.** No bare problems. 4 exercises per day file.
- **Every lab ships** `README.md` + `SOLUTION.md` + `teardown.md`.
- Terraform files must pass `terraform fmt -check` (offline, safe to run).

**Shared naming and interface conventions (all labs):**
- Every lab's `variables.tf` declares `aws_region` (default `"us-east-1"`) and `name_prefix` (default `"awsdevops"`).
- Resource names are `"${var.name_prefix}-<purpose>"`.
- Day labs read the foundation stack via:
  ```hcl
  data "terraform_remote_state" "foundation" {
    backend = "local"
    config  = { path = "../foundation/terraform.tfstate" }
  }
  ```

## Project Layout (target end state)

```
aws_devops_sre/
├── README.md                      Task 1
├── STRATEGY.md                    Task 1
├── COST.md                        Task 2
├── content/
│   ├── GLOSSARY.md                Task 5
│   ├── day01.md                   Task 6
│   ├── day02.md                   Task 7
│   ├── day03.md                   Task 8
│   ├── day04.md                   Task 9
│   └── day05.md                   Task 10
├── app/
│   ├── main.go                    Task 3
│   ├── go.mod                     Task 3
│   ├── Dockerfile                 Task 3
│   └── README.md                  Task 3
├── labs/
│   ├── verify-teardown.sh         Task 2
│   ├── day00/README.md            Task 2
│   ├── foundation/                Task 4   (VPC + ECR; $0/mo; lives all week)
│   │   ├── main.tf  variables.tf  outputs.tf
│   │   ├── terraform.tfvars.example  README.md  teardown.md
│   ├── day01/                     Task 6   CodeBuild + ECR policies
│   ├── day02/                     Task 7   CodePipeline V2 + GH Actions OIDC
│   ├── day03/                     Task 8   ECS Fargate + ALB + CodeDeploy blue/green
│   ├── day04/                     Task 9   kind manifests + eks/ (never applied)
│   └── day05/                     Task 10  Synthetics + composite alarms + capstone
└── docs/superpowers/
    ├── specs/2026-09-02-aws-devops-sre-design.md   (exists)
    └── plans/2026-09-02-aws-devops-sre-plan.md     (this file)
```

**Task dependency order:** 1 → 2 → 3 → 4 → 5 → then 6, 7, 8, 9, 10 (6–10 may run in parallel; all consume Task 3 and Task 4 interfaces) → 11.

---

### Task 1: Path scaffold and navigation

**Files:**
- Create: `aws_devops_sre/README.md`
- Create: `aws_devops_sre/STRATEGY.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the day index table and chain-link vocabulary (`PRODUCE`, `PROVE`, `PROMOTE`, `REVERSE`, `MEASURE`) that every `content/dayNN.md` header reuses verbatim.

- [ ] **Step 1: Write `README.md`**

Match the tone and structure of `aws_system_integrations/README.md` (read it first). Required sections, in order:
1. **Title + one-paragraph framing** — "5-day CI/CD-first DevOps/SRE path. A pipeline is a chain of custody for an artifact." State: ~3–4 h/day, ~17h scheduled, plus ~30 min Day 0.
2. **Prerequisites** — personal AWS account; GitHub account; Terraform >= 1.5; AWS CLI v2; Docker; `kind` + `kubectl` (Day 4 only); Go 1.23. One line stating this path assumes VPC/IAM/ALB fundamentals and points at the sibling `aws_network_components/` and `aws_security_components/` paths.
3. **Start here: Day 0** — link `labs/day00/README.md`, state it takes ~30 min and MUST be done before Day 1 because it sets the budget alarm.
4. **How to use this path** — read `content/dayNN.md` first, then `labs/dayNN/`. State the daily loop: *read → build → break → fix → tear down*.
5. **Day index table** with columns `Day | Chain link | Title | What you can do after | ~Cost`:
   | 1 | PRODUCE | What exactly is the artifact? | Answer "what code is in prod right now?" | ~$0.20 |
   | 2 | PROMOTE | The pipeline is a promotion machine | Scope a GitHub OIDC trust policy correctly | ~$0.30 |
   | 3 | REVERSE | Promotion is only safe if reversible | Ship a blue/green deploy with alarm rollback | ~$1.50 |
   | 4 | (substrate) | Same chain, different substrate | Map the chain onto Kubernetes | $0.00 |
   | 5 | MEASURE | Close the loop | Define SLOs and measure DORA from your pipeline | ~$1.50 |
6. **The foundation stack** — explain `labs/foundation/` is created once on Day 1, costs ~$0/month, and is destroyed after Day 5.
7. **Cost note** — 3 sentences, link `COST.md`, state the whole week is ~$0.74 with teardown (revised down from an earlier ~$3–8 estimate after per-lab costs were recomputed at the arm64 Fargate rate) and name the three traps (NAT gateway, idle ALB, EKS control plane).
8. **Scope boundary** — one short paragraph stating Day 4 makes you *conversant* in Kubernetes, not competent, and that deep EKS is a separate future path.

- [ ] **Step 2: Write `STRATEGY.md`**

Match `aws_system_integrations/STRATEGY.md` in tone and length (~120 lines). Required sections:
1. **"The core mental model: a pipeline is a chain of custody"** — the 5-link table from the spec (link / question it answers / AWS service that owns it), then the paragraph on why design questions become derivable rather than memorized, using the "should we rebuild per environment?" example worked through in one breath.
2. **"Why PROVE has no day of its own"** — 3 sentences, per spec.
3. **"The daily loop"** — numbered 6 steps: name the link → state what this stage proves → map it to AWS → wire it → break it → measure the blast radius.
4. **"What the 80% waste time on"** — reproduce the spec's 9-row trap table verbatim (service-first learning; CodeCommit tutorials; `:latest`; rebuild-per-environment; long-lived CI keys; happy-path labs; rollback as afterthought; EKS before delivery; ignoring cost).
5. **"What the top 1% do differently"** — the spec's 6 bullets.
6. **"The one question that separates levels"** — short closing section: juniors answer *"how do I configure X?"*, seniors answer *"what does this stage prove, and what happens when it's unavailable?"*

- [ ] **Step 3: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre
test -f README.md && test -f STRATEGY.md
grep -c "CodeCommit" README.md STRATEGY.md   # STRATEGY.md must be 1 (the trap row); README.md 0
grep -n "PRODUCE\|PROMOTE\|REVERSE\|MEASURE" README.md | head
```
Expected: both files exist; the day index table has 5 rows; no account IDs (`grep -E '[0-9]{12}'` returns nothing).

---

### Task 2: Cost safety net

**Files:**
- Create: `aws_devops_sre/COST.md`
- Create: `aws_devops_sre/labs/day00/README.md`
- Create: `aws_devops_sre/labs/verify-teardown.sh`

**Interfaces:**
- Consumes: Task 1's day index (cost column must agree).
- Produces: `labs/verify-teardown.sh` — every `labs/dayNN/teardown.md` ends by invoking it. Produces the Day 0 pre-flight checklist that `README.md` links.

- [ ] **Step 1: Write `COST.md`**

Required sections:
1. **"Read this before Day 1"** — the $10 budget alarm is non-negotiable; the alarm is what makes the rest of the path safe to experiment in.
2. **"The three traps"** — the spec's binding-rules table (NAT gateway ~$0.045/h; idle ALB ~$0.0225/h; EKS control plane ~$0.10/h), each with the design rule this path adopts in response.
3. **"Reference prices"** — reproduce the spec's full price table (us-east-1), with a bolded caveat that prices change and the learner should sanity-check at Day 0.
4. **"Cost per lab"** — table `Day | Billable resources | Cost while running | Cost if left overnight | Cost after teardown`. Day 3 and Day 5 must show the overnight column as ~$0.55 (ALB-dominated) to make the teardown consequence concrete.
5. **"What stays up all week"** — `labs/foundation/`: VPC + IGW + public subnets ($0) and one ECR repo (~$0.002/mo for a 15 MB image). Explicitly: this is safe to leave running, everything else is not.
6. **"Teardown discipline"** — the rule: `terraform destroy` in the lab dir, then run `verify-teardown.sh`, never trust `destroy`'s exit code alone (it succeeds while leaving resources created outside Terraform, e.g. CodeDeploy-managed task sets and auto-created log groups).
7. **"If you see an unexpected charge"** — Cost Explorer grouped by service, then by usage type; the three usual culprits in order.

- [ ] **Step 2: Write `labs/day00/README.md`**

A ~30-minute checklist, all steps as `- [ ]`:
1. `aws sts get-caller-identity` — confirm the right account.
2. Create a **$10 monthly AWS Budget with email alerts at 50% / 80% / 100%** — give the exact console path AND the equivalent `aws budgets create-budget` command with a `<YOUR_EMAIL>` placeholder and a `budget.json` heredoc using account ID `123456789012` as an obvious placeholder.
3. Set the region and confirm: `aws configure get region`.
4. Create the **CodeConnections → GitHub** connection (console-only handshake; explain *why* it cannot be fully automated — the OAuth handshake requires a browser). Record the ARN. Note it starts life in `PENDING` and must reach `AVAILABLE`.
5. A short note: **CodeCommit is closed to new AWS accounts since July 2024.** If a tutorial starts with `git push codecommit`, stop reading it. This is why the path uses GitHub.
6. Fork/create the learner's own GitHub repo for the sample app; record `<YOUR_GITHUB_USERNAME>/<YOUR_REPO>`.
7. Tool version checks: `terraform version` (>= 1.5), `aws --version` (v2), `docker info`, `kind version`, `go version` (1.23+).
8. Copy `terraform.tfvars.example` → `terraform.tfvars` in `labs/foundation/` and fill it. Note that `terraform.tfvars` must never be committed and add the `.gitignore` line to suggest.

- [ ] **Step 3: Write `labs/verify-teardown.sh`**

A read-only audit script. `#!/usr/bin/env bash`, `set -uo pipefail` (NOT `-e` — it must report all findings, not stop at the first). It must:
- Accept optional `--region` (default `us-east-1`) and `--prefix` (default `awsdevops`).
- Print a clear banner and check, each as a labeled section with ✅/⚠️ output:
  - **NAT gateways** in any state except `deleted` — `aws ec2 describe-nat-gateways` — this is the loudest alarm; any hit prints the hourly burn rate.
  - **Load balancers** — `aws elbv2 describe-load-balancers` filtered by name prefix.
  - **ECS services with `desiredCount > 0`** — `aws ecs list-clusters` → `list-services` → `describe-services`.
  - **Running Fargate tasks** — `aws ecs list-tasks`.
  - **EKS clusters** — `aws eks list-clusters` — should always be empty in this path.
  - **CloudWatch alarms** matching the prefix.
  - **Synthetics canaries** in `RUNNING` state.
  - **CloudWatch log groups** matching the prefix with `retentionInDays == null` (never-expire = a slow leak).
- Explicitly **exclude** the foundation VPC and ECR repo from warnings, printing them under an "expected to still exist" section.
- Exit 0 with a summary line: `N unexpected billable resource(s) found` and a reminder that this script only reads, never deletes.
- Include a comment block at the top stating it makes only read-only AWS API calls.

- [ ] **Step 4: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre
bash -n labs/verify-teardown.sh && echo "syntax ok"
grep -n "delete\|terminate\|destroy\|rm " labs/verify-teardown.sh   # must return nothing: read-only
grep -E '[0-9]{12}' COST.md labs/day00/README.md                     # only 123456789012 placeholder allowed
```
Expected: syntax ok; no mutating verbs in the script; every cost figure in `COST.md` agrees with `README.md`'s day index.

---

### Task 3: The artifact — the Go service followed for five days

**Files:**
- Create: `aws_devops_sre/app/main.go`
- Create: `aws_devops_sre/app/go.mod`
- Create: `aws_devops_sre/app/Dockerfile`
- Create: `aws_devops_sre/app/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces — **every later task depends on these exact names**:
  - Module path: `awsdevops-sample`
  - Env vars read: `PORT` (default `8080`), `POISON` (`"true"` → `/readyz` returns 503), `BURN_RATE` (float `0.0`–`1.0`, fraction of `/burn` requests returning 500)
  - ldflags-injected vars: `main.version`, `main.gitCommit`
  - Routes: `GET /` → 200 JSON `{"service","version","commit","hostname"}`; `GET /healthz` → 200 `ok` (liveness, never fails); `GET /readyz` → 200 `ready` or 503 `poisoned` (readiness); `GET /burn` → 500 `burned` with probability `BURN_RATE`, else 200 `ok`
  - Image: `linux/arm64`, final stage `FROM scratch`, single static binary at `/app`, `ENTRYPOINT ["/app"]`, `EXPOSE 8080`
  - Build args: `VERSION`, `GIT_COMMIT`

- [ ] **Step 1: Write `app/go.mod`**

```
module awsdevops-sample

go 1.23
```

No third-party dependencies — stdlib `net/http` only. This is deliberate and must be stated in `app/README.md`: a dependency-free build keeps CodeBuild caching lessons about *layers and modules* rather than about dependency resolution flakiness.

- [ ] **Step 2: Write `app/main.go`**

Standard library only. Structure:

```go
package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
)

// Injected at build time via -ldflags "-X main.version=... -X main.gitCommit=..."
var (
	version   = "dev"
	gitCommit = "unknown"
)

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	port := env("PORT", "8080")
	poisoned := env("POISON", "false") == "true"
	burnRate, err := strconv.ParseFloat(env("BURN_RATE", "0"), 64)
	if err != nil {
		log.Printf(`{"level":"warn","msg":"invalid BURN_RATE, defaulting to 0","value":%q}`, env("BURN_RATE", "0"))
		burnRate = 0
	}

	hostname, _ := os.Hostname()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"service":  "awsdevops-sample",
			"version":  version,
			"commit":   gitCommit,
			"hostname": hostname,
		})
	})

	// Liveness: is the process up? Never fails on purpose.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Readiness: should this instance receive traffic? The poison switch.
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if poisoned {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("poisoned"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	// Drives ALB 5XX metrics so rollback alarms can be tested deterministically.
	mux.HandleFunc("GET /burn", func(w http.ResponseWriter, r *http.Request) {
		if rand.Float64() < burnRate {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte("burned"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	log.Printf(`{"level":"info","msg":"starting","version":%q,"commit":%q,"port":%q,"poisoned":%t,"burn_rate":%v}`,
		version, gitCommit, port, poisoned, burnRate)

	srv := &http.Server{Addr: ":" + port, Handler: mux}
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf(`{"level":"fatal","msg":%q}`, err.Error())
	}
}
```

Log lines are hand-rolled JSON on purpose — Day 5's structured-logging section refers back to this and asks the learner to critique it.

- [ ] **Step 3: Write `app/Dockerfile`**

```dockerfile
# Stage 1 — build a fully static arm64 binary.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build

ARG VERSION=dev
ARG GIT_COMMIT=unknown

WORKDIR /src
COPY go.mod ./
COPY main.go ./

# CGO off + scratch base = no libc, no shell, no package manager, ~15MB image.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION} -X main.gitCommit=${GIT_COMMIT}" \
      -o /out/app .

# Stage 2 — the artifact.
FROM scratch
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
```

- [ ] **Step 4: Write `app/README.md`**

Cover: what each route is for and which day uses it (`/readyz` → Day 3 poison test and Day 4 readiness-probe test; `/burn` → Day 3 and Day 5 alarm tests); why zero dependencies; why `scratch` (attack surface, pull time, ECR storage — and the tradeoff: no shell means no `docker exec` debugging, which is a real cost the learner should be able to argue about); why arm64 everywhere (CodeBuild ARM is ~30% cheaper, Fargate arm64 is cheaper, Apple Silicon `kind` matches); and the exact local run command:
```bash
go run .                      # then: curl localhost:8080/readyz
POISON=true go run .          # 503
BURN_RATE=0.5 go run .        # ~half of /burn requests 500
```

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/app
gofmt -l .            # must print nothing
go vet ./...          # must pass — local only, no network, no infra
```
Expected: `gofmt` silent, `go vet` clean. Do **not** run `docker build`.

---

### Task 4: Foundation stack (VPC + ECR, ~$0/month, lives all week)

**Files:**
- Create: `aws_devops_sre/labs/foundation/main.tf`
- Create: `aws_devops_sre/labs/foundation/variables.tf`
- Create: `aws_devops_sre/labs/foundation/outputs.tf`
- Create: `aws_devops_sre/labs/foundation/terraform.tfvars.example`
- Create: `aws_devops_sre/labs/foundation/README.md`
- Create: `aws_devops_sre/labs/foundation/teardown.md`

**Interfaces:**
- Consumes: Task 2's `verify-teardown.sh` (referenced from `teardown.md`).
- Produces — **exact output names consumed by Tasks 6–10**:
  - `vpc_id` (string)
  - `public_subnet_ids` (list(string), 2 AZs)
  - `ecr_repository_url` (string)
  - `ecr_repository_arn` (string)
  - `ecr_repository_name` (string)
  - Variables: `aws_region` (default `"us-east-1"`), `name_prefix` (default `"awsdevops"`)

- [ ] **Step 1: Write `variables.tf`**

```hcl
variable "aws_region" {
  description = "AWS region for all resources in this path."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name so teardown verification can find them."
  type        = string
  default     = "awsdevops"
}
```

- [ ] **Step 2: Write `main.tf`**

Required resources — **no NAT gateway, no private subnets, no VPC endpoints**:
- `terraform` block: `required_version = ">= 1.5"`, `required_providers.aws.version = "~> 5.0"`.
- `provider "aws"` with `region = var.aws_region` and `default_tags` applying `{ Project = var.name_prefix, ManagedBy = "terraform", Path = "aws_devops_sre" }` — the tags are what make cost attribution possible in Cost Explorer, and `README.md` must say so.
- `data "aws_availability_zones" "available" { state = "available" }`.
- `aws_vpc` — `cidr_block = "10.42.0.0/16"`, DNS hostnames + support enabled.
- `aws_internet_gateway`.
- Two `aws_subnet` (via `count = 2`) — `10.42.${count.index}.0/24`, `map_public_ip_on_launch = true`, spread across the first two AZs.
- One `aws_route_table` with `0.0.0.0/0` → IGW, plus two `aws_route_table_association`.
- `aws_ecr_repository` — `name = "${var.name_prefix}-sample"`, `image_tag_mutability = "IMMUTABLE"`, `image_scanning_configuration { scan_on_push = true }` (basic scanning, free), `force_delete = true` (so teardown never wedges on stored images — and a comment saying this is a *lab* choice that would be wrong in production).
- `aws_ecr_lifecycle_policy` — keep the 10 most recent images, expire the rest. Include the JSON inline.

Add a header comment block stating: this stack costs approximately **$0/month** (VPC, IGW, subnets, and route tables are free; ECR storage for one ~15 MB image is under a cent) and is intended to stay up for the whole week.

- [ ] **Step 3: Write `outputs.tf`**

```hcl
output "vpc_id" {
  description = "VPC shared by every lab in this path."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnets. Public on purpose: no NAT gateway anywhere in this path."
  value       = aws_subnet.public[*].id
}

output "ecr_repository_url" {
  description = "Push/pull URL for the sample service image."
  value       = aws_ecr_repository.sample.repository_url
}

output "ecr_repository_arn" {
  description = "Used by Day 1 and Day 2 IAM policies."
  value       = aws_ecr_repository.sample.arn
}

output "ecr_repository_name" {
  description = "Used by CodeBuild buildspec and Day 3 task definitions."
  value       = aws_ecr_repository.sample.name
}
```

- [ ] **Step 4: Write `terraform.tfvars.example` and `README.md`**

`terraform.tfvars.example`:
```hcl
# Copy to terraform.tfvars and adjust. NEVER commit terraform.tfvars.
aws_region  = "us-east-1"
name_prefix = "awsdevops"
```

`README.md` must cover: what this stack is and why it exists (the artifact must outlive any single lab, or the chain of custody is a story rather than a fact); the exact run order (`terraform init` → `plan` → `apply`); the ~$0/month cost claim broken down line by line; the explicit statement that **public subnets are a deliberate cost decision, not an oversight** — in production these workloads belong in private subnets behind a NAT gateway or VPC endpoints, and the learner should be able to state what that would cost and what it would buy; and that this stack is destroyed only after Day 5.

- [ ] **Step 5: Write `teardown.md`**

State clearly: **do not destroy this until after Day 5.** Then the end-of-week sequence: `terraform destroy` in `labs/foundation/`, then `bash ../verify-teardown.sh`, then the manual check for any ECR repo or VPC that survived. Note the common failure: `destroy` fails on the VPC because a Day 3 ALB or ENI still exists — the fix is to destroy the day lab first, and this ordering dependency is itself the lesson.

- [ ] **Step 6: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/foundation
terraform fmt -check          # offline; must pass
grep -c "nat_gateway\|aws_nat" main.tf     # must be 0
grep -c "IMMUTABLE" main.tf                # must be 1
test ! -f terraform.tfvars && echo "no real tfvars committed"
```
Expected: fmt clean, zero NAT references, immutable tags on, no `terraform.tfvars` present. Do **not** run `terraform init` or `apply`.

---

### Task 5: Glossary

**Files:**
- Create: `aws_devops_sre/content/GLOSSARY.md`

**Interfaces:**
- Consumes: Task 1's chain-link vocabulary; Task 3's route and env-var names.
- Produces: canonical one-line definitions that day files link to rather than re-defining.

- [ ] **Step 1: Write `GLOSSARY.md`**

Plain-English, one to three sentences each, alphabetical, matching the style of `aws_system_integrations/content/GLOSSARY.md` (read it first). Minimum entries, each stating *what it is* and *why it matters here*:

`Artifact` · `Attestation` · `Bake period` · `Blue/green deployment` · `buildspec` · `Canary (deployment)` · `Canary (synthetic)` · `Chain of custody` · `Change failure rate` · `CodeConnections` · `Composite alarm` · `Deployment circuit breaker` · `DORA metrics` · `Error budget` · `Four golden signals` · `Image digest` · `Image tag immutability` · `IRSA` · `Lead time for changes` · `Liveness probe` · `MTTR` · `OIDC federation` · `Promotion` · `Readiness probe` · `Rolling update` · `Rollback` · `SLI` · `SLO` · `Target group` · `Task definition` · `Task role vs execution role` · `Traffic shifting`

Two entries carry extra weight and must be written with care, because they are the two the learner will most often need to explain to someone else:
- **`Image digest`** — must contrast with tag: a tag is a *label someone can move*; a digest is *the content itself*. Custody is only real when you promote digests.
- **`Task role vs execution role`** — the distinction beginners get wrong: the execution role is what ECS itself uses to *start* your container (pull the image, write logs); the task role is what *your code* uses at runtime. Cross-reference `IRSA` as the Kubernetes analog.

- [ ] **Step 2: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre
grep -c '^## \|^### ' content/GLOSSARY.md    # >= 32 entries
grep -n "Image digest" content/GLOSSARY.md
```

---

### Task 6: Day 1 — PRODUCE (content + lab)

**Files:**
- Create: `aws_devops_sre/content/day01.md`
- Create: `aws_devops_sre/labs/day01/README.md`
- Create: `aws_devops_sre/labs/day01/SOLUTION.md`
- Create: `aws_devops_sre/labs/day01/main.tf`
- Create: `aws_devops_sre/labs/day01/variables.tf`
- Create: `aws_devops_sre/labs/day01/outputs.tf`
- Create: `aws_devops_sre/labs/day01/buildspec.yml`
- Create: `aws_devops_sre/labs/day01/terraform.tfvars.example`
- Create: `aws_devops_sre/labs/day01/teardown.md`

**Interfaces:**
- Consumes: `labs/foundation` outputs `ecr_repository_url`, `ecr_repository_arn`, `ecr_repository_name`; the `app/` build contract from Task 3 (build args `VERSION`, `GIT_COMMIT`; arm64; `scratch`).
- Produces: CodeBuild project named `"${var.name_prefix}-build"`; output `codebuild_project_name`; the `buildspec.yml` that Task 7's pipeline reuses unchanged.

- [ ] **Step 1: Write `content/day01.md`**

Use the Content Day Skeleton from the spec exactly. Header values: chain link `PRODUCE`; time `~3.3h (content ~55m · lab ~115m · break/fix ~20m · teardown ~5m)`; cost `~$0.20`. Question of the day: **"What exactly is the thing we ship, and is it byte-identical every time?"**

`## Core concepts` must cover, in this order:
1. **The artifact is the unit of custody** — why "we deploy the `main` branch" is a category error.
2. **buildspec anatomy** — `version: 0.2`, the `install`/`pre_build`/`build`/`post_build` phases and what each is *conventionally* for versus what actually differs (only `install` gets runtime versions; a non-zero exit anywhere fails the build; `finally` blocks run regardless). State plainly which failures do *not* fail a build by default: a failing command inside a `finally` block, and — the one that bites people — a `docker push` whose output is not checked.
3. **Compute selection** — `BUILD_GENERAL1_SMALL` on `ARM_CONTAINER` vs x86 vs Lambda compute. Give the price delta (~$0.0034 vs ~$0.005 per build-minute) and the two constraints of Lambda compute (15-min cap, no privileged mode → no Docker builds), so the learner can derive when it applies.
4. **Caching** — local caching modes (`LOCAL_SOURCE_CACHE`, `LOCAL_DOCKER_LAYER_CACHE`, `LOCAL_CUSTOM_CACHE`) vs S3 caching, and the honest tradeoff: local cache is free and fast but only hits when CodeBuild reuses a host, so it is best-effort; S3 cache is reliable but costs a download every build. Give the rule: local for layer caching, S3 for dependency caches that must hit.
5. **Privileged mode and Docker-in-CodeBuild** — why it is required to build images, and what it grants.
6. **Artifacts vs reports** — `artifacts:` (files handed to the next stage) vs `reports:` (test results CodeBuild parses and displays). Beginners conflate them.
7. **Two roles, not one** — the CodeBuild service role vs the pipeline role vs the ECR resource policy. State the least-privilege shape: the build role needs `ecr:GetAuthorizationToken` (account-wide, cannot be resource-scoped — explain why) plus push actions scoped to the one repository ARN.
8. **ECR as the custody register** — tag immutability, lifecycle policies, scan-on-push (basic, free) vs enhanced Inspector scanning (~$0.09/image, named but not enabled), and **digests as true identity**.
9. **Secrets** — `env.parameter-store` and `env.secrets-manager` in buildspec vs plaintext `env.variables`; and the leak nobody expects: build logs echo commands, so a secret passed as a CLI argument lands in CloudWatch Logs.

`## Decision rules` table — at least 5 rows, e.g. *"Build needs Docker → privileged mode + ARM_CONTAINER, not Lambda compute, because Lambda compute cannot run a Docker daemon."*

`## Exercises` — exactly 4, each with hint and solution sketch:
1. Given a buildspec that tags `:latest`, rewrite it to tag by immutable digest-friendly identity, and explain what breaks in the deploy stage as a result (answer: the deploy stage can no longer say "latest"; it must be *given* a specific tag — which is the point).
2. Compute the monthly CodeBuild cost for 40 builds/day at 3 min on ARM small vs x86 small. (Hint: ~$0.0034 vs ~$0.005 per minute. Sketch: 40 × 3 × 30 = 3600 build-min/mo → ~$12.24 vs ~$18.00; ~$5.76/mo saved, and the arithmetic matters less than noticing that compute choice is a *pricing* decision.)
3. A build succeeds but the pushed image is missing the version string. Name the three most likely causes. (Sketch: ldflags not passed as `--build-arg`; the `ARG` not declared in the build stage of the Dockerfile; the variable name in `-X main.version` not matching the Go package-level variable.)
4. Write the least-privilege IAM policy statement for the build role's ECR push. (Sketch: two statements — `ecr:GetAuthorizationToken` on `"*"` because it is not resource-scopable, and `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage` scoped to the repository ARN.)

`## Anti-patterns` — 4 bullets, each naming the *failure mode*, not just the rule: `:latest`; per-environment rebuilds; secrets as plaintext env vars; `FROM ubuntu` for a static Go binary.

- [ ] **Step 2: Write `labs/day01/buildspec.yml`**

`version: 0.2`. Phases:
- `env.variables`: `IMAGE_REPO_NAME`, `AWS_DEFAULT_REGION` documented as injected by Terraform.
- `pre_build`: ECR login via `aws ecr get-login-password | docker login --password-stdin` (note in a comment: piping via stdin instead of passing the token as an argument is what keeps it out of the build log), then derive `IMAGE_TAG` from `CODEBUILD_RESOLVED_SOURCE_VERSION` (first 12 chars) — **not** from a branch name.
- `build`: `docker build --build-arg VERSION="$IMAGE_TAG" --build-arg GIT_COMMIT="$CODEBUILD_RESOLVED_SOURCE_VERSION" -t "$REPO_URI:$IMAGE_TAG" app/`
- `post_build`: `docker push`, then capture the pushed digest with `docker inspect --format='{{index .RepoDigests 0}}'` and write `imageDetail.json` — explain in a comment that Day 2's pipeline and Day 3's deploy consume the *digest*, not the tag.
- `artifacts`: `imageDetail.json`.
- `cache`: `LOCAL_DOCKER_LAYER_CACHE` and `LOCAL_SOURCE_CACHE` modes.

- [ ] **Step 3: Write `labs/day01/main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`**

`variables.tf`: `aws_region`, `name_prefix` (per Global Constraints), plus `github_repo_url` (string, no default, described with a `https://github.com/<YOUR_USERNAME>/<YOUR_REPO>` placeholder).

`main.tf` resources:
- The standard `terraform`/`provider` blocks and the `data "terraform_remote_state" "foundation"` block from Global Constraints.
- `aws_iam_role` for CodeBuild with `codebuild.amazonaws.com` trust.
- `aws_iam_role_policy` with three statements: CloudWatch Logs (`CreateLogGroup`/`CreateLogStream`/`PutLogEvents` scoped to the project's log group ARN pattern), `ecr:GetAuthorizationToken` on `"*"` **with an inline comment explaining it cannot be resource-scoped**, and the five ECR push actions scoped to `data.terraform_remote_state.foundation.outputs.ecr_repository_arn`.
- `aws_cloudwatch_log_group` — name `/aws/codebuild/${var.name_prefix}-build`, **`retention_in_days = 1`**.
- `aws_codebuild_project` — `name = "${var.name_prefix}-build"`; `environment` with `compute_type = "BUILD_GENERAL1_SMALL"`, `type = "ARM_CONTAINER"`, `image = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"`, `privileged_mode = true`, and env vars `REPO_URI` / `IMAGE_REPO_NAME` / `AWS_DEFAULT_REGION` sourced from the foundation outputs; `source` of type `GITHUB` with `location = var.github_repo_url` and `buildspec = file("${path.module}/buildspec.yml")`; `cache { type = "LOCAL", modes = [...] }`; `logs_config` pointing at the log group.
- Add a comment block at the top: **no `vpc_config`** — attaching CodeBuild to a VPC would require a NAT gateway for ECR access, which this path forbids.

`outputs.tf`: `codebuild_project_name`, `codebuild_role_arn`, `log_group_name`.

- [ ] **Step 4: Write `labs/day01/README.md` and `SOLUTION.md`**

`README.md`: goal in one line ("produce one immutable, identifiable artifact"); success signal ("an image in ECR whose tag is a commit SHA and which cannot be overwritten"); prerequisites (Day 0 done, foundation applied); numbered run steps (`terraform init/plan/apply`, then `aws codebuild start-build --project-name ...`, then `aws ecr describe-images` to see the tag and digest); then the **Break it** section: attempt `docker push` of a second image under the same tag and observe the `ImageTagAlreadyExistsException`; then disable immutability, push `:latest` twice from two different commits, and attempt to answer "which commit is running?" — the exercise is to notice that the only remaining answer is the digest.

`SOLUTION.md`: expected `aws ecr describe-images` output shape (with placeholder digests), the exact error text for the immutability violation, the answer to the break-it question, and a short "what you should now be able to explain" list mapped to Success Criteria 2, 3, and 12.

- [ ] **Step 5: Write `labs/day01/teardown.md`**

`terraform destroy` in `labs/day01/`; note the CodeBuild log group is Terraform-managed here so it goes with the destroy, but warn that CodeBuild *auto-creates* log groups if the project is run before apply completes, and those are not in state; then `bash ../verify-teardown.sh`. State explicitly: **leave `labs/foundation/` up.** Cost after teardown: $0 (the ECR image is under a cent and stays for Day 2).

- [ ] **Step 6: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/day01
terraform fmt -check
grep -c "vpc_config\|nat_gateway" main.tf        # must be 0
grep -c "retention_in_days" main.tf              # must be >= 1
grep -n "latest" buildspec.yml                   # must return nothing
cd ../../ && grep -c "Hint:" content/day01.md    # must be 4
grep -c "Solution sketch:" content/day01.md      # must be 4
```

---

### Task 7: Day 2 — PROMOTE (content + lab)

**Files:**
- Create: `aws_devops_sre/content/day02.md`
- Create: `aws_devops_sre/labs/day02/README.md`
- Create: `aws_devops_sre/labs/day02/SOLUTION.md`
- Create: `aws_devops_sre/labs/day02/main.tf`
- Create: `aws_devops_sre/labs/day02/variables.tf`
- Create: `aws_devops_sre/labs/day02/outputs.tf`
- Create: `aws_devops_sre/labs/day02/oidc.tf`
- Create: `aws_devops_sre/labs/day02/github-actions-workflow.yml.example`
- Create: `aws_devops_sre/labs/day02/terraform.tfvars.example`
- Create: `aws_devops_sre/labs/day02/teardown.md`

**Interfaces:**
- Consumes: foundation outputs; Day 1's `codebuild_project_name` and `buildspec.yml` (reused unchanged — reuse *is* the lesson).
- Produces: `pipeline_name`, `artifact_bucket_name`, `github_oidc_role_arn`.

- [ ] **Step 1: Write `content/day02.md`**

Header: chain link `PROMOTE`; time `~3.4h (content ~60m · lab ~120m · break/fix ~20m · teardown ~5m)`; cost `~$0.30`. Question of the day: **"How does an artifact cross an environment boundary without changing?"**

`## Core concepts`:
1. **A stage is a claim, not a script** — for each stage ask "what does this prove?" and delete stages that prove nothing.
2. **CodePipeline V2 anatomy** — stages, actions, `runOrder` for parallel vs sequential, the S3 artifact store and what actually moves between stages (a zip in S3, not a Docker image — a distinction that explains a lot of confusing behavior).
3. **Source via CodeConnections** — branch and file-path trigger filters, and the note that **CodeCommit is closed to new accounts since July 2024**, framed as the reason this path uses GitHub.
4. **V1 vs V2 pricing** — V1 is ~$1/month per active pipeline; V2 is ~$0.002/action-minute with 100 free action-minutes monthly. Give the crossover so the learner can derive which is cheaper for their own usage, and note V2 is required for the trigger filters used here.
5. **Promotion without rebuilding** — the central mechanic: the build stage emits `imageDetail.json` containing a *digest*, and every downstream stage consumes that digest. Say directly: if your deploy stage names a tag rather than a digest, you have a promotion machine that can silently ship something you never tested.
6. **Manual approval gates** — what makes an approval meaningful (it must name the artifact and link the evidence) versus theater.
7. **Where configuration lives** — introduce, then defer the detail to Day 3.
8. **GitHub Actions + OIDC** — the trust chain end to end: GitHub issues a short-lived OIDC token → AWS STS validates it against the IAM OIDC provider → `AssumeRoleWithWebIdentity` returns temporary credentials. Emphasize: **no long-lived keys anywhere**. Then the `sub` claim, in detail, with the exact string forms `repo:OWNER/REPO:ref:refs/heads/main` versus the dangerous `repo:OWNER/REPO:*` versus the catastrophic `*`. Include the correct condition block using `StringEquals` on `token.actions.githubusercontent.com:sub`, and explain why `StringLike` with a wildcard is where people get burned.
9. **Choosing between them** — a decision rule, not a preference: CodePipeline when approvals, cross-account promotion, and AWS-native artifact custody matter; GitHub Actions when build ergonomics, matrix builds, and PR feedback matter; and the common real answer — GitHub Actions builds and pushes, CodePipeline or CodeDeploy promotes.

`## Decision rules` — at least 5 rows.

`## Exercises` — exactly 4, hint + solution sketch each:
1. Write the OIDC trust policy condition that allows exactly one repo's `main` branch. (Sketch: `StringEquals` with `"token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:ref:refs/heads/main"` plus `"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"`.)
2. Given `"sub": "repo:OWNER/REPO:*"` with `StringLike`, name three things an attacker who can open a PR could now do. (Sketch: pull_request workflows and arbitrary branches match the wildcard, so any contributor who can create a branch or PR in that repo can assume the role; the fix is pinning the ref, and using `environment:` claims for prod.)
3. A pipeline redeploys yesterday's execution and ships different code than it did yesterday. Explain how. (Sketch: the deploy stage resolves a mutable tag at deploy time rather than consuming the digest recorded at build time.)
4. Compute CodePipeline V2 cost for 3 executions/day, 4 actions each, ~2 action-minutes per action. (Sketch: 3 × 4 × 2 = 24 action-min/day → ~720/month; minus 100 free → 620 × $0.002 ≈ $1.24/month; then compare with V1's flat ~$1/pipeline-month and notice the answer depends entirely on execution frequency.)

`## Anti-patterns` — 4 bullets: rebuilding per environment; config baked into images; static access keys in CI; approval gates that approve nothing specific.

- [ ] **Step 2: Write `labs/day02/main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`**

`variables.tf`: `aws_region`, `name_prefix`, `codeconnection_arn` (no default; described with a `arn:aws:codeconnections:us-east-1:123456789012:connection/<UUID>` placeholder and a pointer to Day 0), `github_owner`, `github_repo`, `github_branch` (default `"main"`).

`main.tf`:
- Standard `terraform`/`provider`/`data "terraform_remote_state" "foundation"` blocks.
- `data "terraform_remote_state" "day01"` reading `../day01/terraform.tfstate` — to consume `codebuild_project_name`. Add a comment: reusing Day 1's build project rather than declaring a second one is itself the "build once" principle applied to the lab.
- `aws_s3_bucket` for pipeline artifacts + `aws_s3_bucket_public_access_block` (all four settings `true`) + `aws_s3_bucket_server_side_encryption_configuration` (AES256) + `aws_s3_bucket_lifecycle_configuration` expiring objects after 7 days (cost hygiene, and a comment saying so). Bucket name uses `random_id` or `data.aws_caller_identity.current.account_id` suffix for global uniqueness — use the account-id suffix and note the account ID is not a secret but should still not be hardcoded in the file.
- `aws_iam_role` + `aws_iam_role_policy` for CodePipeline: S3 artifact bucket access scoped to that bucket ARN, `codebuild:StartBuild`/`BatchGetBuilds` scoped to the Day 1 project ARN, `codestar-connections:UseConnection` (note: the IAM action prefix is still `codestar-connections` even though the service is now CodeConnections — a genuine trip hazard worth calling out in a comment) scoped to `var.codeconnection_arn`.
- `aws_codepipeline` with `pipeline_type = "V2"` and four stages: `Source` (CodeStarSourceConnection, `FullRepositoryId = "${var.github_owner}/${var.github_repo}"`, `BranchName`, `DetectChanges = true`), `Build` (CodeBuild, consuming the source artifact, producing `BuildOutput`), `DeployStaging` (a CodeBuild action running a placeholder deploy script — with a comment that Day 3 replaces this with real CodeDeploy), `Approval` (manual approval with `CustomData` naming the artifact digest), `DeployProd` (placeholder, same shape).
- A `trigger` block filtering on branch and on `app/**` file paths, with a comment explaining V2-only.

`outputs.tf`: `pipeline_name`, `artifact_bucket_name`, `github_oidc_role_arn`.

- [ ] **Step 3: Write `labs/day02/oidc.tf`**

- `aws_iam_openid_connect_provider` for `https://token.actions.githubusercontent.com`, `client_id_list = ["sts.amazonaws.com"]`. Include a comment noting that the `thumbprint_list` requirement was relaxed by AWS for this well-known provider but the argument may still be required by the provider version — supply the documented thumbprint with a comment saying to verify it rather than trust a copy-pasted value.
- `aws_iam_role` `"${var.name_prefix}-gha-oidc"` whose assume-role policy uses `AssumeRoleWithWebIdentity` with **`StringEquals`** on both `:aud` (`sts.amazonaws.com`) and `:sub` (`repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}`).
- Immediately below, a **large commented-out block** showing the two dangerous variants (`StringLike` + `:*`, and a missing `:aud` condition) labeled `# DO NOT USE — this is the Break-it exercise`. The learner uncomments it deliberately in the lab.
- A minimal permissions policy on the role: ECR push to the foundation repo ARN only.

- [ ] **Step 4: Write `labs/day02/github-actions-workflow.yml.example`**

A complete workflow: `on.push.branches: [main]`, top-level `permissions: { id-token: write, contents: read }` (with a comment that `id-token: write` is what makes OIDC work and is the single most commonly omitted line), a job using `aws-actions/configure-aws-credentials@v4` with `role-to-assume: <YOUR_GHA_OIDC_ROLE_ARN>` and `aws-region`, then `aws-actions/amazon-ecr-login@v2`, then the same `docker build`/`push` commands as the buildspec — so the learner can see the two systems doing identical work through different trust models. Header comment: copy to `.github/workflows/build.yml` in **your own** repo; never commit a real role ARN to a public repo without understanding the trust policy first.

- [ ] **Step 5: Write `labs/day02/README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: goal, success signal ("one digest travels from source to prod-approval without a rebuild"), run steps, then **Break it**: swap the trust policy for the commented-out wildcard version, `terraform apply`, then reason about (do not perform) what a PR from a fork could now reach; restore, re-apply, and write one sentence on what the wildcard granted.

`SOLUTION.md`: the correct trust policy JSON in full; the enumerated blast radius of the wildcard version; the digest-vs-tag answer; expected `aws codepipeline get-pipeline-state` output shape.

`teardown.md`: `terraform destroy`; then the two things `destroy` leaves behind — objects in the artifact bucket if versioning was enabled (S3 bucket deletion fails on non-empty buckets; give the `aws s3 rm --recursive` command) and the OIDC provider if another role references it. Then `bash ../verify-teardown.sh`. Leave foundation up.

- [ ] **Step 6: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/day02
terraform fmt -check
grep -c "StringLike" oidc.tf          # must appear ONLY inside the commented DO-NOT-USE block
grep -n "pipeline_type" main.tf       # must be "V2"
grep -c "id-token: write" github-actions-workflow.yml.example   # must be 1
cd ../../ && grep -c "Hint:" content/day02.md && grep -c "Solution sketch:" content/day02.md   # 4 and 4
```

---

### Task 8: Day 3 — REVERSE (content + lab) — the heaviest day

**Files:**
- Create: `aws_devops_sre/content/day03.md`
- Create: `aws_devops_sre/labs/day03/README.md`
- Create: `aws_devops_sre/labs/day03/SOLUTION.md`
- Create: `aws_devops_sre/labs/day03/main.tf`
- Create: `aws_devops_sre/labs/day03/alb.tf`
- Create: `aws_devops_sre/labs/day03/ecs.tf`
- Create: `aws_devops_sre/labs/day03/codedeploy.tf`
- Create: `aws_devops_sre/labs/day03/variables.tf`
- Create: `aws_devops_sre/labs/day03/outputs.tf`
- Create: `aws_devops_sre/labs/day03/appspec.yaml.example`
- Create: `aws_devops_sre/labs/day03/taskdef.json.example`
- Create: `aws_devops_sre/labs/day03/terraform.tfvars.example`
- Create: `aws_devops_sre/labs/day03/teardown.md`

Split across four `.tf` files because this is the largest lab; one file per boundary (network edge / compute / deployment control) keeps each readable.

**Interfaces:**
- Consumes: foundation `vpc_id`, `public_subnet_ids`, `ecr_repository_url`; the app's `/healthz`, `/readyz`, `/burn` routes and `POISON` / `BURN_RATE` env vars from Task 3.
- Produces: `alb_dns_name`, `ecs_cluster_name`, `ecs_service_name`, `codedeploy_app_name`, `codedeploy_group_name`, `rollback_alarm_name` — all consumed by Task 10 (Day 5).

- [ ] **Step 1: Write `content/day03.md`**

Header: chain link `REVERSE`; time `~3.75h (content ~60m · lab ~125m · break/fix ~25m · teardown ~15m)`; cost `~$1.50`. Question of the day: **"How do we undo a promotion, and how long are users hurt before we do?"**

Open `## Why this matters` by naming the learner's context directly: this is the day that maps onto deploying WSO2 components to ECS Fargate, and the mechanics here are the ones that make a Friday deploy survivable.

`## Core concepts`:
1. **Reversibility is a build-time property.** If the artifact is not immutable and digest-addressable, there is nothing to roll back *to*. Explicit callback to Day 1.
2. **Blue/green on ECS** — two target groups, one listener, CodeDeploy shifting traffic between them; the replacement task set; what "green" actually is (a second task set, not a second cluster).
3. **Traffic shifting strategies** — `AllAtOnce`, `Canary10Percent5Minutes`, `Linear10PercentEvery1Minute`. For each: what it costs in deploy duration, and what class of bug it can actually catch. Make the honest point that canary only catches bugs that show up in aggregate metrics within the canary window — a bug affecting 0.1% of users will pass every one of them.
4. **The bake period and automatic rollback** — the original task set is kept alive for `termination_wait_time_in_minutes`, which is what makes rollback fast; the tradeoff is you pay for both task sets during the bake.
5. **The deployment circuit breaker** — what it catches (tasks that fail to start or fail health checks) versus what it does not (a task that starts healthy and serves wrong answers). This distinction is the whole reason alarms exist.
6. **Health checks that mean something** — ALB target group health check on `/readyz`, not `/healthz`. Spell out the difference: liveness answers "is the process alive?", readiness answers "should this instance receive traffic?" A health check pointed at a route that always returns 200 will happily certify a broken deploy.
7. **Alarms as rollback triggers** — `alarm_configuration` on the CodeDeploy deployment group, using an ALB `HTTPCode_Target_5XX_Count` alarm. Cover the parameters that decide whether rollback is fast or theoretical: period, evaluation periods, `treat_missing_data`. Warn explicitly: `treat_missing_data = "missing"` on a low-traffic service produces an alarm that never fires.
8. **Where configuration lives** — the four-way boundary. Image (things true for every environment), task definition (things true for this environment), Parameter Store (non-secret config that changes without a deploy), Secrets Manager (secrets, with rotation and cost ~$0.40/secret/month). Give the rule for choosing and note that ECS injects both via `secrets` in the container definition, so the *code* does not know the difference — which is the point.
9. **Task role vs execution role** — reinforce the glossary entry with the concrete failure: an image pull failure means the *execution* role is wrong; an `AccessDenied` from your own code means the *task* role is wrong.

`## Decision rules` — at least 6 rows, including one for choosing a shift strategy given a traffic volume.

`## Exercises` — exactly 4, hint + solution sketch:
1. A blue/green deploy succeeds, the circuit breaker never trips, and the service returns HTTP 200 with wrong data. Which control should have caught it? (Sketch: none of the deployment controls — this needs an alarm on a *business* SLI, which is Day 5. The circuit breaker only observes task startup and health checks.)
2. Given a service handling 2 requests/minute, design a 5XX rollback alarm that actually fires. (Sketch: short periods with few datapoints are noisy at this volume; either lengthen the window and accept slower rollback, use a rate-based metric math expression rather than a raw count, or set `treat_missing_data` deliberately. State the real tradeoff: at 2 rpm you cannot have both fast and reliable automated rollback, and knowing that is the answer.)
3. Compute the cost of a 30-minute blue/green deploy with a 15-minute bake, two 0.25vCPU/0.5GB tasks. (Sketch: ~$0.0123/h per task; both task sets alive for the bake → ~2 × 0.0123 × 0.25h ≈ $0.006. The point of the arithmetic: bake time is nearly free, so short bake periods are a false economy.)
4. Your rollback needs a rebuild to execute. Name the design error. (Sketch: the deploy consumed a tag or a source ref instead of a stored digest, so the previous artifact no longer exists as an addressable object. Custody was broken at PRODUCE, and the symptom only appeared at REVERSE.)

`## Anti-patterns` — 4 bullets: health checks that only prove the process is alive; rollback plans requiring a rebuild; secrets in task-definition `environment`; all-at-once deploys with no alarm.

- [ ] **Step 2: Write the Terraform**

`variables.tf`: `aws_region`, `name_prefix`, `image_tag` (no default — the learner passes the Day 1 tag, and a comment states that requiring this by hand is deliberate: it makes the digest hand-off visible before Day 5 automates it).

`alb.tf`: `aws_security_group` for the ALB (ingress 80 from `0.0.0.0/0`, egress all) and one for the tasks (ingress 8080 **from the ALB security group only**, egress all); `aws_lb` (`internal = false`, in `data.terraform_remote_state.foundation.outputs.public_subnet_ids`); **two** `aws_lb_target_group` (`blue`, `green`) with `target_type = "ip"`, `health_check { path = "/readyz", matcher = "200", interval = 15, healthy_threshold = 2, unhealthy_threshold = 2 }` — with a comment stating why `/readyz` and not `/healthz`; one `aws_lb_listener` on port 80 forwarding to blue, with `lifecycle { ignore_changes = [default_action] }` and a comment explaining that CodeDeploy mutates the listener outside Terraform and without this the next `terraform apply` fights the deployment.

`ecs.tf`: `aws_ecs_cluster`; `aws_cloudwatch_log_group` `/ecs/${var.name_prefix}` with **`retention_in_days = 1`**; task execution role (attach `AmazonECSTaskExecutionRolePolicy`) and a separate task role with no policies plus a comment naming the distinction; `aws_ecs_task_definition` — `requires_compatibilities = ["FARGATE"]`, `network_mode = "awsvpc"`, `cpu = "256"`, `memory = "512"`, `runtime_platform { cpu_architecture = "ARM64", operating_system_family = "LINUX" }`, container pulling `"${foundation.ecr_repository_url}:${var.image_tag}"`, port 8080, `awslogs` driver, and `environment` entries for `POISON` and `BURN_RATE` both defaulting to safe values with a comment that Day 3's break-it step flips them; `aws_ecs_service` with `launch_type = "FARGATE"`, `desired_count = 1`, `deployment_controller { type = "CODE_DEPLOY" }`, `network_configuration` with `assign_public_ip = true` (comment: this is what lets us avoid a NAT gateway) and the task security group, `load_balancer` block pointing at blue, and `lifecycle { ignore_changes = [task_definition, load_balancer, desired_count] }` with a comment explaining CodeDeploy ownership.

`codedeploy.tf`: `aws_codedeploy_app` with `compute_platform = "ECS"`; `aws_cloudwatch_metric_alarm` `"${var.name_prefix}-5xx"` on `AWS/ApplicationELB` `HTTPCode_Target_5XX_Count`, `statistic = "Sum"`, `period = 60`, `evaluation_periods = 1`, `threshold = 5`, `treat_missing_data = "notBreaching"` with a comment pointing at Exercise 2; IAM role for CodeDeploy with `AWSCodeDeployRoleForECS` attached; `aws_codedeploy_deployment_group` with `deployment_style { deployment_option = "WITH_TRAFFIC_CONTROL", deployment_type = "BLUE_GREEN" }`, `blue_green_deployment_config` (`terminate_blue_instances_on_deployment_success { action = "TERMINATE", termination_wait_time_in_minutes = 5 }`, `deployment_ready_option { action_on_timeout = "CONTINUE_DEPLOYMENT" }`), `deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"`, `load_balancer_info.target_group_pair_info` naming blue/green and the listener, `auto_rollback_configuration { enabled = true, events = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"] }`, and `alarm_configuration { enabled = true, alarms = [alarm name] }`.

`appspec.yaml.example` and `taskdef.json.example`: the two files CodeDeploy consumes, with `<TASK_DEFINITION>` and `<IMAGE1_NAME>` placeholders and comments explaining that CodePipeline substitutes them — this is the seam Day 5 automates.

`outputs.tf`: the six outputs named in Interfaces.

- [ ] **Step 3: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: goal; success signal ("a bad build reaches 10% of traffic, an alarm fires, and traffic returns to the previous task set without human action"); run steps including the `aws deploy create-deployment` invocation with the appspec; then **Break it** in two escalating stages — (a) set `POISON=true` in a new task definition revision and deploy: the *health check* stops it before any traffic shifts, demonstrating the circuit breaker; (b) set `BURN_RATE=0.5` and deploy: this one passes health checks, takes 10% of traffic, drives 5XX, trips the alarm, and rolls back. Then the two questions: how long were users affected, and what would have caught it sooner? Include the `aws deploy get-deployment` command for reading the rollback in the deployment's own record.

`SOLUTION.md`: expected deployment lifecycle events for both break-it stages side by side (this contrast is the core teaching moment), the alarm math, answers to both questions, and a "what you should now be able to explain" list mapped to Success Criteria 6 and 7.

`teardown.md`: **the most important teardown in the path.** Ordered: stop any in-progress deployment (`aws deploy stop-deployment --auto-rollback-enabled`) because `terraform destroy` fails while a deployment is running; scale the ECS service to 0; `terraform destroy`; then the resources `destroy` misses — CodeDeploy-created task sets, and the ALB if the listener was mutated outside state; then `bash ../verify-teardown.sh` and read the ALB section specifically. State the overnight cost of forgetting: ~$0.55/night, dominated by the ALB.

- [ ] **Step 4: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/day03
terraform fmt -check
grep -c "nat_gateway" *.tf                      # 0
grep -c "assign_public_ip" ecs.tf               # >= 1
grep -n '"/readyz"' alb.tf                      # health check must target /readyz
grep -c "ignore_changes" ecs.tf alb.tf          # both files must have at least 1
grep -c "retention_in_days" ecs.tf              # >= 1
cd ../../ && grep -c "Hint:" content/day03.md && grep -c "Solution sketch:" content/day03.md   # 4 and 4
```

---

### Task 9: Day 4 — Substrate swap (content + lab), Kubernetes at conversancy level

**Files:**
- Create: `aws_devops_sre/content/day04.md`
- Create: `aws_devops_sre/labs/day04/README.md`
- Create: `aws_devops_sre/labs/day04/SOLUTION.md`
- Create: `aws_devops_sre/labs/day04/kind-cluster.yaml`
- Create: `aws_devops_sre/labs/day04/k8s/deployment.yaml`
- Create: `aws_devops_sre/labs/day04/k8s/service.yaml`
- Create: `aws_devops_sre/labs/day04/eks/main.tf`
- Create: `aws_devops_sre/labs/day04/eks/variables.tf`
- Create: `aws_devops_sre/labs/day04/eks/README.md`
- Create: `aws_devops_sre/labs/day04/teardown.md`

**Interfaces:**
- Consumes: the app image and its `/readyz` + `POISON` contract from Task 3; Day 3's blue/green vocabulary for the ECS↔K8s mapping table.
- Produces: nothing consumed by later tasks. Day 5 references Day 3's ECS stack, not this one.

- [ ] **Step 1: Write `content/day04.md`**

Header: chain link `(substrate)`; time `~3.2h (content ~55m · lab ~110m · break/fix ~20m · teardown ~5m)`; cost `$0.00`. Question of the day: **"Does the chain of custody survive a change of substrate?"**

`## Why this matters` must open with the scope contract, stated plainly: this day makes you *conversant*, not competent. Deep EKS is a separate path. The purpose here is to falsify the mental model — if the chain only works on ECS, it was an ECS story rather than an abstraction.

`## Core concepts`:
1. **Reconciliation vs events** — the single most important conceptual difference. ECS deployments are *events* you trigger; Kubernetes runs a *control loop* continuously reconciling declared state. Consequence: `kubectl apply` is not a deployment, it is an edit to desired state, and something else decides when reality matches.
2. **The five objects that matter here** — Pod, Deployment, ReplicaSet, Service, Ingress. One paragraph each, no more.
3. **Rolling update vs blue/green** — `maxSurge`/`maxUnavailable`, and why the K8s default is a rolling update rather than blue/green.
4. **Readiness probes as the deploy gate** — the direct analog of Day 3's target group health check, and the crucial behavior: a Deployment with a failing readiness probe *stalls* rather than completing, which means a bad image never fully rolls out. This is the lab's punchline.
5. **Why immutability matters more here** — with `imagePullPolicy: Always` and a mutable tag, two pods of the "same" Deployment can be running different code. On ECS a task definition pins the image; on K8s nothing stops the tag from moving underneath you.
6. **The ECS ↔ Kubernetes mapping table** — required, and the highest-value artifact of the day: task definition ↔ Pod spec; service ↔ Deployment; task set ↔ ReplicaSet; target group ↔ Service; ALB listener rule ↔ Ingress; task role ↔ ServiceAccount + IRSA; execution role ↔ node role / pull secret; circuit breaker ↔ `progressDeadlineSeconds`; `desired_count` ↔ `replicas`.
7. **IRSA** — a ServiceAccount annotated with a role ARN, an OIDC provider on the cluster, and pods receiving a projected token. Name the direct lineage: this is the *same* `AssumeRoleWithWebIdentity` trust mechanism as Day 2's GitHub OIDC, with a different issuer. Making that connection is worth more than any EKS configuration detail.
8. **How a pipeline reaches a cluster** — push (`kubectl` in CodeBuild: simple, needs cluster credentials in CI, CI must reach the API server) vs pull (GitOps: no cluster credentials in CI, drift detection, extra component to run). Name Argo CD and Flux, state they are deferred to the EKS path, and give the one-line rule for when the pull model starts paying off.
9. **What EKS costs and why we are not using it today** — ~$0.10/h control plane plus nodes plus (usually) a NAT gateway; ~$100+/month for an idle learning cluster.

`## Exercises` — exactly 4, hint + solution sketch:
1. Fill in the ECS↔K8s mapping table from memory. (Sketch: the table above; grade yourself on task set ↔ ReplicaSet and task role ↔ IRSA, the two most commonly missed.)
2. A Deployment update leaves 3 old pods and 1 new pod running for 20 minutes. What is happening and is it broken? (Sketch: the new pod is failing its readiness probe, so the rollout is blocked at `maxSurge`. This is correct behavior — it is the cluster refusing to ship a broken version — and it eventually fails at `progressDeadlineSeconds`.)
3. Explain why IRSA and Day 2's GitHub OIDC are the same mechanism. (Sketch: both are `AssumeRoleWithWebIdentity` against an IAM OIDC provider; only the issuer and the `sub` claim format differ — `system:serviceaccount:NS:NAME` versus `repo:OWNER/REPO:ref:...`.)
4. Your team runs 4 services on ECS Fargate and is considering EKS. Give the honest cost and complexity delta. (Sketch: EKS adds control plane, node management or Fargate profiles, usually NAT, plus a cluster-upgrade cadence ECS does not have; it pays off with many services, heavy per-service customization, or an existing K8s-fluent team. At 4 services it likely does not — and being able to say that is a senior answer.)

`## Anti-patterns` — 4 bullets: `kubectl apply` treated as a deployment strategy; missing readiness probes; node IAM roles instead of IRSA; assuming a Deployment rollback restores data.

- [ ] **Step 2: Write the manifests**

`kind-cluster.yaml`: single-node cluster, `extraPortMappings` exposing container port 30080 → host 8080 so the learner can `curl localhost:8080` without `kubectl port-forward`.

`k8s/deployment.yaml`: `replicas: 2`; image field as `<YOUR_ECR_URL>:<TAG>` **with a comment offering the local alternative** (`kind load docker-image`) so the lab works without ECR pull credentials on the cluster; `imagePullPolicy: IfNotPresent`; a **readinessProbe on `/readyz`** and a **livenessProbe on `/healthz`** with a comment naming which Day 3 concept each mirrors; `env` entries for `POISON` (default `"false"`) and `PORT`; resource requests/limits (`100m`/`128Mi` requests); `progressDeadlineSeconds: 120` with a comment naming it the circuit-breaker analog.

`k8s/service.yaml`: `type: NodePort`, `nodePort: 30080`, targeting port 8080.

- [ ] **Step 3: Write `eks/main.tf`, `eks/variables.tf`, `eks/README.md` — authored, never applied**

`eks/README.md` must open with a bold, unmissable banner: **DO NOT `terraform apply` THIS DIRECTORY DURING THIS PATH.** It costs ~$0.10/h for the control plane before nodes, and this path's Day 4 runs on `kind` for free. It is here so the future EKS path starts from working code.

`eks/main.tf`: a minimal, readable EKS reference — `aws_eks_cluster` consuming the foundation VPC's public subnets; a managed node group; `aws_iam_openid_connect_provider` for the cluster's OIDC issuer; and a worked **IRSA** example: an `aws_iam_role` whose trust policy conditions on `StringEquals` of `<OIDC_ISSUER>:sub` = `system:serviceaccount:default:awsdevops-sample` — placed directly beside a comment pointing back to Day 2's GitHub OIDC trust policy so the identical shape is impossible to miss. Every resource carries a comment estimating its monthly cost.

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: goal; success signal ("a broken readiness probe stalls the rollout instead of shipping"); steps — `kind create cluster --config kind-cluster.yaml`, `kind load docker-image`, `kubectl apply -f k8s/`, `kubectl rollout status`, `curl localhost:8080`; then a normal image update and `kubectl rollout status` again; then **Break it**: set `POISON=true` in the Deployment env, apply, and watch `kubectl get pods` show the new pod `Running` but `0/1 READY` while the old pods keep serving — then `kubectl rollout undo`. Explicitly ask the learner to compare this with Day 3's circuit breaker and name which failure each catches.

`SOLUTION.md`: expected `kubectl get pods` and `kubectl rollout status` output at each stage, the ECS↔K8s comparison written out, and the answer to why the rollout stalls rather than fails immediately.

`teardown.md`: `kind delete cluster` — and one line noting cost is $0 because nothing was ever created in AWS. Then the reminder that `eks/` was never applied, with the `aws eks list-clusters` command to prove it.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/day04
grep -c "readinessProbe\|livenessProbe" k8s/deployment.yaml    # >= 2
grep -n "readyz\|healthz" k8s/deployment.yaml                  # both must appear
grep -ci "do not.*apply" eks/README.md                         # >= 1
cd ../../ && grep -c "Hint:" content/day04.md && grep -c "Solution sketch:" content/day04.md   # 4 and 4
grep -ci "conversant" content/day04.md                         # scope contract must be stated
```

---

### Task 10: Day 5 — MEASURE + capstone (content + lab)

**Files:**
- Create: `aws_devops_sre/content/day05.md`
- Create: `aws_devops_sre/labs/day05/README.md`
- Create: `aws_devops_sre/labs/day05/SOLUTION.md`
- Create: `aws_devops_sre/labs/day05/main.tf`
- Create: `aws_devops_sre/labs/day05/variables.tf`
- Create: `aws_devops_sre/labs/day05/canary.js.example`
- Create: `aws_devops_sre/labs/day05/SLO-TEMPLATE.md`
- Create: `aws_devops_sre/labs/day05/RUNBOOK-TEMPLATE.md`
- Create: `aws_devops_sre/labs/day05/teardown.md`

**Interfaces:**
- Consumes: Day 3's `alb_dns_name`, `ecs_service_name`, `codedeploy_app_name`, `rollback_alarm_name` via `data "terraform_remote_state" "day03"` reading `../day03/terraform.tfstate`; Day 2's `pipeline_name`; the app's `/burn` route.
- Produces: the two documents that are the path's real deliverable.

- [ ] **Step 1: Write `content/day05.md`**

Header: chain link `MEASURE`; time `~3.5h (content ~50m · lab ~130m · break/fix ~15m · teardown ~15m)`; cost `~$1.50`. Question of the day: **"How do we know the chain is healthy, and how do we prove it to someone else?"**

`## Core concepts`:
1. **SLI → SLO → error budget** — an SLI is a measurement, an SLO is a target on it, an error budget is what the target leaves you. Then the connection that makes it operational: the error budget is the *deployment velocity dial*. Budget remaining → ship. Budget exhausted → stop shipping features and spend on reliability. Without that link, SLOs are decoration.
2. **Choosing an SLI** — must be measured as close to the user as possible. Point out that Day 3's `HTTPCode_Target_5XX_Count` alarm is a *proxy*, and name what it misses (200 responses carrying wrong data; client-side failures; anything before the ALB).
3. **The four golden signals** — latency, traffic, errors, saturation — mapped to the concrete CloudWatch metrics available from the Day 3 stack.
4. **DORA metrics from your own pipeline** — for each of the four, the exact data source in what the learner built: deployment frequency (CodeDeploy `list-deployments`), lead time for changes (commit timestamp → deployment `completeTime`), change failure rate (deployments with `rollbackInfo` present ÷ total), MTTR (deployment `createTime` → rollback complete). State honestly that MTTR measured this way only covers auto-rollback and undercounts incidents needing human diagnosis.
5. **Composite alarms** — why five separate alarms produce five pages for one incident, and how `ALARM(a) AND ALARM(b)` reduces noise. Note the cost angle: composite alarms are billed too, and 10 alarms are free.
6. **Synthetic canaries** — the one signal that works when traffic is zero, which is exactly the situation in a lab and at 3am. ~$0.0012/run; note the S3 artifact bucket and Lambda a canary creates behind the scenes, because they surprise people at teardown.
7. **Structured logging** — return to `app/main.go`'s hand-rolled JSON log lines and critique them: no timestamp (CloudWatch adds one, but the container's own clock is what you need for correlation), no request ID, no correlation with X-Ray trace IDs. Ask what would need to change to make them queryable in CloudWatch Logs Insights, and give one example Insights query.
8. **X-Ray, briefly** — what a trace buys over logs at a service boundary; sampling rules as the cost control.
9. **Cost retrospective** — walk the whole week's stack and ask the learner to state, before looking, which resource dominated. (Answer: the ALB.)

`## Decision rules` — at least 4 rows, including when a synthetic canary beats a real-traffic alarm.

`## Exercises` — exactly 4, hint + solution sketch:
1. Write an SLO for the sample service, then compute the error budget in minutes for a 30-day window. (Sketch: e.g. 99.5% availability over 30 days → 0.5% × 43,200 min = 216 min of budget. The number matters less than being able to say what spends it.)
2. Your change failure rate is 20% but MTTR is 4 minutes. Should you slow down deploys? (Sketch: probably not — a high failure rate with fast, automatic recovery is a different situation from a low failure rate with slow manual recovery. Compare total budget burn, not either number alone. This is exactly the reasoning DORA is for.)
3. Write a CloudWatch Logs Insights query returning the p99 latency by version from the sample service's logs, then explain why it cannot work as the logs are currently written. (Sketch: the app logs no latency field and no per-request line at all; the exercise is to notice that the *instrumentation* is the gap, not the query.)
4. Design a composite alarm that pages only for a real user-facing outage. (Sketch: `ALARM(5xx_rate) AND ALARM(canary_failure)` — requiring both a real-traffic signal and a synthetic one filters single-source noise; then state the failure mode you just accepted, namely that an outage affecting only real users during a canary gap is now slower to page.)

`## Anti-patterns` — 4 bullets: SLOs with no error-budget policy; alarming on causes instead of symptoms; measuring MTTR only for auto-rollbacks; never-expiring log retention.

- [ ] **Step 2: Write `main.tf`, `variables.tf`, `canary.js.example`**

`main.tf`:
- Standard blocks plus `data "terraform_remote_state" "day03"`.
- `aws_cloudwatch_metric_alarm` for **p99 target response time** (`TargetResponseTime`, `extended_statistic = "p99"`) on the Day 3 ALB.
- `aws_cloudwatch_composite_alarm` combining the Day 3 5XX alarm with the p99 alarm, with a comment naming the noise-reduction tradeoff.
- `aws_synthetics_canary` — `runtime_version` pinned with a comment to check for the current version, `schedule { expression = "rate(5 minutes)" }`, handler from `canary.js.example`, plus its required IAM role and S3 artifact bucket (with a 1-day lifecycle expiration and a comment that this bucket is a teardown trap).
- `aws_cloudwatch_dashboard` laying out the four golden signals from the Day 3 stack in one JSON body.
- A comment block at the top listing this lab's hourly cost and stating that the Day 3 stack must be up for these alarms to have anything to observe.

`canary.js.example`: a minimal Synthetics heartbeat script hitting `http://<ALB_DNS>/readyz`, asserting a 200, with placeholders and a comment on where the canary's own logs land.

- [ ] **Step 3: Write `SLO-TEMPLATE.md` and `RUNBOOK-TEMPLATE.md`**

These two are **the deliverable of the entire path** and must be genuinely usable, not decorative.

`SLO-TEMPLATE.md`: service name; SLI definition with the exact metric and the measurement window; the SLO target and why that number; error budget in minutes; the **error budget policy** (what the team does at 50%, 75%, 100% burn — this section is what makes the document real); explicit exclusions; and the review cadence.

`RUNBOOK-TEMPLATE.md`: written for an engineer at 3am who did not build the system. Sections: symptom → first check (with the literal commands, including `aws deploy get-deployment` and the Logs Insights query); decision tree for roll-back-now vs investigate; the exact rollback command; how to confirm the rollback worked; who to notify; and what to write down for the postmortem. A filled-in example for the sample service must accompany the blank template — a blank runbook teaches nothing.

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: the capstone, as one continuous exercise: commit a change → pipeline builds → digest promoted → canary deployment begins → the learner drives `/burn` traffic against the ALB (give the `while` loop with `curl`) → the 5XX alarm breaches → CodeDeploy rolls back automatically → the learner then pulls the four DORA metrics with the CLI commands provided → and finally fills in `SLO-TEMPLATE.md` and `RUNBOOK-TEMPLATE.md` for the service. State the success signal: **you can hand both documents to another engineer and they could operate this service without asking you a question.**

`SOLUTION.md`: a worked example of every DORA calculation with sample CLI output; a filled-in SLO document; a filled-in runbook; and a final self-check listing all 12 Success Criteria from the spec with the day that covered each.

`teardown.md`: **the end-of-path teardown, in strict order** — stop the canary first (a running canary recreates artifacts), destroy `labs/day05`, then `labs/day03` (the ALB), then `labs/day02` (empty the S3 artifact bucket first), then `labs/day01`, then finally `labs/foundation`. Then `bash ../verify-teardown.sh` and require a clean result. Close with the Cost Explorer check to run 24 hours later, because some charges land late — and a note that finishing the week with a verified $0 run rate is itself a professional habit worth keeping.

- [ ] **Step 5: Verify**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre/labs/day05
terraform fmt -check
grep -c "composite_alarm" main.tf                 # >= 1
grep -ci "error budget policy" SLO-TEMPLATE.md    # >= 1
grep -ci "rollback" RUNBOOK-TEMPLATE.md           # >= 1
cd ../../ && grep -c "Hint:" content/day05.md && grep -c "Solution sketch:" content/day05.md   # 4 and 4
```

---

### Task 11: Final verification sweep

**Files:**
- Modify: any file failing a check below.

**Interfaces:**
- Consumes: everything.
- Produces: a path that satisfies every Global Constraint.

- [ ] **Step 1: Constraint scan**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre

echo "== no NAT gateways anywhere =="
grep -rn "nat_gateway\|aws_nat_gateway" --include="*.tf" . ; echo "expect: nothing"

echo "== no real 12-digit account IDs (only 123456789012 placeholder allowed) =="
grep -rnE '\b[0-9]{12}\b' --include="*.tf" --include="*.md" --include="*.yml" --include="*.yaml" . | grep -v "123456789012" ; echo "expect: nothing"

echo "== no committed tfvars =="
find . -name "terraform.tfvars" ; echo "expect: nothing"

echo "== no secrets =="
grep -rniE "AKIA[0-9A-Z]{16}|aws_secret_access_key\s*=|ghp_[A-Za-z0-9]{36}" . ; echo "expect: nothing"

echo "== every lab has README + teardown =="
for d in labs/day0*/ labs/foundation/; do
  test -f "$d/README.md" || echo "MISSING README: $d"
  test -f "$d/teardown.md" || echo "MISSING teardown: $d"
done

echo "== every day lab has SOLUTION =="
for d in labs/day01 labs/day02 labs/day03 labs/day04 labs/day05; do
  test -f "$d/SOLUTION.md" || echo "MISSING SOLUTION: $d"
done

echo "== log retention set wherever log groups exist =="
grep -rln "aws_cloudwatch_log_group" --include="*.tf" . | while read -r f; do
  grep -q "retention_in_days" "$f" || echo "NO RETENTION: $f"
done

echo "== terraform formatting =="
for d in labs/foundation labs/day01 labs/day02 labs/day03 labs/day05 labs/day04/eks; do
  (cd "$d" && terraform fmt -check >/dev/null 2>&1) || echo "FMT: $d"
done
```

- [ ] **Step 2: Content completeness scan**

```bash
cd /Users/hunghd/git_clone/learning_path/aws_devops_sre

echo "== 4 hints and 4 solution sketches per day =="
for f in content/day0*.md; do
  h=$(grep -c "Hint:" "$f"); s=$(grep -c "Solution sketch:" "$f")
  [ "$h" -eq 4 ] && [ "$s" -eq 4 ] || echo "$f: hints=$h sketches=$s (want 4/4)"
done

echo "== required sections in every day file =="
for f in content/day0*.md; do
  for sec in "## Why this matters" "## The question of the day" "## Core concepts" "## Decision rules" "## Lab" "## Break it" "## Exercises" "## Anti-patterns" "## Teardown" "## Self-check"; do
    grep -q "$sec" "$f" || echo "$f missing: $sec"
  done
done

echo "== placeholders =="
grep -rnE "TBD|TODO|FIXME|fill in details|implement later" --include="*.md" . ; echo "expect: nothing"
```

- [ ] **Step 3: Cross-document consistency**

Check by reading, not by grep:
- The cost figures in `README.md`'s day index, `COST.md`'s per-lab table, and each `content/dayNN.md` header agree with each other.
- The time figures in each `content/dayNN.md` header match the spec's realism table (3.3 / 3.4 / 3.75 / 3.2 / 3.5 hours).
- Every Terraform output named in a task's **Produces** block actually exists in that lab's `outputs.tf`, and every `terraform_remote_state` reference in a later lab uses a name that exists.
- Every route and env var referenced in Days 3, 4, and 5 (`/healthz`, `/readyz`, `/burn`, `POISON`, `BURN_RATE`) matches `app/main.go` exactly.
- All 12 spec Success Criteria are covered by some day, per the mapping in `labs/day05/SOLUTION.md`.

- [ ] **Step 4: Report**

Report to the learner: files created, any check that failed and how it was fixed, and any spec requirement that ended up uncovered. **Do not run git commands. Do not commit.**
