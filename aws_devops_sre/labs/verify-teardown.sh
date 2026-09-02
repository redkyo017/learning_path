#!/usr/bin/env bash
#
# verify-teardown.sh — read-only billable-resource audit for aws_devops_sre.
#
# This script makes ONLY read-only AWS API calls (describe-*, list-*). It
# never creates, changes, or removes anything. It is safe to run at any
# time, as often as you like, against a live AWS account. Run it after
# tearing a lab down with Terraform — a clean Terraform exit code only
# proves Terraform cleared what it knows about; it says nothing about
# resources CodeDeploy, ECS, or CloudWatch created outside Terraform's view.
#
# Usage:
#   ./verify-teardown.sh [--region us-east-1] [--prefix awsdevops]
#
set -uo pipefail

REGION="us-east-1"
PREFIX="awsdevops"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="$2"
      shift 2
      ;;
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

UNEXPECTED=0

banner() {
  echo ""
  echo "== $1 =="
}

echo "############################################################"
echo "# verify-teardown.sh — read-only audit"
echo "# region: ${REGION}   name prefix: ${PREFIX}"
echo "# This script only calls describe-*/list-* AWS APIs. It never"
echo "# removes, or changes anything."
echo "############################################################"

# ---------------------------------------------------------------------------
banner "NAT gateways (the loudest alarm — ~\$0.045/h each while still present)"
NAT_JSON=$(aws ec2 describe-nat-gateways \
  --region "${REGION}" \
  --filter "Name=state,Values=pending,available,deleting" \
  --output json 2>/dev/null)
if [[ -z "${NAT_JSON}" ]]; then
  echo "⚠️  Could not query NAT gateways (check AWS credentials/permissions)."
else
  NAT_COUNT=$(echo "${NAT_JSON}" | grep -c '"NatGatewayId"' || true)
  if [[ "${NAT_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${NAT_COUNT} NAT gateway(s) found still present."
    echo "    This path targets ZERO NAT gateways, path-wide. Each one burns"
    echo "    ~\$0.045/h (~\$32/month) plus per-GB processed while it stays up."
    UNEXPECTED=$((UNEXPECTED + NAT_COUNT))
  else
    echo "✅ No NAT gateways found."
  fi
fi

# ---------------------------------------------------------------------------
banner "Load balancers matching prefix '${PREFIX}'"
ALB_JSON=$(aws elbv2 describe-load-balancers --region "${REGION}" --output json 2>/dev/null)
if [[ -z "${ALB_JSON}" ]]; then
  echo "⚠️  Could not query load balancers (check AWS credentials/permissions)."
else
  ALB_COUNT=$(echo "${ALB_JSON}" | grep -o "\"LoadBalancerName\": *\"${PREFIX}[^\"]*\"" | wc -l | tr -d ' ')
  if [[ "${ALB_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${ALB_COUNT} load balancer(s) matching '${PREFIX}' found."
    echo "    The ALB only belongs to this path on Day 3 and Day 5, and only"
    echo "    for the duration of that session. ~\$0.0225/h + LCU while it exists."
    UNEXPECTED=$((UNEXPECTED + ALB_COUNT))
  else
    echo "✅ No load balancers matching '${PREFIX}' found."
  fi
fi

# ---------------------------------------------------------------------------
banner "ECS services with desiredCount > 0"
ECS_HITS=0
CLUSTERS=$(aws ecs list-clusters --region "${REGION}" --output text --query 'clusterArns[]' 2>/dev/null)
if [[ -z "${CLUSTERS}" ]]; then
  echo "✅ No ECS clusters found (or none matched)."
else
  for CLUSTER in ${CLUSTERS}; do
    if [[ "${CLUSTER}" != *"${PREFIX}"* ]]; then
      continue
    fi
    SERVICES=$(aws ecs list-services --region "${REGION}" --cluster "${CLUSTER}" --output text --query 'serviceArns[]' 2>/dev/null)
    for SVC in ${SERVICES}; do
      DESIRED=$(aws ecs describe-services --region "${REGION}" --cluster "${CLUSTER}" --services "${SVC}" \
        --output text --query 'services[0].desiredCount' 2>/dev/null)
      if [[ -n "${DESIRED}" && "${DESIRED}" != "0" && "${DESIRED}" != "None" ]]; then
        echo "⚠️  Service ${SVC} in cluster ${CLUSTER} has desiredCount=${DESIRED}."
        ECS_HITS=$((ECS_HITS + 1))
      fi
    done
  done
  if [[ "${ECS_HITS}" -eq 0 ]]; then
    echo "✅ No ECS services with desiredCount > 0 found under prefix '${PREFIX}'."
  else
    UNEXPECTED=$((UNEXPECTED + ECS_HITS))
  fi
fi

# ---------------------------------------------------------------------------
banner "Running Fargate tasks"
TASK_HITS=0
if [[ -n "${CLUSTERS:-}" ]]; then
  for CLUSTER in ${CLUSTERS}; do
    if [[ "${CLUSTER}" != *"${PREFIX}"* ]]; then
      continue
    fi
    TASKS=$(aws ecs list-tasks --region "${REGION}" --cluster "${CLUSTER}" --desired-status RUNNING \
      --output text --query 'taskArns[]' 2>/dev/null)
    for T in ${TASKS}; do
      echo "⚠️  Running task: ${T} (cluster ${CLUSTER})"
      TASK_HITS=$((TASK_HITS + 1))
    done
  done
fi
if [[ "${TASK_HITS}" -eq 0 ]]; then
  echo "✅ No running Fargate tasks found under prefix '${PREFIX}'."
else
  UNEXPECTED=$((UNEXPECTED + TASK_HITS))
fi

# ---------------------------------------------------------------------------
banner "EKS clusters (should always be empty in this path)"
EKS_JSON=$(aws eks list-clusters --region "${REGION}" --output json 2>/dev/null)
if [[ -z "${EKS_JSON}" ]]; then
  echo "⚠️  Could not query EKS clusters (check AWS credentials/permissions)."
else
  RAW_LIST=$(echo "${EKS_JSON}" | tr -d '[:space:]')
  if [[ "${RAW_LIST}" == '{"clusters":[]}' ]]; then
    echo "✅ No EKS clusters found. This path never applies EKS Terraform — good."
  else
    echo "⚠️  EKS cluster(s) found: ${EKS_JSON}"
    echo "    This path's Day 4 EKS Terraform is meant to be authored, never applied."
    UNEXPECTED=$((UNEXPECTED + 1))
  fi
fi

# ---------------------------------------------------------------------------
banner "CloudWatch alarms matching prefix '${PREFIX}'"
ALARM_JSON=$(aws cloudwatch describe-alarms --region "${REGION}" --alarm-name-prefix "${PREFIX}" --output json 2>/dev/null)
if [[ -z "${ALARM_JSON}" ]]; then
  echo "⚠️  Could not query CloudWatch alarms (check AWS credentials/permissions)."
else
  ALARM_COUNT=$(echo "${ALARM_JSON}" | grep -c '"AlarmName"' || true)
  if [[ "${ALARM_COUNT}" -gt 0 ]]; then
    echo "ℹ️  ${ALARM_COUNT} CloudWatch alarm(s) matching '${PREFIX}' found."
    echo "    First 10 free, then ~\$0.10/alarm-month — not usually the cause of a"
    echo "    surprise bill on its own, but double check these are the ones you expect."
  else
    echo "✅ No CloudWatch alarms matching '${PREFIX}' found."
  fi
fi

# ---------------------------------------------------------------------------
banner "Target groups matching prefix '${PREFIX}'"
TG_JSON=$(aws elbv2 describe-target-groups --region "${REGION}" --output json 2>/dev/null)
if [[ -z "${TG_JSON}" ]]; then
  echo "⚠️  Could not query target groups (check AWS credentials/permissions)."
else
  TG_COUNT=$(echo "${TG_JSON}" | grep -o "\"TargetGroupName\": *\"${PREFIX}[^\"]*\"" | wc -l | tr -d ' ')
  if [[ "${TG_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${TG_COUNT} target group(s) matching '${PREFIX}' found."
    echo "    A blue/green CodeDeploy deployment creates a replacement target group on every"
    echo "    run — an orphaned one (no ALB left pointing at it) is easy to miss by hand."
    UNEXPECTED=$((UNEXPECTED + TG_COUNT))
  else
    echo "✅ No target groups matching '${PREFIX}' found."
  fi
fi

# ---------------------------------------------------------------------------
banner "S3 buckets matching prefix '${PREFIX}'"
S3_JSON=$(aws s3api list-buckets --output json 2>/dev/null)
if [[ -z "${S3_JSON}" ]]; then
  echo "⚠️  Could not query S3 buckets (check AWS credentials/permissions)."
else
  S3_COUNT=$(echo "${S3_JSON}" | grep -o "\"Name\": *\"${PREFIX}[^\"]*\"" | wc -l | tr -d ' ')
  if [[ "${S3_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${S3_COUNT} S3 bucket(s) matching '${PREFIX}' found:"
    echo "${S3_JSON}" | grep -o "\"Name\": *\"${PREFIX}[^\"]*\"" | sed 's/^/      /'
    echo "    Day 2's pipeline-artifacts bucket and Day 5's capstone-artifacts and"
    echo "    canary-artifacts buckets are all created WITHOUT (pipeline/capstone) or"
    echo "    with (canary) force_destroy — a non-empty one blocks 'terraform destroy'"
    echo "    until emptied by hand. Storage itself is cheap, but a bucket surviving"
    echo "    here means its Terraform destroy did not actually finish."
    UNEXPECTED=$((UNEXPECTED + S3_COUNT))
  else
    echo "✅ No S3 buckets matching '${PREFIX}' found."
  fi
fi

# ---------------------------------------------------------------------------
banner "Synthetics canaries in RUNNING state"
CANARY_JSON=$(aws synthetics describe-canaries --region "${REGION}" --output json 2>/dev/null)
if [[ -z "${CANARY_JSON}" ]]; then
  echo "⚠️  Could not query Synthetics canaries (check AWS credentials/permissions)."
else
  RUNNING_COUNT=$(echo "${CANARY_JSON}" | grep -o '"State": *"RUNNING"' | wc -l | tr -d ' ')
  if [[ "${RUNNING_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${RUNNING_COUNT} canary(ies) in RUNNING state."
    echo "    Day 5's canary should be stopped and removed during teardown — a forgotten"
    echo "    canary keeps running on its schedule at ~\$0.0012/run."
    UNEXPECTED=$((UNEXPECTED + RUNNING_COUNT))
  else
    echo "✅ No Synthetics canaries in RUNNING state."
  fi
fi

# ---------------------------------------------------------------------------
banner "Orphaned Synthetics 'cwsyn-*' Lambda functions"
LAMBDA_JSON=$(aws lambda list-functions --region "${REGION}" --output json 2>/dev/null)
if [[ -z "${LAMBDA_JSON}" ]]; then
  echo "⚠️  Could not query Lambda functions (check AWS credentials/permissions)."
else
  CWSYN_COUNT=$(echo "${LAMBDA_JSON}" | grep -o "\"FunctionName\": *\"cwsyn-${PREFIX}[^\"]*\"" | wc -l | tr -d ' ')
  if [[ "${CWSYN_COUNT}" -gt 0 ]]; then
    echo "⚠️  ${CWSYN_COUNT} 'cwsyn-${PREFIX}-*' Lambda function(s) found."
    echo "    aws_synthetics_canary creates this Lambda function behind the scenes — it is"
    echo "    NOT its own Terraform resource. 'terraform destroy' on the canary resource"
    echo "    removes it too, but a canary ever deleted by hand in the console can leave"
    echo "    this (and its own never-expire log group, checked below) behind."
    UNEXPECTED=$((UNEXPECTED + CWSYN_COUNT))
  else
    echo "✅ No 'cwsyn-${PREFIX}-*' Lambda functions found."
  fi
fi

# ---------------------------------------------------------------------------
banner "CloudWatch log groups matching '${PREFIX}' with no retention limit"
LOG_JSON=$(aws logs describe-log-groups --region "${REGION}" --log-group-name-prefix "/aws" --output json 2>/dev/null)
if [[ -z "${LOG_JSON}" ]]; then
  echo "⚠️  Could not query CloudWatch log groups (check AWS credentials/permissions)."
else
  # Fall back to a broader, unfiltered scan too, since our log groups may not live under /aws.
  LOG_JSON_ALL=$(aws logs describe-log-groups --region "${REGION}" --output json 2>/dev/null)
  LEAK_COUNT=0
  # Extracting logGroupName/retentionInDays pairs is fiddly in pure bash/grep; use a python-free
  # heuristic: any logGroupName containing the prefix that has no "retentionInDays" key set.
  while read -r LG; do
    [[ -z "${LG}" ]] && continue
    RETENTION=$(aws logs describe-log-groups --region "${REGION}" --log-group-name-prefix "${LG}" \
      --output text --query 'logGroups[0].retentionInDays' 2>/dev/null)
    if [[ -z "${RETENTION}" || "${RETENTION}" == "None" ]]; then
      echo "⚠️  Log group ${LG} has no retention limit set (never-expire = slow leak)."
      LEAK_COUNT=$((LEAK_COUNT + 1))
    fi
  done < <(echo "${LOG_JSON_ALL}" | grep -o "\"logGroupName\": *\"[^\"]*${PREFIX}[^\"]*\"" | sed 's/.*: *"//;s/"$//')
  if [[ "${LEAK_COUNT}" -eq 0 ]]; then
    echo "✅ No log groups matching '${PREFIX}' with an unset retention limit found."
  else
    UNEXPECTED=$((UNEXPECTED + LEAK_COUNT))
  fi
  echo "    Every log group this path creates should be set to retention_in_days = 1."
fi

# ---------------------------------------------------------------------------
banner "Expected to still exist (foundation stack — do NOT tear these down mid-week)"
echo "ℹ️  labs/foundation/ VPC (CIDR 10.42.0.0/16) — free (VPC, IGW, public subnets, route tables)."
echo "ℹ️  labs/foundation/ ECR repository '${PREFIX}-sample' — ~\$0.002/month for a ~15 MB image."
echo "    Both are created once on Day 1 and kept only until the end of Day 5. This script does not"
echo "    warn about either — their presence here is correct at every point in the path."

# ---------------------------------------------------------------------------
echo ""
echo "############################################################"
echo "${UNEXPECTED} unexpected billable resource(s) found"
echo "This script only reads AWS state — it never removes anything."
echo "If it found something, go tear it down via Terraform (or the console)"
echo "and re-run this script to confirm."
echo "############################################################"

exit 0
