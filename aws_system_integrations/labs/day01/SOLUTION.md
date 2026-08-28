# Day 1 Lab — Solution Guide

## Architecture explanation: why HTTP API GW, not REST API GW

This lab uses `aws_apigatewayv2_api` (HTTP API), not `aws_api_gateway_rest_api` (REST API). The reasons:

| Requirement | HTTP API suffices? | REST API needed? |
|---|---|---|
| Lambda integration (proxy) | Yes | Yes |
| Lambda authorizer | Yes | Yes |
| CORS | Yes | Yes |
| Stage-level throttling | Yes | Yes |
| Per-client usage plans / API keys | No | Yes |
| VTL mapping templates | No | Yes |
| Request model validation | No | Yes |

This lab does not need usage plans (per-client quotas), VTL, or request model validation. HTTP API GW is the correct choice. The cost difference: HTTP API costs ~$1.00/million requests vs REST API ~$3.50/million requests — a 70% saving. At scale (100M requests/month) that is $250/month saved for no functional difference.

The throttling on the `$default` stage (`throttling_rate_limit = 10`, `throttling_burst_limit = 20`) is HTTP API's equivalent of a usage plan for the whole API. It is not per-client quota enforcement (that requires REST API + usage plans + API keys), but it is sufficient for rate-limiting the entire API surface.

---

## BFF Lambda logic walkthrough

The `bff_aggregator` Lambda calls both mock backends concurrently using Python's `concurrent.futures.ThreadPoolExecutor`:

```python
with ThreadPoolExecutor(max_workers=2) as pool:
    futures = {
        pool.submit(invoke, ACCOUNT_FUNCTION):     "account",
        pool.submit(invoke, TRANSACTION_FUNCTION): "transactions",
    }
    for future in as_completed(futures, timeout=UPSTREAM_TIMEOUT_S):
        key = futures[future]
        results[key] = future.result()
```

Key design decisions:

1. **Parallel, not sequential.** If account-svc takes 200ms and transaction-svc takes 150ms, sequential calls take 350ms; parallel calls take 200ms (the max). The ThreadPoolExecutor fires both Lambdas at the same time.
2. **Per-upstream timeout.** `as_completed(futures, timeout=UPSTREAM_TIMEOUT_S)` imposes a deadline on the fan-in. Any upstream that does not respond within `UPSTREAM_TIMEOUT_S` seconds causes a `TimeoutError`, which is caught and stored in `errors`.
3. **Partial response.** If one upstream fails, the BFF returns a 207 Multi-Status with the available data and an `_errors` map. The client can render partial data rather than showing a complete failure.
4. **No business logic in the BFF.** The Lambda does not validate the balance, filter transactions by type, or apply any fee calculations. It only fetches, merges, and forwards. Business logic belongs in the mock services (or real services in production).

---

## JWT authorizer explanation

### Why Lambda authorizer instead of Cognito for this lab

| Approach | Pros | Cons |
|---|---|---|
| Lambda authorizer | Full control over validation logic; no external dependency; simple to understand | Must implement JWT signature verification yourself in production |
| Cognito User Pools authorizer | Managed JWT validation; no custom Lambda needed; integrates with Cognito identity | Requires a Cognito User Pool (more AWS resources); overkill for a lab |
| API GW JWT authorizer (built-in) | No Lambda needed; validates JWT against JWKS URI automatically | Requires a real JWKS endpoint (e.g., Cognito, Auth0) |

This lab uses a Lambda authorizer because it makes the policy document construction explicit and visible. The lab authorizer accepts any non-empty Bearer token — in production, replace the validation with PyJWT signature verification against your JWKS endpoint.

### How the policy document is constructed

The Lambda authorizer must return an IAM policy document:

```python
policy = {
    "principalId": "mobile-user",
    "policyDocument": {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "execute-api:Invoke",
                "Effect": "Allow",
                "Resource": stage_arn,  # arn:aws:execute-api:region:account:api-id/*
            }
        ],
    },
    "context": {"userId": "demo-user-001"},
}
```

The `Resource` is generalised to `arn:...:api-id/*` (all routes in the API). If you set it to the exact route ARN, the cached policy only authorises that one route. A broad resource is correct here because the authorizer cache TTL is 60 seconds — the same policy is reused for all `/summary` calls from the same token within the TTL window.

The `context` map is passed to the Lambda integration as `$context.authorizer.*` — you can use it to forward the `userId` to the BFF without decoding the JWT a second time.

---

## Usage plan explanation

HTTP API GW does not have named usage plans (that is a REST API feature). Instead, the `$default` stage has:

```hcl
default_route_settings {
  throttling_rate_limit  = 10   # steady-state rate: 10 req/s
  throttling_burst_limit = 20   # token bucket burst capacity
}
```

**Throttle (rate + burst):** Controls how many requests per second API GW forwards to the backend. `throttling_rate_limit` is the steady-state rate — the token bucket refill rate. `throttling_burst_limit` is the bucket size — the maximum number of requests that can be served instantly before the rate limit kicks in. Requests above the burst capacity receive HTTP 429.

**Quota:** REST API GW usage plans have a `quota` parameter (e.g., 10,000 requests/day per API key). HTTP API GW has no equivalent — throttle is the only lever. If you need per-client daily quotas, use REST API GW + usage plans + API keys.

**When does the client see 429?** When the request rate exceeds the burst capacity and the token bucket is empty. The burst capacity of 20 means up to 20 simultaneous requests can be served at once; beyond that, API GW starts rejecting with 429 before the request even reaches the Lambda.

---

## Break it answer

**Setup:** BFF Lambda timeout set to 1s; `time.sleep(3)` added before calling the transaction mock.

**What the client sees:**

1. The BFF Lambda starts, fires the account mock (returns quickly), and begins the `time.sleep(3)` before calling the transaction mock.
2. After 1 second, the Lambda runtime terminates the function (Lambda timeout).
3. API GW receives a Lambda service exception (the function timed out).
4. API GW returns HTTP 504 Gateway Timeout to the client.
5. The client never receives a partial response — it is all-or-nothing.

**Why no partial response?** The HTTP API GW + Lambda Proxy integration is synchronous. API GW waits for the Lambda to return a complete response object. If Lambda times out, it does not return a response object at all — it raises an exception. API GW has no partial response to return, so it emits its own 504.

**How long does the client wait?** Exactly the Lambda timeout duration (1s in this exercise), not the API GW integration timeout (20s configured in main.tf). The Lambda fires first.

**The correct fix:**
- Add per-upstream timeouts inside the BFF Lambda: `as_completed(futures, timeout=5)` limits the fan-in wait to 5s regardless of which backend is slow.
- If a backend times out, return a partial response (207) with the available data rather than failing everything.
- Do not rely on the API GW integration timeout as a safety net — it fires only when the Lambda itself hangs (e.g., deadlock), not when upstream services are slow.

**The timeout hierarchy:**
```
Per-upstream timeout (5s) < BFF Lambda timeout (15s) < API GW integration timeout (20s) < API GW max (29s)
```
Each layer is a backstop for the one inside it. The per-upstream timeout is the most important because it enables partial responses.

---

## Common mistakes in this lab

**1. Lambda execution role missing `lambda:InvokeFunction` on peer Lambdas**

The BFF aggregator invokes the account mock and transaction mock via the AWS SDK (`boto3.client("lambda").invoke(...)`). This requires the BFF Lambda's execution role to have `lambda:InvokeFunction` on those two function ARNs. Without this, the BFF Lambda raises `AccessDeniedException` at runtime, which surfaces as a 500 to the client.

The `main.tf` adds `aws_iam_policy.bff_invoke` and attaches it to `aws_iam_role.lambda_exec`. If you see 500 errors and `AccessDeniedException` in CloudWatch Logs, check the IAM policy attachment.

**2. Authorizer cache TTL set to 0 — re-auth on every request**

`authorizer_result_ttl_in_seconds = 0` disables caching. Every request to `/summary` triggers a separate Lambda authorizer invocation before the BFF Lambda invocation. This doubles the cost and adds 10–50ms of latency (cold-start or warm Lambda invocation time) to every request. The lab sets TTL to 60s. For testing (where you want to verify that a bad token is rejected immediately), set TTL to 0 temporarily, then restore it.

**3. Forgetting to attach stage to deployment / auto_deploy not set**

HTTP API GW with `auto_deploy = true` on the stage automatically deploys route changes. If `auto_deploy` were false, you would need to create `aws_apigatewayv2_deployment` resources and trigger them manually. The symptom: routes return 404 even though the resources exist in Terraform. The lab uses `auto_deploy = true` to avoid this friction. In production, disable auto-deploy and manage deployment via CI/CD for controlled rollout.

**4. Broad `source_arn` on `aws_lambda_permission`**

The lab uses `${aws_apigatewayv2_api.banking_bff.execution_arn}/*/*` — this allows any stage and any route to invoke the Lambda. In production, tighten this to the specific stage ARN to prevent other APIs in the account from invoking your Lambdas if their ARNs are ever shared.
