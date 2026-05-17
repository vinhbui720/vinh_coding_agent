# WezTerm + Jcode Dotfiles

Portable repo for my WezTerm and Jcode setup.

## What is included

- `~/.wezterm.lua`
- `~/.local/bin/jcode-wrappers/wezterm`
- `~/.jcode/config.toml`
- `~/.jcode/skills/gog-vinh/` custom helper skill
- external skill manifest for NotebookLM without vendoring its source

## What is intentionally NOT included

- auth tokens, sessions, logs, caches
- Jcode memory databases
- vendored upstream repos such as NotebookLM source

## Repo layout

- `home/` mirrors files under `$HOME`
- `scripts/install.sh` creates symlinks
- `scripts/validate.sh` checks symlinks and basic config parsing
- `docs/external-skills.md` documents non-vendored skills

## Install on a new machine

```bash
git clone <your-repo-url> ~/wezterm-jcode-dotfiles
cd ~/wezterm-jcode-dotfiles
bash scripts/install.sh
bash scripts/validate.sh
```

## External skills

NotebookLM is kept external on purpose. See `docs/external-skills.md`.

## Add a new wrapper or tool later

1. Put the real file under `home/...`
2. Re-run `bash scripts/install.sh`
3. Commit the new file

## Notes

- Installer backs up existing non-symlink files before replacing them.
- Symlinks keep the live config pointed at this repo, so edits here apply immediately.
