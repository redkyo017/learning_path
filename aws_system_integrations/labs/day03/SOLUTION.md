# Day 3 Lab — Solution and Explanation

## Gateway Endpoint vs Interface Endpoint: the core difference

These two endpoint types solve the same problem (private path to an AWS service) through completely different mechanisms:

| | Gateway Endpoint | Interface Endpoint |
|---|---|---|
| **Implementation** | Route table entry | ENI with private IP in your subnet |
| **DNS change** | None — works via routing | `private_dns_enabled=true` overrides public DNS |
| **Services covered** | S3, DynamoDB only | 100+ AWS services |
| **Cost** | Free | $0.01/hr per AZ + $0.01/GB |
| **Availability** | Tied to route table | Tied to subnet; one ENI per AZ |
| **Security group** | Not applicable | Required — controls inbound to ENI |
| **Endpoint policy** | Supported | Supported |

**Gateway Endpoint works by routing:** When your Lambda calls `s3.amazonaws.com`, the DNS resolves to S3's public IPs as usual. But before the packet leaves the subnet, the route table is checked. A prefix-list entry (`pl-xxxxxxxx` — the S3 managed prefix list for your region) matches the destination IP and redirects the packet to the gateway endpoint, keeping it on the AWS backbone. No DNS override, no ENI — just a routing shortcut.

**Interface Endpoint works by DNS override:** When `private_dns_enabled = true`, a private hosted zone is automatically created in your VPC. `sqs.ap-southeast-1.amazonaws.com` resolves to the ENI's private IP instead of the public SQS IP. The Lambda SDK calls the same endpoint URL it always has — the DNS change is invisible to the application. The packet goes to the ENI → VPC Endpoint → SQS on the backbone.

---

## Private DNS override — what actually happens

When you create an Interface Endpoint with `private_dns_enabled = true`:

1. AWS creates a private hosted zone for the service's regional DNS name (e.g., `sqs.ap-southeast-1.amazonaws.com`).
2. It associates that private zone with your VPC.
3. Inside the VPC, Route 53 resolver (at `169.254.169.253`) returns the ENI's private IP for that hostname.
4. Outside the VPC, the public DNS returns SQS's public IP, as normal.

This is split-horizon DNS at the service level. The Lambda SDK does not need any endpoint URL override — `boto3.client('sqs')` works exactly as before. The private resolution is automatic.

**Requirement:** The VPC must have `enable_dns_support = true` and `enable_dns_hostnames = true`. Both are set in `main.tf`. Without them, private DNS override does not function.

---

## PrivateLink cross-account flow

In a real cross-account setup (versus this single-account simulation):

```
Account A (provider / card vault)           Account B (consumer / payment processor)
─────────────────────────────────           ──────────────────────────────────────────
1. Create NLB in front of vault service
2. Create VPC Endpoint Service (NLB ARN)
   acceptance_required = true
   allowed_principals = [Account B role]
                                            3. Create Interface Endpoint:
                                               service_name = Account A's service name
                                               State: pending-acceptance

4. Approve endpoint request
   (aws_vpc_endpoint_connection_accepter
    or manual approval in console)
                                               State: available

                                            5. DNS record in private hosted zone:
                                               vault.internal.bank.com →
                                               endpoint DNS name
                                               (resolves to ENI private IP)
```

Key points:
- No VPC CIDRs need to be shared or non-overlapping — PrivateLink uses the ENI, not routing.
- Account A never sees Account B's VPC — only the endpoint connection request.
- Endpoint policy in Account A scopes what Account B can call: specific actions on specific resources.
- Account B IAM policies scope what roles in Account B can use the endpoint.
- For a real vault, the allowed actions would be `kms:Decrypt` and `kms:GenerateDataKey` only — not `kms:*`.

---

## Break it answer

**What happens when you delete the SQS Interface Endpoint:**

1. DNS for `sqs.ap-southeast-1.amazonaws.com` inside the VPC immediately falls back to the public SQS IP (the private hosted zone entry is removed with the endpoint).
2. The Lambda SDK resolves the public SQS IP and attempts a TCP connection to port 443.
3. The consumer VPC has no internet gateway and no NAT gateway. The TCP SYN packet reaches no route and is dropped by the VPC without an RST or ICMP unreachable.
4. The AWS SDK connection attempt times out after its configured timeout (default: ~5 seconds per attempt, 3 attempts). Lambda eventually raises: `EndpointConnectionError: Could not connect to the endpoint URL: "https://sqs.ap-southeast-1.amazonaws.com/..."` or `Connection timeout`.
5. S3 writes continue to succeed — the Gateway Endpoint is a route table entry, not an ENI, and it remains in place.

**This is not a 403 or authorization error** — the connection drops at the TCP layer before any HTTP request is made. This is a key debugging distinction: if you see a 403, the packet reached SQS but IAM policy denied it. If you see a timeout, the packet never reached SQS — it is a network path problem.

**VPC Flow Logs observation:** With no endpoint, the flow log shows SYN packets from the Lambda ENI to the public SQS IP with `REJECT` or no ACCEPT record. The traffic is dropped inside the VPC — it never even attempts to exit. This confirms that the isolated subnet (no IGW, no NAT) is truly isolated.

**The lesson:** VPC Endpoints are not optional in isolated private subnets. They are the only egress path. Forgetting to create an endpoint for a service results in silent connection failures, not helpful error messages.

---

## Cost comparison: NAT Gateway vs Interface Endpoints (100 GB/month, 2 AZs)

| Component | NAT Gateway (1 per AZ) | Interface Endpoints (2 AZs) |
|-----------|----------------------|------------------------------|
| Fixed hourly cost | $0.045/hr × 2 × 730 = **$65.70/mo** | $0.01/hr × 2 endpoints × 2 AZs × 730 = **$29.20/mo** |
| Data processing (100 GB) | $0.045 × 100 = **$4.50** | $0.01 × 100 = **$1.00** |
| **Total** | **$70.20/mo** | **$30.20/mo** |
| PCI scope impact | Traffic on internet-routable path | Traffic stays on AWS backbone |

Replacing NAT with Interface Endpoints for two services (SQS and SNS in this example) saves ~$40/month and removes the PCI scope concern. At higher traffic volumes (1 TB/month), the savings are proportionally larger: NAT processing at 1 TB = $45; endpoint processing = $10.

Gateway Endpoint for S3 is free and has no data processing charge — replacing NAT for S3 saves the full $0.045/GB NAT processing cost with no downside.

---

## Terraform design notes

**`private_dns_enabled = true` requires two VPC settings:**
```hcl
enable_dns_support   = true  # allows Route 53 resolver
enable_dns_hostnames = true  # required for endpoint DNS to work
```
Both are set in `main.tf`. Forgetting these is a common source of "why isn't private DNS working" bugs.

**S3 bucket policy `DenyNonVpcEndpointAccess`:**
The bucket policy in `main.tf` uses a `Deny` on all access unless `aws:SourceVpce` matches the Gateway Endpoint ID. This means even if someone has valid IAM credentials, they cannot access the bucket from outside the VPC. This is a defense-in-depth control important for PCI environments.

**`acceptance_required = false` in the Endpoint Service:**
In this single-account lab, auto-acceptance is used for simplicity. In production cross-account PrivateLink, always set `acceptance_required = true` and use `aws_vpc_endpoint_connection_accepter` to approve specific requests — or automate approval only for known principals.
