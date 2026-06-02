# Project 5: Employee Onboarding Orchestrator

**Mark Dunn | Automation & AI Orchestration Portfolio | May 2026**

---

## What This Does

An n8n workflow that automates the full employee onboarding sequence from a single trigger. When a new hire record is added to a Google Sheet, the workflow fires and orchestrates the following without any manual intervention:

- Generates a personalized welcome email for the new hire
- Generates a 30-60-90 day onboarding plan tailored to their role and department
- Sends the welcome email and onboarding plan to the new hire
- Generates 3-5 manager action items for the first week
- Generates a first-week agenda summary for the manager
- Sends a combined action items and agenda email to the hiring manager
- Creates one Google Task per action item, labeled with the manager's name
- Calculates the 30-day check-in date from the hire's start date
- Logs the full onboarding record to a status tracker in Google Sheets

All AI generation is handled by Groq LLMs (llama-3.3-70b-versatile). All outputs are personalized per hire based on name, role, department, start date, and manager.

---

## Architecture

```
Google Sheets Trigger (new hire row added)
    |
    |-- Basic LLM Chain (Welcome Email Gen)
    |       |
    |       Code Node (Sanitize output)
    |           |
    |           Basic LLM Chain1 (30-60-90 Plan Gen)
    |               |
    |               Code Node (Sanitize + split into day_30 / day_60 / day_90)
    |                   |
    |                   |-- Send a message (Welcome email to new hire)
    |                   |
    |                   |-- Action Item Gen (LLM extracts manager action items)
    |                   |       |
    |                   |       Clean (Sanitize)
    |                   |           |
    |                   |           Code Node (Split on --- delimiter)
    |                   |               |
    |                   |               Merge (action items + agenda)
    |                   |                   |
    |                   |                   |-- Send a message1 (Manager email)
    |                   |                   |
    |                   |                   |-- Split Out --> Create a task --> Limit(1)
    |                   |
    |                   |-- Wait (30s) --> Agenda Gen (LLM generates first-week agenda)
    |                                       |
    |                                       Clean1 (Sanitize)
    |
    |-- Check_In (Code Node -- calculates start date + 30 days)
    |
    Merge1 (synchronization gate -- waits for all branches)
        |
        Append row in sheet (Google Sheets status log)
```

---

## Stack

| Component | Tool |
|---|---|
| Workflow automation | n8n |
| Trigger | Google Sheets (rowAdded event) |
| LLM provider | Groq (llama-3.3-70b-versatile) |
| Welcome email | Gmail |
| Manager email | Gmail |
| Task creation | Google Tasks |
| Status logging | Google Sheets |

---

## Workflow Nodes

| Node | Type | Purpose |
|---|---|---|
| Google Sheets Trigger | Trigger | Fires on new row in New Hires sheet |
| Basic LLM Chain | LangChain chainLlm | Generates personalized welcome email |
| Code in JavaScript | Code | Sanitizes LLM output, strips markdown |
| Basic LLM Chain1 | LangChain chainLlm | Generates 30-60-90 day onboarding plan |
| Code in JavaScript1 | Code | Sanitizes and splits plan into day_30, day_60, day_90 fields |
| Action Item Gen | LangChain chainLlm | Extracts 3-5 manager action items from the plan |
| Wait | Wait | 30-second throttle before Agenda Gen to avoid rate limits |
| Agenda Gen | LangChain chainLlm | Generates first-week agenda summary for manager |
| Clean | Code | Sanitizes Action Item Gen output |
| Clean1 | Code | Sanitizes Agenda Gen output |
| Code in JavaScript3 | Code | Splits action items on --- delimiter into array |
| Merge | Merge | Combines action items and agenda branches (Combine By Position) |
| Send a message | Gmail | Sends welcome email + 30-60-90 plan to new hire |
| Send a message1 | Gmail | Sends action items + agenda to hiring manager |
| Split Out | Split Out | Splits action_items array into individual items |
| Create a task | Google Tasks | Creates one task per action item, prefixed with manager name |
| Limit | Limit | Reduces 5 task outputs to 1 item before Merge1 |
| Check_In | Code | Calculates 30-day check-in date from start date |
| Merge1 | Merge | Synchronization gate -- waits for all branches before logging |
| Append row in sheet | Google Sheets | Logs full onboarding record to status tracker |

---

## Data Sources

**Input sheet (New Hires):** Google Sheet with one row per new hire containing:

| Column | Description |
|---|---|
| First Name | New hire first name |
| Last Name | New hire last name |
| Role | Job title |
| Department | Department name |
| Start Date | Start date (YYYY-MM-DD format) |
| Manager | Manager full name |
| Manager Email | Manager email address |
| Contact Email | New hire email address |
| Plan Tier | Employment type (e.g. Full Time) |

**Output sheet (Status):** Google Sheet log written by the workflow containing:

| Column | Value |
|---|---|
| Timestamp | Workflow execution time |
| First Name | From trigger |
| Last Name | From trigger |
| Role | From trigger |
| Department | From trigger |
| Start Date | From trigger |
| Manager | From trigger |
| Welcome Email Sent | Yes (static -- execution confirms delivery) |
| Manager Email Sent | Yes (static -- execution confirms delivery) |
| Tasks Created | Yes (static -- execution confirms delivery) |
| Scheduled Check-In Date | Start date + 30 days |
| Onboarding Status | Initiated |

---

## Setup Instructions

### 1. Prerequisites

- n8n instance (cloud or self-hosted)
- Groq API account (free tier sufficient for testing)
- Google account with access to Gmail, Google Sheets, and Google Tasks
- OAuth2 credentials configured in n8n for: Google Sheets Trigger, Gmail, Google Tasks

### 2. Google Sheets Setup

Create a Google Sheet with two tabs:

- **NewHires** -- input sheet with the columns listed above
- **Status** -- output sheet with the log columns listed above

### 3. Google Tasks Setup

Create a task list in Google Tasks to receive onboarding action items. Note the Task List ID -- you will need it to configure the Create a task node.

### 4. Import the Workflow

1. Download `Proj5_Clean.json`
2. In n8n, go to Workflows, click Import, and select the file
3. After import, update the following placeholders:

| Placeholder | Replace With |
|---|---|
| `YOUR_GOOGLE_SHEET_ID` | Your Google Sheet ID (from the URL) |
| `YOUR_GOOGLE_SHEET_URL` | Your Google Sheet URL |
| `YOUR_GOOGLE_TASKS_LIST_ID` | Your Google Tasks list ID |
| `YOUR_CREDENTIAL_ID` | Your n8n credential IDs for each service |

### 5. Post-Import Checklist

After importing, verify the following before running:

- All credential references are pointing to your configured credentials
- Google Sheets Trigger is set to the correct sheet and tab
- Append row in sheet is pointing to the Status tab
- Create a task is pointing to the correct task list
- Both Gmail nodes have sendTo fields set to dynamic expressions (not hardcoded emails)
- Merge node (first) is set to Combine By Position with Include Any Unpaired Items enabled
- Merge1 node is set to Combine By Position with 4 inputs

---

## Key Design Decisions

**LLM output sanitization:** Every LLM node is followed by a Code node that strips markdown headers, bold markers, bullet points, numbered lists, reasoning traces (`<think>` tags), and literal `\n` strings before passing output downstream. Treating LLM output as dirty by default prevents formatting issues in Gmail and Google Sheets.

**Action item delimiter:** The Action Item Gen prompt instructs the model to separate items with `---` on its own line rather than newlines. Models follow delimiter instructions more reliably than newline instructions. The downstream Code node splits on `---` to produce a clean array.

**Limit node after Google Tasks:** The Create a task node outputs one item per task (5 items for 5 action items). A Limit node set to 1 reduces this to a single item before Merge1, preventing the final logging node from writing 5 rows per hire.

**Static confirmation fields:** Welcome Email Sent, Manager Email Sent, and Tasks Created are logged as static `Yes` values. If any upstream node fails, n8n halts execution and the log row is never written. Reaching the Append Row node is itself confirmation that all branches completed successfully.

**30-day check-in date:** Rather than creating a calendar event (which requires additional OAuth scope and a secondary Google account for safe testing), the workflow calculates the check-in date as start date plus 30 days and logs it to the status tracker. A calendar integration is documented as a V2 addition.

**Wait node:** A 30-second wait is inserted before the Agenda Gen branch to throttle parallel LLM calls and avoid Groq free-tier rate limit errors when processing multiple hires in a single run.

---

## Build Approach

This workflow was built manually in n8n with Claude as the architecture and debugging partner, then benchmarked against a Claude Code rebuild. This is the third project in a portfolio of automation and AI orchestration builds.

**Build time:** Manual build -- approximately 6 hours including debugging

**Documented patterns from this build:**
- Limit node as a cleaner alternative to Aggregate for reducing multi-item branches to a single synchronization item
- `---` delimiter as a more reliable separator than newlines for LLM-generated lists
- Static confirmation fields as a valid logging pattern when workflow execution itself is the audit trail

---

## Known Limitations and V2 Ideas

- **Google Tasks has no assignment feature.** Tasks are prefixed with the manager name as a workaround. A production implementation would use Asana or Jira where tasks can be formally assigned via API.
- **Calendar integration deferred.** The 30-day check-in date is logged to Sheets rather than creating a calendar event. A Google Calendar node or Calendly integration would be the V2 addition.
- **Single-run processing.** The workflow processes hires one at a time as rows are added. A batch trigger reading all rows at once would be more efficient for bulk onboarding events.
- **No error handling.** V1 has no retry logic or error notification. A V2 addition would include an error workflow that sends an alert if any node fails mid-execution.

---

## License

Personal portfolio project. Not intended for production use without additional error handling, security review, and credential management.
