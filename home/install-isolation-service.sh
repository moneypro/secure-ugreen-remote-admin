#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
install -m 0755 "$root/home/isolation.sh" /usr/local/sbin/friend-nas-isolation
install -m 0644 "$root/home/friend-nas-isolation.service" /etc/systemd/system/friend-nas-isolation.service
systemctl daemon-reload
systemctl enable --now friend-nas-isolation.service

