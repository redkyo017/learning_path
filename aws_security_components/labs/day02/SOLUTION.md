# Day 2 lab — SOLUTION

Expected outputs, exact `AccessDenied` text, and the fix rationale. Read
`README.md` first and try the lab yourself before reading this — the value
is in generating and reading the real AccessDenied text in your own
account, not in pattern-matching this file.

## THE BREAK — expected outputs

### Step 1 — baseline denial (before any escalation)

```
An error occurred (AccessDenied) when calling the GetSecretValue operation: User: arn:aws:sts::<account-id>:assumed-role/aws-sec-lab-day02-low-priv-role/day02-break is not authorized to perform: secretsmanager:GetSecretValue on resource: <secret-arn> because no identity-based policy allows the secretsmanager:GetSecretValue action
```

This is a plain identity-policy denial — note the phrase **"because no
identity-based policy allows..."**. Keep this exact phrase in mind; the
harden-phase denial below uses different wording, and the difference is
the whole point.

### Step 2 — RegisterTaskDefinition succeeds

Returns a task definition ARN like
`arn:aws:ecs:<region>:<account-id>:task-definition/day02-escalate:1` with
HTTP 200 — no error. This is `low_priv` using its wildcarded
`iam:PassRole` on `high_priv_role_arn` (and on
`base_task_execution_role_arn`) with no resource restriction stopping it.

### Step 3 — RunTask + logs: the escalation, proven

```
--- CALLER IDENTITY (watch which role this is) ---
{
    "UserId": "AROAEXAMPLE:escalate",
    "Account": "<account-id>",
    "Arn": "arn:aws:sts::<account-id>:assumed-role/aws-sec-lab-day02-high-priv-role/escalate"
}
--- SECRET ACCESS CHECK (value intentionally NOT printed - see ANTIPATTERNS.md #10) ---
SECRET READ: SUCCESS
```

**Why this is the success signal for the break:** the `Arn` in the caller
identity is `assumed-role/...-high-priv-role/...`, not `low-priv-role`. The
task low_priv launched runs as high_priv and the `SECRET READ: SUCCESS`
line proves it can do something (`secretsmanager:GetSecretValue` on the
base app secret) that Step 1 proved low_priv cannot do directly. Nothing
about low_priv's own effective permission set changed on paper — the
escalation happened entirely through the role it was allowed to pass.

## THE HARDEN — expected outputs

After `permission_boundary_enabled = true` and `terraform apply`, repeating
the exact same attempt with a freshly-assumed low_priv session:

```
An error occurred (AccessDenied) when calling the RegisterTaskDefinition operation: User: arn:aws:sts::<account-id>:assumed-role/aws-sec-lab-day02-low-priv-role/day02-harden is not authorized to perform: iam:PassRole on resource: arn:aws:iam::<account-id>:role/aws-sec-lab-day02-high-priv-role because no permissions boundary allows the iam:PassRole action
```

(Per AWS's own documentation, `iam:PassRole` is checked at
`RegisterTaskDefinition`, so this is the likely point where the denial
surfaces. If your account instead allows `RegisterTaskDefinition` to
succeed and denies at `RunTask`, the wording is the same shape with
`RunTask`/`ecs:RunTask` in place of `RegisterTaskDefinition` — either
observed point is a valid signal that the boundary is working; the
important string, "because no permissions boundary allows...", is
identical either way. Likewise, the denied-action name itself may read
`iam:PassRole` or an ECS action — the boundary's allow-list omits both,
so don't fixate on which exact action name shows up.)

**The tell:** compare the two AccessDenied strings.

| | Phrase | What it means |
|---|---|---|
| Step 1 (baseline) | "...because **no identity-based policy** allows..." | The identity policy itself never granted this action. |
| Harden phase | "...because **no permissions boundary** allows..." | The identity policy *does* grant this action (low_priv's `MisScopedPassRole` statement, `Resource: "*"`, is still there, unedited) — but the boundary's allow-list doesn't include `iam:PassRole` at all, so the intersection is empty. |

That second phrase is the concrete, observable proof that **the boundary,
not the identity policy, is what's capping this now** — exactly the
"effective permission = intersection" model from the canonical evaluation
order. `low_priv_boundary`'s policy document
(`aws_iam_policy.low_priv_boundary` in `main.tf`) never lists
`iam:PassRole`, `ecs:RegisterTaskDefinition`, or `ecs:RunTask` in its single
`Allow` statement — omission from an allow-list boundary is as effective
as an explicit deny, because nothing outside the boundary's list can ever
be in the intersection.

## Fix rationale

The identity-policy fix (narrowing `MisScopedPassRole`'s `Resource` to a
specific safe role ARN) would also have worked, and is the fix you'd
reach for in a single-role, single-owner situation. This lab deliberately
reaches for the **boundary** instead, because it generalizes: a
permission boundary is what you'd hand to a team that's allowed to create
*their own* roles and policies — you can't hand-audit every policy they
write, but the boundary guarantees none of them can ever exceed the
ceiling, no matter what `Resource: "*"` grants they write for themselves
later. Fixing only the one `MisScopedPassRole` statement fixes this one
role; the boundary fixes the whole class of mistake for this role, going
forward, regardless of what its identity policy is edited to say next.

## Verify checklist (matches the plan's "Verify" line)

- [x] Boundary demonstrably caps the escalation — see the two contrasting
      `AccessDenied` strings above (this file).
- [x] `main.tf` reviewed by hand (Terraform not installed in the authoring
      environment — see the day-02 report for the manual-review checklist
      used in place of `terraform validate`).
