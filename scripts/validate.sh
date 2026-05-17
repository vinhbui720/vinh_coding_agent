#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_link() {
  local live="$1"
  local expected="$2"
  local actual
  actual=$(readlink -f "$live" 2>/dev/null || true)
  if [ "$actual" = "$expected" ]; then
    echo "OK symlink: $live"
  else
    echo "FAIL symlink: $live -> $actual expected $expected" >&2
    return 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL missing command: $1" >&2
    return 1
  }
  echo "OK command: $1"
}

check_link "$HOME/.wezterm.lua" "$REPO_DIR/home/.wezterm.lua"
check_link "$HOME/.local/bin/jcode-wrappers/wezterm" "$REPO_DIR/home/.local/bin/jcode-wrappers/wezterm"
check_link "$HOME/.jcode/config.toml" "$REPO_DIR/home/.jcode/config.toml"
check_link "$HOME/.jcode/skills/gog-vinh" "$REPO_DIR/home/.jcode/skills/gog-vinh"
check_link "$HOME/.jcode/skills/config-sync" "$REPO_DIR/home/.jcode/skills/config-sync"

chmod +x "$REPO_DIR/home/.local/bin/jcode-wrappers/wezterm"
find "$REPO_DIR/home/.jcode/skills/gog-vinh/scripts" -type f -name '*.sh' -exec chmod +x {} +
find "$REPO_DIR/home/.jcode/skills/config-sync/scripts" -type f -name '*.sh' -exec chmod +x {} +

require_cmd bash
require_cmd git
require_cmd wezterm
require_cmd jcode

wezterm --config-file "$HOME/.wezterm.lua" show-keys >/dev/null
jcode --version >/dev/null

echo "Validation passed"
