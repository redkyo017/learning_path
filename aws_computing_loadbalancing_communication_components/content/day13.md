# Day 13 — Full Reference Architecture (Optional)

Read this before starting the integration exercise. Budget: 20 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Trace a request from API Gateway through ALB to an ECS task and back
- Trace an event from an ECS task through EventBridge to an SQS consumer
- Identify which layer is responsible when a given failure symptom occurs
- Describe the steps to add a new service to the architecture

---

## The three-layer mental model

Before tracing any request, hold this structure in mind:

> **Three phases, one system. Phase 1 is the traffic layer — ALB routes HTTP. Phase 2 is the compute layer — EC2 ASG and ECS Fargate serve requests. Phase 3 is the communication layer — SQS, SNS, EventBridge, API Gateway, and Kinesis connect services. Together they form a production-ready integration platform. Every failure belongs to exactly one layer. Finding the layer is the first step to finding the fix.**

---

## The complete architecture

All three Terraform phases run in one VPC, reusing the `aws_network_components` foundation. The traffic layer (Phase 1) sits at the edge. The compute layer (Phase 2) processes requests in private subnets. The communication layer (Phase 3) connects everything asynchronously.

**Component connections:**
- API Gateway (HTTP API) receives external HTTPS requests → VPC Link → ALB
- ALB: `/api/*` path rule → ECS Fargate target group (ip type, awsvpc mode); `/*` default rule → EC2 ASG target group (instance type)
- ECS Fargate tasks: process `/api/` requests, publish events to SQS, SNS, or EventBridge
- EC2 ASG: serves `/*` requests
- SNS topic: fan-out to multiple SQS queues with filter policies per subscriber
- EventBridge custom bus: routes domain events (e.g. `order.created`) to SQS queues and ECS task targets
- Kinesis Data Stream: high-throughput event ingestion, feeds Firehose → S3 and real-time analytics consumers
- All compute in private subnets; ALB in public subnets; no public IPs on EC2 or Fargate tasks

```
Internet
   │
[API Gateway HTTP API]
   │ VPC Link
[ALB]
┌──┴──────────────┐
[EC2 ASG]    [ECS Fargate]
(/*)         (/api/*)
                  │ publishes
            ┌─────┼──────────┐
        [SQS]  [SNS]  [EventBridge]
          │       │        │
       [consumer] [SQS×3]  [SQS]
                  │
             [Kinesis] ← high-throughput events
```

---

## End-to-end request trace

A client calls `GET /api/orders/123`. Follow the request through every component.

1. Client sends `GET /api/orders/123` to the API Gateway endpoint URL.
2. API Gateway receives the request, applies the stage throttle limit (10,000 req/s), and evaluates the JWT authoriser.
3. VPC Link routes the request to the ALB's private DNS name — traffic stays inside the VPC, never on the public internet.
4. ALB evaluates listener rules. `/api/*` matches — ALB selects a healthy ECS Fargate task IP from the target group.
5. The selected Fargate task receives the request on its ENI. The task's security group allows inbound on the container port from the ALB security group.
6. The task fetches the order from DynamoDB, builds the response, and publishes an `OrderViewed` event to the EventBridge custom bus.
7. An EventBridge rule matches `detail-type = OrderViewed` and delivers the event to the SQS analytics queue.
8. A second ECS task (the analytics consumer) polls the SQS queue, receives the event, processes it, and deletes the message.
9. The HTTP response — 200 OK with the order JSON — returns from the Fargate task → ALB → VPC Link → API Gateway → client.

Total path: API Gateway enforces → ALB routes → ECS serves → EventBridge routes → SQS delivers → consumer processes. Each component is responsible for exactly one concern.

---

## Event-driven trace

A client calls `POST /api/orders` to create a new order. The request triggers a chain of asynchronous work.

1. ECS Fargate task processes the `POST`, writes the order to DynamoDB, and publishes to the SNS topic with message attribute `event_type=order.created`.
2. SNS fan-out: the billing subscription filter matches `event_type=order.created` and delivers to the billing SQS queue. The notifications subscription delivers to the notifications SQS queue. The analytics subscription has no filter and receives all events.
3. The billing consumer (ECS task) polls the billing SQS queue, processes payment, and deletes the message.
4. The notifications consumer polls the notifications SQS queue and sends a confirmation email.
5. Concurrently: the ECS task also publishes an `OrderCreated` event to the EventBridge custom bus.
6. An EventBridge rule matches `detail-type = OrderCreated` and routes the event to the SQS audit-log queue.
7. The audit-log consumer writes a durable audit record.

Each consumer operates at its own speed. A slow billing consumer does not block notifications. Each SQS queue is isolated — one consumer failing does not affect others. This is the core value of the SNS + SQS fan-out pattern.

---

## Layer-based failure diagnosis

When a failure occurs, identify the layer first. The layer determines the correct debugging tool.

| Symptom | Likely layer | First check |
|---|---|---|
| `502 Bad Gateway` from API Gateway | Compute — ALB or ECS/EC2 | Target group health in ALB console |
| `429 Too Many Requests` from API Gateway | API Gateway throttle | Stage throttling settings |
| Messages not being processed | Communication — SQS | SQS DLQ depth + consumer task logs |
| Events not routing to targets | Communication — EventBridge | EventBridge rule invocation metrics + rule DLQ |
| Container failing to start | Compute — ECS | ECS stopped task reason (console or CLI) |
| Slow responses under load | Compute or Communication | ALB target response time metric + SQS queue depth |

**The debugging discipline:** every symptom has exactly one correct first check. Do not reach for CloudTrail or CloudWatch Logs Insights until you have checked the most proximate component. A 502 is not a Kinesis problem. A 429 is not an ECS problem. Start at the layer the symptom belongs to, then trace inward.

---

## Adding a new service

When you add a service to the architecture, follow this checklist in order. Skipping steps produces the "cannot connect" failures that cost hours to diagnose.

1. Create an ECR repository and push the container image.
2. Write the ECS task definition: set `networkMode = awsvpc`, specify CPU and memory, reference the ECR image, and configure the task execution role (ECR pull permissions) and task role (application permissions).
3. Create an ECS service: set the desired count, deployment configuration, and health check grace period. Decide whether it is ALB-backed (external or internal HTTP path) or purely event-driven (no ALB rule needed).
4. Create a security group for the new task. If ALB-backed: allow inbound from the ALB security group on the container port. If internal: allow inbound from the security groups of services that will call it.
5. Add SNS subscriptions or EventBridge rules for any events the service needs to consume. Create a dedicated SQS queue as the subscription target — do not share queues with other consumers.
6. Add Terraform resources to the `phase2_containers` module (or `phase3_communication` if the service is purely event-driven with no HTTP path).
7. Add IAM permissions to the task role for every AWS service the task will call — DynamoDB, SQS, S3, Kinesis, etc. Grant only the actions the service actually needs. Principle of least privilege is not optional.

---

## Best practices

- **Keep Terraform modules independent.** `phase2_containers` should be destroyable without destroying `phase1_compute`. Use remote state data sources or output variables to share subnet IDs and security group IDs across modules — not hard-coded resource IDs.
- **Use separate SQS queues per consumer.** A shared queue means one slow or failing consumer starves or blocks others. One queue per consumer is not wasteful — SQS pricing is per message, not per queue.
- **Version event schemas.** Include a `version` field in every EventBridge event's `detail`. When you need to change an event's structure, publish the new version alongside the old one and migrate consumers gradually. Without versioning, a schema change breaks all consumers simultaneously and requires a coordinated deploy across every service.

---

## Common pitfalls

- **All services sharing one SQS queue.** A slow consumer reduces effective throughput for every other consumer. The queue appears healthy (messages are flowing) but work is silently backlogged. One DLQ overflow can affect all consumers if they share the same queue configuration.
- **No DLQ on any queue.** A malformed message or a consistently failing consumer creates an invisible retry loop. Without a DLQ, there is no signal — no alarm, no CloudWatch metric, no visibility into the failure. Always configure a DLQ and alarm on `ApproximateNumberOfMessagesVisible > 0`.
- **Ignoring cross-AZ traffic cost.** ALB health checks reach ECS tasks across AZs. Fargate tasks pulling large ECR images incur cross-AZ data transfer fees if the ECR VPC endpoint is not in the same AZ as the task. In high-scale environments, these charges accumulate. Audit cross-AZ traffic patterns before scaling out — use VPC endpoints for ECR and S3 to eliminate the bulk of it.

---

## Exercises

Answer before starting the integration exercise:

1. A `POST /api/orders` returns 200 but no `OrderCreated` event arrives in the SQS analytics queue. List three possible failure points in order of most to least likely.
2. You need to add a search-indexing service that must index every order created. It does not need to handle HTTP requests. How do you wire it into the existing architecture without modifying the order service?
3. Your ECS Fargate task can receive messages from SQS but cannot write items to DynamoDB. The task execution role is correctly configured. What do you check?

## Lab reference

Follow Day 13 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 13 — Full Reference Architecture
The service I found hardest to understand: ...
One thing I would design differently: ...
The debugging tool I reached for most: ...
```
