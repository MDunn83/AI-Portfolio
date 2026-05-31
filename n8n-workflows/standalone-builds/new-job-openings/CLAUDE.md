# New Job Openings v2 — Project CLAUDE.md

Applies to the `new-job-openings` project only. Read the root CLAUDE.md and n8n_SKILL.md first — this file adds only project-specific context.

---

## Project Files

| File | Status | Notes |
|---|---|---|
| `new-job-openings-v2.json` | **Active** | The workflow to modify |
| `archive/new-job-openings.json` | Superseded | v1 — do not modify |
| `archive/PermDB_clean.json` | Superseded | v1 seeder — do not modify |
| `archive/README_v1.md` | Superseded | v1 user-facing README |
| `README.md` | Active | User setup guide |
| `BUILD_PROCESS.md` | Active | Architecture and bug history |

---

## Workflow Identity

- **File:** `new-job-openings-v2.json`
- **n8n name:** `New Job Openings - v2`
- **Trigger:** Schedule Trigger at 6:00 AM daily
- **Node count:** 8

## Node List and Connections

```
Schedule Trigger → [Read Jobs DB (dead-end), Read Company List]
Read Company List → Fetch Filter Dedup
Fetch Filter Dedup → Build Email Code
Build Email Code → Send Email
Send Email → Prepare Rows Code
Prepare Rows Code → Append New Jobs
```

Read Jobs DB has NO outgoing connection. It is wired only from Schedule Trigger and executes as a dead-end to populate the cross-node reference cache.

---

## Google Sheets Structure

### Jobs DB (dedup source + append target)
| Column | Notes |
|---|---|
| title | Job title |
| url | Job posting URL — the dedup key |
| company | Display name from Company List |
| updated_at | From the API |
| first_published | From the API |

### Company List (read-only input)
| Column | Notes |
|---|---|
| Company | Display name used in email body |
| Type | `greenhouse` or `ashby` (case-insensitive) |
| Token | Board slug from the company's job board URL |

---

## Filter Configuration

Edit these constants at the top of the **Fetch Filter Dedup** Code node:

```javascript
const TITLE_EXCLUDE = ['Product', 'Social Media', 'Account', 'Sales', 'Marketing'];
const TITLE_KEYWORDS = ['Manager', 'AI'];
const TITLE_MODE = 'any';
const LOCATION_KEYWORDS = ['Remote'];
const LOCATION_MODE = 'any';
```

Exclude terms are always OR-matched and run before include checks.

---

## Critical Architecture Rules

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

---

## APIs Supported

| Type value | API endpoint |
|---|---|
| `greenhouse` | `https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=false` |
| `ashby` | `https://api.ashbyhq.com/posting-api/job-board/{token}` |

Both APIs are public — no authentication required. Ashby requires the `accept: application/json` header.
