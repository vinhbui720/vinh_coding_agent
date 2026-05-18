#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_link() {
  local live="$1"
  local expected="$2"
  local actual expected_resolved
  actual=$(readlink -f "$live" 2>/dev/null || true)
  expected_resolved=$(readlink -f "$expected" 2>/dev/null || true)
  if [ "$actual" = "$expected_resolved" ]; then
    echo "OK symlink: $live"
  else
    echo "FAIL symlink: $live -> $actual expected $expected_resolved" >&2
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
check_link "$HOME/.jcode/mcp.json" "$REPO_DIR/home/.jcode/mcp.json"
check_link "$HOME/.jcode/skills/gog-vinh" "$REPO_DIR/home/.jcode/skills/gog-vinh"
check_link "$HOME/.jcode/skills/config-sync" "$REPO_DIR/home/.jcode/skills/config-sync"
check_link "$HOME/.memory-wrapper" "$REPO_DIR/home/.memory-wrapper"
check_link "$HOME/.jcode/skills/sync-memory" "$HOME/.memory-wrapper/skills/sync-memory"
check_link "$HOME/.jcode/skills/load-context" "$HOME/.memory-wrapper/skills/load-context"
check_link "$HOME/.jcode/skills/save-decision" "$HOME/.memory-wrapper/skills/save-decision"
check_link "$HOME/.jcode/skills/bm25-search" "$HOME/.memory-wrapper/skills/bm25-search"
check_link "$HOME/.jcode/skills/graph-query" "$HOME/.memory-wrapper/skills/graph-query"
check_link "$HOME/.jcode/skills/crystallize" "$HOME/.memory-wrapper/skills/crystallize"

for skill in gog-vinh config-sync sync-memory load-context save-decision bm25-search notebooklm graph-query crystallize; do
  check_link "$HOME/.claude/skills/$skill" "$HOME/.jcode/skills/$skill"
done

chmod +x "$REPO_DIR/home/.local/bin/jcode-wrappers/wezterm"
find "$REPO_DIR/home/.jcode/skills/gog-vinh/scripts" -type f -name '*.sh' -exec chmod +x {} +
find "$REPO_DIR/home/.jcode/skills/config-sync/scripts" -type f -name '*.sh' -exec chmod +x {} +
find "$REPO_DIR/home/.memory-wrapper/bin" -type f -exec chmod +x {} +

require_cmd bash
require_cmd git
require_cmd wezterm
require_cmd jcode
require_cmd python3
require_cmd curl

[ -f "$HOME/.memory-wrapper/.env" ] || { echo "FAIL missing env: $HOME/.memory-wrapper/.env" >&2; exit 1; }
grep -Fq 'AGENTMEMORY_SECRET=' "$HOME/.memory-wrapper/.env"
grep -Fq '# >>> MEMORY WRAPPER >>>' "$HOME/.bashrc"

wezterm --config-file "$HOME/.wezterm.lua" show-keys >/dev/null
jcode --version >/dev/null
python3 -m json.tool "$HOME/.jcode/mcp.json" >/dev/null
"$HOME/.memory-wrapper/bin/agentmemory-status" >/dev/null
"$HOME/.memory-wrapper/bin/graph-stats" >/dev/null

echo "Validation passed"
