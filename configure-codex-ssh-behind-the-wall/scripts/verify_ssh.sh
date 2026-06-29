#!/usr/bin/env bash
set -euo pipefail

host="${1:-codex-${USER}}"

ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" 'printf "host=%s\nuser=%s\npwd=%s\nhome=%s\n" "$(hostname)" "$(whoami)" "$PWD" "$HOME"'
