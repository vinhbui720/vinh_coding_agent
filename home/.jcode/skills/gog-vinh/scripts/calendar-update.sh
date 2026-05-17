#!/bin/bash
# Update/edit calendar events
# Usage:
#   calendar-update.sh <account> <event-id> --summary=STR [--from=DATE] [--to=DATE] [--location=STR] [--attendees=STR] [--rrule=STR]

set -euo pipefail
source "$(dirname "$0")/_accounts.sh"
source "$(dirname "$0")/_calendar-helpers.sh"

account=$1
event_id="${2:-}"
shift 2 || true

if [ -z "$event_id" ]; then
  echo "Usage: calendar-update.sh <account> <event-id> [--summary=STR] [--from=DATE] [--to=DATE] [--location=STR] [--attendees=STR] [--rrule=STR] [--tz=TZ]"
  echo ""
  echo "Examples:"
  echo "  calendar-update.sh study abc123def456 --summary='New Title' --location='Room 202'"
  echo "  calendar-update.sh work xyz789 --from='2026-05-20' --to='2026-05-20'"
  exit 1
fi

email=$(resolve_account "$account")

# Get current event details
echo "🔍 Fetching event details..."
current=$(gog calendar raw primary "$event_id" --account "$email" --json 2>/dev/null)

if [ -z "$current" ]; then
  echo "❌ Event not found: $event_id"
  exit 1
fi

# Extract current values
current_summary=$(echo "$current" | jq -r '.summary // empty')
current_location=$(echo "$current" | jq -r '.location // empty')
current_attendees=$(echo "$current" | jq -r '.attendees[].email' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
current_rrule=$(echo "$current" | jq -r '.recurrence[0] // empty' 2>/dev/null)

echo "📝 Current event:"
echo "   Summary: $current_summary"
echo "   Location: ${current_location:-(none)}"
[ -n "$current_attendees" ] && echo "   Attendees: $current_attendees"
[ -n "$current_rrule" ] && echo "   Recurrence: $current_rrule"
echo ""

# Parse update options
summary="$current_summary"
location="$current_location"
attendees="$current_attendees"
rrule="$current_rrule"
from=""
to=""
tz="+07:00"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary=*)
      summary="${1#--summary=}"
      shift
      ;;
    --from=*)
      from="${1#--from=}"
      shift
      ;;
    --to=*)
      to="${1#--to=}"
      shift
      ;;
    --location=*)
      location="${1#--location=}"
      shift
      ;;
    --attendees=*)
      attendees=$(parse_attendees "${1#--attendees=}")
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

# Build update command
cmd=(gog calendar update primary "$event_id" --account "$email" --summary "$summary")

# Handle dates if provided
if [ -n "$from" ] || [ -n "$to" ]; then
  if [ -z "$from" ] || [ -z "$to" ]; then
    echo "❌ Both --from and --to are required when changing dates"
    exit 1
  fi

  from_date=$(parse_date "$from")
  to_date=$(parse_date "$to")
  from_rfc=$(to_rfc3339 "$from_date" "10:00:00" "$tz")
  to_rfc=$(to_rfc3339 "$to_date" "11:00:00" "$tz")

  cmd+=(--from "$from_rfc" --to "$to_rfc")
fi

[ -n "$location" ] && cmd+=(--location "$location")
[ -n "$attendees" ] && cmd+=(--attendees "$attendees")
[ -n "$rrule" ] && cmd+=(--rrule "$rrule")

# Show what will change
echo "📋 Updates:"
echo "   Summary: $summary"
[ -n "$from" ] && echo "   From: $(parse_date "$from")"
[ -n "$to" ] && echo "   To: $(parse_date "$to")"
echo "   Location: ${location:-(none)}"
[ -n "$attendees" ] && echo "   Attendees: $attendees"
[ -n "$rrule" ] && echo "   Recurrence: $rrule"
echo ""

read -p "Apply updates? (y/N) " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# Execute update
if "${cmd[@]}" >/dev/null 2>&1; then
  echo "✅ Event updated successfully!"
else
  echo "❌ Failed to update event"
  exit 1
fi
