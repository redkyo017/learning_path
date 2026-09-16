# Day 40 Lab: ECS Cluster + CP + IS Task Definitions

## Overview

This Terraform lab creates the foundation of the WSO2 Fargate deployment:
- An ECS cluster with Container Insights enabled
- IAM execution and task roles (with least-privilege separation)
- Control Plane task definition (ports 9443, 9611, 9711)
- Identity Server task definition (ports 9443, 9763)
- CloudWatch log groups for both services

**Important:** This is an **authored lab**. You will NOT run `terraform apply`. This lab is for study and understanding only.

## Key Resources

### ECS Cluster
- Name: `{environment}-wso2` (default: `dev-wso2`)
- Capacity provider: FARGATE (not EC2)
- Container Insights: enabled (for advanced CloudWatch monitoring)

### IAM Roles

**Execution Role (`ecs_execution`):**
- Used by ECS agent at container startup
- Permissions: Pull ECR images, write CloudWatch logs
- Policy: AmazonECSTaskExecutionRolePolicy (AWS-managed)

**Task Role (`ecs_task`):**
- Used by container code at runtime
- Permissions: Read Secrets Manager for WSO2 keystores
- Resource: `arn:aws:secretsmanager:{region}:{account}:secret:{environment}/wso2/*`

**Why separate roles?**
- Principle of least privilege: execution role is short-lived; task role is long-lived.
- If container is compromised, attacker gets task role permissions only, not ECR access.

### Task Definitions

**Control Plane (CP):**
- CPU: 1024, Memory: 2048 MB
- Ports: 9443 (HTTPS), 9611 (event hub), 9711 (event hub)
- Health check: `curl https://localhost:9443/services/Version`
- Start period: 120 seconds (WSO2 boot time)

**Identity Server (IS):**
- CPU: 1024, Memory: 2048 MB
- Ports: 9443 (HTTPS), 9763 (HTTP)
- Health check: `curl -X HEAD https://localhost:9443/oauth2/token`
- Start period: 120 seconds
- **Why HEAD request?** `/oauth2/token` requires authentication, but the endpoint exists. HEAD returns 400, confirming IS is alive.

### CloudWatch Log Groups
- `/ecs/{environment}/wso2-cp` (7-day retention)
- `/ecs/{environment}/wso2-is` (7-day retention)

## Study Points

### 1. Why startPeriod = 120?

WSO2 components need time to initialize:
1. Container starts
2. WSO2 bootstrap runs (reads config, initializes caches, connects to datasources)
3. Health check first probe fires

If health checks start immediately (startPeriod = 0), they'll fail before WSO2 is ready, and ECS will replace the task. 120 seconds gives WSO2 breathing room.

### 2. CP Ports Explained

| Port | Purpose | Used By |
|------|---------|---------|
| 9443 | HTTPS API | GW, TM, other components |
| 9611 | Event hub (binary) | CP-to-CP sync, GW, TM |
| 9711 | Event hub (binary) | CP-to-CP sync, GW, TM |

Why two ports for event hub? Historically, 9611 and 9711 handle different event types or clustering protocols in WSO2.

### 3. IS Health Check: Why HEAD to /oauth2/token?

IS doesn't have a `/services/Version` endpoint like CP. The `/oauth2/token` endpoint is always present in the OAuth implementation. A HEAD request (no body, no authentication) returns 400, but proves IS is running and accepting HTTP requests.

Alternative: You could use `/services/Version` if IS has it (depends on IS version). Check your WSO2 IS documentation.

### 4. Execution Role vs. Task Role

**Question:** Why not just give the execution role all permissions, and use it for both startup and runtime?

**Answer:**
- Execution role is needed ONLY during container startup (pull image, write logs).
- Once the container is running, the task role takes over for AWS API calls inside the container.
- If the container is compromised at runtime, the attacker inherits the task role, not the execution role.
- By separating them, you limit the blast radius of a container compromise.

**Example:**
- Execution role has `secretsmanager:GetSecretValue` for startup secrets injection.
- Compromised container can read secrets (via task role).
- But compromised container CANNOT update ECR repo or delete logs (no execution role access).

## Variables to Customize

| Variable | Default | Notes |
|----------|---------|-------|
| `environment` | `dev` | Tag for resource names; e.g., `prod`, `staging`, `dev` |
| `aws_region` | `ap-southeast-1` | AWS region; change if deploying elsewhere |
| `aws_account_id` | `TODO_REPLACE_...` | Your AWS account ID (12 digits); required for Secrets Manager ARN |
| `image_uri_cp` | `TODO_REPLACE:wso2-cp:latest` | ECR image URI for CP; format: `123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/wso2-cp:latest` |
| `image_uri_is` | `TODO_REPLACE:wso2-is:latest` | ECR image URI for IS |

## Outputs

After studying the code, you can reference these outputs:
- `cluster_arn`: ARN of the ECS cluster (needed for ECS services in Day 41)
- `cp_task_def_arn`: ARN of CP task definition
- `is_task_def_arn`: ARN of IS task definition
- `ecs_task_role_arn`: ARN of the task role (useful for additional IAM policies)

## Next Steps

This lab is part of a 3-day series:
- **Day 40** (this): ECS cluster + CP + IS
- **Day 41**: Add GW + TM + ALB
- **Day 42**: Add security groups + autoscaling

The Terraform labs are cumulative. Day 41's `main.tf` will include all Day 40 resources plus new ones.

## Exercise Review

If you're stuck on the Day 40 content exercises, refer to:
- **Exercise 1 (Service Discovery):** CloudWatch log groups help you debug; filter by `activityid` (correlation ID) to track requests across services.
- **Exercise 2 (Startup Order):** Health checks enforce order implicitly; IS starts first (no deps), CP next, then GW and TM.
- **Exercise 3 (Task Restart):** New Fargate task = new ENI. Cloud Map DNS abstracts this; always use DNS names, never hardcoded IPs.
