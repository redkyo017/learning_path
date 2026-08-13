#!/usr/bin/env bash
#
# Day 16 lab teardown — disables GuardDuty, deletes the CloudTrail trail +
# its S3 bucket, removes the disposable IAM user/policy, the SNS topic,
# and both EventBridge rules created by setup.sh.
#
# Reads .day16-state.env (written by setup.sh) for every resource ID —
# run this from the same directory setup.sh was run from, and don't
# delete that file before running this.
#
# Usage: ./teardown.sh --profile my-sandbox-profile [--yes]
#
set -euo pipefail

PROFILE=""
ASSUME_YES="no"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.day16-state.env"

usage() {
  echo "Usage: $0 --profile <aws-profile> [--yes]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2 ;;
    --yes)
      ASSUME_YES="yes"; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown argument: $1" >&2
      usage ;;
  esac
done

if [ -z "$PROFILE" ]; then
  usage
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  echo "Nothing to tear down, or setup.sh was run from a different directory." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$STATE_FILE"

if [ "$ASSUME_YES" != "yes" ]; then
  echo "About to delete, in region $REGION, account $ACCOUNT_ID:"
  echo "  - EventBridge rules: $RULE_GUARDDUTY, $RULE_CLOUDTRAIL"
  echo "  - SNS topic: $TOPIC_ARN"
  echo "  - GuardDuty detector: $DETECTOR_ID (this stops GuardDuty billing)"
  echo "  - CloudTrail trail: $TRAIL_NAME and bucket: $BUCKET_NAME (emptied then deleted)"
  echo "  - IAM user: $LAB_USER and policy: $LAB_POLICY_ARN"
  read -r -p "Type 'yes' to continue: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted — nothing was removed."
    exit 1
  fi
fi

AWS="aws --profile $PROFILE --region $REGION"

echo
echo "--- Removing EventBridge rules ---"
$AWS events remove-targets --rule "$RULE_GUARDDUTY" --ids "1" || true
$AWS events delete-rule --name "$RULE_GUARDDUTY" || true
$AWS events remove-targets --rule "$RULE_CLOUDTRAIL" --ids "1" || true
$AWS events delete-rule --name "$RULE_CLOUDTRAIL" || true

echo
echo "--- Removing SNS topic ---"
$AWS sns delete-topic --topic-arn "$TOPIC_ARN" || true

echo
echo "--- Disabling/deleting GuardDuty detector (stops GuardDuty billing) ---"
$AWS guardduty delete-detector --detector-id "$DETECTOR_ID" || true

echo
echo "--- Stopping and deleting CloudTrail trail ---"
$AWS cloudtrail stop-logging --name "$TRAIL_NAME" || true
$AWS cloudtrail delete-trail --name "$TRAIL_NAME" || true

echo
echo "--- Emptying and deleting CloudTrail S3 bucket ---"
$AWS s3 rm "s3://$BUCKET_NAME" --recursive || true
$AWS s3api delete-bucket --bucket "$BUCKET_NAME" || true

echo
echo "--- Removing disposable IAM user + policy ---"
$AWS iam detach-user-policy --user-name "$LAB_USER" --policy-arn "$LAB_POLICY_ARN" || true
# Delete every non-default policy version created during the replay before
# the policy itself can be deleted (a policy with >1 version can't be
# deleted directly).
VERSION_IDS=$($AWS iam list-policy-versions --policy-arn "$LAB_POLICY_ARN" \
  --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || echo "")
for V in $VERSION_IDS; do
  $AWS iam delete-policy-version --policy-arn "$LAB_POLICY_ARN" --version-id "$V" || true
done
$AWS iam delete-policy --policy-arn "$LAB_POLICY_ARN" || true
$AWS iam delete-user --user-name "$LAB_USER" || true

echo
echo "============================================================"
echo " Teardown complete. Verify with:"
echo "   aws --profile $PROFILE guardduty list-detectors           # expect empty"
echo "   aws --profile $PROFILE --region $REGION cloudtrail describe-trails --trail-name-list $TRAIL_NAME  # expect empty"
echo "   aws --profile $PROFILE s3 ls s3://$BUCKET_NAME             # expect NoSuchBucket error"
echo "   aws --profile $PROFILE iam get-user --user-name $LAB_USER  # expect NoSuchEntity"
echo "============================================================"

rm -f "$STATE_FILE"
