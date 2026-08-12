#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"

section identity
hostnamectl 2>&1 || true
uname -a
cat /etc/os-release

section network
ip -brief address
ip route show table main
ip -6 route show table main

section public-connectivity
run_if_present curl -4 --max-time 8 -fsS https://checkip.amazonaws.com
run_if_present tailscale netcheck

section tailscale-summary
if command -v tailscale >/dev/null && command -v jq >/dev/null; then
  tailscale status --json | jq '{Self:{HostName:.Self.HostName,TailscaleIPs:.Self.TailscaleIPs,Online:.Self.Online},PeerCount:([.Peer[]]|length)}'
else
  printf 'tailscale or jq unavailable\n'
fi

section listeners
ss -H -lntu

section wireguard-and-docker
run_if_present wg show
if command -v docker >/dev/null; then
  docker version --format '{{.Server.Version}}' 2>&1 || true
  docker compose version 2>&1 || true
  docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
  docker network ls
fi

section firewall-summary
if sudo -n true 2>/dev/null; then
  sudo nft list tables 2>&1 || true
  sudo iptables -S INPUT 2>&1 || true
  sudo iptables -S FORWARD 2>&1 || true
  sudo iptables -S DOCKER-USER 2>&1 || true
else
  printf 'passwordless sudo unavailable; rerun with sudo for firewall data\n'
fi

section virtualization
systemd-detect-virt 2>&1 || true
lscpu | sed -n '/Architecture/p;/Model name/p;/Virtualization/p'
ls -l /dev/kvm /dev/net/tun 2>&1 || true
