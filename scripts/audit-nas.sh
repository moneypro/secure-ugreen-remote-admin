#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "$0")/lib.sh"

section identity
hostnamectl 2>&1 || true
uname -a
cat /etc/os-release 2>&1 || true
uname -m

section ugos-version-and-persistence
for candidate in /etc/ugreen-release /etc/ugos-release /etc/version /etc.defaults/VERSION; do
  if [[ -f "$candidate" ]]; then
    printf -- '--- %s\n' "$candidate"
    sed -n '1,120p' "$candidate"
  fi
done
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS / /etc /var 2>&1 || true
systemctl is-enabled docker ssh sshd 2>&1 || true

section network
ip -brief address
ip route show table main
ip rule show
ip -6 route show table main

section listeners
ss -H -lntup

section firewall
nft list tables 2>&1 || true
iptables-save 2>&1 || true
ip6tables-save 2>&1 || true

section docker
if command -v docker >/dev/null; then
  docker version
  docker info --format '{{json .SecurityOptions}}'
  docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
  docker network ls
  docker info --format 'DockerRootDir={{.DockerRootDir}} LiveRestore={{.LiveRestoreEnabled}}'
else
  printf 'docker not installed\n'
fi

section wireguard
lsmod | awk '$1 == "wireguard" {print}' || true
modinfo wireguard 2>&1 | sed -n '1,40p' || true
command -v wg || true
ls -l /dev/net/tun 2>&1 || true

section virtualization
systemd-detect-virt 2>&1 || true
lscpu | sed -n '/Architecture/p;/Model name/p;/Virtualization/p'
ls -l /dev/kvm 2>&1 || true

section startup-and-upgrade-clues
systemctl list-unit-files --state=enabled --no-legend 2>&1 || true
find /etc/systemd/system /usr/local /opt -maxdepth 2 -type f -printf '%m %u:%g %p\n' 2>/dev/null | sort
