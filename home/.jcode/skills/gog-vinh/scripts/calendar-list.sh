#!/bin/bash
# List calendar events with filtering and formatting
# Usage:
#   calendar-list.sh <account> [--today|--tomorrow|--week|--month|--from=DATE [--to=DATE]] [--format=table|csv|json]

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
shift || true

email=$(resolve_account "$account")

# Parse options
mode="today"
from_date=""
to_date=""
format="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)
      mode="today"
      shift
      ;;
    --tomorrow)
      mode="tomorrow"
      shift
      ;;
    --week)
      mode="week"
      shift
      ;;
    --month)
      mode="month"
      shift
      ;;
    --from=*)
      from_date="${1#--from=}"
      mode="custom"
      shift
      ;;
    --to=*)
      to_date="${1#--to=}"
      shift
      ;;
    --format=*)
      format="${1#--format=}"
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done

# Calculate date range based on mode
case "$mode" in
  today)
    from_date=$(date --iso-8601=date)
    to_date="$from_date"
    ;;
  tomorrow)
    from_date=$(date -d "tomorrow" --iso-8601=date)
    to_date="$from_date"
    ;;
  week)
    from_date=$(date --iso-8601=date)
    to_date=$(date -d "+6 days" --iso-8601=date)
    ;;
  month)
    from_date=$(date --iso-8601=date)
    to_date=$(date -d "+30 days" --iso-8601=date)
    ;;
  custom)
    if [ -z "$from_date" ]; then
      echo "❌ --from= is required for custom range"
      exit 1
    fi
    to_date="${to_date:-$from_date}"
    ;;
esac

# Parse dates
from_date=$(parse_date "$from_date")
to_date=$(parse_date "$to_date")
from_rfc=$(to_rfc3339 "$from_date" "00:00:00" "+00:00")
to_rfc=$(to_rfc3339 "$to_date" "23:59:59" "+00:00")

# Get events
events=$(gog calendar list primary --account "$email" --json 2>/dev/null | \
  jq "[.events[] | select(.start.dateTime >= \"$from_rfc\" and .start.dateTime <= \"$to_rfc\") | sort_by(.start.dateTime)]")

count=$(echo "$events" | jq 'length')

# Display based on format
case "$format" in
  table)
    echo "📅 Events from $from_date to $to_date ($count total)"
    echo ""

    if [ "$count" -eq 0 ]; then
      echo "   (none)"
    else
      # Group by date
      echo "$events" | jq -r '.[] | .start.dateTime' | cut -d'T' -f1 | sort -u | while read -r date; do
        day=$(day_of_week "$date")
        echo "$date ($day)"

        echo "$events" | jq -r ".[] | select(.start.dateTime | startswith(\"$date\")) | \"\(.start.dateTime | split(\"T\")[1] | split(\"+\")[0] | .[0:5]) - \(.summary // \"(no title)\")\"" | \
        while read -r event; do
          echo "  • $event"
        done
        echo ""
      done
    fi
    ;;

  csv)
    echo "date,time,summary,location,attendees"
    echo "$events" | jq -r '.[] | "\(.start.dateTime | split("T")[0]),\(.start.dateTime | split("T")[1] | split("+")[0] | .[0:5]),\(.summary // ""),\(.location // ""),\(.attendees[]?.email | join(";") // "")"'
    ;;

  json)
    echo "$events" | jq '.'
    ;;

  *)
    echo "❌ Unknown format: $format"
    exit 1
    ;;
esac

echo ""
[ "$count" -gt 0 ] && echo "💡 Use calendar-search.sh for more detailed filtering"
