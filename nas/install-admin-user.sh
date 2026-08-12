#!/usr/bin/env bash
set -Eeuo pipefail

user_name=friend-admin
public_key_file=
sudo_mode=password
source_address=10.250.78.2

while (($#)); do
  case "$1" in
    --user) user_name=$2; shift 2 ;;
    --public-key) public_key_file=$2; shift 2 ;;
    --sudo-mode) sudo_mode=$2; shift 2 ;;
    --source) source_address=$2; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { printf 'run with sudo\n' >&2; exit 1; }
[[ -r "$public_key_file" ]] || { printf 'cannot read public key\n' >&2; exit 1; }
[[ "$sudo_mode" == password || "$sudo_mode" == nopasswd ]] || { printf 'sudo mode must be password or nopasswd\n' >&2; exit 2; }

key=$(<"$public_key_file")
[[ "$key" == ssh-ed25519\ * ]] || { printf 'expected an Ed25519 public key\n' >&2; exit 1; }

backup_dir=/var/backups/friend-nas-remote/$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup_dir"
cp -a /etc/passwd /etc/group /etc/shadow /etc/sudoers "$backup_dir/"
[[ ! -d /etc/sudoers.d ]] || cp -a /etc/sudoers.d "$backup_dir/"

if ! id "$user_name" >/dev/null 2>&1; then
  useradd --create-home --user-group --shell /bin/bash "$user_name"
fi

home_dir=$(getent passwd "$user_name" | cut -d: -f6)
install -d -m 0700 -o "$user_name" -g "$user_name" "$home_dir/.ssh"
auth_file="$home_dir/.ssh/authorized_keys"
touch "$auth_file"
chown "$user_name:$user_name" "$auth_file"
chmod 0600 "$auth_file"

entry="from=\"$source_address\",no-agent-forwarding,no-X11-forwarding,no-user-rc $key"
grep -Fqx "$entry" "$auth_file" || printf '%s\n' "$entry" >>"$auth_file"

sudoers_file="/etc/sudoers.d/90-$user_name"
if [[ "$sudo_mode" == password ]]; then
  printf '%s ALL=(ALL:ALL) ALL\n' "$user_name" >"$sudoers_file"
else
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user_name" >"$sudoers_file"
fi
chmod 0440 "$sudoers_file"
visudo -cf "$sudoers_file"
printf 'installed user=%s source=%s sudo_mode=%s backup=%s\n' "$user_name" "$source_address" "$sudo_mode" "$backup_dir"
