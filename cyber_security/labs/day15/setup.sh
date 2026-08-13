#!/usr/bin/env bash
# Day 15 lab setup — AWS sandbox only.
#
# Creates, in the caller's own AWS account:
#   1. An IAM instance role, deliberately over-permissive (AmazonS3ReadOnlyAccess)
#      as this lab's ATTACK baseline. Defense 3 (content/day15-metadata-s3.md)
#      tightens this to least privilege by hand, against the same role.
#   2. A "private" S3 bucket (Block Public Access ON, no public policy) holding
#      one object — reachable only with valid AWS credentials.
#   3. A "public" S3 bucket (Block Public Access OFF, a public-read bucket
#      policy) holding one object — reachable with zero credentials, on purpose.
#   4. A security group allowing inbound tcp/8080 (the lab app) and tcp/22 (ssh,
#      optional debugging) ONLY from $ALLOWED_CIDR.
#   5. One EC2 instance (t3.micro, free-tier eligible), IMDSv1 allowed
#      (HttpTokens=optional) on purpose — this lab's attack baseline — running a
#      small, deliberately SSRF-vulnerable "URL preview" app on port 8080 via
#      user-data.
#
# No credentials are hardcoded anywhere in this script. It authenticates using
# whatever named AWS CLI profile you export as $AWS_PROFILE — you must have
# already configured that profile yourself (`aws configure --profile ...`).
#
# This script only ever AUTHORS AWS CLI invocations — it is not executed as
# part of building this lab; validate it with `bash -n setup.sh` before your
# first real run in your own sandbox account.
#
# Cost: one t3.micro instance (free-tier eligible, first 12 months of a new
# account; standard on-demand rate otherwise — a few cents/hour) + two mostly-
# empty S3 buckets (negligible, well under a cent). Nothing here enables
# GuardDuty, NAT gateways, or any other line item with meaningful cost. Run
# `./teardown.sh` when you're done — see README.md's teardown reminder.

set -euo pipefail

# --- Required configuration --------------------------------------------------
: "${AWS_PROFILE:?Set AWS_PROFILE to a pre-configured named AWS CLI profile (never hardcode credentials). Example: export AWS_PROFILE=cyberlab-sandbox}"
: "${ALLOWED_CIDR:?Set ALLOWED_CIDR to YOUR IP in CIDR form, e.g.: export ALLOWED_CIDR=\"\$(curl -s https://checkip.amazonaws.com)/32\" -- refuses to default to 0.0.0.0/0}"

AWS_REGION="${AWS_REGION:-us-east-1}"
PREFIX="${PREFIX:-cyberlab-day15}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.day15-state.env"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

AWS=(aws --profile "$AWS_PROFILE" --region "$AWS_REGION")

echo "== Day 15 setup: profile=$AWS_PROFILE region=$AWS_REGION prefix=$PREFIX =="

# --- Preflight ----------------------------------------------------------------
command -v aws >/dev/null || { echo "aws CLI not found on PATH" >&2; exit 1; }
"${AWS[@]}" sts get-caller-identity >/dev/null || {
  echo "Could not authenticate with profile '$AWS_PROFILE'. Configure it first: aws configure --profile $AWS_PROFILE" >&2
  exit 1
}

ACCOUNT_ID="$("${AWS[@]}" sts get-caller-identity --query Account --output text)"
ROLE_NAME="${PREFIX}-instance-role"
PROFILE_NAME="${PREFIX}-instance-profile"
SG_NAME="${PREFIX}-sg"
PRIVATE_BUCKET="${PREFIX}-private-${ACCOUNT_ID}"
PUBLIC_BUCKET="${PREFIX}-public-${ACCOUNT_ID}"
KEY_TAG="Key=purpose,Value=${PREFIX}"

# --- 1. IAM instance role (deliberately over-permissive baseline) -----------
echo "-- Creating IAM role: $ROLE_NAME (attack baseline: AmazonS3ReadOnlyAccess, broad on purpose)"

cat > "$WORKDIR/trust-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

"${AWS[@]}" iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "file://$WORKDIR/trust-policy.json" \
  --tags Key=purpose,Value="$PREFIX" \
  --description "Day 15 lab instance role -- ATTACK baseline, deliberately broad. Tighten in Defense 3."

"${AWS[@]}" iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

"${AWS[@]}" iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
"${AWS[@]}" iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"

echo "-- Waiting for IAM instance profile propagation (~10s)"
sleep 10

# --- 2. Private bucket (Block Public Access ON) ------------------------------
echo "-- Creating private bucket: $PRIVATE_BUCKET"
"${AWS[@]}" s3api create-bucket --bucket "$PRIVATE_BUCKET" \
  $( [ "$AWS_REGION" != "us-east-1" ] && echo --create-bucket-configuration LocationConstraint="$AWS_REGION" )
"${AWS[@]}" s3api put-public-access-block --bucket "$PRIVATE_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
"${AWS[@]}" s3api put-bucket-tagging --bucket "$PRIVATE_BUCKET" \
  --tagging "TagSet=[{Key=purpose,Value=$PREFIX}]"

echo "This object is only reachable with a valid AWS credential (Section 2, Step 4)." \
  > "$WORKDIR/internal-secret.txt"
"${AWS[@]}" s3 cp "$WORKDIR/internal-secret.txt" "s3://$PRIVATE_BUCKET/internal-secret.txt"

# --- 3. Public bucket (Block Public Access OFF, public-read policy) ---------
echo "-- Creating misconfigured PUBLIC bucket: $PUBLIC_BUCKET"
"${AWS[@]}" s3api create-bucket --bucket "$PUBLIC_BUCKET" \
  $( [ "$AWS_REGION" != "us-east-1" ] && echo --create-bucket-configuration LocationConstraint="$AWS_REGION" )
"${AWS[@]}" s3api put-public-access-block --bucket "$PUBLIC_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
"${AWS[@]}" s3api put-bucket-tagging --bucket "$PUBLIC_BUCKET" \
  --tagging "TagSet=[{Key=purpose,Value=$PREFIX}]"

cat > "$WORKDIR/public-bucket-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${PUBLIC_BUCKET}/*"
  }]
}
EOF
"${AWS[@]}" s3api put-bucket-policy --bucket "$PUBLIC_BUCKET" \
  --policy "file://$WORKDIR/public-bucket-policy.json"

echo "This object needs zero credentials to read -- see content/day15-metadata-s3.md, Step 5." \
  > "$WORKDIR/exposed-notes.txt"
"${AWS[@]}" s3 cp "$WORKDIR/exposed-notes.txt" "s3://$PUBLIC_BUCKET/exposed-notes.txt"

# --- 4. Security group, locked to $ALLOWED_CIDR only -------------------------
echo "-- Creating security group: $SG_NAME (ingress restricted to $ALLOWED_CIDR)"
VPC_ID="$("${AWS[@]}" ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
SG_ID="$("${AWS[@]}" ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Day 15 lab -- app (8080) and ssh (22), restricted to \$ALLOWED_CIDR" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{$KEY_TAG}]" \
  --query 'GroupId' --output text)"

"${AWS[@]}" ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --cidr "$ALLOWED_CIDR"
"${AWS[@]}" ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr "$ALLOWED_CIDR"

# --- 5. Launch EC2 instance with the vulnerable app via user-data -----------
echo "-- Resolving latest Amazon Linux 2023 AMI"
AMI_ID="$("${AWS[@]}" ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)"

cat > "$WORKDIR/url_preview.py" <<'PYEOF'
#!/usr/bin/env python3
"""Day 15 target: a deliberately vulnerable "URL preview" service.

GET /fetch?url=<url> makes a server-side GET request to whatever URL is
given and returns the body -- classic SSRF, architecturally identical to
Day 9's SSRF lab target. It forwards ONLY the URL: no custom headers, no
alternate HTTP methods, no allowlist, no block on link-local addresses.
That narrow shape is exactly why IMDSv2 (Defense 1, content/day15-metadata-
s3.md) stops it cold: IMDSv2 requires a PUT plus a header carrying a
session token, and this app's fetch code can do neither.

Authorized-sandbox-only: this app is meant to be attacked, on purpose, only
inside the AWS account and instance this lab's setup.sh created.
"""
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

BANNER = b"cyberlab-day15 URL Preview Service. Try: GET /fetch?url=<url>\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(BANNER)
            return
        if parsed.path == "/fetch":
            target = parse_qs(parsed.query).get("url", [None])[0]
            if not target:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"missing url param\n")
                return
            try:
                # VULNERABLE ON PURPOSE: no allowlist, no block on
                # link-local/metadata addresses -- fetches ANY
                # attacker-supplied URL, server-side. Only ever issues a
                # plain GET with no custom headers (see module docstring).
                req = urllib.request.Request(target, method="GET")
                with urllib.request.urlopen(req, timeout=3) as resp:
                    body = resp.read()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)
            except Exception as exc:
                self.send_response(502)
                self.end_headers()
                self.wfile.write(str(exc).encode())
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, fmt, *args):
        pass  # keep instance console output quiet


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PYEOF

# base64-embed the app source into user-data so no S3/SSM staging step is
# needed before the instance can start it.
APP_B64="$(base64 < "$WORKDIR/url_preview.py" | tr -d '\n')"

cat > "$WORKDIR/user-data.sh" <<USERDATA
#!/bin/bash
mkdir -p /opt/lab
echo "$APP_B64" | base64 -d > /opt/lab/url_preview.py
cat > /etc/systemd/system/day15-app.service <<'UNIT'
[Unit]
Description=Day 15 lab vulnerable URL preview app
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/lab/url_preview.py
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now day15-app.service
USERDATA

echo "-- Launching EC2 instance ($INSTANCE_TYPE, IMDSv1 allowed -- attack baseline)"
INSTANCE_ID="$("${AWS[@]}" ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --iam-instance-profile "Name=$PROFILE_NAME" \
  --security-group-ids "$SG_ID" \
  --metadata-options "HttpTokens=optional,HttpPutResponseHopLimit=1,HttpEndpoint=enabled" \
  --user-data "file://$WORKDIR/user-data.sh" \
  --tag-specifications "ResourceType=instance,Tags=[{$KEY_TAG},{Key=Name,Value=$PREFIX}]" \
  --query 'Instances[0].InstanceId' --output text)"

echo "-- Waiting for instance to reach running state"
"${AWS[@]}" ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP="$("${AWS[@]}" ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"

# --- Persist state for teardown.sh ------------------------------------------
cat > "$STATE_FILE" <<EOF
AWS_PROFILE=$AWS_PROFILE
AWS_REGION=$AWS_REGION
PREFIX=$PREFIX
ACCOUNT_ID=$ACCOUNT_ID
ROLE_NAME=$ROLE_NAME
PROFILE_NAME=$PROFILE_NAME
SG_ID=$SG_ID
PRIVATE_BUCKET=$PRIVATE_BUCKET
PUBLIC_BUCKET=$PUBLIC_BUCKET
INSTANCE_ID=$INSTANCE_ID
EOF

echo "== Day 15 setup complete =="
echo "Instance public IP : $PUBLIC_IP"
echo "App URL            : http://$PUBLIC_IP:8080/"
echo "Instance role       : $ROLE_NAME"
echo "Private bucket      : $PRIVATE_BUCKET"
echo "Public bucket        : $PUBLIC_BUCKET"
echo
echo "State saved to $STATE_FILE for teardown.sh."
echo "REMINDER: run ./teardown.sh when you're done with this lab -- see README.md."
