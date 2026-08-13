#!/usr/bin/env bash
#
# Day 14 lab — setup.sh
#
# AUTHORIZED USE ONLY: run this only against your own AWS sandbox account,
# using a named AWS CLI profile with administrator-level access in that
# sandbox. Never run this against a production account or any account you
# don't own or don't have explicit written authorization to test.
#
# What this creates:
#   - IAM user "day14-lowpriv" (programmatic access only, no console login)
#   - IAM managed policy "day14-lowpriv-policy", attached to that user, with:
#       * a handful of read-only IAM/STS calls (enumeration surface)
#       * the PLANTED MISCONFIG: iam:CreatePolicyVersion +
#         iam:SetDefaultPolicyVersion, scoped by Resource to the policy's own
#         ARN — this policy can rewrite and re-activate itself.
#   - A fresh access key for day14-lowpriv, written to a local, gitignored
#     JSON file (never printed to stdout, never committed).
#
# No credentials are hardcoded anywhere in this script. It authenticates
# entirely via a named AWS CLI profile (AWS_PROFILE env var, or --profile),
# exactly like every other AWS CLI invocation on this machine.
#
# Cost: IAM users, policies, and access keys are free. This lab creates no
# billable resources. Run ./teardown.sh when you're done regardless — an
# orphaned low-privilege access key sitting in your sandbox account is a
# standing risk even though it costs nothing.

set -euo pipefail

PROFILE="${AWS_PROFILE:-cyberlab-sandbox}"
USER_NAME="day14-lowpriv"
POLICY_NAME="day14-lowpriv-policy"
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/output"

echo "== Day 14 setup =="
echo "Using AWS CLI profile: ${PROFILE}"
echo "(override with: AWS_PROFILE=<your-sandbox-profile> ./setup.sh)"
echo

mkdir -p "${OUTPUT_DIR}"

echo "[1/6] Resolving account ID via sts:get-caller-identity ..."
ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" \
  --query 'Account' --output text)"
echo "      Account: ${ACCOUNT_ID}"

# The policy ARN is deterministic once we know the account ID and policy
# name, so we can reference it inside the policy document itself before the
# policy exists — this self-reference is exactly the planted misconfig.
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "[2/6] Creating IAM user: ${USER_NAME} ..."
aws iam create-user \
  --user-name "${USER_NAME}" \
  --tags Key=purpose,Value=cyber-security-day14-lab \
  --profile "${PROFILE}" >/dev/null

echo "[3/6] Writing planted-misconfig policy document ..."
POLICY_DOC="$(mktemp)"
cat > "${POLICY_DOC}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnumerationReadOnly",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "iam:GetUser",
        "iam:ListAttachedUserPolicies",
        "iam:ListUserPolicies",
        "iam:ListGroupsForUser",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PLANTED_MISCONFIG_SelfModifyingPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ],
      "Resource": "${POLICY_ARN}"
    }
  ]
}
EOF

echo "[4/6] Creating managed policy: ${POLICY_NAME} ..."
aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document "file://${POLICY_DOC}" \
  --description "Day 14 lab: low-priv policy with a self-referential CreatePolicyVersion misconfig" \
  --profile "${PROFILE}" >/dev/null
rm -f "${POLICY_DOC}"

echo "[5/6] Attaching policy to ${USER_NAME} ..."
aws iam attach-user-policy \
  --user-name "${USER_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" >/dev/null

echo "[6/6] Creating access key for ${USER_NAME} ..."
aws iam create-access-key \
  --user-name "${USER_NAME}" \
  --profile "${PROFILE}" \
  --output json > "${OUTPUT_DIR}/day14-lowpriv-access-key.json"
chmod 600 "${OUTPUT_DIR}/day14-lowpriv-access-key.json"

echo
echo "== Setup complete =="
echo "User:        ${USER_NAME}"
echo "Policy ARN:  ${POLICY_ARN}"
echo "Access key:  ${OUTPUT_DIR}/day14-lowpriv-access-key.json (chmod 600, gitignored)"
echo
echo "Next: configure a local profile from that file, e.g.:"
echo "  aws configure set aws_access_key_id     <AccessKeyId>     --profile day14-lowpriv"
echo "  aws configure set aws_secret_access_key <SecretAccessKey> --profile day14-lowpriv"
echo
echo "Then follow content/day14-iam-privesc.md Section 2 and labs/day14/README.md."
echo "Reminder: run ./teardown.sh when you are done with this lab."
