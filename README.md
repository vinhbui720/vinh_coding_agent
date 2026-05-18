# WezTerm + Jcode Dotfiles

Portable repo for my terminal, Jcode, and wrapper-only memory setup.

## Goal

Use this repo to recreate my environment on another machine with minimal manual work.
Live config is managed by symlink: the real files in `$HOME` should point to files inside this repo.

## Repo structure

```text
home/
  .wezterm.lua
  .local/bin/jcode-wrappers/wezterm
  .jcode/config.toml
  .jcode/mcp.json
  .jcode/skills/gog-vinh/
  .jcode/skills/config-sync/
  .memory-wrapper/
scripts/
  bootstrap.sh
  install.sh
  post-install.sh
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
- wrapper-only long-term memory setup for Jcode + agentmemory

## What is NOT included

- auth, OAuth, tokens, sessions, logs, caches
- Jcode memory state
- real memory secrets in `.memory-wrapper/.env`
- upstream third-party skill source repos
- cloned `agentmemory` source checkout

## Fast setup on a new machine

```bash
git clone <repo-url> ~/wezterm-jcode-dotfiles
cd ~/wezterm-jcode-dotfiles
bash scripts/bootstrap.sh
```

What `bootstrap.sh` does:
- checks core dependencies
- installs top-level managed symlinks into `$HOME`
- creates `~/.memory-wrapper/.env` if missing
- appends the memory shell-init block to `~/.bashrc`
- appends `~/.local/bin/jcode-wrappers` to `PATH` in `~/.bashrc` (must come before `/usr/bin` so the wezterm wrapper shadows the real binary)
- clones external skills if missing
- clones and installs `agentmemory` dependencies
- runs validation

If you want the steps manually:

```bash
bash scripts/install.sh
bash scripts/post-install.sh
bash scripts/install-external-skills.sh
~/.memory-wrapper/bin/install-memory-deps
bash scripts/validate.sh
```

## Managed live paths

These are the paths that should exist in `$HOME` after install:

- `~/.wezterm.lua`
- `~/.local/bin/jcode-wrappers/wezterm`
- `~/.jcode/config.toml`
- `~/.jcode/mcp.json`
- `~/.jcode/skills/gog-vinh`
- `~/.jcode/skills/config-sync`
- `~/.memory-wrapper`
- `~/.jcode/skills/sync-memory` -> `~/.memory-wrapper/skills/sync-memory`
- `~/.jcode/skills/load-context` -> `~/.memory-wrapper/skills/load-context`
- `~/.jcode/skills/save-decision` -> `~/.memory-wrapper/skills/save-decision`
- `~/.jcode/skills/bm25-search` -> `~/.memory-wrapper/skills/bm25-search`

## Memory wrapper layout

```text
~/.memory-wrapper/
  .env
  bin/
    install-memory-deps
    agentmemory-start
    sync-memory
    jc
    post-session
    agentmemory-mcp
  skills/
    sync-memory/
    load-context/
    save-decision/
    bm25-search/
```

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

## Memory usage

Start or restart memory server:

```bash
~/.memory-wrapper/bin/agentmemory-start
```

Common skills:
- `/sync-memory`
- `/load-context`
- `/save-decision`
- `/bm25-search`

## Agentmemory quick playbook (cross-machine)

Use this checklist on any machine to ensure Jcode + agentmemory works fully.

### 1) Health first

```bash
~/.memory-wrapper/bin/memory-doctor
# auto-repair common issues
~/.memory-wrapper/bin/memory-doctor --fix
```

### 2) Core workflow

```bash
# Recall context
~/.memory-wrapper/bin/memory-search "<project/task query>" 7

# Save memory + auto graph extraction
~/.memory-wrapper/bin/memory-save-and-extract decision "<title>" "<content>"

# Query knowledge graph
~/.memory-wrapper/bin/graph-query "<query>" 10

# Pin permanent knowledge (never decay)
~/.memory-wrapper/bin/crystallize "<title>" "<content>" "tag1,tag2"
```

### 3) Useful status commands

```bash
~/.memory-wrapper/bin/agentmemory-status
~/.memory-wrapper/bin/graph-stats
```

### 4) Jcode skills to use

- `/load-context` for memory + graph + crystals
- `/save-decision` for save + auto graph-extract
- `/graph-query` for relationship exploration
- `/crystallize` for permanent memory
- `/sync-memory` to sync peers

### 5) Integration principle

Keep Jcode native memory features enabled. Agentmemory wrappers are additive and should enhance recall, graph knowledge, and durable decisions without replacing core Jcode memory behavior.


If an LLM/agent is setting this up on a different machine, it should check these items and fix mismatches:

1. **Symlinks**
   - verify every managed live path above
   - verify `.jcode/skills/{sync-memory,load-context,save-decision,bm25-search}` point into `~/.memory-wrapper/skills/`

2. **Required binaries**
   - required: `bash`, `git`, `python3`, `curl`
   - expected for full setup: `wezterm`, `jcode`, `node`, `npm`, `npx`
   - optional for `gog-vinh`: `gog`

3. **PATH order for wezterm wrapper**
   - `~/.local/bin/jcode-wrappers` must appear in `PATH` **before** `/usr/bin`
   - Without this, `which wezterm` resolves to `/usr/bin/wezterm` and the split-pane wrapper is never called
   - Verify with: `which wezterm` → should return `~/.local/bin/jcode-wrappers/wezterm`
   - `post-install.sh` appends this automatically; if it was run on an older version, add manually:
     ```bash
     export PATH="$HOME/.local/bin/jcode-wrappers:$PATH"
     ```

4. **`jc` wrapper must not pipe when stdout is a TTY**
   - The `jc` script (aliased as `jcode`) uses `| tee` to capture transcripts
   - Piping destroys the TTY, causing: `Error: jcode TUI requires an interactive terminal`
   - The fix is already in `home/.memory-wrapper/bin/jc`: it checks `[ -t 1 ]` and `exec`s directly when in a TTY
   - If the alias `jcode` is missing or points to the raw binary directly, the TUI works but transcript capture is skipped — that is acceptable

5. **Machine-specific paths**
   - Search for absolute paths like `/home/...`, `/tmp/...`, machine-specific repo paths, or old usernames
   - Replace them with relative paths derived from the current script location where possible
   - Keep configs portable: prefer `$(dirname "$0")`, `$HOME`, or repo-relative paths

6. **Secrets and local state**
   - Never commit auth files, browser state, sessions, caches, or `.memory-wrapper/.env`
   - Keep local secrets outside git

7. **Validation**
   - Run `bash scripts/validate.sh`
   - If validation fails, fix symlinks first, then missing binaries, then bad paths inside configs/scripts

8. **Sync policy**
   - Prefer `bash ~/.jcode/skills/config-sync/scripts/sync.sh ~/wezterm-jcode-dotfiles`
   - Do not force-push automatically
   - Do not auto-commit unreviewed user changes
   - If adding new top-level config paths, update `MANAGED_PATHS` in `scripts/install.sh`

## How to add more tools or wrappers later

1. Put the file or directory under the matching path inside `home/`
2. Add that top-level path to `MANAGED_PATHS` in `scripts/install.sh`
3. If it is a Jcode memory skill, either place it in `home/.memory-wrapper/skills/` or add a new alias rule
4. Re-run `bash scripts/install.sh`
5. Re-run `bash scripts/post-install.sh`
6. Re-run `bash scripts/validate.sh`
7. Commit the new file
8. Run the sync skill to publish safely
