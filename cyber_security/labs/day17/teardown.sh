#!/usr/bin/env bash
#
# labs/day17/teardown.sh
#
# Removes every resource setup.sh (and the Defense Lab's optional Flow Logs
# steps, if you ran them) created for Day 17, discovered by the
# Project=cyberlab-day17 tag rather than by hardcoded IDs, then verifies
# the account is clean.
#
# Credentials: NEVER hardcoded. Use the same named AWS CLI profile as
# setup.sh:
#     export AWS_PROFILE=<your-sandbox-profile>
#     ./teardown.sh

set -euo pipefail

: "${AWS_PROFILE:?Set AWS_PROFILE to the same named AWS CLI profile used in setup.sh.}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="cyberlab-day17"
export AWS_PROFILE AWS_REGION

echo "== Day 17 teardown: region=${AWS_REGION} profile=${AWS_PROFILE} project-tag=${PROJECT_TAG} =="

filter_tag=(--filters "Name=tag:Project,Values=${PROJECT_TAG}")

echo "[1/8] Terminating tagged EC2 instance(s)"
INSTANCE_IDS=$(aws ec2 describe-instances "${filter_tag[@]}" \
  --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' \
  --output text)
if [ -n "$INSTANCE_IDS" ]; then
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS >/dev/null
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
  echo "    terminated: $INSTANCE_IDS"
else
  echo "    none found"
fi

echo "[2/8] Deleting tagged security group(s)"
SG_IDS=$(aws ec2 describe-security-groups "${filter_tag[@]}" \
  --query 'SecurityGroups[].GroupId' --output text)
for sg in $SG_IDS; do
  aws ec2 delete-security-group --group-id "$sg"
  echo "    deleted SG $sg"
done

echo "[3/8] Disassociating + deleting tagged route table(s)"
RTB_IDS=$(aws ec2 describe-route-tables "${filter_tag[@]}" \
  --query 'RouteTables[].RouteTableId' --output text)
for rtb in $RTB_IDS; do
  ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids "$rtb" \
    --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
    --output text)
  for assoc in $ASSOC_IDS; do
    aws ec2 disassociate-route-table --association-id "$assoc"
  done
  aws ec2 delete-route-table --route-table-id "$rtb"
  echo "    deleted route table $rtb"
done

echo "[4/8] Detaching + deleting tagged Internet Gateway(s)"
IGW_IDS=$(aws ec2 describe-internet-gateways "${filter_tag[@]}" \
  --query 'InternetGateways[].InternetGatewayId' --output text)
for igw in $IGW_IDS; do
  VPC_ATTACHED=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$igw" \
    --query 'InternetGateways[0].Attachments[0].VpcId' --output text)
  if [ -n "$VPC_ATTACHED" ] && [ "$VPC_ATTACHED" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ATTACHED"
  fi
  aws ec2 delete-internet-gateway --internet-gateway-id "$igw"
  echo "    deleted IGW $igw"
done

echo "[5/8] Deleting tagged subnet(s)"
SUBNET_IDS=$(aws ec2 describe-subnets "${filter_tag[@]}" \
  --query 'Subnets[].SubnetId' --output text)
for subnet in $SUBNET_IDS; do
  aws ec2 delete-subnet --subnet-id "$subnet"
  echo "    deleted subnet $subnet"
done

echo "[6/8] Deleting tagged VPC(s)"
VPC_IDS=$(aws ec2 describe-vpcs "${filter_tag[@]}" \
  --query 'Vpcs[].VpcId' --output text)
for vpc in $VPC_IDS; do
  aws ec2 delete-vpc --vpc-id "$vpc"
  echo "    deleted VPC $vpc"
done

echo "[7/8] Best-effort cleanup of Defense Lab extras (Flow Logs, log group, IAM role) - only if you ran Defense 3"
FLOW_LOG_IDS=$(aws ec2 describe-flow-logs "${filter_tag[@]}" \
  --query 'FlowLogs[].FlowLogId' --output text 2>/dev/null || true)
if [ -n "${FLOW_LOG_IDS:-}" ] && [ "$FLOW_LOG_IDS" != "None" ]; then
  aws ec2 delete-flow-logs --flow-log-ids $FLOW_LOG_IDS >/dev/null || true
  echo "    deleted flow log(s) $FLOW_LOG_IDS"
else
  echo "    no tagged flow logs found"
fi
if aws logs describe-log-groups --log-group-name-prefix /cyberlab/day17/vpc-flow-logs \
    --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q '/cyberlab/day17/vpc-flow-logs'; then
  aws logs delete-log-group --log-group-name /cyberlab/day17/vpc-flow-logs || true
  echo "    deleted log group /cyberlab/day17/vpc-flow-logs"
else
  echo "    no /cyberlab/day17/vpc-flow-logs log group found"
fi
if aws iam get-role --role-name day17-flow-logs-role >/dev/null 2>&1; then
  aws iam delete-role-policy --role-name day17-flow-logs-role \
    --policy-name day17-flow-logs-write >/dev/null 2>&1 || true
  aws iam delete-role --role-name day17-flow-logs-role || true
  echo "    deleted IAM role day17-flow-logs-role"
else
  echo "    no day17-flow-logs-role IAM role found"
fi

echo "[8/8] Verifying the account is clean"
REMAINING=$(aws ec2 describe-vpcs "${filter_tag[@]}" \
  --query 'Vpcs[].VpcId' --output text)
if [ -z "$REMAINING" ]; then
  echo "TEARDOWN_OK - no cyberlab-day17-tagged VPC remains."
else
  echo "WARNING: tagged VPC(s) still present: $REMAINING - investigate manually."
  exit 1
fi
