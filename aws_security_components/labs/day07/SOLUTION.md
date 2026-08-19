# Day 7 lab — SOLUTION

Expected outputs for each step in `README.md`, and the fix rationale.
Real runs will show your own account ID / ARNs / task IDs where this
file shows placeholders — that's expected, not a discrepancy.

## THE BREAK — outside VPC, before `apply`

```
$ aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-1:<acct>:secret:aws-sec-lab/app-secret-XXXXXX

{
    "ARN": "arn:aws:secretsmanager:us-east-1:<acct>:secret:aws-sec-lab/app-secret-XXXXXX",
    "Name": "aws-sec-lab/app-secret",
    "VersionId": "...",
    "SecretString": "<whatever you set out-of-band, or this key is simply absent if no value was ever put>",
    "VersionStages": ["AWSCURRENT"],
    "CreatedDate": ...
}
```

**Exit code 0. HTTP 200.** No resource policy existed on the secret at
this point, so the only gate was the identity policy on whatever
principal is calling — which, for both the task role and (typically)
a sandbox-account admin identity, already allows this action. Network
location was irrelevant. This is the finding: *"VPC-deployed" is not
"VPC-only."*

## THE HARDEN — after `apply`

### Test 1 — outside VPC (expected: denied)

```
$ aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-1:<acct>:secret:aws-sec-lab/app-secret-XXXXXX

An error occurred (AccessDeniedException) when calling the GetSecretValue operation:
User: arn:aws:iam::<acct>:user/<you> is not authorized to perform: secretsmanager:GetSecretValue
on resource: aws-sec-lab/app-secret-XXXXXX because no resource-based policy allows the
secretsmanager:GetSecretValue action
```

**This exact wording is an unverified placeholder — do not treat it as
gospel.** Record your actual returned text here when you run this
live. What you should expect, at minimum: for a resource-policy denial
keyed on `aws:SourceVpce`, the message identifies that the call was
rejected by a resource-based policy / condition, not simply "you lack
permission" — because your identity policy (the same one that allowed
this in THE BREAK) did not change at all. Only the network path
changed, and that's what the resource policy is now keying on.

### Test 2 — inside VPC via ECS Exec (expected: success)

Get a shell inside the running task with ECS Exec, then run the CLI
call **from inside the container**, using the task role's credentials
(the task itself never calls this API — you are calling it manually to
get a real in-VPC data point with the same identity/permission the
task role has always had):

```
$ aws ecs execute-command --cluster <cluster-arn> --task <task-arn> \
    --container app --interactive --command "/bin/sh"
...
# inside the container:
$ aws secretsmanager get-secret-value --secret-id "$SECRET_ARN"
{
    "ARN": "arn:aws:secretsmanager:us-east-1:<acct>:secret:aws-sec-lab/app-secret-XXXXXX",
    "Name": "aws-sec-lab/app-secret",
    "VersionId": "...",
    "SecretString": "...",
    "VersionStages": ["AWSCURRENT"],
    "CreatedDate": ...
}
```

Same action, same secret, same `Deny`-bearing resource policy now in
place — succeeds because the request, made from inside the task's
network namespace inside the VPC, transited
`aws_vpc_endpoint.secretsmanager` (private DNS resolves the standard
`secretsmanager.<region>.amazonaws.com` name to the endpoint's private
IP for anything resolving it inside this VPC), so `aws:SourceVpce`
matched the endpoint ID in the policy's condition and the `Deny` did
not fire. This is the real in-VPC success half of the signal — set
side by side with Test 1's outside-VPC denial, same secret, same
resource policy, only the network path differs.

### Test 3 — Reachability Analyzer (expected: path found)

```
$ aws ec2 describe-network-insights-analyses --network-insights-analysis-ids nia-0123456789abcdef0
{
    "NetworkInsightsAnalyses": [
        {
            "NetworkInsightsAnalysisId": "nia-0123456789abcdef0",
            "Status": "succeeded",
            "NetworkPathFound": true,
            "ForwardPathComponents": [
                { "component": { "id": "eni-<task-eni>" } },
                { "component": { "id": "eni-<endpoint-eni>" } }
            ]
        }
    ]
}
```

`NetworkPathFound: true` for the task ENI → endpoint ENI hop on 443
confirms the intended path is open. This is the "least exposure" proof
required by the lab brief: the path exists for the ENI the SG's
`allowed_client_cidr` is meant to cover, and — per Exercise 1's
reasoning — the private subnet's NACL and lack of an internet route
mean no path exists from outside the VPC at all, regardless of what
the SG's CIDR is scoped to. Reachability Analyzer can only trace paths
between two VPC-resident endpoints, so it cannot directly emit a
"denied from the internet" result the way the CLI test can — its job
here is confirming the *intended* in-VPC path, not re-proving the
outside-denial (Test 1 already did that).

## Fix rationale (why this is the right fix, not just *a* fix)

- The gap was never "the identity policy is too broad." The task
  role's `ReadOwnSecret` grant is exactly what the app needs — Day 1's
  over-broad-S3 lesson doesn't apply here. The gap was the total
  absence of any statement answering "and from where?"
- Fixing this by tightening the identity policy further would not have
  worked: identity policies describe *who*, not *where the request
  physically originated*. Only a resource-policy condition using a
  network-aware key (`aws:SourceVpce`, `aws:SourceIp`) can express
  "from inside this VPC" at all.
- The explicit `Deny` (rather than simply omitting an Allow for
  non-VPC callers) matters because it beats every other Allow in the
  evaluation order unconditionally — including any future identity
  policy someone attaches without realizing this constraint exists.
  That's the durability property you want from a control meant to
  hold for the life of the resource, not just today's task role.

## Finding summary (for your journal.md)

| Finding | Before | After |
|---|---|---|
| Secret reachable from outside VPC with valid IAM perms | Yes (200) | No (`AccessDeniedException`) |
| Secret reachable from inside the task (ECS Exec, task role, in-VPC) | Yes (200) | Yes (200) — unchanged, now via endpoint |
| Resource policy present on the secret | None | Explicit Deny unless `aws:SourceVpce` matches |
| Network path task ENI → endpoint ENI (443) | N/A (endpoint didn't exist) | `NetworkPathFound: true` |

Note: the app itself (`app.py`) never calls `GetSecretValue` at
runtime — the "inside the task" row above is you, manually, inside the
container via ECS Exec, using the task role's credentials. The task
role has always had permission to make this call; only the network
path (and, after `apply`, the resource policy's condition on it)
changed between the two columns.
