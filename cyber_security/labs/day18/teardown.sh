#!/usr/bin/env bash
#
# Day 18 — Cloud consolidation lab: teardown.sh
#
# Deletes every resource setup.sh created, then runs documented checks that
# the account is left clean: IAM users, EC2, S3, CloudTrail trails, and
# GuardDuty. This script only DELETES what setup.sh CREATED (the resources
# named in .day18-state.env) — it never deletes a CloudTrail trail or
# GuardDuty detector, because Day 18 never creates one (it deliberately reuses
# free CloudTrail Event History + sample GuardDuty findings — see README.md).
# For those two, this script only REPORTS current state so you can decide.
#
# Usage: ./teardown.sh [--profile <aws-profile>] [--region <aws-region>]
#   Both are optional — if omitted, this reads them back out of
#   .day18-state.env (the exact profile/region setup.sh used).

set -uo pipefail  # not -e: we want every deletion attempted even if one fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.day18-state.env"
CRED_FILE="$SCRIPT_DIR/aws-credentials-day18.txt"

CLI_PROFILE=""
CLI_REGION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) CLI_PROFILE="$2"; shift 2 ;;
    --region) CLI_REGION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./teardown.sh [--profile <aws-profile>] [--region <aws-region>]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$STATE_FILE" ]]; then
  echo "WARNING: $STATE_FILE not found." >&2
  echo "Either setup.sh was never run, or its state file was already removed." >&2
  echo "Nothing to look up automatically — if you know resource names by hand," >&2
  echo "delete them via the AWS console/CLI directly. Skipping to the account-" >&2
  echo "clean CHECKS below still runs, using --profile/--region if you passed them." >&2
  PROFILE="$CLI_PROFILE"
  REGION="${CLI_REGION:-us-east-1}"
else
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  PROFILE="${CLI_PROFILE:-$PROFILE}"
  REGION="${CLI_REGION:-$REGION}"
fi

if [[ -z "$PROFILE" ]]; then
  echo "ERROR: no profile known (not in .day18-state.env and not passed with --profile)." >&2
  exit 1
fi

AWS=(aws --profile "$PROFILE" --region "$REGION")
FAILED=0

step() {
  # step "description" -- runs the rest of the args, tolerating failure, and
  # prints a clear PASS/FAIL so a partial teardown is never silently dropped.
  local desc="$1"; shift
  echo "[*] $desc"
  if "$@"; then
    echo "    OK"
  else
    echo "    SKIPPED or already gone (non-fatal) — see message above."
    FAILED=1
  fi
}

echo "================================================================"
echo " Day 18 teardown — profile=$PROFILE region=$REGION"
echo "================================================================"

# ---------------------------------------------------------------------------
# 1. EC2 instance + security group.
# ---------------------------------------------------------------------------
if [[ -n "${INSTANCE_ID:-}" ]]; then
  step "Terminating EC2 instance $INSTANCE_ID..." \
    "${AWS[@]}" ec2 terminate-instances --instance-ids "$INSTANCE_ID"
  echo "[*] Waiting for termination (this can take ~30-60s)..."
  "${AWS[@]}" ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" 2>/dev/null || true
fi

if [[ -n "${SG_ID:-}" ]]; then
  step "Deleting security group $SG_ID..." \
    "${AWS[@]}" ec2 delete-security-group --group-id "$SG_ID"
fi

# ---------------------------------------------------------------------------
# 2. Instance profile + app role + app policy.
#    Order matters: remove role from profile -> delete profile -> detach
#    policy from role -> delete role -> delete all non-default policy
#    versions -> delete policy (AWS refuses to delete a policy with more than
#    one version still attached, or while it's attached to any principal).
# ---------------------------------------------------------------------------
if [[ -n "${INSTANCE_PROFILE_NAME:-}" && -n "${ROLE_NAME:-}" ]]; then
  step "Removing role from instance profile..." \
    "${AWS[@]}" iam remove-role-from-instance-profile \
      --instance-profile-name "$INSTANCE_PROFILE_NAME" --role-name "$ROLE_NAME"
fi
if [[ -n "${INSTANCE_PROFILE_NAME:-}" ]]; then
  step "Deleting instance profile $INSTANCE_PROFILE_NAME..." \
    "${AWS[@]}" iam delete-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME"
fi

if [[ -n "${ROLE_NAME:-}" && -n "${APP_POLICY_ARN:-}" ]]; then
  step "Detaching app policy from role..." \
    "${AWS[@]}" iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$APP_POLICY_ARN"
fi
if [[ -n "${ROLE_NAME:-}" ]]; then
  step "Deleting role $ROLE_NAME..." \
    "${AWS[@]}" iam delete-role --role-name "$ROLE_NAME"
fi

if [[ -n "${APP_POLICY_ARN:-}" ]]; then
  echo "[*] Deleting non-default versions of app policy (if the escalation drill was run, there will be one)..."
  VERSIONS="$("${AWS[@]}" iam list-policy-versions --policy-arn "$APP_POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || true)"
  for v in $VERSIONS; do
    "${AWS[@]}" iam delete-policy-version --policy-arn "$APP_POLICY_ARN" --version-id "$v" \
      && echo "    deleted version $v" || echo "    could not delete version $v (non-fatal)"
  done
  step "Deleting app policy $APP_POLICY_ARN..." \
    "${AWS[@]}" iam delete-policy --policy-arn "$APP_POLICY_ARN"
fi

# ---------------------------------------------------------------------------
# 3. Learner user + policy + access key.
# ---------------------------------------------------------------------------
if [[ -n "${LEARNER_USER_NAME:-}" ]]; then
  echo "[*] Deleting any access keys for $LEARNER_USER_NAME..."
  KEY_IDS="$("${AWS[@]}" iam list-access-keys --user-name "$LEARNER_USER_NAME" \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || true)"
  for k in $KEY_IDS; do
    "${AWS[@]}" iam delete-access-key --user-name "$LEARNER_USER_NAME" --access-key-id "$k" \
      && echo "    deleted access key $k" || echo "    could not delete access key $k (non-fatal)"
  done
fi

if [[ -n "${LEARNER_USER_NAME:-}" && -n "${LEARNER_POLICY_ARN:-}" ]]; then
  step "Detaching learner policy from user..." \
    "${AWS[@]}" iam detach-user-policy --user-name "$LEARNER_USER_NAME" --policy-arn "$LEARNER_POLICY_ARN"
fi
if [[ -n "${LEARNER_USER_NAME:-}" ]]; then
  step "Deleting user $LEARNER_USER_NAME..." \
    "${AWS[@]}" iam delete-user --user-name "$LEARNER_USER_NAME"
fi
if [[ -n "${LEARNER_POLICY_ARN:-}" ]]; then
  step "Deleting learner policy $LEARNER_POLICY_ARN..." \
    "${AWS[@]}" iam delete-policy --policy-arn "$LEARNER_POLICY_ARN"
fi

# ---------------------------------------------------------------------------
# 4. S3 bucket (empty it first — delete-bucket fails on a non-empty bucket).
# ---------------------------------------------------------------------------
if [[ -n "${BUCKET_NAME:-}" ]]; then
  step "Emptying S3 bucket $BUCKET_NAME..." \
    "${AWS[@]}" s3 rm "s3://${BUCKET_NAME}" --recursive
  step "Deleting S3 bucket $BUCKET_NAME..." \
    "${AWS[@]}" s3api delete-bucket --bucket "$BUCKET_NAME"
fi

# ---------------------------------------------------------------------------
# 5. Documented clean-account checks (IAM users, EC2, S3, trails, GuardDuty).
# ---------------------------------------------------------------------------
echo ""
echo "================================================================"
echo " Clean-account checks"
echo "================================================================"

check() {
  local label="$1"; shift
  echo -n "  $label ... "
  "$@"
}

echo "-- IAM user (expect: An error occurred (NoSuchEntity)) --"
"${AWS[@]}" iam get-user --user-name "${LEARNER_USER_NAME:-day18-learner}" 2>&1 | tail -1

echo "-- IAM role (expect: An error occurred (NoSuchEntity)) --"
"${AWS[@]}" iam get-role --role-name "${ROLE_NAME:-day18-app-role}" 2>&1 | tail -1

echo "-- EC2 instances tagged Name=${INSTANCE_TAG_NAME:-day18-ssrf-target} (expect: no rows) --"
"${AWS[@]}" ec2 describe-instances \
  --filters "Name=tag:Name,Values=${INSTANCE_TAG_NAME:-day18-ssrf-target}" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text

echo "-- S3 bucket ${BUCKET_NAME:-<unknown>} (expect: An error occurred (404) or NoSuchBucket) --"
if [[ -n "${BUCKET_NAME:-}" ]]; then
  "${AWS[@]}" s3api head-bucket --bucket "$BUCKET_NAME" 2>&1 | tail -1
else
  echo "  (bucket name unknown — state file missing; check the AWS console directly)"
fi

echo "-- CloudTrail trails (informational: Day 18 never creates a trail;" \
     "if this list is non-empty, it predates this lab, e.g. from Day 16) --"
"${AWS[@]}" cloudtrail describe-trails --query 'trailList[].Name' --output text

echo "-- GuardDuty detectors (informational: Day 18 never creates/deletes a" \
     "detector; if one is enabled here, it predates this lab, e.g. from Day 16" \
     "-- disable it yourself with 'aws guardduty delete-detector' if you no" \
     "longer want the ongoing cost) --"
"${AWS[@]}" guardduty list-detectors --query 'DetectorIds' --output text

# ---------------------------------------------------------------------------
# 6. Remove local state + credential files last, once teardown is done.
# ---------------------------------------------------------------------------
rm -f "$STATE_FILE" "$CRED_FILE"
echo ""
echo "================================================================"
if [[ "$FAILED" -eq 0 ]]; then
  echo " Teardown complete. Local state/credential files removed."
else
  echo " Teardown finished with at least one SKIPPED step above (often just"
  echo " 'already deleted' from a re-run) — re-read the checks above to"
  echo " confirm the account is actually clean before trusting this exit."
fi
echo "================================================================"
