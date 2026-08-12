#!/usr/bin/env bash
set -Eeuo pipefail

env_file=${1:-/etc/friend-nas-remote/site.env}
[[ -r "$env_file" ]] || { printf 'cannot read %s\n' "$env_file" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

: "${ROUTE53_ZONE_ID:?}"
: "${ROUTE53_RECORD:?}"
: "${ROUTE53_TTL:=60}"
: "${ROUTE53_AWS_PROFILE:=friend-nas-ddns}"

public_ip=$(curl -4 --max-time 10 -fsS https://checkip.amazonaws.com | tr -d '[:space:]')
[[ "$public_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || { printf 'invalid public IPv4 result\n' >&2; exit 1; }

current=$(aws --profile "$ROUTE53_AWS_PROFILE" route53 list-resource-record-sets \
  --hosted-zone-id "$ROUTE53_ZONE_ID" \
  --query "ResourceRecordSets[?Name == '${ROUTE53_RECORD%.}.' && Type == 'A']|[0].ResourceRecords[0].Value" \
  --output text)

if [[ "$current" == "$public_ip" ]]; then
  printf 'route53-current record=%s address=%s\n' "$ROUTE53_RECORD" "$public_ip"
  exit 0
fi

change_file=$(mktemp)
trap 'rm -f "$change_file"' EXIT
printf '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s","Type":"A","TTL":%s,"ResourceRecords":[{"Value":"%s"}]}}]}\n' \
  "$ROUTE53_RECORD" "$ROUTE53_TTL" "$public_ip" >"$change_file"

aws --profile "$ROUTE53_AWS_PROFILE" route53 change-resource-record-sets \
  --hosted-zone-id "$ROUTE53_ZONE_ID" \
  --change-batch "file://$change_file" >/dev/null
printf 'route53-updated record=%s old=%s new=%s\n' "$ROUTE53_RECORD" "$current" "$public_ip"

