"""
Day 9 auto-quarantine Lambda.

Trigger: an EventBridge rule matching High-or-above-severity GuardDuty
findings (source "aws.guardduty", detail-type "GuardDuty Finding",
detail.severity >= 7 — see the rule in ../main.tf).

What it does, in order:
  1. Re-checks severity defensively (never trust that the upstream rule
     is the only thing that can ever invoke this function — a manual
     test invoke, a rule edited later, etc.).
  2. Extracts the compromised principal from the finding.
  3. SAFETY GUARDRAIL: refuses to act on any role except the exact task
     role ARN this lab was deployed against (TASK_ROLE_ARN env var).
     A real deployment would generalize this to a scope list/tag check
     — never let a remediation function act on an arbitrary ARN found
     in event JSON it didn't verify.
  4. Attaches a deny-all permission boundary (full lockout — safe for
     this role because it's single-purpose; see content/day09 for when
     this is the WRONG choice).
  5. Attaches a token-time-scoped inline deny (kills the specific
     already-issued session, independent of the boundary).
  6. Tags the role for audit trail.
  7. Returns a structured result — this function's CloudWatch Logs
     entry IS the "containment happened" record referenced from
     SOLUTION.md.

Every IAM call below is scoped, by the Lambda's own execution-role
policy (see main.tf), to exactly one resource ARN — this function
cannot touch any other role in the account even if the event JSON
told it to.
"""

import datetime
import json
import os

import boto3

iam = boto3.client("iam")

TASK_ROLE_ARN = os.environ["TASK_ROLE_ARN"]
TASK_ROLE_NAME = TASK_ROLE_ARN.split("/")[-1]
QUARANTINE_BOUNDARY_ARN = os.environ["QUARANTINE_BOUNDARY_ARN"]
MIN_SEVERITY = float(os.environ.get("MIN_SEVERITY", "7"))

REVOKE_POLICY_NAME = "Day09RevokeOldSessions"


def _extract_role_name(detail: dict) -> str | None:
    """
    Pull the compromised principal's ROLE NAME out of a GuardDuty
    finding's `resource` block (not an ARN — for an assumed-role
    session, GuardDuty's accessKeyDetails.userName is the role name
    itself, e.g. "aws-sec-lab-task-role"). GuardDuty finding shapes
    vary by type; this lab's finding types (task-role credential theft
    / use-outside-AWS / crypto-mining call) surface the principal under
    resource.accessKeyDetails for an AccessKey-typed resource. Extend
    this function if you wire up additional finding types later.
    """
    resource = detail.get("resource", {})
    access_key = resource.get("accessKeyDetails")
    if access_key:
        return access_key.get("userName")
    return None


def handler(event, context):
    detail = event.get("detail", {})
    severity = detail.get("severity", 0)
    finding_type = detail.get("type", "unknown")
    finding_id = detail.get("id", "unknown")

    if severity < MIN_SEVERITY:
        print(json.dumps({
            "action": "skipped",
            "reason": "below MIN_SEVERITY threshold",
            "severity": severity,
            "finding_id": finding_id,
        }))
        return {"action": "skipped", "reason": "severity"}

    candidate_role_name = _extract_role_name(detail)

    if candidate_role_name != TASK_ROLE_NAME:
        # SAFETY GUARDRAIL: do not act on a principal we weren't
        # explicitly told to guard. Log loudly and stop. This is what
        # makes it safe to fire arbitrary/synthetic GuardDuty sample
        # findings through this pipeline without risking action on the
        # wrong resource.
        print(json.dumps({
            "action": "refused",
            "reason": "principal name did not match TASK_ROLE_NAME allow-list",
            "candidate_role_name": candidate_role_name,
            "finding_id": finding_id,
            "finding_type": finding_type,
        }))
        return {"action": "refused", "reason": "out-of-scope principal"}

    role_name = TASK_ROLE_NAME
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    # 1) Full lockout — deny-all permission boundary. Blocks every
    #    existing AND future session on this role until removed.
    iam.put_role_permissions_boundary(
        RoleName=role_name,
        PermissionsBoundary=QUARANTINE_BOUNDARY_ARN,
    )

    # 2) Surgical revoke — deny only requests using credentials issued
    #    before "now". Redundant with the boundary for THIS single-
    #    purpose role, included so the technique is demonstrated
    #    end-to-end (see content/day09 exercise 3 for when this is the
    #    one you'd use WITHOUT the boundary, on a shared role).
    revoke_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "DenySessionsIssuedBeforeContainment",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "DateLessThan": {"aws:TokenIssueTime": now_iso}
            },
        }],
    }
    iam.put_role_policy(
        RoleName=role_name,
        PolicyName=REVOKE_POLICY_NAME,
        PolicyDocument=json.dumps(revoke_policy),
    )

    # 3) Audit trail on the role itself, independent of CloudWatch Logs.
    iam.tag_role(
        RoleName=role_name,
        Tags=[
            {"Key": "quarantine", "Value": "true"},
            {"Key": "quarantine-finding-id", "Value": finding_id},
            {"Key": "quarantine-finding-type", "Value": finding_type[:200]},
            {"Key": "quarantine-timestamp", "Value": now_iso},
        ],
    )

    result = {
        "action": "quarantined",
        "role_name": role_name,
        "role_arn": TASK_ROLE_ARN,
        "finding_id": finding_id,
        "finding_type": finding_type,
        "severity": severity,
        "boundary_attached": QUARANTINE_BOUNDARY_ARN,
        "revoke_policy_attached": REVOKE_POLICY_NAME,
        "contained_at": now_iso,
    }
    print(json.dumps(result))
    return result
