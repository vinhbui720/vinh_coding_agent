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
scripts/
  install.sh
  validate.sh
docs/
  external-skills.md
```

## What is included

- WezTerm main config
- Jcode wrapper for WezTerm
- Jcode config
- custom `gog-vinh` skill

## What is NOT included

- auth, OAuth, tokens, sessions, logs, caches
- Jcode memory state
- upstream third-party skill source repos

## Install on a new machine

```bash
git clone <repo-url> ~/wezterm-jcode-dotfiles
cd ~/wezterm-jcode-dotfiles
bash scripts/install.sh
bash scripts/validate.sh
```

`install.sh` will back up existing non-symlink files and replace them with symlinks.

## External skills

Some skills are intentionally external. See:

- `docs/external-skills.md`

Example: NotebookLM should be installed separately at `~/.jcode/skills/notebooklm`.

## LLM adaptation checklist

If an LLM/agent is setting this up on a different machine, it should check these items and fix mismatches:

1. **Symlinks**
   - `~/.wezterm.lua` -> `~/wezterm-jcode-dotfiles/home/.wezterm.lua`
   - `~/.local/bin/jcode-wrappers/wezterm` -> `~/wezterm-jcode-dotfiles/home/.local/bin/jcode-wrappers/wezterm`
   - `~/.jcode/config.toml` -> `~/wezterm-jcode-dotfiles/home/.jcode/config.toml`
   - `~/.jcode/skills/gog-vinh` -> `~/wezterm-jcode-dotfiles/home/.jcode/skills/gog-vinh`

2. **Required binaries**
   - `wezterm`
   - `jcode`
   - `bash`
   - `git`
   - `gog` for the `gog-vinh` skill

3. **Machine-specific paths**
   - Search for absolute paths like `/home/...`, `/tmp/...`, machine-specific repo paths, or old usernames
   - Replace them with relative paths derived from the current script location where possible
   - Keep configs portable: prefer `$(dirname "$0")`, `$HOME`, or repo-relative paths

4. **Secrets and local state**
   - Never commit auth files, browser state, sessions, or caches into this repo
   - Keep local secrets outside git

5. **Validation**
   - Run `bash scripts/validate.sh`
   - If validation fails, fix symlinks first, then missing binaries, then bad paths inside configs/scripts

## How to add more tools or wrappers later

1. Put the file under the matching path inside `home/`
2. Re-run `bash scripts/install.sh`
3. Re-run `bash scripts/validate.sh`
4. Commit the new file
