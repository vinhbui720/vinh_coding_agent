#!/usr/bin/env bash
set -euo pipefail

expand_path() {
  local p="$1"
  if [[ "$p" == ~/* ]]; then
    printf '%s/%s\n' "$HOME" "${p#~/}"
  else
    printf '%s\n' "$p"
  fi
}

install_git_skill() {
  local name="$1"
  local repo="$2"
  local target_raw="$3"
  local target
  target="$(expand_path "$target_raw")"

  mkdir -p "$(dirname "$target")"

  if [ -d "$target/.git" ]; then
    echo "SKIP $name: already cloned at $target"
    return 0
  fi

  if [ -e "$target" ] && [ ! -d "$target/.git" ]; then
    echo "SKIP $name: target exists and is not a git repo: $target"
    return 0
  fi

  echo "CLONE $name -> $target"
  git clone "$repo" "$target"
}

install_git_skill \
  notebooklm \
  https://github.com/PleasePrompto/notebooklm-skill \
  ~/.jcode/skills/notebooklm
