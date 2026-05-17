#!/usr/bin/env bash
# Create email draft and print a Gmail drafts link.

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

if [ -z "${GOG_KEYRING_PASSWORD:-}" ]; then
  echo "❌ Error: GOG_KEYRING_PASSWORD not set"
  echo "Add to ~/.bashrc:"
  echo "  export GOG_KEYRING_PASSWORD='your_password'"
  exit 1
fi

ACCOUNT="${1:-study}"
RECIPIENT="${2:-}"
SUBJECT="${3:-}"
BODY="${4:-}"

if [ -z "$RECIPIENT" ] || [ -z "$SUBJECT" ] || [ -z "$BODY" ]; then
  echo "Usage: $0 <account> <recipient_email> <subject> <body>"
  exit 1
fi

EMAIL=$(resolve_account "$ACCOUNT")
[ "$EMAIL" = "ALL" ] && { echo "Cannot draft from 'all'; pick one account." >&2; exit 1; }

echo "📧 Creating draft..."
echo "From: $EMAIL"
echo "To: $RECIPIENT"
echo "Subject: $SUBJECT"
echo ""

RESULT=$(bash "$DIR/draft.sh" "$ACCOUNT" "$RECIPIENT" "$SUBJECT" "$BODY" 2>&1)
DRAFT_ID=$(echo "$RESULT" | awk '/draft_id/ {print $2; exit}')

if [ -z "$DRAFT_ID" ]; then
  echo "❌ Failed to create draft"
  echo "$RESULT"
  exit 1
fi

echo "✅ Draft created successfully!"
echo ""
echo "📧 Draft ID: $DRAFT_ID"
echo "📮 Account: $ACCOUNT ($EMAIL)"
echo "👤 Recipient: $RECIPIENT"
echo ""
echo "🔗 Open draft: https://mail.google.com/#drafts/$DRAFT_ID"
echo ""
echo "Or login to $EMAIL and check your Drafts folder"
