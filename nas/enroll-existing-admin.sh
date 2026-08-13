#!/usr/bin/env bash
set -Eeuo pipefail

user_name=
primary_key=
recovery_key=
primary_source=10.250.78.2
recovery_source=10.250.79.2

while (($#)); do
  case "$1" in
    --user) user_name=$2; shift 2 ;;
    --primary-key) primary_key=$2; shift 2 ;;
    --recovery-key) recovery_key=$2; shift 2 ;;
    --primary-source) primary_source=$2; shift 2 ;;
    --recovery-source) recovery_source=$2; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
[[ -n "$user_name" ]] || { printf 'missing --user\n' >&2; exit 2; }
id "$user_name" >/dev/null 2>&1 || { printf 'user does not exist; create it as an administrator in UGOS first\n' >&2; exit 1; }
[[ -r "$primary_key" && -r "$recovery_key" ]] || { printf 'cannot read both public keys\n' >&2; exit 1; }

for key_file in "$primary_key" "$recovery_key"; do
  grep -Eq '^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( |$)' "$key_file" || {
    printf 'expected a one-line Ed25519 public key: %s\n' "$key_file" >&2
    exit 1
  }
done

if ! sudo -l -U "$user_name" >/dev/null 2>&1; then
  printf '%s is not authorized by the current sudo policy; assign administrator role in UGOS\n' "$user_name" >&2
  exit 1
fi

home_dir=$(getent passwd "$user_name" | cut -d: -f6)
group_name=$(id -gn "$user_name")
[[ -n "$home_dir" && -d "$home_dir" ]] || {
  printf 'home directory missing; enable the personal folder in UGOS first\n' >&2
  exit 1
}

backup_dir=/var/backups/friend-nas-remote/$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup_dir"
[[ ! -e "$home_dir/.ssh/authorized_keys" ]] || cp -a "$home_dir/.ssh/authorized_keys" "$backup_dir/authorized_keys"

install -d -m 0700 -o "$user_name" -g "$group_name" "$home_dir/.ssh"
auth_file="$home_dir/.ssh/authorized_keys"
touch "$auth_file"
chown "$user_name:$group_name" "$auth_file"
chmod 0600 "$auth_file"
chmod go-w "$home_dir"

append_key() {
  local source_address=$1 key_file=$2 key entry
  key=$(<"$key_file")
  entry="from=\"$source_address\",no-agent-forwarding,no-X11-forwarding,no-user-rc $key"
  grep -Fqx "$entry" "$auth_file" || printf '%s\n' "$entry" >>"$auth_file"
}

append_key "$primary_source" "$primary_key"
append_key "$recovery_source" "$recovery_key"

install -d -m 0700 /etc/friend-nas-remote
printf '%s\n' "$user_name" >/etc/friend-nas-remote/admin-user
chmod 0600 /etc/friend-nas-remote/admin-user

printf 'enrolled existing UGOS admin=%s home=%s backup=%s\n' "$user_name" "$home_dir" "$backup_dir"
printf 'sudo policy (verify it includes full commands):\n'
sudo -l -U "$user_name"

