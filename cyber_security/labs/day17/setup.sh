#!/usr/bin/env bash
#
# labs/day17/setup.sh
#
# Day 17 — Cloud network security. Provisions a VPC + public subnet + an
# EC2 instance behind a DELIBERATELY OVER-PERMISSIVE security group, so the
# Attack/Assess lab (content/day17-cloud-network.md, Section 2) has a real,
# internet-reachable target to find and scan.
#
# AUTHORIZED SANDBOX ONLY. Run this only in an AWS account you own or are
# explicitly authorized to test in — never a shared or production account.
# This script genuinely opens SSH (22/tcp) and a full TCP port range
# (0-65535/tcp) to 0.0.0.0/0 on purpose, as the lab's planted misconfig.
#
# Credentials: NEVER hardcoded. Set AWS_PROFILE to a named AWS CLI profile
# you've already configured (`aws configure --profile <name>`) before
# running this script:
#     export AWS_PROFILE=<your-sandbox-profile>
#     ./setup.sh
#
# Cost: one t3.micro EC2 instance (typically free-tier eligible — check
# your own account's free-tier status, it is not guaranteed) plus a VPC,
# subnet, Internet Gateway, route table, and security group (all free of
# charge on their own). Nothing here enables GuardDuty, CloudTrail, or any
# other billed detective control. Run ./teardown.sh as soon as you're done
# — see README.md for the full cost note and teardown reminder.

set -euo pipefail

: "${AWS_PROFILE:?Set AWS_PROFILE to a named AWS CLI profile before running this script (never hardcode credentials). See README.md.}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="cyberlab-day17"
CIDR_VPC="10.60.0.0/16"
CIDR_SUBNET="10.60.1.0/24"

export AWS_PROFILE AWS_REGION

echo "== Day 17 setup: region=${AWS_REGION} profile=${AWS_PROFILE} project-tag=${PROJECT_TAG} =="

tag_spec() {
  # $1 = resource type, $2 = Name tag value
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=Project,Value=%s}]' \
    "$1" "$2" "$PROJECT_TAG"
}

echo "[1/8] Creating VPC (${CIDR_VPC})"
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$CIDR_VPC" \
  --tag-specifications "$(tag_spec vpc day17-vpc)" \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
echo "    VPC_ID=$VPC_ID"

echo "[2/8] Creating public subnet (${CIDR_SUBNET})"
AZ=$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[0].ZoneName' --output text)
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$CIDR_SUBNET" \
  --availability-zone "$AZ" \
  --tag-specifications "$(tag_spec subnet day17-public-subnet)" \
  --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch
echo "    SUBNET_ID=$SUBNET_ID"

echo "[3/8] Creating + attaching an Internet Gateway"
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "$(tag_spec internet-gateway day17-igw)" \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "    IGW_ID=$IGW_ID"

echo "[4/8] Creating a route table (0.0.0.0/0 -> IGW) and associating it with the subnet"
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table day17-public-rtb)" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table \
  --route-table-id "$RTB_ID" \
  --subnet-id "$SUBNET_ID" >/dev/null
echo "    RTB_ID=$RTB_ID"

echo "[5/8] Creating the OVER-PERMISSIVE security group (this IS the lab's planted misconfig)"
SG_ID=$(aws ec2 create-security-group \
  --group-name "day17-exposed-sg" \
  --description "Day 17 lab target SG - deliberately over-permissive, do not reuse outside this lab" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec security-group day17-exposed-sg)" \
  --query 'GroupId' --output text)
# Rule A (intended): the instance's real, deliberately public service.
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description="intended public web service"}]' >/dev/null
# Rule B (planted, risky): a management port open to the entire internet.
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description="RISKY: SSH open world-wide, planted for the assess lab"}]' >/dev/null
# Rule C (planted, risky): every TCP port open to the entire internet.
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions 'IpProtocol=tcp,FromPort=0,ToPort=65535,IpRanges=[{CidrIp=0.0.0.0/0,Description="RISKY: all TCP ports open world-wide, planted for the assess lab"}]' >/dev/null
echo "    SG_ID=$SG_ID"

echo "[6/8] Looking up the latest Amazon Linux 2023 AMI via the public SSM parameter"
AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)
echo "    AMI_ID=$AMI_ID"

echo "[7/8] Launching the exposed EC2 instance (t3.micro, no key pair - this lab never needs an interactive SSH session)"
USER_DATA=$(cat <<'EOF'
#!/bin/bash
yum install -y httpd
systemctl enable httpd
systemctl start httpd
echo "<html><body><h1>Day17 exposed target</h1><p>cyberlab-day17</p></body></html>" > /var/www/html/index.html
EOF
)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --user-data "$USER_DATA" \
  --tag-specifications "$(tag_spec instance day17-exposed-instance)" \
  --query 'Instances[0].InstanceId' --output text)
echo "    INSTANCE_ID=$INSTANCE_ID"

echo "[8/8] Waiting for the instance to reach 'running' and fetching its public IP"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

cat <<SUMMARY

== Day 17 setup complete ==
VPC:        $VPC_ID
Subnet:     $SUBNET_ID
IGW:        $IGW_ID
Route tbl:  $RTB_ID
SG:         $SG_ID
  - 80/tcp   from 0.0.0.0/0  (intended public web service)
  - 22/tcp   from 0.0.0.0/0  (PLANTED RISKY RULE)
  - 0-65535/tcp from 0.0.0.0/0  (PLANTED RISKY RULE)
Instance:   $INSTANCE_ID
Public IP:  $PUBLIC_IP

Next steps: see content/day17-cloud-network.md (Section 2, Attack/Assess Lab)
and labs/day17/README.md for the full walkthrough, e.g.:
    nmap -Pn -p 22,80,443,3306,3389,8080 $PUBLIC_IP

Remember to run ./teardown.sh when you're done - see README.md for the
cost note and teardown reminder.
SUMMARY
