#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$REPO_DIR/home"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"
MANAGED_PATHS=(
  ".wezterm.lua"
  ".local/bin/jcode-wrappers/wezterm"
  ".jcode/config.toml"
  ".jcode/mcp.json"
  ".jcode/skills/gog-vinh"
  ".jcode/skills/config-sync"
  ".memory-wrapper"
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

link_skill_alias() {
  local name="$1"
  mkdir -p "$HOME/.jcode/skills"
  ln -sfn "$HOME/.memory-wrapper/skills/$name" "$HOME/.jcode/skills/$name"
  echo "linked skill alias ~/.jcode/skills/$name -> ~/.memory-wrapper/skills/$name"
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

for skill in sync-memory load-context save-decision bm25-search; do
  link_skill_alias "$skill"
done

echo "Done. Run: bash scripts/post-install.sh && bash scripts/validate.sh"
