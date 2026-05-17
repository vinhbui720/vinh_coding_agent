#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING: $1" >&2
    return 1
  }
}

warn_cmd() {
  command -v "$1" >/dev/null 2>&1 || echo "WARN: optional command missing: $1"
}

echo "==> Checking core dependencies"
need_cmd bash
need_cmd git
warn_cmd wezterm
warn_cmd jcode
warn_cmd gog

echo "==> Installing symlinks"
bash "$REPO_DIR/scripts/install.sh"

echo "==> Installing external skills if needed"
bash "$REPO_DIR/scripts/install-external-skills.sh"

echo "==> Running validation"
bash "$REPO_DIR/scripts/validate.sh"

echo "Bootstrap complete"
