#!/usr/bin/env bash
#
# Day 14 lab — teardown.sh
#
# Removes everything setup.sh created: the access key(s), the user, the
# policy (including any extra versions the Attack Lab pushed via
# CreatePolicyVersion), and the local credentials file.
#
# Safe to run even after the Attack Lab has escalated the policy to
# Action:*/Resource:* — teardown always runs from the admin-level sandbox
# profile, which already has full rights regardless of what the low-priv
# policy's current document says.
#
# Uses the same named-profile pattern as setup.sh; no credentials hardcoded.

set -euo pipefail

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
USER_NAME="day14-lowpriv"
POLICY_NAME="day14-lowpriv-policy"
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/output"

echo "== Day 14 teardown =="
echo "Using AWS CLI profile: ${PROFILE}"
echo

ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" \
  --query 'Account' --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "[1/6] Deleting access key(s) for ${USER_NAME} (if any) ..."
KEY_IDS="$(aws iam list-access-keys --user-name "${USER_NAME}" \
  --profile "${PROFILE}" --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text 2>/dev/null || true)"
if [[ -n "${KEY_IDS}" ]]; then
  for KEY_ID in ${KEY_IDS}; do
    echo "      deleting access key ${KEY_ID}"
    aws iam delete-access-key --user-name "${USER_NAME}" \
      --access-key-id "${KEY_ID}" --profile "${PROFILE}"
  done
else
  echo "      none found (already removed, or user does not exist)"
fi

echo "[2/6] Detaching ${POLICY_NAME} from ${USER_NAME} (if attached) ..."
aws iam detach-user-policy --user-name "${USER_NAME}" \
  --policy-arn "${POLICY_ARN}" --profile "${PROFILE}" 2>/dev/null \
  || echo "      already detached, or user/policy does not exist"

echo "[3/6] Deleting non-default policy versions of ${POLICY_NAME} ..."
VERSION_IDS="$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" \
  --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
  --output text 2>/dev/null || true)"
if [[ -n "${VERSION_IDS}" ]]; then
  for VERSION_ID in ${VERSION_IDS}; do
    echo "      deleting policy version ${VERSION_ID}"
    aws iam delete-policy-version --policy-arn "${POLICY_ARN}" \
      --version-id "${VERSION_ID}" --profile "${PROFILE}"
  done
else
  echo "      none found (already removed, or policy does not exist)"
fi

echo "[4/6] Deleting policy ${POLICY_NAME} (removes its default version too) ..."
aws iam delete-policy --policy-arn "${POLICY_ARN}" --profile "${PROFILE}" 2>/dev/null \
  || echo "      already removed, or policy does not exist"

echo "[5/6] Deleting user ${USER_NAME} ..."
aws iam delete-user --user-name "${USER_NAME}" --profile "${PROFILE}" 2>/dev/null \
  || echo "      already removed, or user does not exist"

echo "[6/6] Removing local credentials file ..."
rm -f "${OUTPUT_DIR}/day14-lowpriv-access-key.json"

echo
echo "== Verify (run manually) =="
echo "  aws iam get-user --user-name ${USER_NAME} --profile ${PROFILE}"
echo "Expected: an error naming NoSuchEntity — confirming the user is gone."
echo
echo "== Teardown complete =="
