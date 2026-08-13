#!/usr/bin/env bash
#
# Day 16 lab setup — enable CloudTrail + GuardDuty telemetry, replay the
# Day 14 IAM-privesc signature call and the Day 15 IMDS-cred-theft finding
# types, and wire an EventBridge -> SNS alert.
#
# AUTHORIZED SANDBOX ONLY. Requires an explicit --profile (a named AWS CLI
# profile you already configured with `aws configure --profile <name>`).
# This script never reads, writes, or embeds any credential itself — it
# only ever passes --profile through to the AWS CLI, which resolves
# credentials from your existing profile configuration.
#
# COST WARNING: GuardDuty is NOT part of the always-free tier. It has a
# 30-day free trial per account/region, then bills per finding/analyzed
# event (roughly a few dollars a month for a small, low-traffic sandbox
# account, but it is real, ongoing, non-zero cost as long as the detector
# stays enabled). CloudTrail's first trail and IAM API calls are
# effectively free at this scale. Read labs/day16/README.md before running
# this against a real account. Run teardown.sh when you're done.
#
# Usage:
#   ./setup.sh --profile my-sandbox-profile --region us-east-1 \
#              --email you@example.com [--yes]
#
set -euo pipefail

PROFILE=""
REGION=""
EMAIL=""
ASSUME_YES="no"
STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.day16-state.env"

usage() {
  echo "Usage: $0 --profile <aws-profile> --region <aws-region> --email <notify-email> [--yes]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2 ;;
    --region)
      REGION="$2"; shift 2 ;;
    --email)
      EMAIL="$2"; shift 2 ;;
    --yes)
      ASSUME_YES="yes"; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown argument: $1" >&2
      usage ;;
  esac
done

if [ -z "$PROFILE" ] || [ -z "$REGION" ] || [ -z "$EMAIL" ]; then
  usage
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI not found on PATH." >&2
  exit 1
fi

if ! aws configure list-profiles 2>/dev/null | grep -qx "$PROFILE"; then
  echo "ERROR: AWS CLI profile '$PROFILE' not found. Configure it first with:" >&2
  echo "  aws configure --profile $PROFILE" >&2
  exit 1
fi

echo "============================================================"
echo " Day 16 lab setup — profile: $PROFILE  region: $REGION"
echo "============================================================"
echo
echo "!!! GUARDDUTY COST / FREE-TRIAL WARNING !!!"
echo "GuardDuty is NOT always-free. This script enables a GuardDuty"
echo "detector in $REGION under the '$PROFILE' account. AWS gives a"
echo "30-day free trial per account/region; after that (or if this"
echo "account already used its trial), GuardDuty bills per analyzed"
echo "event/finding — typically a few dollars a month for a small"
echo "sandbox, but it is real, ongoing cost until you disable the"
echo "detector. This script's teardown.sh disables it, but ONLY if"
echo "you actually run teardown.sh when you're done today."
echo
echo "This also creates: an S3 bucket + CloudTrail trail, a disposable"
echo "IAM user + policy, an SNS topic + email subscription, and two"
echo "EventBridge rules. All are free-tier-friendly at lab scale."
echo

if [ "$ASSUME_YES" != "yes" ]; then
  read -r -p "Type 'yes' to continue: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted — nothing was created."
    exit 1
  fi
fi

AWS="aws --profile $PROFILE --region $REGION"
ACCOUNT_ID=$($AWS sts get-caller-identity --query Account --output text)
SUFFIX=$(date +%Y%m%d%H%M%S)
BUCKET_NAME="day16-cloudtrail-${ACCOUNT_ID}-${SUFFIX}"
TRAIL_NAME="day16-lab-trail"
LAB_USER="day16-lab-user"
LAB_POLICY_NAME="day16-lab-policy"
SNS_TOPIC_NAME="day16-cloud-alerts"
RULE_GUARDDUTY="day16-guardduty-findings"
RULE_CLOUDTRAIL="day16-createpolicyversion"

echo
echo "--- Step 1/6: S3 bucket + CloudTrail trail ---"
$AWS s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
  $( [ "$REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$REGION" )
$AWS s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
    }
  ]
}
EOF
)
$AWS s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$BUCKET_POLICY"

$AWS cloudtrail create-trail \
  --name "$TRAIL_NAME" \
  --s3-bucket-name "$BUCKET_NAME" \
  --is-multi-region-trail false \
  --no-include-global-service-events
$AWS cloudtrail start-logging --name "$TRAIL_NAME"
echo "CloudTrail trail '$TRAIL_NAME' logging to s3://$BUCKET_NAME"

echo
echo "--- Step 2/6: GuardDuty detector ---"
EXISTING_DETECTOR=$($AWS guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null || echo "None")
if [ "$EXISTING_DETECTOR" = "None" ] || [ -z "$EXISTING_DETECTOR" ]; then
  DETECTOR_ID=$($AWS guardduty create-detector --enable --query DetectorId --output text)
  echo "Created GuardDuty detector: $DETECTOR_ID"
else
  DETECTOR_ID="$EXISTING_DETECTOR"
  echo "Reusing existing GuardDuty detector: $DETECTOR_ID"
fi

echo
echo "--- Step 3/6: disposable IAM user + policy for the CreatePolicyVersion replay ---"
$AWS iam create-user --user-name "$LAB_USER" >/dev/null
LAB_POLICY_DOC=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": ["s3:ListAllMyBuckets"], "Resource": "*"}
  ]
}
EOF
)
LAB_POLICY_ARN=$($AWS iam create-policy \
  --policy-name "$LAB_POLICY_NAME" \
  --policy-document "$LAB_POLICY_DOC" \
  --query 'Policy.Arn' --output text)
$AWS iam attach-user-policy --user-name "$LAB_USER" --policy-arn "$LAB_POLICY_ARN"
echo "Created $LAB_USER with narrow starting policy $LAB_POLICY_ARN"
echo "Replay the escalation yourself with (see content/day16-cloud-detection.md Step 2):"
echo "  $AWS iam create-policy-version --policy-arn $LAB_POLICY_ARN --set-as-default \\"
echo "    --policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}'"

echo
echo "--- Step 4/6: GuardDuty sample findings (IMDS cred-theft variants + privesc) ---"
$AWS guardduty create-sample-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-types \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS" \
    "PrivilegeEscalation:IAMUser/AdministrativePermissions"
echo "Sample findings requested (tagged sample:true, distinguishable from real detections)."

echo
echo "--- Step 5/6: SNS topic + email subscription ---"
TOPIC_ARN=$($AWS sns create-topic --name "$SNS_TOPIC_NAME" --query TopicArn --output text)
$AWS sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL" >/dev/null
echo "Created SNS topic $TOPIC_ARN — CONFIRM the subscription email sent to $EMAIL"

TOPIC_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEventBridgePublish",
      "Effect": "Allow",
      "Principal": {"Service": "events.amazonaws.com"},
      "Action": "sns:Publish",
      "Resource": "${TOPIC_ARN}"
    }
  ]
}
EOF
)
$AWS sns set-topic-attributes --topic-arn "$TOPIC_ARN" --attribute-name Policy --attribute-value "$TOPIC_POLICY"

echo
echo "--- Step 6/6: EventBridge rules -> SNS ---"
$AWS events put-rule \
  --name "$RULE_GUARDDUTY" \
  --event-pattern '{"source":["aws.guardduty"],"detail-type":["GuardDuty Finding"]}' \
  --state ENABLED
$AWS events put-targets --rule "$RULE_GUARDDUTY" \
  --targets "Id"="1","Arn"="$TOPIC_ARN"

$AWS events put-rule \
  --name "$RULE_CLOUDTRAIL" \
  --event-pattern '{"source":["aws.iam"],"detail-type":["AWS API Call via CloudTrail"],"detail":{"eventName":["CreatePolicyVersion","SetDefaultPolicyVersion"]}}' \
  --state ENABLED
$AWS events put-targets --rule "$RULE_CLOUDTRAIL" \
  --targets "Id"="1","Arn"="$TOPIC_ARN"

echo "EventBridge rules '$RULE_GUARDDUTY' and '$RULE_CLOUDTRAIL' -> SNS topic $TOPIC_ARN"

cat > "$STATE_FILE" <<EOF
PROFILE=$PROFILE
REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
BUCKET_NAME=$BUCKET_NAME
TRAIL_NAME=$TRAIL_NAME
DETECTOR_ID=$DETECTOR_ID
LAB_USER=$LAB_USER
LAB_POLICY_NAME=$LAB_POLICY_NAME
LAB_POLICY_ARN=$LAB_POLICY_ARN
SNS_TOPIC_NAME=$SNS_TOPIC_NAME
TOPIC_ARN=$TOPIC_ARN
RULE_GUARDDUTY=$RULE_GUARDDUTY
RULE_CLOUDTRAIL=$RULE_CLOUDTRAIL
EOF

echo
echo "============================================================"
echo " Setup complete. Resource IDs written to: $STATE_FILE"
echo " Next: content/day16-cloud-detection.md Section 2, Steps 2-5."
echo " When done: ./teardown.sh --profile $PROFILE"
echo "============================================================"
