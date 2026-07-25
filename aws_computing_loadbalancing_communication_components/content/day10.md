# Day 10 — EventBridge

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Distinguish default, custom, and partner event buses and explain when to use each
- Write an event pattern that matches on `detail-type` and a nested field inside `detail`
- Explain the EventBridge vs SNS decision in concrete terms
- Configure a DLQ for failed target invocations and explain what is captured there
- Describe how cross-account event delivery works at the resource policy level

---

## The router mental model

Before touching the console, internalise this framework:

> **EventBridge is a router for events. Publishers put events on a bus. Rules match events by content and route them to targets. Publishers don't know about targets; targets don't know about publishers. This is the purest form of decoupling: the only shared contract is the event schema.**

Compare this to SNS: an SNS publisher knows the topic ARN and calls `Publish`. With EventBridge, the publisher calls `PutEvents` on a bus — it has no knowledge of which rules exist or which targets will receive the event. Rules are owned by the consuming team, not the producing team. Adding a new consumer requires no change to the producer.

---

## Event buses

Three types, each with a different ownership model:

**Default bus** receives events from over 100 AWS services automatically: EC2 instance state changes, S3 object creation, CodePipeline stage transitions, ECS task state changes, and more. Every account has exactly one default bus — it cannot be deleted. AWS writes to the default bus; you create rules to react.

**Custom bus** is your application's event channel. Best practice is to keep application events on a custom bus and AWS service events on the default bus. Benefits: cleaner rule management, clearer ownership, separate resource policies for cross-account access, and the ability to grant other accounts permission to publish to a specific bus without opening the default bus.

**Partner bus** ingests events from third-party SaaS providers — Zendesk, GitHub, Salesforce, PagerDuty, and others. The SaaS provider publishes to your account's partner event source; you create rules on the partner bus to react. No credentials or polling infrastructure required on your side.

---

## Event structure

All EventBridge events — from AWS services, your application, or SaaS partners — follow the same envelope:

```json
{
  "version": "0",
  "id": "uuid",
  "source": "com.myapp.orders",
  "account": "123456789",
  "time": "2026-07-23T10:00:00Z",
  "region": "ap-southeast-1",
  "detail-type": "OrderCreated",
  "detail": {
    "orderId": "123",
    "amount": 99.99,
    "status": "pending"
  }
}
```

**`source`:** publisher identifier. For AWS services this is fixed (e.g., `aws.ec2`, `aws.s3`). For custom events you choose — use reverse-DNS notation (`com.myapp.orders`).

**`detail-type`:** the event category within a source. Equivalent to a subject line. Keep it specific: `OrderCreated` is better than `Event`.

**`detail`:** your payload. Any valid JSON object. This is where your event data lives — and where event patterns do their most specific matching.

---

## Rules and event patterns

A rule has three components: the event bus it monitors, an event pattern (or schedule), and up to 5 targets.

**Event patterns** are JSON documents that describe which events to match. A pattern matches an event if every field in the pattern matches the corresponding field in the event envelope. Fields not in the pattern are ignored.

Common pattern forms:

- **Match by detail-type:**
  ```json
  {"detail-type": ["OrderCreated"]}
  ```

- **Match by source and a nested detail field:**
  ```json
  {
    "source": ["com.myapp.orders"],
    "detail": {"status": ["pending"]}
  }
  ```

- **Prefix match:**
  ```json
  {"source": [{"prefix": "com.myapp"}]}
  ```

- **Anything-but:**
  ```json
  {"detail-type": [{"anything-but": "HealthCheck"}]}
  ```

- **Numeric range on a detail field:**
  ```json
  {"detail": {"amount": [{"numeric": [">", 100]}]}}
  ```

**Schedule rules** do not use event patterns. They fire on a cron expression (`cron(0 9 * * ? *)`) or rate (`rate(5 minutes)`) and invoke targets directly with a generated event.

**The most common pattern mistake:** writing `{"status": ["pending"]}` when `status` lives inside `detail`. The top-level envelope has no `status` field; the pattern never matches. The correct form is `{"detail": {"status": ["pending"]}}`. Validate patterns with the "Test event pattern" feature in the EventBridge console before deploying.

---

## Targets and IAM

Each rule can invoke up to 5 targets simultaneously. Supported targets include: SQS, Lambda, ECS task, Step Functions state machine, SNS topic, Kinesis Data Stream, API Gateway endpoint, and another EventBridge bus (for cross-account routing).

**EventBridge requires an IAM role** with permission to call the target. The role is specified on the rule.

Common permissions required by target type:

| Target | Required permission |
|---|---|
| SQS | `sqs:SendMessage` on the queue |
| Lambda | `lambda:InvokeFunction` (or a Lambda resource policy granting `events.amazonaws.com`) |
| ECS task | `ecs:RunTask` + `iam:PassRole` (for both the task execution role and the task role) |
| Step Functions | `states:StartExecution` |

**ECS requires two permissions because EventBridge must both run the task and hand off the task role to it.** `ecs:RunTask` allows the API call; `iam:PassRole` allows EventBridge to bind the execution role and task role to the launched task. Missing either one causes invocation failure.

**Missing permissions are the most common Day 10 failure.** The invocation fails silently in the EventBridge console — no red error indicator on the rule. Diagnose via CloudWatch `FailedInvocations` metric on the rule and CloudTrail `AccessDenied` events for the target API call.

---

## DLQ for failed target invocations

EventBridge retries failed target invocations for up to 24 hours with exponential backoff. If delivery still fails after all retries, the event is discarded — unless you have configured a DLQ.

Configure a DLQ (SQS queue) on the **target**, not on the rule. The DLQ captures events that could not be delivered after all retries. Each failed event lands in the DLQ with metadata that records the failure reason — this is your diagnostic record.

**Without a DLQ, events that fail delivery after 24 hours of retries are permanently lost with no audit trail.** Always configure a DLQ on production targets. Alarm on DLQ depth > 0.

---

## EventBridge vs SNS

| | EventBridge | SNS |
|---|---|---|
| Routing logic | Content-based (match any JSON field in envelope or detail) | Topic-based (subscribe to a topic ARN) |
| Publisher coupling | Publisher knows only the bus; rules are owned by consumers | Publisher knows the topic ARN |
| AWS service events | Yes (default bus receives 100+ service events natively) | No |
| Cross-account | Yes (resource policy on target bus) | Yes |
| Throughput | 10,000 events/s default (soft limit, raiseable) | Unlimited |
| Schema registry | Yes (auto-discover schemas, generate code bindings) | No |
| Use when | Content-based routing, microservices decoupling, reacting to AWS service events, cross-account event mesh | Simple fan-out, push to email/SMS/mobile push |

The key distinction: with SNS, the publisher owns the routing decision — which topic to publish to. With EventBridge, the consuming team owns the routing decision — which rules to create. For a platform with many producers and many consumers each interested in different subsets of events, EventBridge scales the coordination cost better: adding a new consumer requires no change to any producer.

---

## Schema registry

EventBridge can auto-discover schemas from events published to a bus and store them in a schema registry. The registry can then generate code bindings for the event struct in Go, Python, Java, and TypeScript.

This provides a formal contract between teams: the producing team generates the schema from their live events; the consuming team imports the binding and gets compile-time type checking. Schema mismatches surface at build time, not in production. Schemas are versioned — you can track breaking changes over time.

Enable schema discovery on your custom bus in the EventBridge console. There is a small per-event charge for schema discovery; disable it after initial setup if cost is a concern.

---

## Best practices

- **Use a custom bus for application events** — keeps app events separate from the AWS service events on the default bus. Cleaner rule management, clearer team ownership, and separate per-bus resource policies for cross-account access.
- **Always configure a DLQ on production targets** — without it, events that fail delivery after 24 hours of retries are permanently lost with no record.
- **Use the schema registry for cross-team event contracts** — prevents attribute name mismatches from causing silent routing failures at the filter or pattern layer.
- **Match on `detail-type` first, then narrow with `detail` fields** — `detail-type` is the most selective single-field match and makes patterns readable at a glance.

---

## Common pitfalls

- **IAM role missing target permission.** Invocation fails silently — no error in the EventBridge rule console view. Diagnose via CloudWatch `FailedInvocations` metric and CloudTrail `AccessDenied` events for the target service.
- **Event pattern field path mismatch.** Writing `{"status": ["failed"]}` instead of `{"detail": {"status": ["failed"]}}` — the rule never fires because the top-level envelope has no `status` field. Use the console's "Test event pattern" feature before deploying.
- **No DLQ on production targets.** Failed events disappear after 24 hours of retries with no audit trail and no alarm.
- **Confusing schedule rules with event pattern rules.** Schedule rules fire on time (cron/rate) and generate a synthetic event — there is no `detail` from a real publisher. Applying an event pattern to a schedule rule prevents it from ever firing.

---

## Exercises

Answer before starting the lab:

1. Write an event pattern that matches only events from source `com.myapp.orders` where `detail.status` equals `"failed"` or `"cancelled"`.
2. Your EventBridge rule targets an ECS task. The task never launches. CloudWatch shows `FailedInvocations` on the rule. What two IAM permissions do you check first, and why does ECS require two separate permissions rather than one?
3. You want your application to react when an EC2 Auto Scaling group terminates an instance. Which event bus do you use? What is the `source` and likely `detail-type` of the event?
4. You have 3 services publishing events and 5 services consuming them, each interested in a different subset. Why is EventBridge a better fit than 3 SNS topics for this scenario?

## Lab reference

Follow Day 10 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 10 — EventBridge
Key concept — event pattern field path: ...
When would I use SNS instead of EventBridge: ...
Break-it — what I observed when the IAM role was missing ecs:RunTask: ...
```
