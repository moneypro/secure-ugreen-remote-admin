#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"

"$ROOT_DIR/tests/static.sh"

if [[ -f "$PRIVATE_DIR/site.env" ]]; then
  load_site_env
  for name in HOME_ENDPOINT HOME_WG_PORT HOME_WG_ADDRESS HOME_WG_IP HOME_ALLOWED_IP NAS_WG_ADDRESS NAS_WG_IP HOME_PROXY_PORT NAS_ADMIN_USER; do
    [[ -n "${!name:-}" ]] || die "missing $name in private/site.env"
  done
  [[ "$HOME_WG_IP" != "$NAS_WG_IP" ]] || die 'home and NAS WireGuard IPs collide'
  printf 'private configuration: ok\n'
fi
