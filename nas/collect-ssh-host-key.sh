#!/usr/bin/env bash
set -Eeuo pipefail

host=${1:?usage: collect-ssh-host-key.sh HOST OUTPUT}
output=${2:?usage: collect-ssh-host-key.sh HOST OUTPUT}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
ssh-keyscan -T 5 -t ed25519 "$host" 2>/dev/null >"$tmp"
[[ -s "$tmp" ]] || { printf 'no Ed25519 host key received\n' >&2; exit 1; }
awk '{$1="friend-nas-ugos"; print}' "$tmp" >"$output"
chmod 0600 "$output"
ssh-keygen -lf "$output"

