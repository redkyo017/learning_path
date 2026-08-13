#!/usr/bin/env bash
# Day 13 lab setup — Cloud security model & IAM foundations
#
# AUTHORIZED USE ONLY. Run this against your OWN AWS sandbox account only.
# Creates a deliberately OVER-PERMISSIVE IAM setup for you to assess and
# fix in this lab:
#   - an IAM user   (cyberlab-day13-user)
#   - an IAM policy (cyberlab-day13-overpermissive-policy) with a wide-open
#     s3:* statement, attached to both the user and the role below
#   - an IAM role   (cyberlab-day13-role) trusted by ec2.amazonaws.com,
#     which foreshadows Day 14's iam:PassRole discussion
#
# Never hardcode credentials. This script only ever references a named AWS
# CLI profile (AWS_PROFILE env var, or --profile below) that you must have
# already configured with `aws configure --profile <name>`.
#
# Usage:
#   AWS_PROFILE=my-sandbox-profile ./setup.sh
#   ./setup.sh --dry-run           # print the plan, make no API calls

set -euo pipefail

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
REGION="${AWS_REGION:-us-east-1}"
PREFIX="cyberlab-day13"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

USER_NAME="${PREFIX}-user"
ROLE_NAME="${PREFIX}-role"
POLICY_NAME="${PREFIX}-overpermissive-policy"

echo "== Day 13 setup =="
echo "AWS profile: ${PROFILE}"
echo "AWS region:  ${REGION}"
echo "Will create:"
echo "  - IAM user:   ${USER_NAME}"
echo "  - IAM policy: ${POLICY_NAME} (from ${POLICY_DIR}/overpermissive-policy.json)"
echo "  - IAM role:   ${ROLE_NAME} (trust policy: ${POLICY_DIR}/trust-policy.json)"
echo

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "[dry-run] No AWS API calls will be made."
  echo "[dry-run] Would run: aws iam create-user --user-name ${USER_NAME} --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam create-policy --policy-name ${POLICY_NAME} --policy-document file://${POLICY_DIR}/overpermissive-policy.json --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam attach-user-policy --user-name ${USER_NAME} --policy-arn <POLICY_ARN> --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://${POLICY_DIR}/trust-policy.json --profile ${PROFILE}"
  echo "[dry-run] Would run: aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn <POLICY_ARN> --profile ${PROFILE}"
  exit 0
fi

echo "--- Verifying AWS CLI identity under profile '${PROFILE}' ---"
aws sts get-caller-identity --profile "${PROFILE}" --output table

echo "--- Creating IAM user: ${USER_NAME} ---"
aws iam create-user \
  --user-name "${USER_NAME}" \
  --tags Key=purpose,Value=cyberlab-day13 \
  --profile "${PROFILE}"

echo "--- Creating over-permissive policy: ${POLICY_NAME} ---"
POLICY_ARN="$(aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document "file://${POLICY_DIR}/overpermissive-policy.json" \
  --profile "${PROFILE}" \
  --query 'Policy.Arn' --output text)"
echo "Policy ARN: ${POLICY_ARN}"

echo "--- Attaching policy to user ---"
aws iam attach-user-policy \
  --user-name "${USER_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}"

echo "--- Creating role: ${ROLE_NAME} ---"
aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document "file://${POLICY_DIR}/trust-policy.json" \
  --tags Key=purpose,Value=cyberlab-day13 \
  --profile "${PROFILE}"

echo "--- Attaching policy to role ---"
aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}"

echo
echo "Setup complete."
echo "  User:   ${USER_NAME}"
echo "  Role:   ${ROLE_NAME}"
echo "  Policy: ${POLICY_ARN}"
echo
echo "This account now has a live, over-permissive IAM policy attached to"
echo "a real user and role. Work the lab in content/day13-cloud-iam.md,"
echo "then run ./teardown.sh — do not leave this attached longer than needed."
