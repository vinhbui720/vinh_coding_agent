#!/bin/bash
# Delete calendar events (single, multiple, or all with filters)
# Usage:
#   calendar-delete.sh <account> --id=<event-id>                        # Delete one event
#   calendar-delete.sh <account> --ids=<id1>,<id2>,<id3>               # Delete multiple
#   calendar-delete.sh <account> --summary=<text>                      # Delete all matching summary
#   calendar-delete.sh <account> --from=<date> --to=<date>            # Delete range
#   calendar-delete.sh <account> --from=<date> --all                   # Delete all from date onwards

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
shift || true

email=$(resolve_account "$account")
mode=""
ids=()
summary_filter=""
from_date=""
to_date=""
delete_all=false
force=false

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id=*)
      mode="single"
      ids=("${1#--id=}")
      shift
      ;;
    --ids=*)
      mode="multiple"
      IFS=',' read -ra ids <<< "${1#--ids=}"
      shift
      ;;
    --summary=*)
      mode="filter-summary"
      summary_filter="${1#--summary=}"
      shift
      ;;
    --from=*)
      from_date="${1#--from=}"
      shift
      ;;
    --to=*)
      to_date="${1#--to=}"
      shift
      ;;
    --all)
      delete_all=true
      shift
      ;;
    -y|--force)
      force=true
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validation
if [ -z "$mode" ] && [ "$delete_all" = false ]; then
  echo "Usage: calendar-delete.sh <account> [--id=ID|--ids=ID1,ID2|--summary=TEXT|--from=DATE [--to=DATE]] [--all] [-y]"
  echo ""
  echo "Examples:"
  echo "  calendar-delete.sh study --id=abc123def456"
  echo "  calendar-delete.sh work --summary='Old Meeting' -y"
  echo "  calendar-delete.sh personal --from='2026-06-01' --to='2026-06-30' -y"
  echo "  calendar-delete.sh personal --from='2026-06-01' --all -y"
  exit 1
fi

# Get events to delete
case "$mode" in
  single)
    echo "🗑️  Deleting event: ${ids[0]}"
    if [ "$force" = false ]; then
      read -p "   Confirm deletion? (y/N) " -n 1 -r
      echo ""
      [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
    gog calendar delete primary "${ids[0]}" --account "$email" --force
    echo "✅ Deleted"
    ;;

  multiple)
    echo "🗑️  Deleting ${#ids[@]} events..."
    [ "$force" = false ] && {
      for id in "${ids[@]}"; do
        echo "   - $id"
      done
      read -p "Confirm deletion? (y/N) " -n 1 -r
      echo ""
      [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    }

    deleted=0
    failed=0
    for id in "${ids[@]}"; do
      if gog calendar delete primary "$id" --account "$email" --force >/dev/null 2>&1; then
        ((deleted++))
      else
        ((failed++))
      fi
    done
    echo "✅ Deleted: $deleted, Failed: $failed"
    ;;

  filter-summary)
    echo "🔍 Finding events with summary: $summary_filter"

    # Get events matching summary (requires --json and jq parsing)
    events=$(gog calendar list primary --account "$email" --json 2>/dev/null | \
      jq ".events[] | select(.summary | contains(\"$summary_filter\")) | {id, summary, start}")

    if [ -z "$events" ]; then
      echo "   No events found"
      exit 0
    fi

    # Show events and ask for confirmation
    echo "$events" | jq -r '.id + " | " + .summary' | while read -r event_line; do
      echo "   - $event_line"
    done

    if [ "$force" = false ]; then
      read -p "Delete these events? (y/N) " -n 1 -r
      echo ""
      [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi

    # Delete them
    echo "$events" | jq -r '.id' | while read -r id; do
      gog calendar delete primary "$id" --account "$email" --force >/dev/null 2>&1 && \
        echo "   ✅ Deleted: $id"
    done
    ;;

  *)
    if [ "$delete_all" = true ]; then
      if [ -z "$from_date" ]; then
        echo "❌ --all requires --from=<date>"
        exit 1
      fi

      from_parsed=$(parse_date "$from_date")
      from_rfc=$(to_rfc3339 "$from_parsed" "00:00:00" "+00:00")

      echo "🗑️  Deleting ALL events from $from_parsed onwards..."
      echo ""

      if [ "$force" = false ]; then
        read -p "⚠️  This will delete MANY events. Confirm? (y/N) " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
      fi

      # Get all events from date onwards
      events=$(gog calendar list primary --account "$email" --json 2>/dev/null | \
        jq --arg from "$from_rfc" '.events[] | select(.start.dateTime >= $from) | {id, summary}')

      deleted=0
      echo "$events" | jq -r '.id' | while read -r id; do
        if gog calendar delete primary "$id" --account "$email" --force >/dev/null 2>&1; then
          ((deleted++))
          echo -ne "\r  Progress: $deleted deleted..."
        fi
      done
      echo ""
      echo "✅ Done"
    fi
    ;;
esac
