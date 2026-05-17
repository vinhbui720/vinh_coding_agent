#!/usr/bin/env bash
# Gmail search. Usage: search.sh <personal|work|study|all> "<query>" [max=10]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:-all}"
QUERY="${2:-}"
MAX="${3:-10}"

if [ -z "$QUERY" ]; then
  echo "Usage: search.sh <account> \"<query>\" [max]" >&2
  exit 1
fi

for email in $(iter_accounts "$ALIAS"); do
  label=$(label_for "$email")
  echo "── [$label] '$QUERY' ──"
  gog gmail search "$QUERY" --max "$MAX" --account "$email" 2>&1 \
    | grep -v "WARN\|hint" || echo "  (no results)"
  echo
done
