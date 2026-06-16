# BUILD_PROCESS.md

Architecture, design decisions, and node-level spec for the P05 Claude Code build.

---

## Environment

- Automation platform: n8n
- Output: single importable n8n workflow JSON file (`P05-onboarding-automation-claude-code.json`)
- LLM provider: Groq (free tier), model `llama-3.3-70b-versatile`
- Rate limiting: a 3-second wait node between each Groq call to respect free-tier limits

---

## Credentials

Use these exact credential names so n8n wires them on import:

| Service | Credential Name in n8n |
|---|---|
| Gmail | `Gmail OAuth2 API` |
| Google Sheets | `Google Sheets OAuth2 API` |
| Google Tasks | `Google Tasks OAuth2 API` |
| Groq | `Groq account` |

---

## Google Sheet Structure

Both sheets live in the same Google Sheets file on Google Drive.

### New Hire sheet (trigger / input)

Columns, in order:

| Column | Description |
|---|---|
| First Name | New hire's first name |
| Last Name | New hire's last name |
| Role | Job title |
| Department | Department name |
| Start Date | Employment start date |
| Manager | Manager's full name |
| Manager Email | Manager's email address |
| Contact Email | New hire's email address (destination for the welcome email) |
| Plan Tier | Employment type (Full Time, Part Time, Contract, etc.) |

The Google Sheets trigger fires on each new row added. After a row is fully processed and written to the Status sheet, the matching row is deleted from this sheet.

### Status sheet (output / archive)

Columns, in order:

| Column | Description | Source |
|---|---|---|
| Timestamp | Date/time the workflow processed the record | Workflow-generated (now) |
| First Name | | From New Hire sheet |
| Last Name | | From New Hire sheet |
| Role | | From New Hire sheet |
| Department | | From New Hire sheet |
| Start Date | | From New Hire sheet |
| Manager | Manager's full name | From New Hire sheet |
| Contact Email | New hire's email address | From New Hire sheet |
| Welcome Email Sent | Was the welcome email sent? | Yes / No |
| Manager Email Sent | Was the manager email sent? | Yes / No |
| Tasks Created | Were Google Tasks created? | Yes / No |
| Scheduled Check-In Date | 30-day check-in date | Calculated: Start Date + 30 days |
| Onboarding Status | Current onboarding state | Set to Initiate on first write |
| Plan Tier | Employment type | From New Hire sheet |

---

## LLM Calls (Groq, 4 calls per new hire)

All calls use `llama-3.3-70b-versatile`. A 3-second wait node sits between each call.

### Call 1 - Welcome Message

- **Goal:** 3-5 sentence welcome email body addressed to the new hire
- **Tone:** warm, professional, encouraging
- **Input fields:** First Name, Last Name, Role, Department, Start Date, Manager, Plan Tier

### Call 2 - 30/60/90 Day Plan

- **Goal:** role- and department-specific onboarding plan, each phase 2-3 sentences
- **Required output format:** `30 Days: [text]` / `60 Days: [text]` / `90 Days: [text]` on separate lines; downstream nodes parse this structure
- **Input fields:** same as Call 1

### Call 3 - Action Items

- **Goal:** 4-5 specific, actionable items the manager must complete to support the new hire, derived from the Call 2 output
- **Constraint:** each item references the phase (30, 60, or 90 days) it belongs to
- **Input fields:** First Name, Last Name, Role, Department, Manager, plus the Call 2 output

### Call 4 - 30-Day Agenda

- **Goal:** practical 30-day onboarding agenda for the manager to use as a reference; role-specific, not generic
- **Input fields:** First Name, Last Name, Role, Department, Start Date, Plan Tier, plus the Call 2 output

---

## Emails (Gmail, HTML format)

### Email 1 - New Hire Welcome Email

| Field | Value |
|---|---|
| To | `Contact Email` |
| From | Configured Gmail OAuth2 account |
| Subject | `Welcome to the team, {{First Name}}!` |
| Format | HTML |
| Body | Welcome message (Call 1) plus 30/60/90 Day Plan (Call 2) |

### Email 2 - Manager Notification Email

| Field | Value |
|---|---|
| To | `Manager Email` |
| From | Configured Gmail OAuth2 account |
| Subject | `New Hire Onboarding Plan - {{First Name}} {{Last Name}}` |
| Format | HTML |
| Body | 30-Day Agenda (Call 4) plus Action Items (Call 3) |

---

## Google Tasks

- Task list name: `Proj5 NewHires`
- One task per action item (4 to 5 tasks per new hire)
- Task title format: `[Manager Name] - [Action Item text]`
- Task notes: new hire name, role, and the phase (30/60/90) the item belongs to
- Due dates: 30-day items due Start Date + 30 days, 60-day items due Start Date + 60 days, 90-day items due Start Date + 90 days
- Owner: the manager. The name goes in the title and notes because Google Tasks does not support cross-account assignment natively.

---

## Error Handling

- Strategy: retry on failure
- Retry attempts: 3
- Backoff: exponential (2s, then 4s, then 8s)
- Error notifications: none configured

Retry settings live inside each node's `onError` field: `{ "maxTries": 3, "waitBetweenTries": 2000 }`. n8n doubles the wait on each retry for the exponential backoff.

---

## Workflow Node Sequence (high-level)

```
Google Sheets Trigger (New Row)
  -> Set Node (normalize/map fields)
        -> Groq: Welcome Message
              -> Wait (3s)
                    -> Groq: 30/60/90 Plan
                          -> Wait (3s)
                                -> Groq: Action Items
                                      -> Wait (3s)
                                            -> Groq: 30-Day Agenda
                                                  -> Gmail: Welcome Email to new hire
                                                        -> Gmail: Manager Email
                                                              -> Google Tasks: Create tasks (loop per action item)
                                                                    -> Google Sheets: Append row to Status sheet
                                                                          -> Google Sheets: Delete row from New Hire sheet
```

---

## n8n JSON Structure Notes

- Each node requires a unique `id` (UUID v4), a `name`, a `type`, and `typeVersion`.
- Connections are declared separately in the top-level `connections` object, keyed by source node name.
- Credentials are referenced by name, not ID. Use the exact credential names in the Credentials table above.
- The Wait node type is `n8n-nodes-base.wait`; set `resume: "timeInterval"` with `amount: 3` and `unit: "seconds"`.
- Google Sheets append uses operation `append`; delete row uses operation `delete` on `n8n-nodes-base.googleSheets`.
- Google Tasks create uses `n8n-nodes-base.googleTasks` with `resource: "task"`, `operation: "create"`.
- Groq calls use the `n8n-nodes-base.openAi` node pointed at the Groq endpoint, or the dedicated `@n8n/n8n-nodes-langchain.lmChatGroq` node. Prefer the dedicated node when available.

---

## Key Assumptions and Decisions

- `Scheduled Check-In Date` is calculated by the workflow as Start Date + 30 days, not pre-filled.
- `Onboarding Status` is set to Initiate on the first write to the Status sheet.
- `Welcome Email Sent`, `Manager Email Sent`, and `Tasks Created` are written as Yes on success and No on failure.
- `Timestamp` on the Status sheet is the moment the workflow processes the row.
- The New Hire row is only deleted after every prior step completes successfully.
- Groq free tier drives the 3-second waits between LLM calls and the 3-retry exponential backoff on any node failure.
- Google Tasks does not support assigning tasks to other users natively, so the manager's name is embedded in the task title and notes.
