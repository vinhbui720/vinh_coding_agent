#!/bin/bash
# Find scheduling conflicts
# Usage:
#   calendar-conflicts.sh <account> [--from=DATE] [--to=DATE]
#   calendar-conflicts.sh <account> --check="SUMMARY" --date=DATE --time=HH:MM --duration=1h

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
shift || true

email=$(resolve_account "$account")

# Parse options
from_date=""
to_date=""
check_summary=""
check_date=""
check_time=""
check_duration="1h"
mode="scan"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from=*)
      from_date="${1#--from=}"
      mode="scan"
      shift
      ;;
    --to=*)
      to_date="${1#--to=}"
      shift
      ;;
    --check=*)
      mode="check"
      check_summary="${1#--check=}"
      shift
      ;;
    --date=*)
      check_date="${1#--date=}"
      shift
      ;;
    --time=*)
      check_time="${1#--time=}"
      shift
      ;;
    --duration=*)
      check_duration="${1#--duration=}"
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ "$mode" = "check" ]; then
  # Check if a specific time slot is available
  if [ -z "$check_date" ] || [ -z "$check_time" ]; then
    echo "Usage: calendar-conflicts.sh <account> --check=SUMMARY --date=DATE --time=HH:MM [--duration=1h]"
    echo ""
    echo "Example:"
    echo "  calendar-conflicts.sh study --check='Team Standup' --date='2026-05-19' --time='10:00' --duration='1h'"
    exit 1
  fi

  check_date=$(parse_date "$check_date")
  check_start=$(to_rfc3339 "$check_date" "$check_time:00" "+07:00")

  # Calculate end time
  check_end=$(calc_end_time "$check_start" "$check_duration")
  check_end="${check_end}+07:00"

  echo "🔍 Checking availability for: $check_summary"
  echo "   Date: $check_date ($(day_of_week "$check_date"))"
  echo "   Time: $check_time (${check_duration})"
  echo ""

  # Get all events for that day
  day_start=$(to_rfc3339 "$check_date" "00:00:00" "+00:00")
  day_end=$(to_rfc3339 "$check_date" "23:59:59" "+00:00")

  events=$(gog calendar list primary --account "$email" --json 2>/dev/null | \
    jq "[.events[] | select(.start.dateTime >= \"$day_start\" and .start.dateTime <= \"$day_end\")]")

  conflicts=0
  echo "$events" | jq -r '.[] | .start.dateTime + " | " + (.end.dateTime // "N/A") + " | " + (.summary // "(no title)")' | \
  while read -r event_line; do
    IFS='|' read -r event_start event_end event_summary <<< "$event_line"
    event_start=$(echo "$event_start" | xargs)
    event_end=$(echo "$event_end" | xargs)
    event_summary=$(echo "$event_summary" | xargs)

    # Check for conflict
    if check_conflicts "$check_start" "$check_end" "$event_start" "$event_end"; then
      echo "  ⚠️  CONFLICT: $event_summary"
      echo "      $event_start to $event_end"
      ((conflicts++))
    fi
  done

  echo ""
  if [ "$conflicts" -eq 0 ]; then
    echo "✅ Time slot is available!"
  else
    echo "❌ Found $conflicts conflict(s)"
  fi

else
  # Scan for all conflicts in a date range
  if [ -z "$from_date" ]; then
    from_date=$(date --iso-8601=date)
  fi
  to_date="${to_date:-$from_date}"

  from_date=$(parse_date "$from_date")
  to_date=$(parse_date "$to_date")

  echo "🔍 Scanning for conflicts from $from_date to $to_date..."
  echo ""

  from_rfc=$(to_rfc3339 "$from_date" "00:00:00" "+00:00")
  to_rfc=$(to_rfc3339 "$to_date" "23:59:59" "+00:00")

  # Get all events in range
  events=$(gog calendar list primary --account "$email" --json 2>/dev/null | \
    jq "[.events[] | select(.start.dateTime >= \"$from_rfc\" and .start.dateTime <= \"$to_rfc\") | sort_by(.start.dateTime)]")

  total=$(echo "$events" | jq 'length')

  # Check each pair for conflicts
  conflicts_found=0

  for i in $(seq 0 $((total - 1))); do
    for j in $(seq $((i + 1)) $((total - 1))); do
      event1=$(echo "$events" | jq ".[$i]")
      event2=$(echo "$events" | jq ".[$j]")

      start1=$(echo "$event1" | jq -r '.start.dateTime')
      end1=$(echo "$event1" | jq -r '.end.dateTime')
      summary1=$(echo "$event1" | jq -r '.summary // "(no title)"')

      start2=$(echo "$event2" | jq -r '.start.dateTime')
      end2=$(echo "$event2" | jq -r '.end.dateTime')
      summary2=$(echo "$event2" | jq -r '.summary // "(no title)"')

      # Check for conflict
      if check_conflicts "$start1" "$end1" "$start2" "$end2"; then
        if [ "$conflicts_found" -eq 0 ]; then
          echo "Found conflicts:"
          echo ""
        fi

        date1="${start1%%T*}"
        time1="${start1#*T}"
        time1="${time1%+*}"
        time1="${time1%-*}"
        time1="${time1:0:5}"

        echo "  ⚠️  $date1 at $time1"
        echo "      • $summary1 ($start1 to $end1)"
        echo "      • $summary2 ($start2 to $end2)"
        echo ""

        ((conflicts_found++))
      fi
    done
  done

  if [ "$conflicts_found" -eq 0 ]; then
    echo "✅ No conflicts found"
  else
    echo "❌ Found $conflicts_found conflict(s)"
  fi
fi
