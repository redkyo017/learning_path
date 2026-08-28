# Day 3 Lab — Egress + VPC Boundary Patterns

## Scenario

A payment processor Lambda runs in a private subnet and currently routes all outbound traffic through a NAT Gateway. It writes transaction logs to S3 and sends audit events to SQS. A separate card vault service needs to be reachable from the payment VPC without internet traversal and without VPC peering (PCI DSS scope constraint).

**Your goals:**
1. Eliminate the NAT Gateway dependency for S3 and SQS by replacing it with a Gateway Endpoint and an Interface Endpoint.
2. Add a PrivateLink connection from the consumer VPC to a mock card vault service running in a second (provider) VPC — simulating a cross-account PrivateLink setup within a single account.

---

## Architecture

```
CONSUMER VPC (10.0.0.0/16)                PROVIDER VPC (10.1.0.0/16)
┌──────────────────────────────┐          ┌──────────────────────────────┐
│                              │          │                              │
│  Private subnet (10.0.1.0/24)│          │  Private subnet (10.1.1.0/24)│
│  ┌──────────────────────┐    │          │  ┌──────────────────────┐    │
│  │  Lambda (payment      │    │          │  │  Mock card vault EC2  │    │
│  │  processor)           │    │          │  │  (HTTP on port 443)   │    │
│  └──────┬───────────────┘    │          │  └──────────┬───────────┘    │
│         │                    │          │             │                │
│  ┌──────▼────────────────┐   │          │  ┌──────────▼───────────┐    │
│  │  Interface Endpoint   │   │          │  │  NLB                  │    │
│  │  (vault service)      │◄──┼──────────┼──│  (TCP 443)            │    │
│  └───────────────────────┘   │PrivateLink│  └──────────────────────┘    │
│                              │          │             │                │
│  ┌───────────────────────┐   │          │  VPC Endpoint Service        │
│  │  Gateway Endpoint     │   │          │  (accepts consumer endpoint) │
│  │  (S3 — free)          │───┼──────────┼────────► S3 (AWS backbone)   │
│  └───────────────────────┘   │          └──────────────────────────────┘
│                              │
│  ┌───────────────────────┐   │
│  │  Interface Endpoint   │───┼──────────────► SQS (AWS backbone)
│  │  (SQS — private DNS)  │   │
│  └───────────────────────┘   │
│                              │
│  No NAT Gateway              │
│  No Internet Gateway         │
└──────────────────────────────┘
```

**Key observations:**
- The consumer VPC has no NAT Gateway and no Internet Gateway. Lambda can only reach services via VPC Endpoints.
- S3 is reached via a Gateway Endpoint — no ENI, no DNS change, free.
- SQS is reached via an Interface Endpoint — an ENI with a private IP. `private_dns_enabled = true` means Lambda calls `sqs.region.amazonaws.com` and DNS resolves to the ENI private IP automatically.
- The vault service is reached via PrivateLink — the consumer Interface Endpoint connects to the provider's VPC Endpoint Service backed by an NLB.
- VPC Flow Logs capture all traffic for the Break it exercise.

---

## Prerequisites

- Terraform >= 1.5
- AWS credentials with permissions to create VPCs, subnets, Lambda, IAM roles, VPC Endpoints, EC2, NLB, and CloudWatch Logs.
- No real credentials should be committed — use environment variables or AWS SSO.

---

## Steps

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values.
2. Run `terraform init` then `terraform plan` to review the resources.
3. Run `terraform apply` to deploy.
4. Observe the Lambda test invocation result in CloudWatch Logs — it should write to S3 and publish to SQS successfully.
5. Check VPC Flow Logs in CloudWatch — confirm no traffic flows to an internet gateway or NAT gateway for S3/SQS calls.
6. Attempt the Break it exercise below.
7. Run teardown per `teardown.md` when finished.

---

## Break it exercise

**Delete the SQS Interface Endpoint.** With no NAT Gateway and no SQS Interface Endpoint, invoke the Lambda again.

Questions to answer:
- Does the Lambda invocation time out, receive a connection refused, or receive a specific AWS SDK error?
- Does the error message indicate a DNS failure, a TCP connection failure, or an HTTP-level error?
- Does the S3 write succeed while the SQS publish fails, or do both fail?
- Look at VPC Flow Logs — do you see any traffic attempting to leave the VPC, or does it drop silently?

**What to expect:** Because `private_dns_enabled = true` is set on the Interface Endpoint, deleting the endpoint causes `sqs.region.amazonaws.com` to fall back to the public DNS IP. In the consumer VPC (no internet gateway), TCP to the public SQS endpoint is dropped silently — no RST, no ICMP unreachable. The Lambda SDK retries its configured number of times, then raises a connection timeout error. S3 continues to work because the Gateway Endpoint is still in the route table. This demonstrates that VPC Endpoints are not optional in isolated subnets — they are the only path out.

See `SOLUTION.md` for the full explanation and the Break it answer.

---

## Files in this lab

| File | Purpose |
|------|---------|
| `main.tf` | All AWS resources |
| `variables.tf` | Input variable declarations |
| `terraform.tfvars.example` | Example values (copy to terraform.tfvars) |
| `SOLUTION.md` | Explanation of mechanics and Break it answer |
| `teardown.md` | Teardown checklist with cost reminders |
