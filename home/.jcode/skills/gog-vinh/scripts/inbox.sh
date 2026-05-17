#!/usr/bin/env bash
# Quick unread inbox summary. Usage: inbox.sh <personal|work|study|all> [max=5]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:-all}"
MAX="${2:-5}"

for email in $(iter_accounts "$ALIAS"); do
  label=$(label_for "$email")
  echo "── [$label] $email ──"
  gog gmail search 'is:unread in:inbox' --max "$MAX" --account "$email" 2>&1 \
    | grep -v "WARN\|hint" || echo "  (no unread or error)"
  echo
done
