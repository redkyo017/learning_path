#!/usr/bin/env bash
# Day 13 lab teardown — removes every resource setup.sh created.
#
# AUTHORIZED USE ONLY. Run this against the same AWS sandbox account and
# profile you ran setup.sh against.
#
# Usage:
#   AWS_PROFILE=my-sandbox-profile ./teardown.sh
#   ./teardown.sh --dry-run        # print the plan, make no API calls

set -euo pipefail

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
PREFIX="cyberlab-day13"

USER_NAME="${PREFIX}-user"
ROLE_NAME="${PREFIX}-role"
POLICY_NAME="${PREFIX}-overpermissive-policy"

echo "== Day 13 teardown =="
echo "AWS profile: ${PROFILE}"
echo "Will delete: IAM user ${USER_NAME}, IAM role ${ROLE_NAME}, IAM policy ${POLICY_NAME}"
echo "(and, if you created it while working the lab: any least-privilege"
echo " replacement policy you attached during the Defense Lab section)"
echo

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "[dry-run] No AWS API calls will be made."
  echo "[dry-run] Would run: aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn <POLICY_ARN> --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam delete-role --role-name ${ROLE_NAME} --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam detach-user-policy --user-name ${USER_NAME} --policy-arn <POLICY_ARN> --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam delete-user --user-name ${USER_NAME} --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam delete-policy --policy-arn <POLICY_ARN> --profile ${PROFILE}"
  exit 0
fi

ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" --query 'Account' --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "Account: ${ACCOUNT_ID}"
echo "Policy ARN: ${POLICY_ARN}"
echo

echo "--- Detaching policy from role (if attached) ---"
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" || true

echo "--- Deleting role ---"
aws iam delete-role \
  --role-name "${ROLE_NAME}" \
  --profile "${PROFILE}" || true

echo "--- Detaching policy from user (if attached) ---"
aws iam detach-user-policy \
  --user-name "${USER_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" || true

echo "--- Deleting user ---"
aws iam delete-user \
  --user-name "${USER_NAME}" \
  --profile "${PROFILE}" || true

echo "--- Deleting non-default policy versions (if you created one via create-policy-version in the Defense Lab) ---"
NON_DEFAULT_VERSIONS="$(aws iam list-policy-versions \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" \
  --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
  --output text 2>/dev/null || true)"
for VERSION_ID in ${NON_DEFAULT_VERSIONS}; do
  echo "  deleting policy version ${VERSION_ID}"
  aws iam delete-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --version-id "${VERSION_ID}" \
    --profile "${PROFILE}" || true
done

echo "--- Deleting policy (default version) ---"
aws iam delete-policy \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" || true

echo
echo "Teardown complete. Verify every resource is actually gone:"
echo "  aws iam get-user --user-name ${USER_NAME} --profile ${PROFILE}   # expect NoSuchEntity"
echo "  aws iam get-role --role-name ${ROLE_NAME} --profile ${PROFILE}   # expect NoSuchEntity"
echo "  aws iam get-policy --policy-arn ${POLICY_ARN} --profile ${PROFILE}  # expect NoSuchEntity"
