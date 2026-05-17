#!/usr/bin/env bash
# Send email. Usage: send.sh <personal|work|study> <to> <subject> <body>
# WARNING: ALWAYS get Vinh's approval before calling this (per his boundaries).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:?account alias required}"
TO="${2:?recipient required}"
SUBJECT="${3:?subject required}"
BODY="${4:?body required}"

EMAIL=$(resolve_account "$ALIAS")
[ "$EMAIL" = "ALL" ] && { echo "Cannot send to 'all'; pick one account." >&2; exit 1; }

echo "Sending from [$ALIAS] $EMAIL → $TO"
gog gmail send --to "$TO" --subject "$SUBJECT" --body "$BODY" --account "$EMAIL"
