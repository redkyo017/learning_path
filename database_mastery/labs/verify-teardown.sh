#!/usr/bin/env bash
set -euo pipefail

# labs/verify-teardown.sh
#
# Confirms Day 7's cloud lab left nothing billable behind. Every AWS
# resource created by labs/day07/terraform/ is named with the prefix
# "dbm-lab-" (the Atlas cluster is named "dbm-lab", no trailing dash).
# Each check below is independent and reports via pass/fail; each also
# prints the exact command you can run yourself to confirm it.
#
# A teardown verifier that reports success when it could not actually look
# is worse than having none -- if the AWS CLI is missing or not configured,
# this script says so and exits 2, never 0. The Atlas CLI is optional: if
# it is absent, that one check is skipped with a clear message instead of
# being silently counted as a pass.

LAB_PREFIX="dbm-lab"
FAILED=0

pass() { echo "ok: $*"; }
fail() { echo "FAIL: $*"; FAILED=1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFSTATE="${SCRIPT_DIR}/day07/terraform/terraform.tfstate"

# --- AWS CLI presence and configuration -----------------------------------
# Everything below depends on being able to actually query AWS. If we can't,
# we refuse to report a clean result we did not verify.
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not found on PATH -- cannot verify AWS teardown." >&2
  echo "Install it (https://aws.amazon.com/cli/), then re-run this script." >&2
  exit 2
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS CLI is installed but not configured (no valid credentials)." >&2
  echo "Configure it, then re-run: aws sts get-caller-identity" >&2
  exit 2
fi

# --- RDS instances ---------------------------------------------------------
echo "checking for leftover RDS instances -- confirm yourself with:"
echo "  aws rds describe-db-instances --query \"DBInstances[?starts_with(DBInstanceIdentifier, '${LAB_PREFIX}-')].DBInstanceIdentifier\" --output text"
if leftover="$(aws rds describe-db-instances \
    --query "DBInstances[?starts_with(DBInstanceIdentifier, '${LAB_PREFIX}-')].DBInstanceIdentifier" \
    --output text 2>&1)"; then
  if [[ -z "$leftover" || "$leftover" == "None" ]]; then
    pass "no RDS instance with prefix ${LAB_PREFIX}-"
  else
    fail "RDS instance(s) still exist: $leftover"
  fi
else
  fail "could not query RDS instances: $leftover"
fi

# --- RDS manual snapshots ---------------------------------------------------
echo "checking for leftover manual RDS snapshots -- confirm yourself with:"
echo "  aws rds describe-db-snapshots --snapshot-type manual --query \"DBSnapshots[?starts_with(DBSnapshotIdentifier, '${LAB_PREFIX}-')].DBSnapshotIdentifier\" --output text"
if leftover="$(aws rds describe-db-snapshots --snapshot-type manual \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, '${LAB_PREFIX}-')].DBSnapshotIdentifier" \
    --output text 2>&1)"; then
  if [[ -z "$leftover" || "$leftover" == "None" ]]; then
    pass "no manual RDS snapshot with prefix ${LAB_PREFIX}-"
  else
    fail "manual RDS snapshot(s) still exist: $leftover"
  fi
else
  fail "could not query RDS snapshots: $leftover"
fi

# --- RDS subnet groups -------------------------------------------------------
echo "checking for leftover RDS subnet groups -- confirm yourself with:"
echo "  aws rds describe-db-subnet-groups --query \"DBSubnetGroups[?starts_with(DBSubnetGroupName, '${LAB_PREFIX}-')].DBSubnetGroupName\" --output text"
if leftover="$(aws rds describe-db-subnet-groups \
    --query "DBSubnetGroups[?starts_with(DBSubnetGroupName, '${LAB_PREFIX}-')].DBSubnetGroupName" \
    --output text 2>&1)"; then
  if [[ -z "$leftover" || "$leftover" == "None" ]]; then
    pass "no RDS subnet group with prefix ${LAB_PREFIX}-"
  else
    fail "RDS subnet group(s) still exist: $leftover"
  fi
else
  fail "could not query RDS subnet groups: $leftover"
fi

# --- RDS parameter groups ----------------------------------------------------
echo "checking for leftover RDS parameter groups -- confirm yourself with:"
echo "  aws rds describe-db-parameter-groups --query \"DBParameterGroups[?starts_with(DBParameterGroupName, '${LAB_PREFIX}-')].DBParameterGroupName\" --output text"
if leftover="$(aws rds describe-db-parameter-groups \
    --query "DBParameterGroups[?starts_with(DBParameterGroupName, '${LAB_PREFIX}-')].DBParameterGroupName" \
    --output text 2>&1)"; then
  if [[ -z "$leftover" || "$leftover" == "None" ]]; then
    pass "no RDS parameter group with prefix ${LAB_PREFIX}-"
  else
    fail "RDS parameter group(s) still exist: $leftover"
  fi
else
  fail "could not query RDS parameter groups: $leftover"
fi

# --- Atlas cluster (Atlas CLI is optional) -----------------------------------
echo "checking for a leftover Atlas cluster named '${LAB_PREFIX}' -- confirm yourself with:"
echo "  atlas clusters list -o json"
if ! command -v atlas >/dev/null 2>&1; then
  echo "Atlas CLI not found -- it is optional, so this check is skipped." >&2
  echo "Confirm manually in the Atlas UI, or install the CLI and re-run this script." >&2
elif clusters_json="$(atlas clusters list -o json 2>&1)"; then
  if echo "$clusters_json" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${LAB_PREFIX}\""; then
    fail "Atlas cluster '${LAB_PREFIX}' still exists"
  else
    pass "no Atlas cluster named '${LAB_PREFIX}'"
  fi
else
  echo "Atlas CLI present but the call failed (not logged in / not configured)." >&2
  echo "Confirm manually: atlas clusters list" >&2
fi

# --- Local terraform state ---------------------------------------------------
echo "checking local terraform state -- confirm yourself with:"
echo "  terraform -chdir=labs/day07/terraform state list"
if [[ ! -f "$TFSTATE" ]]; then
  pass "no terraform.tfstate file in labs/day07/terraform/"
else
  resource_count=""
  if command -v jq >/dev/null 2>&1; then
    resource_count="$(jq '.resources | length' "$TFSTATE" 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    resource_count="$(python3 -c "import json; print(len(json.load(open('${TFSTATE}')).get('resources', [])))" 2>/dev/null || true)"
  fi

  if [[ "$resource_count" == "0" ]]; then
    pass "terraform.tfstate exists but lists zero resources"
  elif [[ -n "$resource_count" ]]; then
    fail "terraform.tfstate lists ${resource_count} resource(s) -- run: terraform -chdir=labs/day07/terraform destroy"
  else
    fail "terraform.tfstate exists but could not be parsed (no jq or python3 on PATH) -- inspect manually: cat ${TFSTATE}"
  fi
fi

exit "${FAILED:-0}"
