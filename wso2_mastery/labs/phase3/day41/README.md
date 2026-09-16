# Day 41 Lab: GW + TM Task Definitions + ALB

## Overview

This Terraform lab includes **all Day 40 resources** (ECS cluster, CP, IS) **plus**:
- Universal Gateway (GW) task definition
- Traffic Manager (TM) task definition
- Application Load Balancer (ALB) for GW
- ALB target group and listeners (HTTPS + HTTP redirect)
- ALB security group

**Important:** This is an **authored lab**. You will NOT run `terraform apply`. This lab is for study and understanding only.

## Key Day 41 Resources

### GW Task Definition
- CPU: 1024, Memory: 2048 MB
- Ports: 8280 (HTTP), 8243 (HTTPS)
- Health check: `curl https://localhost:8243/services/Version`
- Start period: 90 seconds (faster than CP because GW is stateless)
- Environment variables:
  - `WSO2_CP_URL`: Points to CP via Cloud Map DNS
  - `WSO2_IS_URL`: Points to IS via Cloud Map DNS

### TM Task Definition
- CPU: 512, Memory: 1024 MB (smaller than CP/IS/GW)
- Ports: 9611, 9711 (event hub), 9443 (management)
- Health check: `curl https://localhost:9443/services/Version`
- Start period: 120 seconds

### ALB (Application Load Balancer)
- **Listener on port 443 (HTTPS):**
  - SSL policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2+)
  - Certificate: ACM certificate (provided via `acm_certificate_arn`)
  - Target group: port 8243 (GW HTTPS)

- **Listener on port 80 (HTTP):**
  - Redirect to 443 (HTTP → HTTPS)

- **Target group:**
  - Port: 8243
  - Protocol: HTTPS (connects to container on 8243)
  - Health check: `/services/Version` every 30 seconds
  - Healthy threshold: 2 successful checks
  - Unhealthy threshold: 3 failed checks

### ALB Security Group
- **Ingress 443:** Allow HTTPS from 0.0.0.0/0 (internet)
- **Ingress 80:** Allow HTTP from 0.0.0.0/0 (internet) — redirects to HTTPS
- **Egress:** Allow all outbound (to reach GW tasks in private subnets)

## Study Points

### 1. Why Does GW Have startPeriod = 90 (Not 120)?

**Comparison:**
- CP: 120 seconds (needs to initialize API registry)
- IS: 120 seconds (needs to initialize OAuth store)
- GW: 90 seconds (stateless, just proxies)

GW boots faster because it doesn't maintain state. It can fetch API registry and JWKS from CP and IS during startup.

### 2. ALB Target Group Protocol: HTTPS (Not HTTP)

The ALB connects to GW on port 8243 using **HTTPS**, not HTTP. This means:
- ALB sends encrypted traffic to the container.
- The container (GW) must have an HTTPS certificate on port 8243.
- This is internal encryption (ALB → GW inside the VPC).

**Why not HTTP?** WSO2 components use HTTPS internally for security. The ALB respects this and also uses HTTPS when connecting to the target.

### 3. Health Check Path: /services/Version

WSO2 provides this built-in endpoint for health checks. It returns a JSON payload with version info:
```json
{
  "productVersion": "4.2.0",
  "productName": "WSO2 API Gateway"
}
```

The ALB checks:
- Status code 200?
- Response received within 5 seconds?
- 2 consecutive successes = healthy target
- 3 consecutive failures = unhealthy target

### 4. Cloud Map DNS in GW Environment

GW's environment includes:
```
WSO2_CP_URL=https://cp.wso2.internal:9443
WSO2_IS_URL=https://is.wso2.internal:9443
```

These DNS names are resolved by Route 53 private hosted zone inside the VPC:
- `cp.wso2.internal` → 10.0.11.50 (CP task's private IP)
- `is.wso2.internal` → 10.0.12.30 (IS task's private IP)

GW doesn't go through the ALB to reach CP or IS. It goes directly via DNS.

### 5. Why ALB Listener Has Both HTTP and HTTPS

- **HTTPS (443):** Real API traffic; encrypted.
- **HTTP (80):** Redirect only. Users hit `http://api.example.com`, ALB redirects to `https://api.example.com`.

This is a common pattern: HTTP is never used for actual API traffic, only for redirects.

## Variables to Customize

| Variable | Default | Notes |
|----------|---------|-------|
| `environment` | `dev` | Tag for resource names |
| `aws_region` | `ap-southeast-1` | AWS region |
| `aws_account_id` | `TODO_REPLACE_...` | Your AWS account ID |
| `image_uri_cp` | `TODO_REPLACE:wso2-cp:latest` | ECR image URI for CP |
| `image_uri_is` | `TODO_REPLACE:wso2-is:latest` | ECR image URI for IS |
| `image_uri_gw` | `TODO_REPLACE:wso2-gw:latest` | ECR image URI for GW |
| `image_uri_tm` | `TODO_REPLACE:wso2-tm:latest` | ECR image URI for TM |
| `vpc_id` | `TODO_REPLACE_...` | Your VPC ID (10.0.0.0/16) |
| `public_subnet_ids` | `TODO_REPLACE_...` | Public subnets for ALB (2 subnets recommended) |
| `acm_certificate_arn` | `TODO_REPLACE_...` | ACM certificate ARN (from AWS Certificate Manager) |

### How to Find ACM Certificate ARN

```bash
aws acm list-certificates --region ap-southeast-1
# Output: CertificateArn: arn:aws:acm:ap-southeast-1:123456789012:certificate/abc123...
```

Or create a self-signed certificate for testing (not for production):
```bash
aws acm request-certificate \
  --domain-name api.example.com \
  --validation-method DNS \
  --region ap-southeast-1
```

## Outputs

- `alb_dns_name`: The DNS name of the ALB (e.g., `dev-wso2-gw-1234.ap-southeast-1.elb.amazonaws.com`)
- `alb_security_group_id`: Security group ID of the ALB
- `gw_task_def_arn`: ARN of GW task definition
- `tm_task_def_arn`: ARN of TM task definition
- All Day 40 outputs (cluster, CP, IS)

## Next Steps

This lab is part of a 3-day series:
- **Day 40**: ECS cluster + CP + IS
- **Day 41** (this): Add GW + TM + ALB
- **Day 42**: Add security groups + autoscaling

Day 42's main.tf will include all Day 41 resources plus security group rules and autoscaling policies.

## Exercise Review

If you're stuck on the Day 41 content exercises:
- **Exercise 1 (Why No ALB for CP):** Only GW is public; CP is internal. Use Cloud Map DNS for internal communication.
- **Exercise 2 (Health Check Fails):** Check startPeriod, security groups, and WSO2 logs.
- **Exercise 3 (Service Discovery vs ALB):** Cloud Map gives direct IP routing (low latency); ALB adds a hop and is for external clients only.
