#!/usr/bin/env bash
# Post-teardown sweep — lists every lab resource that can still bill you.
# Usage: ./scripts/sweep.sh [profile] [region]
set -uo pipefail
PROFILE="${1:-${AWS_PROFILE:-sandbox}}"
REGION="${2:-${AWS_REGION:-ap-southeast-1}}"
Q=(--profile "$PROFILE" --region "$REGION" --output text)
dirty=0

check() { # check <label> <output>
  if [ -n "$2" ]; then
    printf '  DIRTY  %-22s %s\n' "$1" "$(echo "$2" | tr '\n' ' ')"
    dirty=1
  else
    printf '  clean  %s\n' "$1"
  fi
}

echo "Sweep: profile=$PROFILE region=$REGION"

check "non-default VPCs" "$(aws ec2 describe-vpcs "${Q[@]}" \
  --query 'Vpcs[?IsDefault==`false`].VpcId')"
check "NAT gateways" "$(aws ec2 describe-nat-gateways "${Q[@]}" \
  --query 'NatGateways[?State!=`deleted`].NatGatewayId')"
check "Elastic IPs" "$(aws ec2 describe-addresses "${Q[@]}" \
  --query 'Addresses[*].AllocationId')"
check "EC2 instances" "$(aws ec2 describe-instances "${Q[@]}" \
  --filters 'Name=instance-state-name,Values=pending,running,stopping,stopped' \
  --query 'Reservations[*].Instances[*].InstanceId')"
check "EBS volumes" "$(aws ec2 describe-volumes "${Q[@]}" --query 'Volumes[*].VolumeId')"
check "VPC endpoints" "$(aws ec2 describe-vpc-endpoints "${Q[@]}" \
  --query 'VpcEndpoints[*].VpcEndpointId')"
check "endpoint services" "$(aws ec2 describe-vpc-endpoint-services "${Q[@]}" \
  --filters 'Name=service-type,Values=Interface' \
  --query 'ServiceDetails[?Owner!=`amazon`].ServiceId')"
check "transit gateways" "$(aws ec2 describe-transit-gateways "${Q[@]}" \
  --query 'TransitGateways[?State!=`deleted`].TransitGatewayId')"
check "TGW attachments" "$(aws ec2 describe-transit-gateway-attachments "${Q[@]}" \
  --query 'TransitGatewayAttachments[?State!=`deleted`].TransitGatewayAttachmentId')"
check "VPN connections" "$(aws ec2 describe-vpn-connections "${Q[@]}" \
  --query 'VpnConnections[?State!=`deleted`].VpnConnectionId')"
check "peering connections" "$(aws ec2 describe-vpc-peering-connections "${Q[@]}" \
  --query 'VpcPeeringConnections[?Status.Code!=`deleted`].VpcPeeringConnectionId')"
check "resolver endpoints" "$(aws route53resolver list-resolver-endpoints "${Q[@]}" \
  --query 'ResolverEndpoints[*].Id')"
check "load balancers" "$(aws elbv2 describe-load-balancers "${Q[@]}" \
  --query 'LoadBalancers[*].LoadBalancerName')"
check "private hosted zones" "$(aws route53 list-hosted-zones \
  --profile "$PROFILE" --output text \
  --query 'HostedZones[?Config.PrivateZone==`true`].Name')"
check "lab log groups" "$(aws logs describe-log-groups "${Q[@]}" \
  --query 'logGroups[?starts_with(logGroupName,`/vpc/`)].logGroupName')"

echo
if [ "$dirty" -eq 0 ]; then
  echo "ALL CLEAR — nothing billable left in $REGION."
else
  echo "LEFTOVERS FOUND — delete the items marked DIRTY above."
  echo "Note: Elastic IPs bill ~\$0.005/hr each even when attached to nothing."
fi
exit "$dirty"
