#!/bin/bash
# Add calendar events (single or bulk with recurrence support)
# Usage:
#   calendar-add.sh <account> <summary> <from> [<to>] [--location=STR] [--attendees=STR] [--rrule=STR] [--tz=TZ]
#   calendar-add.sh <account> --bulk <file.csv> [--tz=TZ]
#
# Examples:
#   calendar-add.sh study "Meeting" "2026-05-19T10:00:00" "2026-05-19T11:00:00" --location="Room 101"
#   calendar-add.sh personal "Daily standup" "2026-05-19T09:00:00" "1h" --rrule="FREQ=DAILY;COUNT=5"
#   calendar-add.sh work --bulk events.csv

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
shift || true

# Check for bulk mode
if [ "${1:-}" = "--bulk" ]; then
  bulk_file="${2:-}"
  tz="${3#--tz=}"
  tz="${tz:-+07:00}"

  if [ ! -f "$bulk_file" ]; then
    echo "❌ Bulk file not found: $bulk_file"
    echo "CSV format: summary,from,to,location,attendees,rrule"
    exit 1
  fi

  email=$(resolve_account "$account")
  created=0
  failed=0

  echo "📋 Processing bulk events from $bulk_file..."
  while IFS=',' read -r summary from to location attendees rrule; do
    # Skip header and empty lines
    [[ "$summary" == "summary" ]] && continue
    [[ -z "$summary" ]] && continue

    # Trim whitespace
    summary=$(echo "$summary" | xargs)
    from=$(echo "$from" | xargs)
    to=$(echo "$to" | xargs)
    location=$(echo "$location" | xargs)
    attendees=$(echo "$attendees" | xargs)
    rrule=$(echo "$rrule" | xargs)

    # Parse dates
    from=$(parse_date "$from")
    to=$(parse_date "$to")
    from_rfc=$(to_rfc3339 "$from" "09:00:00" "$tz")
    to_rfc=$(to_rfc3339 "$to" "10:00:00" "$tz")

    # Build gog command
    cmd=(gog calendar create primary --account "$email" --summary "$summary" --from "$from_rfc" --to "$to_rfc")

    [ -n "$location" ] && cmd+=(--location "$location")
    [ -n "$rrule" ] && cmd+=(--rrule "$rrule")
    [ -n "$attendees" ] && cmd+=(--attendees "$attendees")

    if "${cmd[@]}" >/dev/null 2>&1; then
      echo "  ✅ $summary"
      ((created++))
    else
      echo "  ❌ $summary"
      ((failed++))
    fi
  done < "$bulk_file"

  echo ""
  echo "Summary: $created created, $failed failed"
  exit 0
fi

# Single event mode
summary="$1"
from="$2"
to="${3:-}"
location=""
attendees=""
rrule=""
tz="+07:00"

shift 2
[ -n "$to" ] && shift || true

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --location=*)
      location="${1#--location=}"
      shift
      ;;
    --attendees=*)
      attendees="${1#--attendees=}"
      attendees=$(parse_attendees "$attendees")
      shift
      ;;
    --rrule=*)
      rrule=$(parse_rrule "${1#--rrule=}")
      shift
      ;;
    --tz=*)
      tz="${1#--tz=}"
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$summary" ] || [ -z "$from" ]; then
  echo "Usage: calendar-add.sh <account> <summary> <from-date> [<to-date>|<duration>] [options]"
  echo ""
  echo "Options:"
  echo "  --location=STR      Event location"
  echo "  --attendees=STR     Comma-separated emails"
  echo "  --rrule=STR         Recurrence rule (daily/weekly/monthly/yearly or FREQ=...)"
  echo "  --tz=TZ             Timezone offset (default: +07:00)"
  echo ""
  echo "Examples:"
  echo "  calendar-add.sh study 'Meeting' '2026-05-19' '2026-05-19' --location='Room 101'"
  echo "  calendar-add.sh personal 'Standup' 'today' '1h' --rrule=daily"
  echo "  calendar-add.sh work --bulk events.csv"
  exit 1
fi

email=$(resolve_account "$account")

# Parse dates and times
from_date=$(parse_date "$from")
if [ -z "$to" ] || [[ "$to" =~ ^[0-9]+[mh]$ ]]; then
  # to is a duration
  duration="${to:-1h}"
  from_rfc=$(to_rfc3339 "$from_date" "10:00:00" "$tz")
  to_rfc=$(calc_end_time "$from_rfc" "$duration")
  to_rfc="${to_rfc}${tz}"
else
  # to is a date
  to_date=$(parse_date "$to")
  from_rfc=$(to_rfc3339 "$from_date" "10:00:00" "$tz")
  to_rfc=$(to_rfc3339 "$to_date" "11:00:00" "$tz")
fi

# Build gog command
cmd=(gog calendar create primary --account "$email" --summary "$summary" --from "$from_rfc" --to "$to_rfc")

[ -n "$location" ] && cmd+=(--location "$location")
[ -n "$rrule" ] && cmd+=(--rrule "$rrule")
[ -n "$attendees" ] && cmd+=(--attendees "$attendees")

# Execute
echo "📅 Creating event: $summary"
echo "   From: $from_rfc"
echo "   To:   $to_rfc"
[ -n "$location" ] && echo "   Location: $location"
[ -n "$rrule" ] && echo "   Recurrence: $rrule"
echo ""

if result=$("${cmd[@]}" 2>&1); then
  event_id=$(echo "$result" | grep "^id" | awk '{print $2}')
  echo "✅ Event created!"
  echo "   ID: $event_id"
  [ -n "$event_id" ] && echo "   View: https://calendar.google.com/calendar/r/eventedit/$event_id"
else
  echo "❌ Failed to create event"
  echo "$result"
  exit 1
fi
