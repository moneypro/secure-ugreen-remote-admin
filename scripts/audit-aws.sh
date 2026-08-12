#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"
need aws

region=${AWS_REGION:-ap-east-1}

section caller
aws sts get-caller-identity --output json

section instances
# The backticks are JMESPath literals, not shell substitutions.
# shellcheck disable=SC2016
aws ec2 describe-instances --region "$region" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,State:State.Name,Type:InstanceType,PublicIPv4:PublicIpAddress,PrivateIPv4:PrivateIpAddress,Vpc:VpcId,Subnet:SubnetId,SGs:SecurityGroups[].GroupId}' \
  --output table

section elastic-ips
aws ec2 describe-addresses --region "$region" \
  --query 'Addresses[].{PublicIPv4:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,InstanceId:InstanceId}' \
  --output table

section ssm
aws ssm describe-instance-information --region "$region" \
  --query 'InstanceInformationList[].{Id:InstanceId,Ping:PingStatus,Platform:PlatformName,Version:PlatformVersion,Agent:AgentVersion}' \
  --output table

section route53-zones
aws route53 list-hosted-zones \
  --query 'HostedZones[].{Name:Name,Private:Config.PrivateZone,Id:Id}' \
  --output table
