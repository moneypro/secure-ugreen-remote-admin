#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"

role=${1:-}
keys_dir="$PRIVATE_DIR/keys"
mkdir -p "$keys_dir"
chmod 700 "$PRIVATE_DIR" "$keys_dir"
umask 077

wg_run() {
  if command -v wg >/dev/null 2>&1; then
    wg "$@"
  elif command -v docker >/dev/null 2>&1; then
    docker run --rm --network none --entrypoint wg lscr.io/linuxserver/wireguard:latest "$@"
  else
    die 'WireGuard tools unavailable; install wireguard-tools or Docker'
  fi
}

generate_wg() {
  local name=$1 private_key="$keys_dir/$1.wg.key" public_key="$keys_dir/$1.wg.pub"
  [[ ! -e "$private_key" && ! -e "$public_key" ]] || die "refusing to overwrite $name WireGuard keys"
  wg_run genkey >"$private_key"
  wg_run pubkey <"$private_key" >"$public_key"
  chmod 600 "$private_key"
  chmod 644 "$public_key"
  printf 'created %s and %s\n' "$private_key" "$public_key"
}

generate_ssh() {
  local name=$1 mode=$2 key="$keys_dir/$1"
  [[ ! -e "$key" && ! -e "$key.pub" ]] || die "refusing to overwrite $name SSH keys"
  if [[ "$mode" == interactive ]]; then
    ssh-keygen -t ed25519 -a 100 -C "$name" -f "$key"
  else
    ssh-keygen -q -t ed25519 -a 100 -N '' -C "$name" -f "$key"
  fi
  chmod 600 "$key"
  chmod 644 "$key.pub"
  printf 'created %s and %s\n' "$key" "$key.pub"
}

case "$role" in
  home|nas) generate_wg "$role" ;;
  primary-admin|recovery-admin) generate_ssh "$role" interactive ;;
  recovery-tunnel) generate_ssh "$role" service ;;
  *) die 'role must be home, nas, primary-admin, recovery-admin, or recovery-tunnel' ;;
esac
