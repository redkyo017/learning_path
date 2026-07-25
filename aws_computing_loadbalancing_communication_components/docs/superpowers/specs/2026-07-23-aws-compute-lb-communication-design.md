# AWS Compute, Load Balancing & Service Communication Mastery Plan

**Date:** 2026-07-23
**Status:** Approved design

## Purpose

Reach production-credible competence in AWS Compute, Load Balancing, and Service
Communication in 12 days (2–3 hours/day, ~28–36 hours total) for an integration
platform engineer whose team designs and operates multi-service, event-driven
infrastructure on AWS. The goal is not certification — it is the ability to design,
build, debug, and reason about real production systems confidently: EC2 fleets,
load balancer selection, auto-scaling, containerised services, and inter-service
messaging patterns.

SAA-C03 coverage is a natural byproduct. Reference: Stephane Maarek's SAA-C03
course on Udemy (used as a syllabus anchor, not a strict dependency).

## Learner context

- Background: AWS basics (EC2, S3, IAM), networking competence from the
  aws_network_components plan. Has touched ALB and ASG but never built them from
  scratch with real intent. Has used ECS/EKS in practice but load balancing
  internals and inter-service messaging are gaps.
- Role: Integration platform team. Responsible for connecting services, teams,
  and accounts — cross-service connectivity, async messaging, and operating
  shared infrastructure.
- Motivation: Consolidating and deepening production-applicable knowledge,
  with SAA-C03 as a secondary outcome.
- Tooling: AWS Console (primary for learning) + Terraform (team's production
  stack). Labs always run Console first, then Terraform — console visibility
  builds the mental model, Terraform codifies what is already understood.
- AWS access: full personal sandbox account, no restrictions. Resources torn
  down at end of each day to control cost.

## Unconventional strategy — what the top 1% actually do

Most learners watch videos, read docs, then attempt a tutorial. They waste time
because they learn services in isolation, without a forcing function that requires
them to *explain* what they built or *fix* what broke. The accelerated approach
has five rules:

**1. "When would I NOT use this?" discipline.**
For every service, explicitly reason about the alternative. Almost anyone can say
what ALB does. Almost none can immediately answer "when NLB instead?" That is
the question architecture reviews and real incidents demand. Every day file
includes a "when NOT this" section.

**2. Narrate-to-consolidate.**
After every console lab, write 3–5 sentences in `journal.md` as if explaining
to a junior engineer. If you cannot explain it simply, you have not learned it
yet. This is the single highest-leverage daily habit.

**3. Mental model before console.**
Every day starts with a core question and framework before touching AWS. Services
exist to solve specific problems — learning the problem before the solution makes
knowledge transferable to novel situations.

**4. Deliberate breakage after every lab.**
Introduce one intentional misconfiguration, diagnose it with the correct tool
(CloudWatch Logs, VPC Reachability Analyzer, CloudTrail, ECS stopped-task reason).
Debugging under controlled conditions — when you already know the answer — builds
the intuition that makes real incidents fast to resolve.

**5. Terraform only after plain-English explanation.**
Never open a `.tf` file until you can narrate what you are about to codify. This
prevents copy-pasting infrastructure you do not understand.

## Mistakes that waste 80% of beginners' time

| Mistake | Why it costs so much time |
|---|---|
| Memorising ALB features without OSI context | Cannot choose ALB vs NLB vs GWLB in novel situations — the OSI layer is the decision criterion |
| Treating ASG as "just autoscaling" | Misses lifecycle hooks → mysterious deploy failures and unexpected instance terminations |
| Confusing SQS / SNS / EventBridge use cases | Wrong tool for the job, discovered in production when it is expensive to change |
| Ignoring ECS awsvpc networking mode | Each Fargate task gets its own ENI + security group — causes "cannot connect" bugs with no obvious cause |
| Watching videos without pausing to build | Concepts without friction are forgotten within 48 hours |
| Reading docs instead of breaking things | 3 hours of reading < 20 minutes of building it wrong and fixing it |

## Three-phase structure

### Phase 1 — Traffic & Compute (Days 1–4)

| Day | Topic | Core question |
|---|---|---|
| 1 | EC2 depth | What am I actually paying for and what can I tune? |
| 2 | Load Balancers (ALB / NLB / GWLB) | At which OSI layer does the routing decision happen? |
| 3 | Auto Scaling Groups | ASG owns instance lifecycle — how do lifecycle hooks change everything? |
| 4 | Phase 1 synthesis | Wire ALB → ASG → EC2; debug a 502; first Terraform module |

**Day 1 — EC2 depth**
Concepts: instance families (compute/memory/storage/GPU), EBS types (gp3/io2/st1/sc1)
and their IOPS/throughput characteristics, instance store vs EBS (persistence,
speed, use case), purchasing options (on-demand/reserved/spot/savings plans),
placement groups (cluster/spread/partition), ENI basics.
Lab: launch instances of two different families, attach different EBS types,
observe IOPS differences, explore spot capacity in the console.
Break: wrong EBS type for a latency-sensitive workload — identify with CloudWatch
EBS metrics.

**Day 2 — Load Balancers**
Concepts: ALB (L7, HTTP/HTTPS, path/host routing, sticky sessions, WAF),
NLB (L4, TCP/UDP, static IP, ultra-low latency, TLS passthrough),
GWLB (L3, inline appliances, GENEVE encapsulation), target groups, listeners,
health checks, cross-zone load balancing, SSL termination vs passthrough.
Lab: ALB with two target groups and path-based routing rules; NLB with static
IP assignment; compare 5xx error surfaces between the two.
Break: health check port misconfiguration causing all targets unhealthy —
diagnose via target group health status and EC2 instance logs.

**Day 3 — Auto Scaling Groups**
Concepts: launch templates vs launch configurations (deprecation context),
scaling policies (target tracking / step / scheduled), lifecycle hooks
(pending:wait for bootstrap, terminating:wait for drain), health checks
(EC2 vs ELB — which takes precedence), instance refresh (max healthy percentage,
checkpoint), warm pools.
Lab: ASG with target tracking CPU policy, simulate load with stress, observe
scale-out event; add a lifecycle hook that pauses launch, complete it via CLI.
Break: lifecycle hook that never sends heartbeat — observe ASG abandon and rollback.

**Day 4 — Phase 1 synthesis**
Wire ALB → ASG → EC2 end-to-end; practice a rolling instance refresh with
zero downtime; deliberately introduce a 502 (target fails health check) and
trace the root cause through target group health → EC2 system log.
Terraform: codify the Phase 1 stack as `terraform/phase1_compute/`. Validate
with `terraform plan` and `apply`. Tear down with `terraform destroy`.

### Phase 2 — Container Layer (Days 5–7)

| Day | Topic | Core question |
|---|---|---|
| 5 | ECS + Fargate + ECR | What does Fargate abstract away, and what do you still own? |
| 6 | ECS + ALB + Service Discovery | How does traffic find ephemeral containers? |
| 7 | Phase 2 synthesis | Same ALB, two target groups: one ASG, one ECS; zero-downtime deploy |

**Day 5 — ECS mental model**
Concepts: task definition (CPU, memory, awsvpc networking mode, container
definitions), service (desired count, deployment configuration, health check
grace period), cluster (Fargate vs EC2 launch type — what changes),
ECR (image lifecycle policy, vulnerability scanning), awsvpc mode (each task
gets its own ENI and security group — this is the key networking insight).
Lab: push a Docker image to ECR; run a Fargate task; inspect the ENI and
security group attached to the running task; stop the task and observe ENI release.
Break: task execution role missing `ecr:GetAuthorizationToken` — diagnose via
ECS stopped task reason and CloudTrail.

**Day 6 — ECS + ALB + Service Discovery**
Concepts: ALB + ECS service integration (dynamic port mapping for EC2 launch
type; fixed port for awsvpc), target group health check for ECS, Cloud Map
service discovery (DNS-based service-to-service), blue/green deployment via
CodeDeploy (two target groups, traffic shifting), task auto-scaling
(target tracking on CPU or ALB request count).
Lab: ECS Fargate service registered with ALB; add Cloud Map for internal
service-to-service DNS; observe target group deregistration during a deploy.
Break: deregistration delay too short — in-flight requests drop with 502;
diagnose via ALB access logs and fix via connection draining settings.

**Day 7 — Phase 2 synthesis**
Connect Phase 1 and Phase 2 on the same ALB: `/api/*` routes to ECS Fargate
service, `/app/*` routes to EC2 ASG — both via separate target groups, one ALB.
Practice: zero-downtime ECS rolling deploy vs CodeDeploy blue/green; observe
traffic split in ALB access logs.
Terraform: codify Phase 2 as `terraform/phase2_containers/`; extend Phase 1
module to add the second target group and routing rule.

### Phase 3 — Communication Layer (Days 8–12)

| Day | Topic | Core question |
|---|---|---|
| 8 | SQS | When does a message get processed twice, and how do you prevent it? |
| 9 | SNS + fan-out patterns | SNS is a megaphone, SQS is a mailbox — when does each fit? |
| 10 | EventBridge | How do you route events without coupling producers to consumers? |
| 11 | API Gateway | What does API Gateway enforce before your code even runs? |
| 12 | Kinesis + final synthesis | When does ordering and throughput change the answer? |

**Day 8 — SQS**
Concepts: standard vs FIFO (ordering guarantee, deduplication, throughput limits),
visibility timeout (the core of at-least-once delivery), message retention,
DLQ (max receive count, alarm on DLQ depth), long polling vs short polling,
batch operations (send/receive/delete), consumer patterns (polling workers on ECS).
Lab: producer Lambda → standard SQS queue → ECS consumer; simulate consumer
failure; observe message reappear after visibility timeout; configure DLQ and
observe failed messages land there.
Break: visibility timeout set shorter than processing time — observe duplicate
processing; fix by extending visibility timeout during processing.

**Day 9 — SNS + fan-out**
Concepts: topics, subscriptions (SQS, Lambda, HTTP, email), message attributes
and filter policies (subscriber-side filtering), SNS + SQS fan-out pattern
(decouple fan-out from consumption rate), FIFO topics (ordered fan-out to FIFO
queues), message delivery retries and dead-letter queues at topic level.
Lab: SNS topic → three SQS queues with different filter policies; publish
messages with varying attributes; observe selective delivery per subscriber.
Break: missing SQS resource-based policy allowing SNS to SendMessage — observe
delivery failure in SNS delivery status logs; fix and verify.

**Day 10 — EventBridge**
Concepts: event buses (default AWS / custom / partner), rules (event patterns
vs schedules), targets (SQS, ECS task, Lambda, Step Functions), schema registry
(auto-discovery, code bindings), DLQ for failed target invocations, cross-account
event delivery via resource-based policy on target bus.
Lab: custom event bus; rule filtering by `detail-type`; targets: SQS queue and
ECS task; publish custom events via CLI; observe routing.
Break: EventBridge IAM role missing `ecs:RunTask` permission — diagnose via
EventBridge DLQ message and CloudTrail; fix IAM policy.

**Day 11 — API Gateway**
Concepts: REST API vs HTTP API (when to use each — HTTP API is cheaper/faster
for proxy use cases; REST API for full request transformation, usage plans,
API keys), integration types (Lambda proxy, HTTP proxy, AWS service), stages
and deployment, throttling and usage plans, CORS configuration, VPC Link for
private integrations (connect to ALB or NLB in VPC without public exposure).
Lab: HTTP API with VPC Link → ALB → ECS service (fully private path); REST API
→ Lambda with IAM authoriser.
Break: CORS misconfiguration — browser preflight 403; diagnose via browser
network tab and API Gateway CloudWatch logs; fix via method response headers.

**Day 12 — Kinesis + final synthesis**
Concepts: Data Streams (shards, sequence numbers, 24h–365d retention, shard
iterator types), enhanced fan-out (dedicated 2 MB/s per consumer), Firehose
(managed delivery to S3/Redshift/OpenSearch, buffering, transformation Lambda),
decision matrix: Kinesis vs SQS vs EventBridge (ordering, throughput, replay,
push vs pull).
Lab: Kinesis Data Stream with two consumers — one standard polling, one enhanced
fan-out; compare read throughput and lag.
Terraform: codify Phase 3 as `terraform/phase3_communication/`.

### Optional Day 13 — Full reference architecture

Wire all three Terraform modules via `terraform/main.tf`:
- API Gateway (HTTP API + VPC Link) → ALB
- ALB routes `/api/*` → ECS Fargate, `/app/*` → EC2 ASG
- ECS services produce to SQS queue; second ECS service consumes
- SNS topic fans out to two SQS queues with filter policies
- EventBridge custom bus routes domain events to ECS tasks
- Kinesis stream for high-throughput event ingestion

End-to-end exercise: send one HTTP request through API Gateway, trace it through
every layer to its final SQS consumer. One multi-service debug exercise:
introduce a failure at the ECS → SQS boundary and diagnose from API Gateway
access logs down to SQS DLQ.

## Infrastructure pattern

**Directory layout:**

```
aws_computing_loadbalancing_communication_components/
├── content/
│   ├── day01.md … day13.md
├── docs/superpowers/
│   ├── specs/    (this file)
│   └── plans/
├── journal.md
└── terraform/
    ├── phase1_compute/
    ├── phase2_containers/
    ├── phase3_communication/
    └── main.tf   (Day 13 — wires all phases)
```

**VPC:** Reuse the existing `aws_network_components` Terraform module. Phases 1–3
deploy into the existing VPC, referencing its subnet and security group outputs
via remote state or data sources.

**Teardown discipline:** `terraform destroy` at the end of every session.
Main cost drivers: ALB (~$0.008/hr), NAT Gateway (~$0.045/hr), Fargate tasks
(per vCPU/memory-second). Estimated cost per 2–3 hour active session: $1–3.

## Tooling reference

| Tool | Purpose |
|---|---|
| AWS Console | Primary for all labs |
| AWS CLI | Quick state inspection (`aws ecs list-tasks`, `aws sqs get-queue-attributes`) |
| CloudWatch Logs/Metrics | Target health, ECS task failures, ASG activity history |
| VPC Reachability Analyzer | Connectivity debug in Phase 1–2 |
| CloudTrail | IAM permission denial debug in Phase 3 |
| ECS stopped-task reason | Container-level failure diagnosis |
| ALB access logs | Request-level routing and error diagnosis |
| Terraform | Codification after console lab is understood |

## Success criteria

By Day 12 you should be able to:
- Choose ALB vs NLB vs GWLB and justify the decision at the OSI layer
- Design an ASG with appropriate lifecycle hooks for a zero-downtime deploy
- Explain why a Fargate task gets its own ENI and what that means for security groups
- Choose between SQS, SNS, EventBridge, and Kinesis for a given messaging requirement
- Trace a 502 from API Gateway through ALB to its root cause in ECS or ASG
- Codify any of the above in Terraform from scratch without referencing examples
