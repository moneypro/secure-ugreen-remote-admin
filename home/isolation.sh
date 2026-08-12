#!/usr/bin/env bash
set -Eeuo pipefail

action=${1:-}
bridge=br-friendwg
state_dir=/var/lib/friend-nas-remote/backups
input_chain=FRIEND-WG-INPUT
forward_chain=FRIEND-WG-FORWARD

need_root() {
  [[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
}

delete_jump() {
  local base=$1 chain=$2
  while iptables -C "$base" -i "$bridge" -j "$chain" 2>/dev/null; do
    iptables -D "$base" -i "$bridge" -j "$chain"
  done
}

case "$action" in
  apply)
    need_root
    mkdir -p "$state_dir"
    chmod 700 "$state_dir"
    timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    iptables-save >"$state_dir/iptables.$timestamp.save"
    ip6tables-save >"$state_dir/ip6tables.$timestamp.save"

    iptables -N "$input_chain" 2>/dev/null || true
    iptables -F "$input_chain"
    iptables -A "$input_chain" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A "$input_chain" -j DROP
    delete_jump INPUT "$input_chain"
    iptables -I INPUT 1 -i "$bridge" -j "$input_chain"

    iptables -N "$forward_chain" 2>/dev/null || true
    iptables -F "$forward_chain"
    iptables -A "$forward_chain" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A "$forward_chain" -j DROP
    delete_jump DOCKER-USER "$forward_chain"
    iptables -I DOCKER-USER 1 -i "$bridge" -j "$forward_chain"

    printf 'isolation installed; persist it only after connectivity tests pass\n'
    ;;
  remove)
    need_root
    delete_jump INPUT "$input_chain"
    delete_jump DOCKER-USER "$forward_chain"
    iptables -F "$input_chain" 2>/dev/null || true
    iptables -X "$input_chain" 2>/dev/null || true
    iptables -F "$forward_chain" 2>/dev/null || true
    iptables -X "$forward_chain" 2>/dev/null || true
    printf 'isolation removed\n'
    ;;
  show)
    iptables -S "$input_chain" 2>&1 || true
    iptables -S "$forward_chain" 2>&1 || true
    ;;
  *)
    printf 'usage: %s apply|remove|show\n' "$0" >&2
    exit 2
    ;;
esac
