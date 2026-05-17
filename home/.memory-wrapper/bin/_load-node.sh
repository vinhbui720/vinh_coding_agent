#!/usr/bin/env bash
set -euo pipefail

if [ -n "${NVM_DIR:-}" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
  . "$HOME/.nvm/nvm.sh"
fi

command -v node >/dev/null 2>&1 || { echo "node not found" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "npm not found" >&2; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "npx not found" >&2; exit 1; }
