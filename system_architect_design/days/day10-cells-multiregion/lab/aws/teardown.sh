#!/usr/bin/env bash
# Day 10 AWS teardown — MANDATORY. Run this the moment you finish the experiment.
# Idempotent: safe to run twice. Verifies nothing of yours remains.
set -euo pipefail

: "${AWS_PROFILE:=sandbox}"
: "${AWS_REGION:=ap-southeast-1}"
export AWS_PROFILE AWS_REGION
PROJECT="day10-cells"

echo ">> If you used Terraform, prefer the clean path:"
echo "   terraform destroy -auto-approve"
echo

echo ">> Verifying no Day-10 resources remain (Project=$PROJECT)..."

echo "--- Load balancers ---"
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT')].LoadBalancerName" \
  --output text

echo "--- Target groups ---"
aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName, '$PROJECT')].TargetGroupName" \
  --output text

echo "--- EC2 instances (not terminated) ---"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].{id:InstanceId,state:State.Name}" --output text

echo
echo ">> Any names/ids printed above are STILL BILLING. Delete them (terraform"
echo "   destroy, or console) and re-run this script until all three are empty."
echo ">> Finally: check the AWS Billing console. Session cost target: \$1-3."
