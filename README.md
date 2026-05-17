# WezTerm + Jcode Dotfiles

Portable repo for my terminal and Jcode setup.

## Goal

Use this repo to recreate my environment on another machine with minimal manual work.
Live config is managed by symlink: the real files in `$HOME` should point to files inside this repo.

## Repo structure

```text
home/
  .wezterm.lua
  .local/bin/jcode-wrappers/wezterm
  .jcode/config.toml
  .jcode/skills/gog-vinh/
  .jcode/skills/config-sync/
scripts/
  bootstrap.sh
  install.sh
  install-external-skills.sh
  validate.sh
docs/
  external-skills.md
```

## What is included

- WezTerm main config
- Jcode wrapper for WezTerm
- Jcode config
- custom `gog-vinh` skill
- custom `config-sync` skill for git-based sync across machines

## What is NOT included

- auth, OAuth, tokens, sessions, logs, caches
- Jcode memory state
- upstream third-party skill source repos

## Fast setup on a new machine

```bash
git clone <repo-url> ~/wezterm-jcode-dotfiles
cd ~/wezterm-jcode-dotfiles
bash scripts/bootstrap.sh
```

What `bootstrap.sh` does:
- checks core dependencies
- installs top-level managed symlinks into `$HOME`
- clones external skills if missing
- runs validation

If you want the steps manually:

```bash
bash scripts/install.sh
bash scripts/install-external-skills.sh
bash scripts/validate.sh
```

`install.sh` backs up existing non-symlink files or directories before replacing them with symlinks.

## Managed live paths

These are the paths that should exist in `$HOME` after install:

- `~/.wezterm.lua`
- `~/.local/bin/jcode-wrappers/wezterm`
- `~/.jcode/config.toml`
- `~/.jcode/skills/gog-vinh`
- `~/.jcode/skills/config-sync`

## Keeping all machines in sync

Use the sync skill after cloning or after changing config:

```bash
bash ~/.jcode/skills/config-sync/scripts/sync.sh ~/wezterm-jcode-dotfiles
```

Behavior:
- local behind remote -> fast-forward pull
- local ahead of remote -> push
- local dirty -> stop and ask for review/commit first
- local and remote diverged -> stop and print recovery guidance

This avoids silent force-push or silent auto-commit.

## External skills

Some skills are intentionally external. See:

- `docs/external-skills.md`

Example: NotebookLM should be installed separately at `~/.jcode/skills/notebooklm`, but `bootstrap.sh` will clone it automatically if missing.

## LLM adaptation checklist

If an LLM/agent is setting this up on a different machine, it should check these items and fix mismatches:

1. **Symlinks**
   - `~/.wezterm.lua` -> `~/wezterm-jcode-dotfiles/home/.wezterm.lua`
   - `~/.local/bin/jcode-wrappers/wezterm` -> `~/wezterm-jcode-dotfiles/home/.local/bin/jcode-wrappers/wezterm`
   - `~/.jcode/config.toml` -> `~/wezterm-jcode-dotfiles/home/.jcode/config.toml`
   - `~/.jcode/skills/gog-vinh` -> `~/wezterm-jcode-dotfiles/home/.jcode/skills/gog-vinh`
   - `~/.jcode/skills/config-sync` -> `~/wezterm-jcode-dotfiles/home/.jcode/skills/config-sync`

2. **Required binaries**
   - required: `bash`, `git`
   - expected for full setup: `wezterm`, `jcode`
   - optional for `gog-vinh`: `gog`

3. **Machine-specific paths**
   - Search for absolute paths like `/home/...`, `/tmp/...`, machine-specific repo paths, or old usernames
   - Replace them with relative paths derived from the current script location where possible
   - Keep configs portable: prefer `$(dirname "$0")`, `$HOME`, or repo-relative paths

4. **External repos**
   - Make sure external skills exist at the documented paths
   - Prefer cloning them separately instead of copying their source into this repo

5. **Secrets and local state**
   - Never commit auth files, browser state, sessions, or caches into this repo
   - Keep local secrets outside git

6. **Validation**
   - Run `bash scripts/validate.sh`
   - If validation fails, fix symlinks first, then missing binaries, then bad paths inside configs/scripts

7. **Sync policy**
   - Prefer `bash ~/.jcode/skills/config-sync/scripts/sync.sh ~/wezterm-jcode-dotfiles`
   - Do not force-push automatically
   - Do not auto-commit unreviewed user changes
   - If adding new top-level config paths, update `MANAGED_PATHS` in `scripts/install.sh`

## How to add more tools or wrappers later

1. Put the file or directory under the matching path inside `home/`
2. Add that top-level path to `MANAGED_PATHS` in `scripts/install.sh`
3. Re-run `bash scripts/install.sh`
4. Re-run `bash scripts/validate.sh`
5. Commit the new file
6. Run the sync skill to publish safely
