#!/usr/bin/env bash
# Today's calendar events. Usage: today.sh <personal|work|study|all>
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:-all}"
FROM=$(date -u +"%Y-%m-%dT00:00:00Z")
TO=$(date -u -d "+1 day" +"%Y-%m-%dT00:00:00Z")

for email in $(iter_accounts "$ALIAS"); do
  label=$(label_for "$email")
  echo "── [$label] today ──"
  gog calendar events primary --from "$FROM" --to "$TO" --account "$email" 2>&1 \
    | grep -v "WARN\|hint" || echo "  (no events)"
  echo
done
