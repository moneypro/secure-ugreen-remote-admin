#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
env_file=${1:?usage: install-ddns.sh private/site.env}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)

install -d -m 0700 /etc/friend-nas-remote
install -m 0600 "$env_file" /etc/friend-nas-remote/site.env
install -m 0755 "$root/home/route53-ddns.sh" /usr/local/sbin/friend-nas-route53-ddns
install -m 0644 "$root/home/friend-nas-ddns.service" /etc/systemd/system/
install -m 0644 "$root/home/friend-nas-ddns.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now friend-nas-ddns.timer

