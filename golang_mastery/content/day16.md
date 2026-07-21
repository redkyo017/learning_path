# Day 16 — AWS ECS Deployment

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Read and write an ECS Fargate task definition for a gRPC service
- Explain why gRPC requires HTTP/2 target groups on ALB and why plain HTTP fails
- Configure `grpc-health-probe` as the ECS container health check command
- Write a multi-stage Dockerfile that produces a minimal gRPC binary image
- Inject secrets and config into containers using SSM Parameter Store

---

## Core mental model

**ECS runs your container as a task — the health check is what ECS uses to know if the task is alive.**

ECS does not understand gRPC. It does not read your proto files or call your RPCs. It runs a health check command on a schedule, checks the exit code, and decides whether to route traffic to the task. If the health check fails consistently, ECS stops the task and starts a replacement.

The chain:

```
ECS task scheduler
  → runs container
    → runs healthCheck.command on an interval
      → grpc-health-probe calls grpc_health_v1.Health/Check
        → your gRPC health server responds SERVING
          → grpc-health-probe exits 0
            → ECS marks task HEALTHY
              → ALB routes traffic to task
```

If any link in this chain breaks (server not started, health proto not registered, grpc-health-probe not in the image), ECS marks the task UNHEALTHY and kills it.

---

## ECS Fargate task definition anatomy

A minimal task definition for a gRPC service:

```json
{
  "family": "payment-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn":      "arn:aws:iam::123456789012:role/paymentServiceTaskRole",
  "containerDefinitions": [
    {
      "name": "payment-service",
      "image": "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/payment-service:v1.2.3",
      "portMappings": [
        { "containerPort": 50051, "protocol": "tcp" }
      ],
      "environment": [
        { "name": "APP_ENV",  "value": "production" },
        { "name": "GRPC_PORT","value": "50051" }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:ssm:ap-southeast-1:123456789012:parameter/payment-service/prod/db-password"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:ssm:ap-southeast-1:123456789012:parameter/payment-service/prod/jwt-secret"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD",
          "/bin/grpc-health-probe",
          "-addr=:50051",
          "-service=payments.v1.PaymentService",
          "-connect-timeout=5s",
          "-rpc-timeout=5s"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 15
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group":         "/ecs/payment-service",
          "awslogs-region":        "ap-southeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Key fields explained

**`cpu` and `memory`**: Specified at the task level for Fargate. Valid CPU/memory combinations are not arbitrary — they follow a fixed table. Common values: 256 CPU / 512MB, 512 CPU / 1GB, 1024 CPU / 2GB. The CPU unit is 1/1024 of a vCPU (256 = 0.25 vCPU).

**`executionRoleArn`**: The role ECS uses to pull the image from ECR and fetch secrets from SSM. This is an ECS infrastructure role — it is not your application's role.

**`taskRoleArn`**: The role your running container code uses to call AWS services (S3, DynamoDB, SQS, etc.). Your application code uses this role. Missing this means `aws-sdk-go` credential resolution fails inside the container.

**`secrets`**: ECS fetches the SSM parameter value at task launch time and injects it as an environment variable. The `executionRoleArn` must have `ssm:GetParameters` permission on the parameter ARN. Secrets are never stored in the task definition itself.

**`healthCheck.startPeriod`**: Grace period after the container starts before health check failures count. Set this long enough for your gRPC server to start. A Go binary typically starts in under 1 second, but allow 15–30 seconds for cold starts on Fargate (image pull + container init).

---

## ALB + gRPC: HTTP/2 requirement

### Why plain HTTP fails for gRPC passthrough

gRPC uses HTTP/2 as its transport. HTTP/2 over plain TCP (h2c) is not the same as HTTP/2 over TLS (h2). ALB does not support h2c (HTTP/2 cleartext) for target groups — it only supports HTTP/2 when the backend connection uses HTTPS.

The failure mode without HTTPS: the ALB sends an HTTP/1.1 request to your gRPC backend. The backend expects an HTTP/2 binary framing preface (`PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n`), receives HTTP/1.1 text, and returns a protocol error. The ALB logs a 502 Bad Gateway.

### Required ALB configuration

| Component | Required setting | Common misconfiguration |
|-----------|-----------------|------------------------|
| Target group protocol | `HTTP` with protocol version `HTTP2` (not `GRPC`) | Protocol `HTTP` with version `HTTP1` — ALB sends HTTP/1.1 to backend |
| Target group protocol (alternative) | `GRPC` protocol version — use for gRPC-specific routing rules | Using `HTTP2` when you need gRPC-specific error handling |
| Listener | `HTTPS:443` with a valid ACM certificate | `HTTP:80` listener — gRPC clients will fail TLS handshake |
| Health check protocol | `HTTP` on the target port | `HTTPS` — unnecessary if TLS terminates at ALB, causes connection refused |
| Health check path | `/grpc.health.v1.Health/Check` | `/health` or `/` — ALB sends HTTP GET, not a gRPC call |
| Security group (target) | Allows ALB security group on gRPC port | Allows `0.0.0.0/0` (overly broad) or wrong port |
| Container port | Must match `containerPort` in task definition | Port mismatch causes immediate connection refused |

### The recommended architecture

```
Internet
  │
  ▼
ALB (HTTPS:443, ACM cert)
  │  TLS terminated at ALB
  │  ALB speaks HTTP/2 to backend (protocol version: HTTP2)
  │
  ▼
ECS Fargate task (HTTP on port 50051, plaintext inside VPC)
  │
  ▼
gRPC server (listens on :50051, no TLS)
```

TLS terminates at the ALB. Traffic inside the VPC between the ALB and ECS tasks is plaintext HTTP/2. This is the standard pattern for internal services. Your gRPC server does not need TLS certificates — `grpc.NewServer()` with no credentials options.

If your organisation requires end-to-end TLS (TLS between ALB and backend), you must configure TLS on your gRPC server with ACM Private CA certificates and use `HTTPS` as the target group protocol.

### Target group creation (AWS CLI)

```bash
aws elbv2 create-target-group \
  --name payment-service-grpc \
  --protocol HTTP \
  --protocol-version HTTP2 \
  --port 50051 \
  --target-type ip \
  --vpc-id vpc-0abc123 \
  --health-check-protocol HTTP \
  --health-check-path /grpc.health.v1.Health/Check \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 10 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3
```

Note: the ALB health check path `/grpc.health.v1.Health/Check` sends an HTTP GET, not a gRPC call. Your gRPC health server will return a 405 or protocol error to this HTTP GET, which causes the ALB health check to fail. **Use `grpc-health-probe` in the ECS container health check, not the ALB health check path, as the primary liveness signal.** Set the ALB health check to a simple HTTP endpoint or a gRPC-capable check if you're using ALB's native gRPC health check support.

---

## grpc-health-probe in ECS

`grpc-health-probe` is a standalone binary from `grpc-ecosystem/grpc-health-probe`. It speaks the `grpc_health_v1` protocol and exits with code 0 (healthy) or non-zero (unhealthy).

Include it in your Docker image:

```dockerfile
# In a multi-stage build, fetch grpc-health-probe
FROM alpine:3.20 AS health-probe
RUN apk add --no-cache curl && \
    curl -fsSL -o /bin/grpc-health-probe \
    "https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/v0.4.28/grpc_health_probe-linux-amd64" && \
    chmod +x /bin/grpc-health-probe
```

ECS task definition health check:

```json
"healthCheck": {
  "command": [
    "CMD",
    "/bin/grpc-health-probe",
    "-addr=:50051",
    "-service=payments.v1.PaymentService",
    "-connect-timeout=5s",
    "-rpc-timeout=5s"
  ],
  "interval": 30,
  "timeout": 10,
  "retries": 3,
  "startPeriod": 15
}
```

The `CMD` form passes arguments directly to the binary without a shell. Use `CMD` not `CMD-SHELL` for binaries — `CMD-SHELL` invokes `/bin/sh -c` which adds unnecessary overhead and requires shell escaping.

---

## Multi-stage Dockerfile for gRPC binary

```dockerfile
# ─── Stage 1: fetch grpc-health-probe ────────────────────────────────────────
FROM alpine:3.20 AS health-probe
RUN apk add --no-cache curl && \
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    curl -fsSL -o /bin/grpc-health-probe \
    "https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/v0.4.28/grpc_health_probe-linux-${ARCH}" && \
    chmod +x /bin/grpc-health-probe

# ─── Stage 2: build ──────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder
WORKDIR /app

# Cache dependency downloads separately from source build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /bin/payment-service \
    ./cmd/payment-service

# ─── Stage 3: runtime ────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

# Copy the health probe and binary
COPY --from=health-probe /bin/grpc-health-probe /bin/grpc-health-probe
COPY --from=builder      /bin/payment-service   /bin/payment-service

EXPOSE 50051

ENTRYPOINT ["/bin/payment-service"]
```

### Why each stage matters

**Stage 1 (health-probe):** Fetches the probe binary without polluting the runtime image with `curl` or Alpine package manager artifacts.

**Stage 2 (builder):** `CGO_ENABLED=0` produces a statically linked binary — no libc dependency. `-trimpath` removes build machine paths from the binary. `-ldflags="-s -w"` strips debug symbols and DWARF info, reducing binary size by 30-40%.

**Stage 3 (distroless):** `gcr.io/distroless/static-debian12:nonroot` has no shell, no package manager, no OS utilities — just the C library stubs a static binary needs. The `:nonroot` tag runs as UID 65532 by default, satisfying container security policies that forbid root.

Resulting image size: typically 15-25MB for a gRPC service vs 300-400MB for a golang:1.23 base image.

---

## Environment config via SSM Parameter Store

### Parameter naming convention

Use a hierarchical path: `/<service>/<env>/<key>`

```
/payment-service/production/db-password
/payment-service/production/jwt-secret
/payment-service/production/kafka-brokers
/payment-service/staging/db-password
```

This enables IAM policies to grant access to all parameters for a given service/environment with a single `arn:aws:ssm:region:account:parameter/payment-service/production/*` ARN pattern.

### IAM policy on the execution role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:ap-southeast-1:123456789012:parameter/payment-service/production/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt"],
      "Resource": "arn:aws:kms:ap-southeast-1:123456789012:key/mrk-abc123"
    }
  ]
}
```

The `kms:Decrypt` permission is required if parameters are `SecureString` type (encrypted with KMS). Without it, ECS fails to launch the task with a cryptic `CannotPullContainerError`.

### Reading config in Go

Since SSM secrets are injected as environment variables by ECS, your application code doesn't need the AWS SDK for config injection:

```go
dbPassword := os.Getenv("DB_PASSWORD")   // ECS injected this from SSM
jwtSecret  := os.Getenv("JWT_SECRET")
```

For config that changes at runtime (feature flags, dynamic limits), use `aws-sdk-go-v2` to read SSM directly:

```go
import (
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/ssm"
)

cfg, _ := config.LoadDefaultConfig(ctx)
client  := ssm.NewFromConfig(cfg)

out, err := client.GetParameter(ctx, &ssm.GetParameterInput{
    Name:           aws.String("/payment-service/production/feature-flags"),
    WithDecryption: aws.Bool(true),
})
```

---

## Returning engineer: what changed since 1.16–1.18

- **`grpc.Dial` vs `grpc.NewClient`**: If you're writing the client inside ECS and calling another service, use `grpc.NewClient`. The lazy connection semantics of `NewClient` are better for ECS startup — the service registers with the load balancer before making outbound connections.
- **Distroless is the new Alpine for Go binaries.** In the 1.16 era, Alpine was the standard small base image. Distroless provides a smaller attack surface (no shell, no package manager), and the `:nonroot` variant satisfies modern security scanning requirements.
- **`aws-sdk-go-v2` is the current SDK.** `aws-sdk-go` (v1) still works but is in maintenance mode. New ECS deployments should use v2: `github.com/aws/aws-sdk-go-v2/*`. The module layout changed significantly — instead of one giant SDK module, each service is a separate Go module.
- **ECS `secrets` field (SSM injection) was added in 2018** — if you last worked with ECS before that, you may have used environment variable overrides or a custom entrypoint script to fetch SSM parameters. The `secrets` field in the task definition does this natively at launch time.
- **ALB `protocol-version: GRPC`** is a newer feature (2020) that adds gRPC-specific routing rules (route by gRPC method, return gRPC-aware error responses). For basic deployments, `HTTP2` is simpler. Use `GRPC` when you need content-based gRPC routing.
- **ECR image scanning on push.** ECR now scans images for CVEs on push by default in many AWS organisations. A large builder layer (with `curl`, build tools) that leaks into the runtime image will generate findings. Multi-stage builds prevent this.

---

## Key concepts to memorize

- ECS health check exit code 0 = healthy; non-zero = unhealthy
- ALB requires `HTTP2` protocol version for gRPC — plain `HTTP` causes 502
- TLS terminates at ALB; backend container uses plaintext gRPC inside the VPC
- `grpc-health-probe` is a standalone binary — include it in the Docker image
- `CMD` not `CMD-SHELL` in ECS `healthCheck.command` — avoids shell overhead
- `executionRoleArn` = ECS infrastructure (ECR pull, SSM fetch); `taskRoleArn` = app AWS calls
- `KMS Decrypt` permission required on execution role for `SecureString` SSM parameters
- `startPeriod` in health check = grace period before failures count

---

## Common mistakes

**1. Using an HTTP target group instead of HTTP/2**

*Why it matters:* The ALB sends HTTP/1.1 to the gRPC backend. The Go gRPC server rejects the connection — it expects an HTTP/2 preface. ALB logs 502. The fix is one CLI command but the symptom (502 immediately on all requests) is confusing without knowing the root cause.

*How to avoid:* Always create the target group with `--protocol-version HTTP2`. Verify with `aws elbv2 describe-target-groups --target-group-arns <arn>` and check `ProtocolVersion`.

**2. Missing `grpc-health-probe` in the Docker image**

*Why it matters:* ECS tries to execute `/bin/grpc-health-probe` and gets "executable not found." The health check fails immediately, ECS marks the task unhealthy after `retries` attempts, and the task is replaced in a loop. Your service never serves traffic.

*How to avoid:* Include the probe fetch in a dedicated Docker stage. Verify the binary is present with a test build before pushing to ECR: `docker run --rm <image> /bin/grpc-health-probe --version`.

**3. Forgetting `kms:Decrypt` on the execution role**

*Why it matters:* ECS fails to launch the task entirely. The error `CannotPullContainerError: ResourceInitializationError: unable to pull secrets or registry auth` is confusing because "pull" implies an image pull failure, not a KMS decryption failure.

*How to avoid:* For any `SecureString` SSM parameter, always include `kms:Decrypt` on the KMS key ARN in the execution role policy. Add it as a standard template in your task definition CDK/Terraform module.

**4. Setting `healthCheck.timeout` greater than `interval`**

*Why it matters:* If `timeout = 30` and `interval = 30`, the health check probe never finishes before the next one starts. ECS queues checks and quickly accumulates failures, killing healthy tasks.

*How to avoid:* Keep `timeout < interval` with headroom. A common safe config: `interval=30, timeout=10`. The probe should respond in under 1 second for a healthy service.

**5. Using the same IAM role for `executionRoleArn` and `taskRoleArn`**

*Why it matters:* The execution role has `ssm:GetParameters` and `ecr:GetAuthorizationToken` permissions — these are ECS infrastructure permissions. If your application code uses this role (because both ARNs point to the same role), it inherits those permissions, violating least-privilege. A compromised container could enumerate your SSM parameters.

*How to avoid:* Always create two separate IAM roles. The execution role is managed by the platform team. The task role is owned by the service team and has only what the application code needs (e.g., `sqs:SendMessage`, `dynamodb:PutItem`).

---

## Check your understanding

1. Your ECS task fails to start with `ResourceInitializationError: unable to pull secrets`. You have confirmed the SSM parameter ARN in the task definition is correct. List the two most likely IAM causes and which IAM role (execution vs task) you would check for each.

2. After deploying a new version, the ALB returns 502 for all gRPC calls but the ECS tasks are marked HEALTHY. What is the most likely misconfiguration on the ALB/target group, and what CLI command verifies it?

3. Your gRPC service starts and the health check passes, but gRPC clients connecting through the ALB get `UNAVAILABLE: transport: connection error: code = Unavailable`. The service works fine when clients connect directly to the Fargate task IP. What property of the ALB listener is almost certainly wrong?
