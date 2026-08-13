#!/usr/bin/env bash
#
# Day 18 — Cloud consolidation lab: setup.sh
#
# Builds a scenario chaining Day 14's IAM enumeration/escalation with Day 15's
# SSRF-to-instance-credentials technique, so it can be detected with Day 16's
# telemetry approach in Stage 4. AUTHORIZED SANDBOX ONLY — see README.md.
#
# What this creates (all deletable by teardown.sh):
#   - An S3 bucket holding one private "flag" object (day18-flag1-....txt)
#   - An IAM role (day18-app-role) + customer-managed policy (day18-app-policy)
#     granting s3:GetObject on the flag object AND iam:CreatePolicyVersion on
#     its own policy ARN — a real AWS IAM-privesc misconfig, deliberately planted.
#   - An EC2 instance profile attaching that role to one t3.micro instance
#     running a minimal SSRF-vulnerable HTTP proxy on port 5000, with IMDSv1
#     left enabled (HttpTokens=optional) — the Day 15 vulnerability class.
#   - A security group allowing inbound tcp/5000 from ONLY the CIDR you pass
#     with --allowed-cidr (your own IP, e.g. "$(curl -s https://checkip.amazonaws.com)/32")
#     — reachable for you to run the attack stages, without leaving the
#     instance open to 0.0.0.0/0. Day 17 covers exactly why that distinction
#     matters; this lab practices it rather than contradicting it.
#   - A low-privilege IAM user (day18-learner) + policy (day18-learner-policy)
#     that can only read/enumerate (EC2 + IAM read-only calls) — this is the
#     entry-point identity for Stage 1. It has NO s3 access and NO
#     iam:CreatePolicyVersion permission of its own.
#
# No credentials are hardcoded anywhere in this script. The day18-learner
# access key is generated live by `aws iam create-access-key` and written only
# to a local, git-ignored-pattern file (aws-credentials-day18.txt). You supply
# your OWN named AWS CLI profile with --profile; this script never assumes a
# default profile or embeds any key material.
#
# Cost: EC2 t3.micro is free-tier eligible (750 hrs/month, new accounts, first
# 12 months); otherwise roughly $0.01/hr in most US regions. S3 + IAM are
# effectively free at this scale. Run teardown.sh as soon as you're done —
# see README.md's cost section for the full breakdown.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing — no hardcoded profile or region.
# ---------------------------------------------------------------------------
PROFILE=""
REGION="us-east-1"
ALLOWED_CIDR=""

usage() {
  cat <<'EOF'
Usage: ./setup.sh --profile <aws-profile> --allowed-cidr <your-ip>/32 [--region <aws-region>]

  --profile        Named AWS CLI profile pointing at YOUR OWN sandbox account.
                    Required. This script never assumes a default profile.
  --allowed-cidr    The only CIDR allowed to reach the lab's SSRF target on
                    port 5000 -- normally your own IP in /32 form, e.g.:
                    --allowed-cidr "$(curl -s https://checkip.amazonaws.com)/32"
                    Required. Refuses 0.0.0.0/0 -- see the check below.
  --region          AWS region to build the lab in. Defaults to us-east-1.
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --allowed-cidr) ALLOWED_CIDR="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  echo "ERROR: --profile is required. This lab never hardcodes credentials —" >&2
  echo "point it at a named AWS CLI profile for your own sandbox account." >&2
  usage
  exit 1
fi

if [[ -z "$ALLOWED_CIDR" ]]; then
  echo "ERROR: --allowed-cidr is required, e.g.:" >&2
  echo "  --allowed-cidr \"\$(curl -s https://checkip.amazonaws.com)/32\"" >&2
  usage
  exit 1
fi
if [[ "$ALLOWED_CIDR" == "0.0.0.0/0" ]]; then
  echo "ERROR: --allowed-cidr refuses 0.0.0.0/0 on purpose. Day 17 covers exactly" >&2
  echo "why an SSRF target reachable from anywhere is its own separate bug --" >&2
  echo "scope this to your own IP instead." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.day18-state.env"
CRED_FILE="$SCRIPT_DIR/aws-credentials-day18.txt"

# ---------------------------------------------------------------------------
# Idempotency guard — refuse to double-provision on top of a previous run.
# ---------------------------------------------------------------------------
if [[ -f "$STATE_FILE" ]]; then
  echo "ERROR: $STATE_FILE already exists — a previous setup.sh run may still" >&2
  echo "be live. Run ./teardown.sh first (it reads this same file), or delete" >&2
  echo "$STATE_FILE yourself only if you have already confirmed by hand that" >&2
  echo "every AWS resource it names is gone." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Preflight checks.
# ---------------------------------------------------------------------------
for bin in aws jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' is required on PATH and was not found." >&2
    exit 1
  fi
done

AWS=(aws --profile "$PROFILE" --region "$REGION")

echo "[*] Verifying profile '$PROFILE' can reach AWS (identity check only, no resources touched yet)..."
ACCOUNT_ID="$("${AWS[@]}" sts get-caller-identity --query Account --output text)"
echo "[*] Confirmed. Building Day 18 lab in account $ACCOUNT_ID, region $REGION."

# ---------------------------------------------------------------------------
# Fixed resource names (IAM-side; a rerun without teardown will collide here
# on purpose — see the idempotency guard above) and a short random suffix for
# the globally-unique S3 bucket name.
# ---------------------------------------------------------------------------
SUFFIX="$(date +%s | tail -c 6)$((RANDOM % 900 + 100))"
BUCKET_NAME="day18-cloud-lab-${ACCOUNT_ID}-${SUFFIX}"
FLAG_KEY="flag1-proof-of-access.txt"
FLAG1_VALUE="day18-flag1-$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)"

ROLE_NAME="day18-app-role"
APP_POLICY_NAME="day18-app-policy"
INSTANCE_PROFILE_NAME="day18-app-instance-profile"

LEARNER_USER_NAME="day18-learner"
LEARNER_POLICY_NAME="day18-learner-policy"

SG_NAME="day18-ssrf-sg"
INSTANCE_TAG_NAME="day18-ssrf-target"

echo "[*] Resource plan:"
echo "      S3 bucket:          $BUCKET_NAME"
echo "      App role:           $ROLE_NAME (+ policy $APP_POLICY_NAME)"
echo "      Instance profile:   $INSTANCE_PROFILE_NAME"
echo "      Learner user:       $LEARNER_USER_NAME (+ policy $LEARNER_POLICY_NAME)"
echo "      Security group:     $SG_NAME"
echo "      EC2 tag Name:       $INSTANCE_TAG_NAME"

# ---------------------------------------------------------------------------
# 1. S3 bucket + private flag object.
# ---------------------------------------------------------------------------
echo "[*] Creating S3 bucket..."
if [[ "$REGION" == "us-east-1" ]]; then
  "${AWS[@]}" s3api create-bucket --bucket "$BUCKET_NAME" >/dev/null
else
  "${AWS[@]}" s3api create-bucket --bucket "$BUCKET_NAME" \
    --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
fi
"${AWS[@]}" s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null

echo "$FLAG1_VALUE" | "${AWS[@]}" s3 cp - "s3://${BUCKET_NAME}/${FLAG_KEY}" >/dev/null
echo "[*] Flag 1 staged privately at s3://${BUCKET_NAME}/${FLAG_KEY} (bucket has Block Public Access ON — only readable by day18-app-role's own credentials)."

# ---------------------------------------------------------------------------
# 2. Customer-managed app policy (the deliberate misconfig) + role.
# ---------------------------------------------------------------------------
echo "[*] Creating IAM role and app policy (the planted privesc misconfig)..."

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
)

"${AWS[@]}" iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --description "Day 18 lab — EC2 instance role, deliberately over-permissive" >/dev/null

APP_POLICY_ARN_PLACEHOLDER="arn:aws:iam::${ACCOUNT_ID}:policy/${APP_POLICY_NAME}"

APP_POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadTheFlag",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/${FLAG_KEY}"
    },
    {
      "Sid": "WhoAmI",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "SelfPolicyEscalationMisconfig",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion"
      ],
      "Resource": "${APP_POLICY_ARN_PLACEHOLDER}"
    }
  ]
}
EOF
)

APP_POLICY_ARN="$("${AWS[@]}" iam create-policy \
  --policy-name "$APP_POLICY_NAME" \
  --description "Day 18 lab — deliberately grants CreatePolicyVersion on itself" \
  --policy-document "$APP_POLICY_DOC" \
  --query 'Policy.Arn' --output text)"

"${AWS[@]}" iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$APP_POLICY_ARN" >/dev/null

echo "[*] Creating instance profile and attaching the role..."
"${AWS[@]}" iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME" >/dev/null
"${AWS[@]}" iam add-role-to-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" --role-name "$ROLE_NAME" >/dev/null
echo "[*] Waiting ~10s for IAM instance-profile propagation..."
sleep 10

# ---------------------------------------------------------------------------
# 3. Low-privilege learner user (Stage 1's entry point).
# ---------------------------------------------------------------------------
echo "[*] Creating low-privilege IAM user (day18-learner) — enumeration-only..."

LEARNER_POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WhoAmI",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "EnumerateEC2",
      "Effect": "Allow",
      "Action": ["ec2:DescribeInstances", "ec2:DescribeSecurityGroups"],
      "Resource": "*"
    },
    {
      "Sid": "EnumerateIAMReadOnly",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

"${AWS[@]}" iam create-user --user-name "$LEARNER_USER_NAME" >/dev/null
LEARNER_POLICY_ARN="$("${AWS[@]}" iam create-policy \
  --policy-name "$LEARNER_POLICY_NAME" \
  --description "Day 18 lab — read-only enumeration, no s3, no CreatePolicyVersion" \
  --policy-document "$LEARNER_POLICY_DOC" \
  --query 'Policy.Arn' --output text)"
"${AWS[@]}" iam attach-user-policy --user-name "$LEARNER_USER_NAME" --policy-arn "$LEARNER_POLICY_ARN" >/dev/null

echo "[*] Generating a live access key for day18-learner (no key material is stored in this script)..."
KEY_JSON="$("${AWS[@]}" iam create-access-key --user-name "$LEARNER_USER_NAME")"
LEARNER_ACCESS_KEY_ID="$(echo "$KEY_JSON" | jq -r '.AccessKey.AccessKeyId')"
LEARNER_SECRET_ACCESS_KEY="$(echo "$KEY_JSON" | jq -r '.AccessKey.SecretAccessKey')"

umask 177
cat > "$CRED_FILE" <<EOF
# Day 18 lab — day18-learner credentials, generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# This file matches the repo's aws-credentials* .gitignore pattern — do not
# commit it, and delete it yourself if that pattern ever changes.
# Use with: aws --profile day18-learner sts get-caller-identity
# (after adding a [day18-learner] profile block to your local ~/.aws/credentials
# with these two values, or export them as AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY).
AWS_ACCESS_KEY_ID=${LEARNER_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${LEARNER_SECRET_ACCESS_KEY}
EOF
echo "[*] day18-learner credentials written to: $CRED_FILE (chmod 600)."

# ---------------------------------------------------------------------------
# 4. Security group (deliberately permissive — SSRF target must be reachable).
# ---------------------------------------------------------------------------
echo "[*] Resolving default VPC and creating the security group..."
VPC_ID="$("${AWS[@]}" ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"
if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "ERROR: no default VPC found in region $REGION for profile $PROFILE." >&2
  echo "This lab expects a default VPC. Create one, or adapt setup.sh to a" >&2
  echo "specific subnet before continuing." >&2
  exit 1
fi

SG_ID="$("${AWS[@]}" ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Day 18 lab — SSRF target on 5000, restricted to --allowed-cidr" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)"
"${AWS[@]}" ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" --protocol tcp --port 5000 --cidr "$ALLOWED_CIDR" >/dev/null

# ---------------------------------------------------------------------------
# 5. EC2 instance — the SSRF-vulnerable target, IMDSv1 left enabled on purpose.
# ---------------------------------------------------------------------------
echo "[*] Resolving latest Amazon Linux 2023 AMI via SSM public parameter..."
AMI_ID="$("${AWS[@]}" ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text)"

USER_DATA=$(cat <<'USERDATA'
#!/bin/bash
mkdir -p /opt/day18
cat > /opt/day18/app.py <<'PYEOF'
"""
Day 18 lab target: a deliberately vulnerable SSRF proxy.
GET /fetch?url=<any-url> makes a server-side request to <url> and returns the
body. No allowlist, no denylist, no check against link-local addresses --
exactly the Day 9/15 SSRF class this whole path teaches you to recognize and
block. Authorized-sandbox-only; this file only exists inside a lab instance
you control.
"""
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/fetch":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"not found")
            return
        qs = parse_qs(parsed.query)
        target_url = qs.get("url", [None])[0]
        if not target_url:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"missing url param")
            return
        try:
            with urllib.request.urlopen(target_url, timeout=5) as resp:
                body = resp.read()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(body)
        except Exception as exc:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(exc).encode())

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
PYEOF
cat > /etc/systemd/system/day18-app.service <<'SVCEOF'
[Unit]
Description=Day 18 lab SSRF target
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/day18/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable --now day18-app.service
USERDATA
)

echo "[*] Launching the EC2 target instance (t3.micro, IMDSv1 allowed — the vulnerability)..."
INSTANCE_ID="$("${AWS[@]}" ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile "Name=${INSTANCE_PROFILE_NAME}" \
  --metadata-options "HttpTokens=optional,HttpPutResponseHopLimit=1,HttpEndpoint=enabled" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_TAG_NAME}}]" \
  --query 'Instances[0].InstanceId' --output text)"

echo "[*] Waiting for the instance to reach 'running'..."
"${AWS[@]}" ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP="$("${AWS[@]}" ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"

# ---------------------------------------------------------------------------
# 6. Persist state for teardown.sh and print the summary.
# ---------------------------------------------------------------------------
cat > "$STATE_FILE" <<EOF
PROFILE=${PROFILE}
REGION=${REGION}
ALLOWED_CIDR=${ALLOWED_CIDR}
ACCOUNT_ID=${ACCOUNT_ID}
BUCKET_NAME=${BUCKET_NAME}
FLAG_KEY=${FLAG_KEY}
ROLE_NAME=${ROLE_NAME}
APP_POLICY_NAME=${APP_POLICY_NAME}
APP_POLICY_ARN=${APP_POLICY_ARN}
INSTANCE_PROFILE_NAME=${INSTANCE_PROFILE_NAME}
LEARNER_USER_NAME=${LEARNER_USER_NAME}
LEARNER_POLICY_NAME=${LEARNER_POLICY_NAME}
LEARNER_POLICY_ARN=${LEARNER_POLICY_ARN}
SG_ID=${SG_ID}
SG_NAME=${SG_NAME}
INSTANCE_ID=${INSTANCE_ID}
INSTANCE_TAG_NAME=${INSTANCE_TAG_NAME}
VPC_ID=${VPC_ID}
PUBLIC_IP=${PUBLIC_IP}
EOF

echo ""
echo "================================================================"
echo " Day 18 lab is UP."
echo "================================================================"
echo " Target public IP:      $PUBLIC_IP  (SSRF app on port 5000)"
echo " day18-app-role ARN:    $(${AWS[@]} iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"
echo " day18-app-policy ARN:  $APP_POLICY_ARN"
echo " Flag 1 location:       s3://${BUCKET_NAME}/${FLAG_KEY}"
echo " Learner credentials:   $CRED_FILE (day18-learner — enumeration only)"
echo ""
echo " Next: work Stage 1 onward in content/day18-cloud-lab.md, then"
echo " labs/day18/README.md for the exact commands, or SOLUTION.md if stuck."
echo ""
echo " COST + TEARDOWN REMINDER: one t3.micro EC2 instance is now running."
echo " Free-tier eligible for new accounts (750 hrs/month first 12 months);"
echo " otherwise roughly \$0.01/hr. Run ./teardown.sh as soon as you finish"
echo " Stage 4 — do not leave this running between sessions."
echo "================================================================"
