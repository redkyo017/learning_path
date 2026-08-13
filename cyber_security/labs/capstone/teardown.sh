#!/usr/bin/env bash
# Capstone lab teardown — tears down the Docker environment (default) and,
# if you ran setup.sh --with-aws, the real S3 bucket + IAM role/instance-
# profile it created.
#
# AUTHORIZED USE ONLY — same scope as setup.sh.
#
# Usage:
#   ./teardown.sh                                    # Docker only
#   ./teardown.sh --with-aws --bucket <bucket-name>  # also delete AWS resources
#   ./teardown.sh --check                            # dry validation, no
#                                                      # docker/aws API calls
#
# The bucket name is NOT guessed (setup.sh's default includes a
# timestamp) -- pass the exact name setup.sh printed, or set
# CAPSTONE_BUCKET_NAME.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
PREFIX="cyberlab-capstone"
ROLE_NAME="${PREFIX}-role"
POLICY_NAME="${PREFIX}-s3-policy"
INSTANCE_PROFILE_NAME="${PREFIX}-instance-profile"

WITH_AWS=0
CHECK_ONLY=0
BUCKET_NAME="${CAPSTONE_BUCKET_NAME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-aws) WITH_AWS=1; shift ;;
    --check|--dry-run) CHECK_ONLY=1; shift ;;
    --bucket) BUCKET_NAME="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

echo "== Capstone teardown =="
echo "Docker: docker compose down -v (removes webapp, host, fake-imds, fake-s3,"
echo "        the internal/imds networks, and their volumes)"
if [[ "${WITH_AWS}" -eq 1 ]]; then
  echo "AWS:    delete instance profile, role, policy, and bucket '${BUCKET_NAME:-<none given>}'"
fi
echo

if [[ "${CHECK_ONLY}" -eq 1 ]]; then
  echo "[check] docker compose config -q ..."
  (cd "${SCRIPT_DIR}" && docker compose config -q) && echo "[check] compose file OK"
  if [[ "${WITH_AWS}" -eq 1 ]]; then
    echo "[check] would delete IAM instance profile: ${INSTANCE_PROFILE_NAME}"
    echo "[check] would delete IAM role:             ${ROLE_NAME}"
    echo "[check] would delete IAM policy:           ${POLICY_NAME}"
    echo "[check] would empty + delete S3 bucket:    ${BUCKET_NAME:-<none given -- required for a real run>}"
    echo "[check] NO aws API calls were made."
  fi
  echo "CAPSTONE_CHECK_OK"
  exit 0
fi

echo "--- Docker: tearing down the capstone environment ---"
(cd "${SCRIPT_DIR}" && docker compose down -v)
echo "Docker teardown complete."
echo

if [[ "${WITH_AWS}" -eq 0 ]]; then
  echo "Teardown complete (Docker only). If you ran setup.sh --with-aws, re-run"
  echo "this script with --with-aws --bucket <name> to also clean up AWS."
  exit 0
fi

if [[ -z "${BUCKET_NAME}" ]]; then
  echo "ERROR: --with-aws requires --bucket <name> (or CAPSTONE_BUCKET_NAME set)." >&2
  echo "The bucket name was printed by setup.sh when it ran." >&2
  exit 1
fi

echo "--- AWS: verifying identity under profile '${PROFILE}' ---"
aws sts get-caller-identity --profile "${PROFILE}" --output table

ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" --query 'Account' --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "Policy ARN: ${POLICY_ARN}"

echo "--- AWS: removing role from instance profile, then deleting the instance profile ---"
aws iam remove-role-from-instance-profile \
  --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
  --role-name "${ROLE_NAME}" \
  --profile "${PROFILE}" || true
aws iam delete-instance-profile \
  --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
  --profile "${PROFILE}" || true

echo "--- AWS: detaching policy from role, then deleting the role ---"
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" || true
aws iam delete-role --role-name "${ROLE_NAME}" --profile "${PROFILE}" || true

echo "--- AWS: deleting non-default policy versions, then the policy itself ---"
NON_DEFAULT_VERSIONS="$(aws iam list-policy-versions \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" \
  --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
  --output text 2>/dev/null || true)"
for VERSION_ID in ${NON_DEFAULT_VERSIONS}; do
  echo "  deleting policy version ${VERSION_ID}"
  aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${VERSION_ID}" --profile "${PROFILE}" || true
done
aws iam delete-policy --policy-arn "${POLICY_ARN}" --profile "${PROFILE}" || true

echo "--- AWS: emptying and deleting bucket ${BUCKET_NAME} ---"
aws s3 rm "s3://${BUCKET_NAME}" --recursive --profile "${PROFILE}" || true
aws s3api delete-bucket --bucket "${BUCKET_NAME}" --profile "${PROFILE}" || true

echo
echo "AWS teardown complete. Verify every resource is actually gone:"
echo "  aws iam get-role --role-name ${ROLE_NAME} --profile ${PROFILE}                       # expect NoSuchEntity"
echo "  aws iam get-instance-profile --instance-profile-name ${INSTANCE_PROFILE_NAME} --profile ${PROFILE}  # expect NoSuchEntity"
echo "  aws iam get-policy --policy-arn ${POLICY_ARN} --profile ${PROFILE}                    # expect NoSuchEntity"
echo "  aws s3api head-bucket --bucket ${BUCKET_NAME} --profile ${PROFILE}                    # expect 404 Not Found"
