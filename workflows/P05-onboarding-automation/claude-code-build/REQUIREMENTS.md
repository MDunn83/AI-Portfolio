# P05 Employee Onboarding Orchestrator
## Requirements Document

---

## Goal

Add a new hire to a Google Sheet. Get back, automatically:

1. A personalized welcome email and a 30/60/90 day plan sent to the new hire.
2. A first-month agenda and action items sent to the manager.
3. One Google Task per action item, owned by the manager.
4. A status log entry recording what happened.

No manual steps. Once the row lands in the sheet, the workflow runs the whole sequence and then removes the row it processed.

---

## Scope

### In scope

- Trigger on a new row added to the New Hire sheet in Google Sheets.
- Read the new hire fields from the trigger row.
- LLM generation of onboarding content (welcome message, 30/60/90 day plan, action items, 30-day agenda) on Groq's free tier.
- HTML welcome email to the new hire via Gmail.
- HTML notification email to the manager via Gmail.
- One Google Task per action item, with due dates derived from the start date.
- A row appended to the Status sheet for each processed hire.
- Deletion of the processed row from the New Hire sheet after the Status row is written.

### Out of scope

- Manual editing or approval of generated content before it sends.
- HRIS or payroll system integration.
- Cross-account task assignment (Google Tasks does not support it natively; the manager's name is embedded in the task instead).
- Error notifications or alerting.
- Multi-account support. Single Google account, single operator.

---

## Functional Requirements

### FR1 - Trigger

The workflow fires when a new row is added to the New Hire sheet. The trigger carries all new hire fields: First Name, Last Name, Role, Department, Start Date, Manager, Manager Email, Contact Email, and Plan Tier.

### FR2 - Welcome message generation

Use the Groq LLM to write a 3 to 5 sentence welcome email body for the new hire. Tone is warm, professional, and encouraging.

### FR3 - 30/60/90 day plan generation

Use the Groq LLM to write a 30/60/90 day onboarding plan tailored to the hire's role and department. Each phase (30, 60, and 90 days) is 2 to 3 sentences.

### FR4 - Action item generation

Use the Groq LLM to derive 4 to 5 action items from the 30/60/90 day plan, all owned by the manager. Each item references the phase it belongs to (30, 60, or 90 days) and is specific and actionable.

### FR5 - 30-day agenda generation

Use the Groq LLM to write a 30-day onboarding agenda the manager can use to guide the new hire through the first month. Practical and role-specific.

### FR6 - New hire welcome email

Send an HTML email to the address in Contact Email. Subject references the new hire's first name. The body includes the welcome message (FR2) and the 30/60/90 day plan (FR3). Send via Gmail from the operator's account.

### FR7 - Manager notification email

Send an HTML email to the address in Manager Email. Subject references the new hire's full name. The body includes the 30-day agenda (FR5) and the action items (FR4). Send via Gmail from the operator's account.

### FR8 - Google Tasks creation

Create one Google Task per action item (4 to 5 per hire) in the task list named `Proj5 NewHires`. The task title pairs the manager's name with the action item text. The notes include the new hire's name, role, and the phase the item belongs to. Due dates come from the start date: 30-day items are due Start Date + 30 days, 60-day items Start Date + 60 days, 90-day items Start Date + 90 days.

### FR9 - Status logging

Append one row to the Status sheet for each processed hire. The row records a processing timestamp, the carried-over hire fields, whether each email sent and whether tasks were created (Yes or No), the calculated 30-day check-in date (Start Date + 30 days), an onboarding status set to Initiate, and the plan tier.

### FR10 - Input row removal

After the Status row is written, delete the corresponding row from the New Hire sheet. The row is only deleted after all prior steps complete successfully.

---

## Non-functional Requirements

### NFR1 - No manual steps after trigger

Once a row lands in the New Hire sheet, the workflow runs to completion without operator intervention.

### NFR2 - Free-tier LLM

All generation runs on Groq's free tier using model `llama-3.3-70b-versatile`. A 3-second wait sits between each Groq call to stay inside the free-tier rate limit.

### NFR3 - Retry on failure

Each node retries up to 3 times on failure with exponential backoff (2s, then 4s, then 8s). No error notifications are configured.

### NFR4 - No hardcoded credentials

Sheet IDs, credential IDs, and email addresses are supplied through n8n's credential manager or set at import. The exported workflow JSON uses placeholders for all IDs.

### NFR5 - Platform

Runs on n8n. The output is a single importable n8n workflow JSON file (`P05-onboarding-automation-claude-code.json`) that imports without modification.

---

## Acceptance Criteria

1. Adding a new row to the New Hire sheet triggers the workflow without manual intervention.
2. The new hire receives an HTML welcome email at the Contact Email address, containing the welcome message and the 30/60/90 day plan.
3. The manager receives an HTML email at the Manager Email address, containing the 30-day agenda and the action items.
4. Each processed hire produces 4 to 5 Google Tasks in the `Proj5 NewHires` list, each titled with the manager's name and action item, with due dates matching the phase (Start Date + 30, 60, or 90 days).
5. Each processed hire produces one new row in the Status sheet with a timestamp, the carried-over fields, the Yes/No send flags, the calculated check-in date, an onboarding status of Initiate, and the plan tier.
6. The processed row is removed from the New Hire sheet only after the Status row is written.
7. All Groq calls use `llama-3.3-70b-versatile` with a 3-second wait between calls.
8. The exported workflow JSON contains no live credentials, sheet IDs, or email addresses.

---

## Reference

- Project overview and three-way comparison: `../README.md`
- Build spec and architecture: `./BUILD_PROCESS.md`
- Build rules for Claude Code: `./CLAUDE.md`
- n8n build rules: `n8n_SKILL.md`
