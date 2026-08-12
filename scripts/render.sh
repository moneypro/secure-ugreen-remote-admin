#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"
load_site_env "${1:-$PRIVATE_DIR/site.env}"

rendered="$PRIVATE_DIR/rendered"
received="$PRIVATE_DIR/received"
keys="$PRIVATE_DIR/keys"
mkdir -p "$rendered" "$received"
chmod 700 "$PRIVATE_DIR" "$rendered" "$received"
umask 077

render_template() {
  local source_file=$1 destination=$2 content
  content=$(<"$source_file")
  content=${content//\{\{HOME_WG_PORT\}\}/$HOME_WG_PORT}
  content=${content//\{\{HOME_WG_ADDRESS\}\}/$HOME_WG_ADDRESS}
  content=${content//\{\{HOME_ALLOWED_IP\}\}/$HOME_ALLOWED_IP}
  content=${content//\{\{NAS_WG_ADDRESS\}\}/$NAS_WG_ADDRESS}
  content=${content//\{\{HOME_ENDPOINT\}\}/$HOME_ENDPOINT}
  content=${content//\{\{PRIMARY_KEEPALIVE\}\}/$PRIMARY_KEEPALIVE}
  content=${content//\{\{HOME_PRIVATE_KEY\}\}/${HOME_PRIVATE_KEY:-}}
  content=${content//\{\{HOME_PUBLIC_KEY\}\}/${HOME_PUBLIC_KEY:-}}
  content=${content//\{\{NAS_PRIVATE_KEY\}\}/${NAS_PRIVATE_KEY:-}}
  content=${content//\{\{NAS_PUBLIC_KEY\}\}/${NAS_PUBLIC_KEY:-}}
  printf '%s\n' "$content" >"$destination.tmp"
  chmod 600 "$destination.tmp"
  mv "$destination.tmp" "$destination"
}

if [[ -f "$keys/home.wg.key" && -f "$received/nas.wg.pub" ]]; then
  HOME_PRIVATE_KEY=$(<"$keys/home.wg.key")
  NAS_PUBLIC_KEY=$(<"$received/nas.wg.pub")
  render_template "$ROOT_DIR/templates/wireguard/home-wg0.conf.tmpl" "$rendered/home-wg0.conf"
  printf 'rendered %s\n' "$rendered/home-wg0.conf"
fi

if [[ -f "$keys/nas.wg.key" && -f "$received/home.wg.pub" ]]; then
  NAS_PRIVATE_KEY=$(<"$keys/nas.wg.key")
  HOME_PUBLIC_KEY=$(<"$received/home.wg.pub")
  render_template "$ROOT_DIR/templates/wireguard/nas-wg0.conf.tmpl" "$rendered/nas-wg0.conf"
  printf 'rendered %s\n' "$rendered/nas-wg0.conf"
fi

if [[ -f "$keys/primary-admin" ]]; then
  known_hosts="$PRIVATE_DIR/known_hosts.ugos"
  cat >"$PRIVATE_DIR/ssh-config.tmp" <<EOF
Host friend-nas
    HostName 127.0.0.1
    Port $HOME_PROXY_PORT
    User $NAS_ADMIN_USER
    IdentityFile $keys/primary-admin
    IdentitiesOnly yes
    HostKeyAlias friend-nas-ugos
    UserKnownHostsFile $known_hosts
    ForwardAgent no
EOF
  chmod 600 "$PRIVATE_DIR/ssh-config.tmp"
  mv "$PRIVATE_DIR/ssh-config.tmp" "$PRIVATE_DIR/ssh-config"
  printf 'rendered %s\n' "$PRIVATE_DIR/ssh-config"
fi

if [[ ! -f "$rendered/home-wg0.conf" && ! -f "$rendered/nas-wg0.conf" ]]; then
  printf 'no WireGuard config rendered; place the peer public key in %s\n' "$received" >&2
fi
