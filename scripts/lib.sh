#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PRIVATE_DIR=${PRIVATE_DIR:-"$ROOT_DIR/private"}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

section() {
  printf '\n## %s\n' "$1"
}

run_if_present() {
  local command_name=$1
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    printf 'not installed: %s\n' "$command_name"
  fi
}

load_site_env() {
  local env_file=${1:-"$PRIVATE_DIR/site.env"}
  [[ -f "$env_file" ]] || die "missing $env_file; copy config/site.env.example first"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

