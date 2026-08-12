#!/usr/bin/env bash
set -Eeuo pipefail

: "${ROLE:?ROLE must be home or nas}"
: "${HOME_WG_PORT:=51830}"
: "${HOME_WG_IP:=10.77.0.1}"
: "${NAS_WG_IP:=10.77.0.10}"
: "${HOME_PROXY_PORT:=22010}"
: "${UGOS_SSH_TARGET:=ugos-host}"
: "${UGOS_SSH_PORT:=22}"
: "${RERESOLVE_SECONDS:=60}"

[[ -r /etc/wireguard/wg0.conf ]] || { printf 'missing /etc/wireguard/wg0.conf\n' >&2; exit 1; }

cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
  wg-quick down wg0 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wg-quick up wg0

iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

case "$ROLE" in
  home)
    : "${HOME_BRIDGE_GATEWAY:=10.250.77.1}"
    iptables -A INPUT -i eth0 -p udp --dport "$HOME_WG_PORT" -j ACCEPT
    iptables -A INPUT -i eth0 -s "$HOME_BRIDGE_GATEWAY/32" -p tcp --dport "$HOME_PROXY_PORT" -j ACCEPT
    iptables -A OUTPUT -o eth0 -p udp --sport "$HOME_WG_PORT" -j ACCEPT
    iptables -A OUTPUT -o wg0 -d "$NAS_WG_IP/32" -p tcp --dport 22 -j ACCEPT
    iptables -A OUTPUT -o wg0 -d "$NAS_WG_IP/32" -p icmp -j ACCEPT
    exec socat "TCP-LISTEN:${HOME_PROXY_PORT},bind=0.0.0.0,reuseaddr,fork" "TCP:${NAS_WG_IP}:22"
    ;;
  nas)
    target_ip=$(getent ahostsv4 "$UGOS_SSH_TARGET" | awk 'NR == 1 {print $1}')
    [[ -n "$target_ip" ]] || { printf 'cannot resolve UGOS SSH target\n' >&2; exit 1; }
    iptables -A INPUT -i wg0 -s "$HOME_WG_IP/32" -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -i wg0 -s "$HOME_WG_IP/32" -p icmp -j ACCEPT
    iptables -A OUTPUT -o wg0 -d "$HOME_WG_IP/32" -p tcp --sport 22 -j ACCEPT
    iptables -A OUTPUT -o wg0 -d "$HOME_WG_IP/32" -p icmp -j ACCEPT
    iptables -A OUTPUT -o eth0 -d "$target_ip/32" -p tcp --dport "$UGOS_SSH_PORT" -j ACCEPT
    iptables -A OUTPUT -o eth0 -p udp --dport "$HOME_WG_PORT" -j ACCEPT
    /usr/local/sbin/reresolve-endpoint.sh &
    exec socat "TCP-LISTEN:22,bind=${NAS_WG_IP},reuseaddr,fork" "TCP:${target_ip}:${UGOS_SSH_PORT}"
    ;;
  *)
    printf 'unsupported ROLE=%s\n' "$ROLE" >&2
    exit 2
    ;;
esac

