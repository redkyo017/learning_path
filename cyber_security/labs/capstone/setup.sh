#!/usr/bin/env bash
# Capstone lab setup — brings up the Docker environment (default) and,
# optionally, a real AWS S3 bucket + IAM role/instance-profile for the
# extra-credit real-AWS variant of the SSRF-to-cloud-creds stage.
#
# AUTHORIZED USE ONLY. The Docker part targets only the containers this
# script starts. The optional AWS part targets only your own AWS sandbox
# account, never hardcodes credentials, and only ever reads a named AWS
# CLI profile (AWS_PROFILE env var, default `cyberlab-sandbox`) that you
# must have already configured with `aws configure --profile <name>`.
#
# Usage:
#   ./setup.sh                 # Docker only (default, free, no AWS calls at all)
#   ./setup.sh --with-aws      # also provision the real S3 bucket + IAM role
#   ./setup.sh --check         # dry validation only -- makes NO docker or aws
#                               # API calls, just checks tools/config are sane
#   ./setup.sh --with-aws --check   # dry validation of the AWS plan too
#
# See README.md for what --with-aws actually buys you (real IMDS instead
# of fake-imds, when the resulting instance profile is attached to a real
# EC2 instance you run this compose file on) and why it is optional.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
REGION="${AWS_REGION:-us-east-1}"
PREFIX="cyberlab-capstone"

BUCKET_NAME="${CAPSTONE_BUCKET_NAME:-${PREFIX}-$(date +%s)}"
ROLE_NAME="${PREFIX}-role"
POLICY_NAME="${PREFIX}-s3-policy"
INSTANCE_PROFILE_NAME="${PREFIX}-instance-profile"

WITH_AWS=0
CHECK_ONLY=0
for arg in "$@"; do
  case "${arg}" in
    --with-aws) WITH_AWS=1 ;;
    --check|--dry-run) CHECK_ONLY=1 ;;
    *) echo "unknown flag: ${arg}" >&2; exit 2 ;;
  esac
done

echo "== Capstone setup =="
echo "Docker: bring up webapp + host + fake-imds + fake-s3 on cyberlab/internal/imds"
if [[ "${WITH_AWS}" -eq 1 ]]; then
  echo "AWS:    provision S3 bucket + IAM role/instance-profile (profile=${PROFILE}, region=${REGION})"
else
  echo "AWS:    skipped (pass --with-aws to also provision real AWS resources)"
fi
echo

# ---------------------------------------------------------------------------
# --check: validate tooling/config only. No docker or aws API calls at all.
# ---------------------------------------------------------------------------
if [[ "${CHECK_ONLY}" -eq 1 ]]; then
  echo "[check] docker compose config -q ..."
  (cd "${SCRIPT_DIR}" && docker compose config -q) && echo "[check] compose file OK"

  echo "[check] does the shared 'attacker' network exist? (labs/base/up.sh creates it)"
  if docker network inspect cyberlab >/dev/null 2>&1; then
    echo "[check] cyberlab network: present"
  else
    echo "[check] cyberlab network: NOT FOUND -- run ../base/up.sh first"
  fi

  if [[ "${WITH_AWS}" -eq 1 ]]; then
    echo "[check] aws CLI present? $(command -v aws || echo 'NOT FOUND')"
    echo "[check] would use profile '${PROFILE}' in region '${REGION}'"
    echo "[check] would create S3 bucket:        ${BUCKET_NAME}"
    echo "[check] would create IAM policy:       ${POLICY_NAME} (scoped to that bucket, see policies/iam-policy-after.json)"
    echo "[check] would create IAM role:         ${ROLE_NAME} (trust policy: policies/trust-policy.json)"
    echo "[check] would create instance profile: ${INSTANCE_PROFILE_NAME}"
    echo "[check] NO aws API calls were made."
  fi
  echo "CAPSTONE_CHECK_OK"
  exit 0
fi

# ---------------------------------------------------------------------------
# Docker: always brought up (this is the default, free, no-AWS-needed path)
# ---------------------------------------------------------------------------
echo "--- Docker: bringing up the capstone environment ---"
mkdir -p "${SCRIPT_DIR}/logs/webapp"
chmod 777 "${SCRIPT_DIR}/logs/webapp" || true
(cd "${SCRIPT_DIR}" && docker compose up -d --build)
echo "Docker environment is up. Verify with:"
echo "  docker compose exec attacker sh -c \"curl -s webapp:5000/ ; echo\"   # (run from ../base)"
echo

if [[ "${WITH_AWS}" -eq 0 ]]; then
  echo "Setup complete (Docker only). Work content/day20-capstone-attack.md."
  exit 0
fi

# ---------------------------------------------------------------------------
# --with-aws: real S3 bucket + IAM role/instance-profile in YOUR sandbox
# ---------------------------------------------------------------------------
echo "--- AWS: verifying identity under profile '${PROFILE}' ---"
aws sts get-caller-identity --profile "${PROFILE}" --output table

echo "--- AWS: creating S3 bucket ${BUCKET_NAME} (region ${REGION}) ---"
if [[ "${REGION}" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "${BUCKET_NAME}" --profile "${PROFILE}"
else
  aws s3api create-bucket --bucket "${BUCKET_NAME}" --profile "${PROFILE}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
fi
aws s3api put-public-access-block --bucket "${BUCKET_NAME}" --profile "${PROFILE}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "--- AWS: uploading the findings object the stolen role will read ---"
TMP_OBJ="$(mktemp)"
printf 'Q3 internal pentest findings -- CONFIDENTIAL, DO NOT DISTRIBUTE\nCTF{capstone-real-aws-creds-stolen-via-ssrf}\n' > "${TMP_OBJ}"
aws s3 cp "${TMP_OBJ}" "s3://${BUCKET_NAME}/confidential/findings.txt" --profile "${PROFILE}"
rm -f "${TMP_OBJ}"

echo "--- AWS: creating scoped IAM policy ${POLICY_NAME} (baseline: over-broad, see policies/iam-policy-before.json) ---"
sed "s/REPLACE_WITH_BUCKET_NAME/${BUCKET_NAME}/g" "${POLICY_DIR}/iam-policy-before.json" > /tmp/capstone-before-policy.json
POLICY_ARN="$(aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document "file:///tmp/capstone-before-policy.json" \
  --profile "${PROFILE}" \
  --query 'Policy.Arn' --output text)"
echo "Policy ARN: ${POLICY_ARN}"

echo "--- AWS: creating IAM role ${ROLE_NAME} (trusted by ec2.amazonaws.com) ---"
aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document "file://${POLICY_DIR}/trust-policy.json" \
  --tags Key=purpose,Value=cyberlab-capstone \
  --profile "${PROFILE}"

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}"

echo "--- AWS: creating instance profile ${INSTANCE_PROFILE_NAME} and adding the role ---"
aws iam create-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" --profile "${PROFILE}"
aws iam add-role-to-instance-profile \
  --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
  --role-name "${ROLE_NAME}" \
  --profile "${PROFILE}"

echo
echo "AWS setup complete."
echo "  Bucket:            ${BUCKET_NAME}"
echo "  IAM role:          ${ROLE_NAME}"
echo "  Instance profile:  ${INSTANCE_PROFILE_NAME}"
echo
echo "To get the REAL SSRF-to-IMDS experience (instead of fake-imds):"
echo "  1. Launch (or reuse) a small EC2 sandbox instance."
echo "  2. Attach instance profile '${INSTANCE_PROFILE_NAME}' to it."
echo "  3. Run 'docker compose up -d webapp host fake-s3' (skip fake-imds) on"
echo "     that instance -- webapp's /admin/fetch SSRF will now reach the"
echo "     REAL 169.254.169.254 and steal REAL temporary credentials for"
echo "     '${ROLE_NAME}', scoped to '${BUCKET_NAME}' only."
echo
echo "Remember: aws iam get-role/get-instance-profile/s3api head-bucket all"
echo "cost nothing while idle, but do not leave this attached to a live EC2"
echo "instance longer than the lab needs. Run ./teardown.sh --with-aws when done."
