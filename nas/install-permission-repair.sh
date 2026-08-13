#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
[[ -r /etc/friend-nas-remote/admin-user ]] || {
  printf 'run enroll-existing-admin.sh first\n' >&2
  exit 1
}

install -m 0755 "$root/nas/fix-ssh-permissions.sh" /usr/local/sbin/friend-nas-fix-ssh-permissions
install -m 0644 "$root/nas/friend-nas-fix-ssh-permissions.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now friend-nas-fix-ssh-permissions.service

