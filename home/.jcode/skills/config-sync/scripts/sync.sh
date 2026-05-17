#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$HOME/wezterm-jcode-dotfiles}"
LARGE_CHANGE_THRESHOLD="${LARGE_CHANGE_THRESHOLD:-12}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

need_cmd git

[ -d "$REPO_DIR" ] || fail "repo directory not found: $REPO_DIR"
cd "$REPO_DIR"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repo: $REPO_DIR"

branch=$(git branch --show-current)
[ -n "$branch" ] || fail "detached HEAD is not supported for auto-sync"

upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
if [ -z "$upstream" ]; then
  fail "no upstream configured for branch '$branch'. Example: git push -u origin $branch"
fi

remote_name=${upstream%%/*}
remote_branch=${upstream#*/}

echo "==> Repo: $REPO_DIR"
echo "==> Branch: $branch"
echo "==> Upstream: $upstream"

echo "==> Fetching remote updates"
git fetch "$remote_name" --prune

status_lines=$(git status --porcelain)
if [ -n "$status_lines" ]; then
  changed_count=$(printf '%s\n' "$status_lines" | sed '/^$/d' | wc -l)
  echo "==> Working tree is dirty: $changed_count changed path(s)"
  git status --short
  echo
  if [ "$changed_count" -ge "$LARGE_CHANGE_THRESHOLD" ]; then
    echo "WARN: large local change set detected. Review carefully before syncing."
  fi
  echo "Next steps:"
  echo "  1. Review: git diff --stat && git diff"
  echo "  2. Validate: bash scripts/validate.sh"
  echo "  3. Commit if desired: git add . && git commit -m \"...\""
  echo "  4. Re-run this sync script"
  exit 2
fi

counts=$(git rev-list --left-right --count HEAD..."$upstream")
behind=$(awk '{print $1}' <<<"$counts")
ahead=$(awk '{print $2}' <<<"$counts")

echo "==> Remote comparison: behind=$behind ahead=$ahead"

if [ "$behind" -eq 0 ] && [ "$ahead" -eq 0 ]; then
  echo "Already up to date."
  exit 0
fi

if [ "$behind" -gt 0 ] && [ "$ahead" -eq 0 ]; then
  echo "==> Local is behind remote. Performing fast-forward pull."
  git pull --ff-only "$remote_name" "$remote_branch"
  echo "Sync complete: pulled latest changes."
  exit 0
fi

if [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ]; then
  commit_count=$(git rev-list --count "$upstream"..HEAD)
  file_count=$(git diff --name-only "$upstream"..HEAD | sed '/^$/d' | wc -l)
  echo "==> Local is ahead of remote by $commit_count commit(s), touching $file_count file(s)."
  if [ "$file_count" -ge "$LARGE_CHANGE_THRESHOLD" ]; then
    echo "WARN: large committed change set. Ensure README/install/validate are updated if new tools or paths were added."
    echo "Recommended review: git diff --stat $upstream..HEAD"
  fi
  echo "==> Pushing local commits"
  git push "$remote_name" "$branch"
  echo "Sync complete: pushed local changes."
  exit 0
fi

echo "DIVERGED: local and remote both have unique commits."
echo "Review with:"
echo "  git log --oneline --graph --decorate --left-right HEAD...$upstream"
echo "Then resolve with one of:"
echo "  git pull --rebase $remote_name $remote_branch"
echo "  git merge $upstream"
echo "After resolving conflicts: bash scripts/validate.sh && git push"
exit 3
