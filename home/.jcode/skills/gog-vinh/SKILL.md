---
name: gog-vinh
description: Low-token Google Workspace helper for Vinh's personal/work/study accounts. Use for Gmail, Calendar, Drive, Contacts, Docs, Sheets. Prefer running scripts directly. Do not inspect scripts unless a command fails or you need to modify/create a helper.
---

# gog-vinh

## Rule: command first, read scripts only on failure

Run helpers from this directory:

```bash
cd ~/.claude/skills/gog-vinh
GOG_KEYRING_PASSWORD="$YOUR_PASSWORD" scripts/<helper>.sh ...
```

Do **not** read script source for normal mail/calendar tasks. Use `--help` or inspect source only if a command fails, syntax is unknown, or a new helper is needed.

## Accounts

- `personal` = `buiquangvinh720@gmail.com`
- `work` = `vinhbui@physicalrobotics.com`
- `study` = `vinh.buiquangvinh@hcmut.edu.vn`
- `all` = personal + work + study

Vietnamese aliases: `cá nhân` → personal, `trường` → study.
If unclear, ask or use `all` for read-only checks.

## Common commands

### Mail

```bash
scripts/inbox.sh all
scripts/search.sh all 'newer_than:7d meeting OR event OR invitation'
scripts/search.sh study 'from:ctsv newer_than:30d'
scripts/draft-email.sh personal to@example.com 'Subject' 'Body'
```

Never send email directly. Create/show draft first, then ask approval before `scripts/send.sh`.

### Calendar read

```bash
scripts/today.sh all
scripts/tomorrow.sh study
scripts/week.sh personal
scripts/calendar-list.sh study --from='2026-05-22' --to='2026-05-30'
scripts/calendar-search.sh study --summary='Triết học'
scripts/calendar-conflicts.sh work --from='2026-05-22' --to='2026-05-30'
```

### Calendar create/update/delete

For exact times, use RFC3339 directly with `gog` to avoid helper ambiguity:

```bash
gog calendar create primary --account vinh.buiquangvinh@hcmut.edu.vn \
  --summary 'Event title' \
  --from '2026-05-23T13:00:00+07:00' \
  --to   '2026-05-23T15:00:00+07:00' \
  --location 'BK-CS1, B4-402'
```

Helper examples:

```bash
scripts/calendar-add.sh study 'Meeting' '2026-05-23T13:00:00' '2026-05-23T15:00:00' --location='Room'
scripts/calendar-update.sh study EVENT_ID --summary='New title'
scripts/calendar-delete.sh study --id=EVENT_ID -y
```

Ask before destructive deletes. Calendar adds are okay when user explicitly asks to add an event.

## Fallback direct gog

```bash
gog gmail search 'newer_than:7d' --account buiquangvinh720@gmail.com
gog calendar list primary --account vinh.buiquangvinh@hcmut.edu.vn --json
gog drive search 'query' --account vinh.buiquangvinh@hcmut.edu.vn
```

## Reauth

If token/auth fails with `invalid_grant`, run:

```bash
scripts/reauth.sh        # all accounts
scripts/reauth.sh study  # one account
```

Remote OAuth flow: step 1 prints URL, open it, copy final localhost callback URL, paste to step 2.

## Helper development, only when needed

- Keep helpers small, composable, `set -euo pipefail`, source `_accounts.sh`.
- First arg should be account alias: `personal|work|study|all`.
- Output compact sections: `── [account] context ──`.
- Use `--json` + `jq` for parsing.
- Add executable bit and document only one-line usage here.
