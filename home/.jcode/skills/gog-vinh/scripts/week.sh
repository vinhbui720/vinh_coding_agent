#!/usr/bin/env bash
# This week's calendar events. Usage: week.sh <personal|work|study|all>
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:-all}"
FROM=$(date -u +"%Y-%m-%dT00:00:00Z")
TO=$(date -u -d "+7 days" +"%Y-%m-%dT00:00:00Z")

for email in $(iter_accounts "$ALIAS"); do
  label=$(label_for "$email")
  echo "── [$label] next 7 days ──"
  gog calendar events primary --from "$FROM" --to "$TO" --account "$email" 2>&1 \
    | grep -v "WARN\|hint" || echo "  (no events)"
  echo
done
