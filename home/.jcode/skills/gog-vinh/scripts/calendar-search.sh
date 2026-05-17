#!/bin/bash
# Search calendar events
# Usage:
#   calendar-search.sh <account> --summary=STR [--from=DATE] [--to=DATE]
#   calendar-search.sh <account> --attendee=EMAIL [--from=DATE] [--to=DATE]
#   calendar-search.sh <account> --location=STR
#   calendar-search.sh <account> --from=DATE [--to=DATE]  # List all in range

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
shift || true

email=$(resolve_account "$account")

# Parse options
summary_filter=""
attendee_filter=""
location_filter=""
from_date=""
to_date=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary=*)
      summary_filter="${1#--summary=}"
      shift
      ;;
    --attendee=*)
      attendee_filter="${1#--attendee=}"
      shift
      ;;
    --location=*)
      location_filter="${1#--location=}"
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
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$summary_filter" ] && [ -z "$attendee_filter" ] && [ -z "$location_filter" ] && [ -z "$from_date" ]; then
  echo "Usage: calendar-search.sh <account> --summary=STR | --attendee=EMAIL | --location=STR | --from=DATE"
  echo ""
  echo "Examples:"
  echo "  calendar-search.sh study --summary='Meeting'"
  echo "  calendar-search.sh work --attendee='user@example.com'"
  echo "  calendar-search.sh personal --from='2026-05-18' --to='2026-05-25'"
  exit 1
fi

# Get all events
echo "🔍 Searching events..."
all_events=$(gog calendar list primary --account "$email" --json 2>/dev/null)

# Build jq filter for .events array
if [ -n "$summary_filter" ]; then
  result=$(echo "$all_events" | jq "[.events[] | select(.summary | contains(\"$summary_filter\"))]")
elif [ -n "$attendee_filter" ]; then
  result=$(echo "$all_events" | jq "[.events[] | select(.attendees[]?.email | contains(\"$attendee_filter\"))]")
elif [ -n "$location_filter" ]; then
  result=$(echo "$all_events" | jq "[.events[] | select(.location | contains(\"$location_filter\"))]")
elif [ -n "$from_date" ]; then
  from_date=$(parse_date "$from_date")
  from_rfc=$(to_rfc3339 "$from_date" "00:00:00" "+00:00")

  if [ -n "$to_date" ]; then
    to_date=$(parse_date "$to_date")
    to_rfc=$(to_rfc3339 "$to_date" "23:59:59" "+00:00")
    result=$(echo "$all_events" | jq --arg from "$from_rfc" --arg to "$to_rfc" "[.events[] | select(.start.dateTime >= \$from and .start.dateTime <= \$to)]")
  else
    result=$(echo "$all_events" | jq --arg from "$from_rfc" "[.events[] | select(.start.dateTime >= \$from)]")
  fi
else
  result=$(echo "$all_events" | jq '[.events[]]')
fi

count=$(echo "$result" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo "   No events found"
  exit 0
fi

echo "   Found $count event(s):"
echo ""

echo "$result" | jq -r '.[] | "\(.id) | \(.summary // "(no title)") | \(.start.dateTime // .start.date // "(unknown time)")"' | \
while read -r event_line; do
  # Parse the result
  IFS='|' read -r id summary start <<< "$event_line"
  id=$(echo "$id" | xargs)
  summary=$(echo "$summary" | xargs)
  start=$(echo "$start" | xargs)

  # Extract date from RFC3339
  start_date="${start%%T*}"
  start_time="${start#*T}"
  start_time="${start_time%+*}"
  start_time="${start_time%-*}"

  printf "  %-40s | %s %s\n" "$id" "$start_date" "${start_time:0:5}"
  printf "    └─ %s\n" "$summary"
done

echo ""
echo "💡 Use calendar-update.sh or calendar-delete.sh with the event ID"
