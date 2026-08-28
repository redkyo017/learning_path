# Day 1 Lab — Mobile Banking BFF on API Gateway

## Scenario

A mobile banking app needs a single `/summary` endpoint that returns both account balance and the last 5 transactions in one HTTP call. The endpoint must:

- Require a JWT Bearer token (returns 401 without one)
- Enforce rate limiting (returns 429 when exceeded)
- Aggregate responses from two independent backend services concurrently

Backend services are simulated by two mock Lambda functions that return hardcoded JSON. This removes the need for a real banking backend while teaching the integration wiring.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Client (curl / mobile app)                                         │
│     GET /summary                                                     │
│     Authorization: Bearer <token>                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  API Gateway HTTP API  (aws_apigatewayv2_api)                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Stage: $default                                             │   │
│  │  Throttle: 10 req/s (burst: 20)                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Lambda Authorizer  (jwt_authorizer)                         │   │
│  │  Accepts any non-empty Bearer token (lab simplification)     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Route: GET /summary → Integration → BFF Lambda              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  BFF Aggregator Lambda  (bff_aggregator)                            │
│  Invokes both mocks concurrently (ThreadPoolExecutor)               │
│  Merges responses into: { "balance": ..., "transactions": [...] }   │
└──────────────────┬──────────────────────────┬───────────────────────┘
                   │                          │
          ┌────────▼────────┐        ┌────────▼────────┐
          │  Account Mock   │        │  Transaction    │
          │  Lambda         │        │  Mock Lambda    │
          │  Returns:       │        │  Returns:       │
          │  { "balance":   │        │  { "transactions│
          │    12450.00 }   │        │    ": [...] }   │
          └─────────────────┘        └─────────────────┘
```

---

## Prerequisites

- AWS CLI configured with a profile that has IAM, Lambda, and API Gateway permissions
- Terraform >= 1.5 installed (`terraform version`)
- `jq` installed for parsing JSON responses (`brew install jq` on macOS)
- An AWS account — this lab uses only free-tier-covered resources at lab volume

---

## What you will build

| Resource | Type | Purpose |
|---|---|---|
| `lab-day01-account-mock` | Lambda (Python 3.12) | Returns hardcoded account balance JSON |
| `lab-day01-transaction-mock` | Lambda (Python 3.12) | Returns hardcoded transaction list JSON |
| `lab-day01-bff-aggregator` | Lambda (Python 3.12) | Fans out to both mocks, merges response |
| `lab-day01-jwt-authorizer` | Lambda (Python 3.12) | Validates Bearer token, returns IAM policy |
| `lab-day01-banking-bff` | API Gateway HTTP API | Entry point for all client calls |
| `lab-day01-lambda-exec-role` | IAM Role | Execution role shared by all Lambdas |

---

## Lab steps

### 1. Initialise Terraform

```bash
cd labs/day01/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if you want a different region
terraform init
```

### 2. Review the plan

```bash
terraform plan
```

Verify that only the resources listed in the table above appear. There should be no unexpected IAM policies or networking resources.

### 3. Apply

```bash
terraform apply
```

Note the `api_endpoint` output value — this is your base URL.

### 4. Smoke test — missing auth returns 401

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://<api-id>.execute-api.<region>.amazonaws.com/summary
# Expected: 401
```

### 5. Smoke test — valid Bearer token returns merged JSON

```bash
curl -s \
  -H "Authorization: Bearer any-non-empty-token" \
  https://<api-id>.execute-api.<region>.amazonaws.com/summary | jq .
# Expected:
# {
#   "balance": 12450.00,
#   "transactions": [
#     { "id": "tx001", "amount": -45.00, "description": "Coffee" },
#     ...
#   ]
# }
```

### 6. Smoke test — rate limit returns 429

```bash
# Fire 50 requests in parallel — a sequential curl loop rarely exceeds
# the 10 req/s throttle, so parallelism is needed to trigger 429s.
seq 1 50 | xargs -P 25 -I {} curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer token" \
  https://<api-id>.execute-api.<region>.amazonaws.com/summary | sort | uniq -c
# Expected: a mix of 200s and 429s once the burst bucket (20) is exhausted
```

---

## Goal

A single authenticated `curl` call to `/summary` returns a merged JSON object:

```json
{
  "balance": 12450.00,
  "transactions": [
    { "id": "tx001", "amount": -45.00, "description": "Coffee shop" },
    { "id": "tx002", "amount": -120.00, "description": "Electricity bill" },
    { "id": "tx003", "amount": 5000.00, "description": "Salary deposit" },
    { "id": "tx004", "amount": -380.00, "description": "Grocery store" },
    { "id": "tx005", "amount": -15.00, "description": "Streaming service" }
  ]
}
```

---

## Success signal

```bash
curl -H "Authorization: Bearer test-token" \
  https://<api-id>.execute-api.<region>.amazonaws.com/summary
```

Returns HTTP 200 with the merged JSON above.

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/summary
```

Returns HTTP 401.

---

## Break it exercise

**Goal:** Observe what happens to the client when the BFF Lambda times out waiting for a slow backend.

**Steps:**

1. In `main.tf`, locate the `aws_lambda_function.bff_aggregator` resource.
2. Temporarily lower the BFF Lambda `timeout` to `1` second (default in the lab is 15s).
3. In the BFF aggregator inline code, add a `time.sleep(3)` before calling the transaction mock — simulating a slow backend.
4. Re-apply with `terraform apply`.
5. Call `/summary` with a valid Bearer token.

**Observe:**
- What HTTP status code does the client receive?
- Does the client receive a partial response (balance without transactions)?
- How long does the client wait before getting the response?

**What to think about:**
- The API GW integration timeout is 29 seconds maximum. The Lambda timeout is your first line of defense.
- When the Lambda times out, API GW receives a Lambda error and returns a generic 504 to the client.
- The client never receives a partial response — it is all-or-nothing.
- The fix is per-upstream timeouts inside the BFF Lambda, not at the API GW level.

**Answer in SOLUTION.md.**

---

## Teardown

Run `teardown.md` steps after every session to avoid charges.
