#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

while IFS= read -r file; do
  bash -n "$file"
done < <(find bin scripts gateway home nas aws tests -type f -name '*.sh' -o -path 'bin/ugreen-remote' | sort)

while IFS= read -r file; do
  sh -n "$file"
done < <(find recovery -type f -name '*.sh' | sort)

if rg -n --hidden --glob '!tests/static.sh' \
  --glob '!README.md' \
  --glob '!SECURITY.md' \
  --glob '!.git/**' \
  '(-----BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY-----|AKIA[0-9A-Z]{16})' .; then
  printf 'possible committed secret detected\n' >&2
  exit 1
fi

if find . \( -path './.git' -o -path './private' \) -prune -o -type f \( -name '*.key' -o -name '*.pem' -o -name 'wg0.conf' \) -print | grep -q .; then
  printf 'secret-like generated file present\n' >&2
  exit 1
fi

printf 'static checks: ok\n'
