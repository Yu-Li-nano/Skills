#!/usr/bin/env bash
set -euo pipefail

host="${1:-codex-${USER}}"
port="${2:-7897}"
local_host="${3:-127.0.0.1}"

printf 'Open your local proxy/VPN client first. Checking proxy at %s:%s...\n' "$local_host" "$port"
if command -v lsof >/dev/null 2>&1; then
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1 || true
fi
if ! curl -I --connect-timeout 8 -x "http://${local_host}:${port}" https://api.openai.com >/dev/null; then
  printf 'Could not confirm a working local proxy at %s:%s. Ask the user to confirm the proxy address and port.\n' "$local_host" "$port" >&2
  exit 1
fi
ssh -fN -o ExitOnForwardFailure=yes -R "${port}:${local_host}:${port}" "$host"
ssh "$host" "curl -I --connect-timeout 10 -x http://127.0.0.1:${port} https://api.openai.com >/dev/null"
printf 'Remote proxy forwarding is active: %s:127.0.0.1:%s -> %s:%s\n' "$host" "$port" "$local_host" "$port"
