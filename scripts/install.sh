#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$REPO_DIR/home"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"
MANAGED_PATHS=(
  ".wezterm.lua"
  ".local/bin/jcode-wrappers/wezterm"
  ".jcode/config.toml"
  ".jcode/skills/gog-vinh"
  ".jcode/skills/config-sync"
)

link_path() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
    echo "relinked $dst"
    return
  fi
  if [ -e "$dst" ]; then
    mv "$dst" "${dst}${BACKUP_SUFFIX}"
    echo "backed up $dst -> ${dst}${BACKUP_SUFFIX}"
  fi
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

for rel in "${MANAGED_PATHS[@]}"; do
  src="$HOME_DIR/$rel"
  dst="$HOME/$rel"
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "SKIP missing repo path: $src" >&2
    continue
  fi
  link_path "$src" "$dst"
done

echo "Done. Run: bash scripts/validate.sh"
