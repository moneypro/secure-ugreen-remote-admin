#!/usr/bin/env bash
set -Eeuo pipefail

: "${HOME_ENDPOINT:?}"
: "${HOME_WG_PORT:?}"
: "${RERESOLVE_SECONDS:=60}"

while true; do
  sleep "$RERESOLVE_SECONDS"
  peer=$(wg show wg0 peers | head -n 1)
  [[ -n "$peer" ]] || continue
  resolved=$(dig +short A "$HOME_ENDPOINT" | awk '/^[0-9]+(\.[0-9]+){3}$/ {print; exit}')
  [[ -n "$resolved" ]] || { printf 'endpoint-resolution-failed host=%s\n' "$HOME_ENDPOINT"; continue; }
  current=$(wg show wg0 endpoints | awk 'NR == 1 {print $2}')
  desired="${resolved}:${HOME_WG_PORT}"
  if [[ "$current" != "$desired" ]]; then
    wg set wg0 peer "$peer" endpoint "$desired"
    printf 'endpoint-updated host=%s endpoint=%s\n' "$HOME_ENDPOINT" "$desired"
  fi
done

