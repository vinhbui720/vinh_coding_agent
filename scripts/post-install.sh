#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
ENV_FILE="$HOME/.memory-wrapper/.env"
ENV_EXAMPLE="$REPO_DIR/home/.memory-wrapper/.env.example"
SHELL_BLOCK_START="# >>> MEMORY WRAPPER >>>"
SHELL_BLOCK_END="# <<< MEMORY WRAPPER <<<"
WRAPPER_PATH_MARKER="jcode-wrappers"

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  python3 - <<'PY'
from pathlib import Path
import secrets
p = Path.home()/'.memory-wrapper'/'.env'
text = p.read_text()
text = text.replace('AGENTMEMORY_SECRET=change-me', f'AGENTMEMORY_SECRET={secrets.token_hex(24)}')
p.write_text(text)
PY
  chmod 600 "$ENV_FILE"
  echo "Created $ENV_FILE with generated secret"
fi

append_block() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -Fq "$SHELL_BLOCK_START" "$rc"; then
    echo "Shell block already present in $rc"
    return 0
  fi
  cat >> "$rc" <<'EOF'

# >>> MEMORY WRAPPER >>>
if [ -f "$HOME/.memory-wrapper/shell-init.sh" ]; then
  source "$HOME/.memory-wrapper/shell-init.sh"
fi
# <<< MEMORY WRAPPER <<<
EOF
  echo "Appended memory shell block to $rc"
}

append_block "$BASHRC"
append_block "$ZSHRC"

ensure_wrapper_path() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -Fq "$WRAPPER_PATH_MARKER" "$rc"; then
    echo "jcode-wrappers already in PATH in $rc"
    return 0
  fi
  cat >> "$rc" <<'EOF'

# jcode wezterm wrapper must shadow /usr/bin/wezterm
export PATH="$HOME/.local/bin/jcode-wrappers:$PATH"
EOF
  echo "Appended jcode-wrappers PATH entry to $rc"
}

ensure_wrapper_path "$BASHRC"
ensure_wrapper_path "$ZSHRC"

echo "Post-install shell setup done"
