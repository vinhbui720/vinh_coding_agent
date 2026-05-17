#!/usr/bin/env bash
# Create a draft email. Usage: draft.sh <personal|work|study> <to> <subject> <body>
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

ALIAS="${1:?account alias required}"
TO="${2:?recipient required}"
SUBJECT="${3:?subject required}"
BODY="${4:?body required}"

EMAIL=$(resolve_account "$ALIAS")
[ "$EMAIL" = "ALL" ] && { echo "Cannot draft to 'all'; pick one account." >&2; exit 1; }

echo "Creating draft from [$ALIAS] $EMAIL → $TO"
gog gmail drafts create --to "$TO" --subject "$SUBJECT" --body "$BODY" --account "$EMAIL"
