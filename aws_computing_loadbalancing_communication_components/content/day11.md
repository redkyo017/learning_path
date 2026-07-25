# Day 11 — API Gateway

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Choose between HTTP API and REST API and justify the decision
- Explain what a VPC Link is and when it is required
- Configure CORS and trace what happens during a browser preflight request
- Explain throttling and what a 429 response means to the client
- Describe the four integration types and which to use for each scenario
- Explain the difference between a stage and a deployment

---

## The front-door mental model

Before touching the console, internalise this question:

> **API Gateway is the front door with enforcement. Authentication, authorisation, throttling, and CORS all happen here — before your backend code runs. Understanding what API Gateway enforces — and what it doesn't — is the key to knowing where to put security controls.**

---

## HTTP API vs REST API — the most important decision

This is the first decision you make when creating an API. Choose wrong and you will either overpay for features you don't need, or discover missing features late in the build.

| | HTTP API | REST API |
|---|---|---|
| Latency | ~1ms | ~5ms |
| Cost | ~70% cheaper | Full price |
| Integrations | Lambda, HTTP, AWS services | Lambda, HTTP, AWS services, Mock |
| Auth | JWT, Lambda, IAM | Cognito, Lambda, IAM, API keys |
| Request/response mapping | No | Yes (Velocity templates) |
| Usage plans + API keys | No | Yes |
| WAF | No (use CloudFront) | Yes |
| WebSocket | No | No (separate WebSocket API product) |
| When to use | Default for new APIs | When you need mapping templates, usage plans, or WAF |

**The decision rule:** start with HTTP API. Switch to REST API only when you need Velocity template transformations, usage plans, or direct WAF attachment. The cost and latency advantages of HTTP API are significant enough that the burden of proof sits with REST API.

---

## Integration types — what happens after API Gateway receives the request

API Gateway is a reverse proxy. It receives a request, applies its enforcement rules, then forwards the request to a backend. How it forwards depends on the integration type.

**1. Lambda proxy**
The entire request envelope — headers, path parameters, query string, body — is serialised into a JSON event and sent to Lambda. Lambda returns a JSON object with `statusCode`, `headers`, and `body`. API Gateway unwraps that response and returns it to the client. No transformation configuration is required. This is the simplest option for Lambda backends: the function receives and controls everything.

**2. HTTP proxy**
API Gateway forwards the request to an HTTP endpoint unchanged. No transformation occurs. The backend receives the original request with `X-Forwarded-For`, `X-Forwarded-Proto`, and other forwarded headers intact. This is the correct integration type when pairing with VPC Link to reach a private ALB — API Gateway proxies to the ALB, which routes onward to ECS or EC2.

**3. AWS service**
Direct integration with an AWS API action — `SQS:SendMessage`, `Kinesis:PutRecord`, `DynamoDB:PutItem` — without any Lambda in the path. API Gateway calls the AWS service directly using an IAM execution role. This eliminates the Lambda invocation cost and latency for simple fan-in scenarios (e.g. accept an event, write it directly to SQS). Requires Velocity mapping templates to construct the request body — which is why this integration type is only available on REST API.

**4. Mock**
API Gateway returns a fixed response without calling any backend. Used for CORS preflight `OPTIONS` responses (return the required headers with a 200) and stub APIs during development. Cost is zero beyond the API Gateway request charge itself.

---

## VPC Link — private integration

Without VPC Link, your backend must have a public IP or DNS name reachable from the internet. That violates the private-subnet-by-default principle.

VPC Link creates a managed Elastic Network Interface inside your VPC. API Gateway uses this ENI to route requests to your backend privately — traffic never leaves AWS's network.

- **HTTP API VPC Link:** connects to an ALB or NLB inside your VPC. This is the correct path for HTTP API → ALB → ECS Fargate (awsvpc mode).
- **REST API VPC Link:** connects to an NLB inside your VPC only. ALB is not supported as a REST API VPC Link target.
- A VPC Link is scoped to a VPC. One VPC Link can serve multiple APIs.
- Your backend's security group must allow inbound traffic from the VPC Link. For HTTP API + ALB, the ALB security group must permit inbound from the API Gateway managed subnets or VPC Link security group.

**When VPC Link is required:** whenever your backend is in a private subnet with no internet-facing endpoint. If your ECS tasks are in private subnets — they should be — the ALB in front of them is the connection point. VPC Link is how API Gateway reaches that ALB without traversing the public internet.

---

## CORS — the browser security model

CORS is not an API Gateway feature — it is a browser security model. API Gateway's CORS configuration generates the correct response headers so browsers permit cross-origin calls.

When JavaScript running at `https://app.example.com` makes a request to `https://api.example.com`, the origins differ. The browser does not send the real request immediately. It first sends an `OPTIONS` preflight request to check whether the server permits the cross-origin call. The server must respond with the correct headers, or the browser blocks the response — even if the actual response would have been a 200 OK.

**Headers that must be present on the response:**
- `Access-Control-Allow-Origin` — the origin(s) permitted. Use a specific origin (`https://app.example.com`) in production. Never use `*` when credentials (cookies or auth headers) are involved.
- `Access-Control-Allow-Methods` — `GET, POST, PUT, DELETE, OPTIONS`
- `Access-Control-Allow-Headers` — the request headers the client is allowed to send (e.g. `Content-Type, Authorization`)

**HTTP API:** enables CORS automatically when you configure the allowed origins, methods, and headers. API Gateway generates the correct Mock integration for `OPTIONS`.

**REST API:** requires manual configuration — add a method for `OPTIONS`, add a Mock integration returning the CORS headers, and ensure the same headers appear on every non-OPTIONS method response.

**The common mistake:** CORS is configured on the 200 route but not on the 4xx error responses. When API Gateway rejects an unauthenticated request with a 401 or 403, that response does not include CORS headers. The browser cannot read the error body. The developer sees a CORS error in the console and debugs CORS when the real issue is authentication.

---

## Throttling — protecting your backend from overload

API Gateway throttles requests before they reach your backend. A throttled request receives a `429 Too Many Requests` response from API Gateway — your backend never sees the request.

**Throttle hierarchy:**
1. **Account default:** 10,000 requests per second burst, 5,000 requests per second steady-state, per region. This is a soft limit — increase via AWS Support.
2. **Stage-level override:** set a default rate and burst for all routes in a stage. Reduces the effective account limit for a specific API.
3. **Route-level override:** set a different rate for a specific route. Useful when one endpoint (e.g. `/api/upload`) is more expensive to serve than others.

**Usage plans (REST API only):** associate an API key with a usage plan to give different clients different rate limits. Client A gets 1,000 req/s; Client B gets 100 req/s. Usage plans also enforce monthly request quotas. HTTP API does not support usage plans — use a Lambda authoriser with application-level logic if you need per-client throttling.

**The operational implication:** a 429 from API Gateway does not mean your backend is slow or failing. It means a throttle limit has been reached. Check the stage throttle settings before investigating ECS or Lambda.

---

## Stages and deployments

A **deployment** is a point-in-time snapshot of your API's routes, integrations, and settings.

A **stage** is a named reference — `dev`, `staging`, `prod` — that points to a deployment. The stage determines the URL clients access: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/`.

**For REST API:** changes are not live until you explicitly create a deployment and associate it with a stage. This is the most common "why isn't my change working" mistake — you updated a route or integration, but it has not been deployed.

**For HTTP API with `auto_deploy = true`:** API Gateway creates a deployment automatically whenever you save a change. No manual deployment step is needed. This is the default for HTTP APIs created in the Console.

Stage variables allow configuration to differ by environment without changing code. A stage variable `{stageVariables.backendUrl}` in the integration URI is substituted at runtime with the value set in that stage — dev points to a dev backend, prod to prod.

---

## Best practices

- **Use HTTP API by default.** The cost and latency advantages are substantial. The only reason to choose REST API is Velocity template transformations, usage plans, or WAF.
- **Use VPC Link for all private backends.** Never expose an ALB or NLB to the public internet just to make it reachable from API Gateway. VPC Link is the correct and secure path.
- **Set CORS to specific origins in production.** `Access-Control-Allow-Origin: *` disables an important browser security control. Use the exact frontend origin string.
- **Configure throttling at the stage level.** An unbounded API can exhaust your account's regional throttle limit, affecting all other APIs in the account. Set a stage-level default and add route-level overrides for expensive endpoints.

---

## Common pitfalls

- **CORS error in browser but 200 in curl.** curl does not enforce CORS — only browsers do. If curl succeeds but the browser blocks the response, the problem is missing or incorrect CORS response headers, not the backend logic.
- **Missing CORS headers on error responses.** A 401 or 403 from API Gateway's authoriser does not automatically inherit CORS headers. The browser cannot read the error body. Fix: configure gateway responses for `UNAUTHORIZED` and `ACCESS_DENIED` response types to include the `Access-Control-Allow-Origin` header.
- **REST API changes not deployed.** You modified a route, an integration, or an authoriser and tested immediately — but the change has no effect. The solution is to create a deployment and associate it with the stage. HTTP API with `auto_deploy=true` eliminates this trap; REST API does not.
- **VPC Link is Active but requests still fail.** VPC Link creates a network path, but security groups control whether traffic is permitted at the destination. Check that the ALB security group allows inbound on the listener port from the VPC Link's underlying subnet CIDR or security group. A healthy VPC Link with a blocking security group produces the same symptom as no VPC Link at all.

---

## Exercises

Answer before starting the lab:

1. Your JavaScript frontend at `https://app.example.com` calls an API at `https://api.example.com`. The `OPTIONS` preflight returns a 200 but the browser still blocks the response. What is the most likely cause?
2. You want API Gateway to write messages directly to SQS without invoking Lambda. Which API type and which integration type do you use, and why?
3. Your API returns 429 under normal load. You check and your backend (ECS) is healthy with no errors. What is throttled and where do you change the limit?

## Lab reference

Follow Day 11 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 11 — API Gateway
Key concept — HTTP API vs REST API: ...
When to use VPC Link: ...
Break-it CORS fix — what was missing and how I found it: ...
```
