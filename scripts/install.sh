#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$REPO_DIR/home"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"

link_file() {
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

while IFS= read -r -d '' file; do
  rel="${file#$HOME_DIR/}"
  link_file "$file" "$HOME/$rel"
done < <(find "$HOME_DIR" -type f -print0)

echo "Done. Run: bash scripts/validate.sh"
