#!/usr/bin/env bash
set -Eeuo pipefail

instance_id=${1:?usage: get-recovery-host-key.sh INSTANCE_ID EIP [REGION]}
eip=${2:?usage: get-recovery-host-key.sh INSTANCE_ID EIP [REGION]}
region=${3:-ap-east-1}

command_id=$(aws ssm send-command \
  --region "$region" \
  --instance-ids "$instance_id" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["cat /etc/ssh/ssh_host_ed25519_key.pub"]' \
  --query 'Command.CommandId' --output text)
aws ssm wait command-executed --region "$region" --command-id "$command_id" --instance-id "$instance_id"
key=$(aws ssm get-command-invocation --region "$region" --command-id "$command_id" --instance-id "$instance_id" --query StandardOutputContent --output text | tr -d '\r\n')
[[ "$key" == ssh-ed25519\ * ]] || { printf 'unexpected host-key result\n' >&2; exit 1; }
printf '[%s]:22 %s\n' "$eip" "$key"
