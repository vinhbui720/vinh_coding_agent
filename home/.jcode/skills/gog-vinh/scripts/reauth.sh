#!/usr/bin/env bash
# Re-authenticate all (or one) gog account(s) using the remote/manual OAuth flow.
#
# PROCESS (recorded 2026-05-22):
#   1. gog auth add <email> --remote --step 1  → prints an auth_url
#   2. Open that URL in a browser, log in as the correct Google account, approve scopes
#   3. Browser redirects to http://127.0.0.1:<port>/oauth2/callback?code=...&state=...
#      (page shows "connection refused" — that is normal; copy the URL from the address bar)
#   4. gog auth add <email> --remote --step 2 --auth-url "<callback-url>"
#      → prints "email  services  client" → done
#
# SETUP FACTS (stored here for future agents):
#   - Binary  : gogcli v0.18.0  ~/.local/bin/gog  (openclaw/gogcli linux_amd64)
#   - Credentials: ~/.config/gogcli/credentials.json
#       client_id     : 380126086939-tbhucrtuatp678mbefe5guksbd6s8ki0.apps.googleusercontent.com
#       project       : omega-moonlight-495810-j2  (Vinh's Google Cloud project on vinhpi)
#       client_secret : <redacted, see ~/.config/gogcli/credentials.json>
#   - Keyring : file backend, password stored in GOG_KEYRING_PASSWORD (set in ~/.bashrc or shell env)
#   - Tokens  : ~/.config/gogcli/keyring/  (PBKDF2-encrypted, password above)
#   - Tokens also synced to vinhpi:/home/vinhpi/.config/gogcli/keyring/ after auth
#
# ACCOUNTS:
#   personal  buiquangvinh720@gmail.com
#   work      vinhbui@physicalrobotics.com        (Google Workspace: physicalrobotics.com)
#   study     vinh.buiquangvinh@hcmut.edu.vn      (Google Workspace: hcmut.edu.vn)
#
# SERVICES authed: gmail,calendar,drive,contacts,tasks,sheets
#
# EXPIRY: refresh_tokens don't expire unless revoked. Access tokens (~1h) are
#   auto-refreshed by gog. Re-run this script only if gog returns "invalid_grant".
#
# HOW TO USE:
#   ./reauth.sh              # re-auth all 3 accounts interactively
#   ./reauth.sh personal     # re-auth one account
#   STEP1_ONLY=1 ./reauth.sh # just print URLs, exchange codes later manually
#
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/_accounts.sh"

if [ -z "${GOG_KEYRING_PASSWORD:-}" ]; then
  echo "❌ Error: GOG_KEYRING_PASSWORD not set"
  echo "Set it in your shell or ~/.bashrc before running this script."
  exit 1
fi
export GOG_KEYRING_PASSWORD
SERVICES="gmail,calendar,drive,contacts,tasks,sheets"
ALIAS="${1:-all}"

# ── helpers ──────────────────────────────────────────────────────────────────

step1() {
  local email="$1"
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "  STEP 1 — Open this URL in browser, log in as: $email"
  echo "╚══════════════════════════════════════════════════════════╝"
  gog auth add "$email" --remote --step 1 --services="$SERVICES" 2>&1 \
    | grep "^auth_url" | sed 's/auth_url\t//'
  echo ""
  echo "  → After approving, the browser shows a 'refused' page."
  echo "    Copy the full URL from the address bar."
  echo ""
}

step2() {
  local email="$1"
  echo -n "  Paste callback URL for $email: "
  read -r callback_url
  gog auth add "$email" --remote --step 2 \
    --auth-url "$callback_url" \
    --services="$SERVICES" 2>&1
}

# ── main ─────────────────────────────────────────────────────────────────────

ACCOUNTS=()
for email in $(iter_accounts "$ALIAS"); do
  ACCOUNTS+=("$email")
done

echo "Re-authenticating: ${ACCOUNTS[*]}"
echo "Keyring password : $GOG_KEYRING_PASSWORD"
echo ""

for email in "${ACCOUNTS[@]}"; do
  step1 "$email"
  if [[ "${STEP1_ONLY:-0}" != "1" ]]; then
    # Try to open browser automatically
    xdg-open "$(gog auth add "$email" --remote --step 1 --services="$SERVICES" 2>&1 \
      | grep "^auth_url" | sed 's/auth_url\t//')" 2>/dev/null || true
    step2 "$email"
    echo "  ✅ $email authenticated"
    echo ""
  fi
done

echo "Done. Syncing tokens to vinhpi..."
rsync -a ~/.config/gogcli/keyring/ vinhpi:/home/vinhpi/.config/gogcli/keyring/ 2>/dev/null \
  && echo "  ✅ Synced to vinhpi" \
  || echo "  ⚠️  vinhpi sync skipped (not reachable)"

echo ""
echo "Current auth state:"
gog auth list 2>&1
