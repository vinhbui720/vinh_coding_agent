---
name: config-sync
description: Keep the shared WezTerm + Jcode config repo synchronized across machines using git. Auto-fetch, detect whether local is behind/ahead/diverged, safely pull or push when possible, and warn when changes are large or need review.
---

# config-sync

Use this skill whenever Vinh asks to sync config, update this machine from remote, publish local config changes, or keep all machines on the same setup.

## Purpose

This skill manages the shared config repo so every machine stays on the same WezTerm + Jcode configuration.

Preferred repo path:

```bash
~/wezterm-jcode-dotfiles
```

## Preferred command

Use the helper script:

```bash
bash home/.jcode/skills/config-sync/scripts/sync.sh
```

Or explicitly point to the repo:

```bash
bash home/.jcode/skills/config-sync/scripts/sync.sh ~/wezterm-jcode-dotfiles
```

## Behavior

The sync script will:

1. check that the repo exists and is a git repo
2. fetch `origin`
3. inspect local branch vs remote tracking branch
4. choose one safe action automatically:
   - **behind only** -> fast-forward pull
   - **ahead only** -> push local commits
   - **up to date** -> no-op
   - **diverged** -> stop and show guidance
5. detect uncommitted changes
   - if changes are small, it will summarize and tell the agent to review/commit first
   - if changes are large, it will warn more strongly and avoid auto-push
6. print next-step guidance when new tools/files should also be added to installer docs

## Important safety rules

- Never force-push automatically.
- Never auto-commit user changes silently.
- If the working tree is dirty, stop and explain what changed.
- If local and remote diverged, stop and show the exact git commands to inspect/rebase/merge.

## Large-change guidance

If many files changed, or new top-level config paths were added, the agent should check:

- `scripts/install.sh` -> update `MANAGED_PATHS`
- `README.md` -> update install/sync notes
- `scripts/validate.sh` -> validate the new tool/config
- `.gitignore` -> ensure secrets/caches are still excluded

## Recommended workflow

### Sync this machine from remote
```bash
bash home/.jcode/skills/config-sync/scripts/sync.sh ~/wezterm-jcode-dotfiles
```

### After editing config on this machine
1. validate config
2. review git diff
3. commit changes
4. run sync script again to push if local is ahead

Example:
```bash
cd ~/wezterm-jcode-dotfiles
bash scripts/validate.sh
git status --short
git add .
git commit -m "Describe config update"
bash home/.jcode/skills/config-sync/scripts/sync.sh .
```

## If diverged

Inspect first:

```bash
cd ~/wezterm-jcode-dotfiles
git log --oneline --graph --decorate --left-right HEAD...@{upstream}
git status
```

Then choose one:

```bash
git pull --rebase origin main
# or
git merge origin/main
```

Resolve conflicts, validate, then push.
