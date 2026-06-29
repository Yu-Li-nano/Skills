#!/usr/bin/env bash
set -euo pipefail

host="${1:-codex-${USER}}"

ssh "$host" 'bash -lc '"'"'
set -euo pipefail
if [ -f /etc/profile.d/modules.sh ]; then
  . /etc/profile.d/modules.sh
fi
if command -v module >/dev/null 2>&1; then
  module load codex
else
  echo "module command not found" >&2
  exit 1
fi
if [ -f ~/.codex/proxy.env ]; then
  . ~/.codex/proxy.env
else
  echo "~/.codex/proxy.env not found; skipping proxy env load" >&2
fi
printf "codex_version="
codex --version
curl -I --connect-timeout 10 https://api.openai.com | sed -n "1,5p"
'"'"''
