#!/bin/sh
set -eu

: "${RECOVERY_EIP:?}"
: "${AWS_RECOVERY_PORT:=22}"
: "${AWS_REVERSE_PORT:=22010}"
: "${UGOS_SSH_TARGET:=ugos-host}"
: "${UGOS_SSH_PORT:=22}"

exec autossh -M 0 -NT \
  -i /run/secrets/recovery-tunnel \
  -o BatchMode=yes \
  -o ExitOnForwardFailure=yes \
  -o IdentitiesOnly=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=/run/secrets/recovery-known-hosts \
  -p "$AWS_RECOVERY_PORT" \
  -R "127.0.0.1:${AWS_REVERSE_PORT}:${UGOS_SSH_TARGET}:${UGOS_SSH_PORT}" \
  "nas-tunnel@${RECOVERY_EIP}"

