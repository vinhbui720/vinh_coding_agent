---
name: gog-vinh
description: Optimized Google Workspace operations for Vinh's three accounts using account aliases (personal, work, study). Use this skill whenever Vinh asks to check email, calendar, drive, contacts, docs, or sheets for any of his three accounts. Includes quick helper scripts under scripts/ for inbox checks, calendar lookups, and email drafting across all accounts.
---

# gog-vinh

Vinh has three Google accounts. Always resolve aliases before calling `gog`:

| Alias    | Email                            |
| -------- | -------------------------------- |
| personal | buiquangvinh720@gmail.com        |
| work     | vinhbui@physicalrobotics.com     |
| study    | vinh.buiquangvinh@hcmut.edu.vn   |

When Vinh says "my work email" → use `work`. "Cá nhân" → `personal`. "Trường" / "study" → `study`.

If Vinh doesn't specify an account, ask which one — or use `all` to run across all three.

## Helper scripts (preferred for common operations)

Located at `scripts/`. All take an account alias (`personal` | `work` | `study` | `all`) as the first arg.

| Script                | Purpose                                    | Example                                          |
| --------------------- | ------------------------------------------ | ------------------------------------------------ |
| **Mail** |  |  |
| `scripts/inbox.sh`    | Unread mail count + previews               | `scripts/inbox.sh all`                           |
| `scripts/search.sh`   | Search Gmail with a query                  | `scripts/search.sh work "from:boss newer_than:3d"` |
| `scripts/draft.sh`    | Create a draft email (low-level)           | `scripts/draft.sh personal to@x.com "Subject" "Body"` |
| `scripts/draft-email.sh` | Create draft + show link (recommended)    | `scripts/draft-email.sh study to@x.com "Subject" "Body"` |
| `scripts/send.sh`     | Send email (ALWAYS show draft first!)      | `scripts/send.sh work to@x.com "Subject" "Body"` |
| **Calendar** |  |  |
| `scripts/today.sh`    | Today's events                             | `scripts/today.sh work`                          |
| `scripts/tomorrow.sh` | Tomorrow's events                          | `scripts/tomorrow.sh work`                       |
| `scripts/week.sh`     | This week's events                         | `scripts/week.sh personal`                       |
| `scripts/calendar-list.sh` | List events (today/week/month/range)    | `scripts/calendar-list.sh study --week`          |
| `scripts/calendar-search.sh` | Search events by criteria              | `scripts/calendar-search.sh study --summary="Meeting"` |
| `scripts/calendar-add.sh` | Create events (single or bulk)           | `scripts/calendar-add.sh study "Meeting" "2026-05-19"` |
| `scripts/calendar-update.sh` | Modify event                           | `scripts/calendar-update.sh work abc123 --summary="New"` |
| `scripts/calendar-delete.sh` | Delete events (single/bulk)            | `scripts/calendar-delete.sh personal --id=xyz789 -y` |
| `scripts/calendar-conflicts.sh` | Find scheduling conflicts            | `scripts/calendar-conflicts.sh study --from="2026-05-18"` |

**Approval rule:** Per Vinh's boundary, ALWAYS show a draft and ask for approval before calling `send.sh`. Use `draft.sh` if unsure.

## Calendar Scripts (Detailed)

### Create Events
```bash
# Single event
calendar-add.sh study "Meeting" "2026-05-19" "2026-05-19" --location="Room 101" --time="10:00"

# With duration
calendar-add.sh personal "Standup" "today" "1h" --rrule=daily --attendees="user1@x.com, user2@y.com"

# Bulk from CSV (summary, from, to, location, attendees, rrule)
calendar-add.sh work --bulk events.csv
```

### List Events
```bash
calendar-list.sh study --today              # Today's events
calendar-list.sh work --week                # This week
calendar-list.sh personal --month           # Next 30 days
calendar-list.sh study --from="2026-05-18" --to="2026-05-25" --format=csv
```

### Search Events
```bash
calendar-search.sh study --summary="Meeting"
calendar-search.sh work --attendee="user@example.com"
calendar-search.sh personal --location="Room 101"
calendar-search.sh study --from="2026-05-18" --to="2026-05-25"
```

### Update Events
```bash
# Get event ID from search/list first
calendar-update.sh study abc123def456 --summary="New Title" --location="Room 202"
calendar-update.sh work xyz789 --from="2026-05-20" --to="2026-05-20"
```

### Delete Events
```bash
calendar-delete.sh personal --id=abc123 -y           # Delete one
calendar-delete.sh work --ids=id1,id2,id3 -y        # Delete multiple
calendar-delete.sh study --summary="Old" -y          # Delete all matching
calendar-delete.sh personal --from="2026-06-01" --all -y  # Delete range
```

### Find Conflicts
```bash
# Check if time slot is available
calendar-conflicts.sh study --check="Team Meeting" --date="2026-05-19" --time="10:00" --duration="1h"

# Scan for all conflicts
calendar-conflicts.sh work --from="2026-05-18" --to="2026-05-25"
```

## Direct gog commands

If a helper doesn't exist for the task, fall back to `gog` directly with the resolved email:

```bash
gog gmail search 'newer_than:7d' --account buiquangvinh720@gmail.com
gog calendar list primary --account vinhbui@physicalrobotics.com --json
gog drive search "query" --account vinh.buiquangvinh@hcmut.edu.vn
```

## Adding new helpers (IMPORTANT — read before doing anything)

**When to create a new script:**
- A task has no existing helper script (e.g., creating calendar events, working with Drive folders, Sheets operations).
- An existing script isn't optimal for the current task (too slow, too verbose, missing options).
- The task will likely be repeated.

**Design rule: modular and composable.** Build small, focused scripts that can call each other. Avoid duplicating logic — extract shared behavior into `_*.sh` helpers and `source` them. This keeps each script short, fast, and easier to optimize later.

**Conventions for new scripts:**

1. **Modularity first** — Single responsibility per script. If you find yourself writing the same logic twice, extract it into a `_helper.sh` file (prefix with `_` to mark as internal) and `source` it.
2. **Compose, don't duplicate** — New scripts should call existing ones when possible. Example: a `daily-brief.sh` could just chain `inbox.sh all` + `today.sh all` + summarize.
3. **Always** start with `set -euo pipefail` and source `_accounts.sh` for alias resolution.
4. **First arg = account alias** (`personal` | `work` | `study` | `all`). Use `iter_accounts "$1"` to loop over accounts.
5. **Compact output** — 1-2 lines per item, prefix sections with `── [label] context ──`.
6. **Use `--json` + `jq`** when parsing structured data; fall back to plain text for display.
7. **Mark mutating actions clearly** — Any script that sends/deletes/modifies external state must include a comment reminding to get Vinh's approval first.
8. **Register the script** — `chmod +x` it and add a row to the helper table above. Keep the table sorted by category (mail → calendar → drive → docs → sheets → contacts).

**Examples of helpers worth creating (do these on first use, not preemptively):**

- ✅ `calendar-add.sh` — create events (single/bulk/recurring)
- ✅ `calendar-list.sh` — list events by time period
- ✅ `calendar-search.sh` — find events by criteria
- ✅ `calendar-update.sh` — modify events
- ✅ `calendar-delete.sh` — delete events (single/bulk/range)
- ✅ `calendar-conflicts.sh` — find scheduling conflicts
- `drive-list.sh <account> [folder-id]` — list Drive files
- `docs-get.sh <account> <doc-id>` — read a Doc
- `sheets-get.sh <account> <sheet-id> <range>` — read sheet data
- `daily-brief.sh` — composite: inbox(all) + today(all), formatted summary

**Optimization tip:** If a script is slow, profile each `gog` call. Often the bottleneck is fetching too many results — tighten `--max` and the search query before adding parallelism.

## Notes

- Set `GOG_KEYRING_PASSWORD` in shell session if running non-interactively (stored in `~/.bashrc` for Vinh's accounts).
- Calendar: `primary` is the default calendar for the account.
- For multi-account commands, the `all` alias loops over personal → work → study.
- **`draft-email.sh` tip:** Use this wrapper script instead of `draft.sh` directly. It provides:
  - Better error handling
  - Automatic Gmail draft link generation (https://mail.google.com/#drafts/<id>)
  - Clear feedback on which account & recipient
  - Recommended for frequent email drafting
