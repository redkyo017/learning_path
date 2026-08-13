#!/usr/bin/env bash
# Day 15 lab teardown — removes every resource setup.sh created.
#
# Reads labs/day15/.day15-state.env (written by setup.sh) for resource IDs.
# If that file is missing, falls back to tag-based lookup on
# purpose=$PREFIX (default cyberlab-day15) so teardown still works even if
# the state file was lost.
#
# Like setup.sh, this script only ever AUTHORS AWS CLI invocations -- it is
# not executed as part of building this lab. Validate with `bash -n
# teardown.sh` before your first real run, and always run it after you're
# done with this lab (see README.md's cost + teardown reminder).

set -uo pipefail  # not -e: teardown must keep going even if one step 404s

: "${AWS_PROFILE:?Set AWS_PROFILE to the same named profile setup.sh used}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.day15-state.env"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
else
  echo "WARNING: $STATE_FILE not found -- falling back to tag-based lookup." >&2
  AWS_REGION="${AWS_REGION:-us-east-1}"
  PREFIX="${PREFIX:-cyberlab-day15}"
  ACCOUNT_ID="$(aws --profile "$AWS_PROFILE" sts get-caller-identity --query Account --output text)"
  ROLE_NAME="${PREFIX}-instance-role"
  PROFILE_NAME="${PREFIX}-instance-profile"
  PRIVATE_BUCKET="${PREFIX}-private-${ACCOUNT_ID}"
  PUBLIC_BUCKET="${PREFIX}-public-${ACCOUNT_ID}"
  SG_ID="$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 describe-security-groups \
    --filters "Name=tag:purpose,Values=$PREFIX" --query 'SecurityGroups[0].GroupId' --output text)"
  INSTANCE_ID="$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 describe-instances \
    --filters "Name=tag:purpose,Values=$PREFIX" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)"
fi

AWS=(aws --profile "$AWS_PROFILE" --region "$AWS_REGION")
echo "== Day 15 teardown: profile=$AWS_PROFILE region=$AWS_REGION prefix=$PREFIX =="

# --- 1. Terminate the EC2 instance ------------------------------------------
if [ -n "${INSTANCE_ID:-}" ] && [ "$INSTANCE_ID" != "None" ]; then
  echo "-- Terminating instance: $INSTANCE_ID"
  "${AWS[@]}" ec2 terminate-instances --instance-ids "$INSTANCE_ID" || true
  echo "-- Waiting for termination"
  "${AWS[@]}" ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" || true
else
  echo "-- No instance ID found; skipping instance termination"
fi

# --- 2. Delete the security group (after the instance's ENI is gone) -------
if [ -n "${SG_ID:-}" ] && [ "$SG_ID" != "None" ]; then
  echo "-- Deleting security group: $SG_ID"
  "${AWS[@]}" ec2 delete-security-group --group-id "$SG_ID" || \
    echo "   (retry manually if the ENI hasn't fully detached yet)"
fi

# --- 3. Remove IAM instance profile + role + attached/inline policies ------
if [ -n "${PROFILE_NAME:-}" ]; then
  echo "-- Removing IAM instance profile: $PROFILE_NAME"
  "${AWS[@]}" iam remove-role-from-instance-profile \
    --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME" || true
  "${AWS[@]}" iam delete-instance-profile --instance-profile-name "$PROFILE_NAME" || true
fi

if [ -n "${ROLE_NAME:-}" ]; then
  echo "-- Detaching/deleting IAM role: $ROLE_NAME"
  "${AWS[@]}" iam detach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess || true
  # Defense 3 (content/day15-metadata-s3.md) may have added this inline
  # policy in place of the managed one above -- remove it too if present.
  "${AWS[@]}" iam delete-role-policy --role-name "$ROLE_NAME" \
    --policy-name day15-scoped-s3-read || true
  "${AWS[@]}" iam delete-role --role-name "$ROLE_NAME" || true
fi

# --- 4. Empty and delete both buckets ---------------------------------------
for BUCKET in "${PRIVATE_BUCKET:-}" "${PUBLIC_BUCKET:-}"; do
  if [ -n "$BUCKET" ]; then
    echo "-- Emptying and deleting bucket: $BUCKET"
    "${AWS[@]}" s3 rm "s3://$BUCKET" --recursive || true
    "${AWS[@]}" s3api delete-bucket-policy --bucket "$BUCKET" || true
    "${AWS[@]}" s3api delete-bucket --bucket "$BUCKET" || true
  fi
done

rm -f "$STATE_FILE"

echo "== Day 15 teardown complete =="
echo "Verify with:"
echo "  aws --profile $AWS_PROFILE --region $AWS_REGION ec2 describe-instances --filters Name=tag:purpose,Values=$PREFIX --query 'Reservations[].Instances[].State.Name'"
echo "  aws --profile $AWS_PROFILE s3 ls | grep $PREFIX   # expect no output"
echo "  aws --profile $AWS_PROFILE iam get-role --role-name $ROLE_NAME   # expect NoSuchEntity"
