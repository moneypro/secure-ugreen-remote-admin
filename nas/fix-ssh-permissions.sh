#!/usr/bin/env bash
set -Eeuo pipefail

config=/etc/friend-nas-remote/admin-user
[[ -r "$config" ]] || { printf 'missing %s\n' "$config" >&2; exit 1; }
user_name=$(<"$config")
id "$user_name" >/dev/null 2>&1 || { printf 'unknown configured user\n' >&2; exit 1; }
home_dir=$(getent passwd "$user_name" | cut -d: -f6)
group_name=$(id -gn "$user_name")
[[ -d "$home_dir/.ssh" ]] || { printf 'missing SSH directory\n' >&2; exit 1; }

chmod go-w "$home_dir"
chmod 0700 "$home_dir/.ssh"
chmod 0600 "$home_dir/.ssh/authorized_keys"
chown -R "$user_name:$group_name" "$home_dir/.ssh"

