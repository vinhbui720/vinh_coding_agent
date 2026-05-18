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
  ".jcode/skills/graph-query"
  ".jcode/skills/crystallize"
  # Matt Pocock engineering skills
  ".jcode/skills/diagnose"
  ".jcode/skills/grill-with-docs"
  ".jcode/skills/improve-codebase-architecture"
  ".jcode/skills/prototype"
  ".jcode/skills/setup-matt-pocock-skills"
  ".jcode/skills/tdd"
  ".jcode/skills/to-issues"
  ".jcode/skills/to-prd"
  ".jcode/skills/triage"
  ".jcode/skills/zoom-out"
  # Matt Pocock productivity skills
  ".jcode/skills/caveman"
  ".jcode/skills/grill-me"
  ".jcode/skills/handoff"
  ".jcode/skills/write-a-skill"
  # Matt Pocock misc skills
  ".jcode/skills/git-guardrails-claude-code"
  ".jcode/skills/setup-pre-commit"
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

link_claude_skill_alias() {
  local name="$1"
  local src="$HOME/.jcode/skills/$name"
  local dst="$HOME/.claude/skills/$name"
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "SKIP missing skill for ~/.claude alias: $src" >&2
    return 0
  fi
  mkdir -p "$HOME/.claude/skills"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "${dst}${BACKUP_SUFFIX}"
    echo "backed up $dst -> ${dst}${BACKUP_SUFFIX}"
  fi
  ln -sfn "$src" "$dst"
  echo "linked skill alias ~/.claude/skills/$name -> ~/.jcode/skills/$name"
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

for skill in sync-memory load-context save-decision bm25-search graph-query crystallize; do
  link_skill_alias "$skill"
done

# Jcode currently discovers slash-command skills from ~/.claude/skills in
# addition to ~/.jcode/skills. Mirror the default profile skills there so new
# Jcode sessions always load the baseline skills on every machine.
for skill in agentmemory gog-vinh config-sync sync-memory load-context save-decision bm25-search notebooklm graph-query crystallize diagnose grill-with-docs improve-codebase-architecture prototype setup-matt-pocock-skills tdd to-issues to-prd triage zoom-out caveman grill-me handoff write-a-skill git-guardrails-claude-code setup-pre-commit; do
  link_claude_skill_alias "$skill"
done

echo "Done. Run: bash scripts/post-install.sh && bash scripts/validate.sh"
