#!/bin/bash
# Calendar helper utilities for gog-vinh
set -euo pipefail
source "$(dirname "$0")/_accounts.sh"

# Parse ISO date and handle relative dates
# Usage: parse_date "2026-05-19" or "today" or "tomorrow" or "+3 days"
parse_date() {
  local input="$1"

  case "$input" in
    today)
      date --iso-8601=date
      ;;
    tomorrow)
      date -d "tomorrow" --iso-8601=date
      ;;
    yesterday)
      date -d "yesterday" --iso-8601=date
      ;;
    +[0-9]*)
      date -d "$input" --iso-8601=date
      ;;
    -[0-9]*)
      date -d "$input" --iso-8601=date
      ;;
    *)
      # Assume it's already in ISO format
      date -d "$input" --iso-8601=date 2>/dev/null || echo "$input"
      ;;
  esac
}

# Convert date to RFC3339 format with timezone
# Usage: to_rfc3339 "2026-05-19" "10:00:00" "+07:00"
to_rfc3339() {
  local date="$1"
  local time="${2:-00:00:00}"
  local tz="${3:-+07:00}"

  echo "${date}T${time}${tz}"
}

# Get day of week name
# Usage: day_of_week "2026-05-19"
day_of_week() {
  local date="$1"
  date -d "$date" "+%A"
}

# Parse recurrence rule (simple support for basic patterns)
# Usage: parse_rrule "daily" or "weekly" or "FREQ=DAILY;COUNT=10"
parse_rrule() {
  local pattern="$1"

  case "${pattern,,}" in
    daily)
      echo "FREQ=DAILY"
      ;;
    weekly)
      echo "FREQ=WEEKLY"
      ;;
    monthly)
      echo "FREQ=MONTHLY"
      ;;
    yearly)
      echo "FREQ=YEARLY"
      ;;
    *)
      # Assume it's already an RRULE
      echo "$pattern"
      ;;
  esac
}

# Calculate end date based on start date and duration
# Usage: calc_end_time "2026-05-19T10:00:00" "1h" or "90m"
calc_end_time() {
  local start="$1"
  local duration="${2:-1h}"

  local start_date="${start%%T*}"
  local start_time="${start#*T}"
  start_time="${start_time%+*}"
  start_time="${start_time%-*}"

  # Parse duration
  local minutes=0
  if [[ $duration =~ ^([0-9]+)h$ ]]; then
    minutes=$((${BASH_REMATCH[1]} * 60))
  elif [[ $duration =~ ^([0-9]+)m$ ]]; then
    minutes=${BASH_REMATCH[1]}
  else
    minutes=60
  fi

  # Calculate end time
  local end_seconds=$(date -d "$start" "+%s")
  end_seconds=$((end_seconds + minutes * 60))
  local end_time=$(date -d "@$end_seconds" "+%H:%M:%S")
  local end_date=$(date -d "@$end_seconds" "+%Y-%m-%d")

  echo "${end_date}T${end_time}"
}

# Format event for display
# Usage: format_event "id" "summary" "start" "location"
format_event() {
  local id="$1"
  local summary="$2"
  local start="$3"
  local location="${4:-}"

  printf "  %-40s | %-20s" "$summary" "$start"
  [ -n "$location" ] && printf " | %s" "$location"
  echo ""
}

# Validate email format
# Usage: validate_email "user@example.com"
validate_email() {
  local email="$1"
  [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Parse attendee list (comma-separated emails)
# Usage: parse_attendees "user1@x.com, user2@y.com"
parse_attendees() {
  local attendees="$1"
  local result=""

  IFS=',' read -ra emails <<< "$attendees"
  for email in "${emails[@]}"; do
    email=$(echo "$email" | xargs)  # trim whitespace
    if validate_email "$email"; then
      [ -n "$result" ] && result="$result,"
      result="$result$email"
    fi
  done

  echo "$result"
}

# Get Monday of next week
# Usage: next_monday
next_monday() {
  local today=$(date "+%w")  # 0=Sunday, 1=Monday, 6=Saturday
  local days_ahead=$((1 - today))
  if [ $days_ahead -le 0 ]; then
    days_ahead=$((days_ahead + 7))
  fi
  date -d "+$days_ahead days" --iso-8601=date
}

# Get Friday of next week
# Usage: next_friday
next_friday() {
  local today=$(date "+%w")  # 0=Sunday, 1=Monday, 6=Saturday
  local days_ahead=$((5 - today))
  if [ $days_ahead -le 0 ]; then
    days_ahead=$((days_ahead + 7))
  fi
  date -d "+$days_ahead days" --iso-8601=date
}

# Filter events by date range
# Usage: filter_by_date <events_json> <from_date> <to_date>
filter_by_date() {
  local events="$1"
  local from="$2"
  local to="$3"

  echo "$events" | jq --arg from "$from" --arg to "$to" \
    '.items[] | select(.start.dateTime >= $from and .start.dateTime <= $to)'
}

# Check for scheduling conflicts
# Usage: check_conflicts <event1_start> <event1_end> <event2_start> <event2_end>
check_conflicts() {
  local start1="$1" end1="$2" start2="$3" end2="$4"

  local ts1=$(date -d "$start1" "+%s")
  local te1=$(date -d "$end1" "+%s")
  local ts2=$(date -d "$start2" "+%s")
  local te2=$(date -d "$end2" "+%s")

  # Check if ranges overlap
  if [ $ts1 -lt $te2 ] && [ $ts2 -lt $te1 ]; then
    return 0  # Conflict exists
  else
    return 1  # No conflict
  fi
}

export -f parse_date to_rfc3339 day_of_week parse_rrule calc_end_time
export -f format_event validate_email parse_attendees next_monday next_friday
export -f filter_by_date check_conflicts
