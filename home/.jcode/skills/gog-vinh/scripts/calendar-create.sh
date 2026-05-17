#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_accounts.sh"

# Create calendar event
# Usage: calendar-create.sh <account> <summary> <start-iso> [end-iso] [location]
# Example: calendar-create.sh study "Phản biện" "2026-05-19T10:00:00" "2026-05-19T11:00:00" "106-B1"

account=$1
summary=$2
start=$3
end=${4:-$(date -d "$start + 1 hour" --iso-8601=seconds)}
location=${5:-}

email=$(resolve_account "$account")

cmd=(
  gog calendar create primary
  --account "$email"
  --summary "$summary"
  --from "$start"
  --to "$end"
)

if [ -n "$location" ]; then
  cmd+=(--location "$location")
fi

"${cmd[@]}"
