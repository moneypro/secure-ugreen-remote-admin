#!/usr/bin/env bash
set -Eeuo pipefail

action=${1:-}
[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
destination=/etc/ssh/sshd_config.d/90-friend-nas-remote.conf

case "$action" in
  apply)
    backup=/var/backups/friend-nas-remote/$(date -u +%Y%m%dT%H%M%SZ)
    install -d -m 0700 "$backup"
    cp -a /etc/ssh/sshd_config "$backup/"
    [[ ! -e "$destination" ]] || cp -a "$destination" "$backup/"
    install -m 0644 "$root/nas/sshd-hardening.conf" "$destination"
    sshd -t
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    printf 'sshd hardened; keep the current session open and test a second key-only session; backup=%s\n' "$backup"
    ;;
  remove)
    rm -f "$destination"
    sshd -t
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    ;;
  check)
    sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|permitrootlogin|pubkeyauthentication) '
    ;;
  *)
    printf 'usage: %s apply|remove|check\n' "$0" >&2
    exit 2
    ;;
esac

