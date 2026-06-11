# New Job Openings v2 — Project CLAUDE.md

> **Public sync notice:** This file lives under `workflows/**` and is mirrored to the public `MDunn83/AI-Portfolio` repo on every merge to `main`. Treat its contents as public. No sheet IDs, no real email addresses, no credential token values.

Applies to the `new-job-openings` project only. Read the root CLAUDE.md and `reference/n8n_SKILL.md` first — this file adds only project-specific rules.

For workflow topology, node-by-node detail, Google Sheets schemas, API specifics, and bug history, see `BUILD_PROCESS.md`. This file does not duplicate that content.

---

## Project Files

| File | Status | Notes |
|---|---|---|
| `new-job-openings-v2.json` | **Active** | The workflow to modify |
| `archive/new-job-openings.json` | Superseded | v1 — do not modify |
| `archive/PermDB_clean.json` | Superseded | v1 seeder — do not modify |
| `archive/README_v1.md` | Superseded | v1 user-facing README |
| `README.md` | Active | User setup guide |
| `BUILD_PROCESS.md` | Active | Architecture, schemas, APIs, bug history |

---

## Workflow Identity

- **File:** `new-job-openings-v2.json`
- **n8n name:** `New Job Openings - v2`
- **Trigger:** Schedule Trigger at 6:00 AM daily
- **Node count:** 8

Full topology and node detail in `BUILD_PROCESS.md` § Architecture.

---

## Critical Architecture Rules

These rules are easy to violate and hard to debug. They override anything in BUILD_PROCESS.md if the two conflict.

**No HTTP Request nodes.** All API calls happen inside Fetch Filter Dedup using `this.helpers.httpRequest()`. Never add HTTP Request nodes — raw API responses stored in n8n execution data cause OOM at 26 companies.

**Read Jobs DB must remain a dead-end.** It must have no outgoing connections. Its sole purpose is to execute before Fetch Filter Dedup so its rows are available via `$('Read Jobs DB').all()`. Adding an outgoing connection causes row multiplication: N DB rows × 26 companies = N×26 items.

**Fetch Filter Dedup must always return exactly one wrapper item.** The return statement must be:
```javascript
return [{ json: { matched: matched, hasNew: matched.length > 0 } }];
```
Never return an empty array. An empty return stops all downstream execution and the email never sends.

**Prepare Rows Code uses a cross-node reference.** It reads from `$('Fetch Filter Dedup').all()[0].json.matched`, not from `$input`. The node immediately before it (Send Email) outputs Gmail API metadata, not job data.

---

## Post-Import Checklist

- [ ] Read Jobs DB: set Document and Sheet to Jobs DB
- [ ] Append New Jobs: set Document and Sheet to Jobs DB (same sheet)
- [ ] Read Company List: set Document and Sheet to Company List
- [ ] All three Google Sheets nodes: connect `Google Sheets OAuth2 API` credential
- [ ] Send Email: connect `Gmail OAuth2 API` credential
- [ ] Build Email Code: replace `YOUR_EMAIL` with actual recipient address

(Generic n8n post-import checks live in `reference/n8n_SKILL.md` § Post-Import Checklist.)
