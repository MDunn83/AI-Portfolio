# P07 Customer Trigger Messaging Pipeline
## Requirements Document

Version 1.0 | June 2026

---

## Goal

Watch a customer database. When a customer hits one of four behavioral triggers, send a personalized, AI-written email that fits that trigger. Write every send (and every suppression) to an activity log.

The four triggers are: a support ticket closed in the last 24 hours, 14 or more days of inactivity, a renewal coming up within 30 days, and a milestone reached. Each trigger gets its own prompt and its own subject line. A 7-day cooldown stops the pipeline from contacting the same customer twice in a short window.

No manual research, no copy-paste. Once the workflow runs, it reads the sheet, decides what to do per customer, and finishes on its own.

---

## Scope

### In scope

- Read all rows from the Customer sheet in Google Sheets.
- Suppress any customer contacted within the last 7 days.
- Categorize each remaining customer against four behavioral triggers, in priority order.
- Generate a personalized email body with an LLM, using a per-category prompt.
- Send the email via Gmail from the operator's account.
- Log every customer to the Activity Log sheet, whether an email went out or not.
- Update the Last Contacted Date for any customer who received an email.

### Out of scope

- Manual editing or curation of the customer list before the run.
- CRM integration.
- Phone, SMS, or direct mail outreach.
- More than one email per customer per run. First matching category wins.
- Multi-user support. Single Google account, single operator.
- Real-time monitoring. The pipeline runs on a trigger, it does not poll continuously.

---

## Functional Requirements

### FR1 -- Trigger and customer read

The workflow reads all rows from the Customer sheet at once. For testing, a Manual Trigger feeds a Google Sheets read node. For production, the Manual Trigger is swapped for a daily Schedule Trigger and nothing else changes. Each row carries the customer fields used by the rest of the pipeline.

### FR2 -- Suppression check

Before any category logic runs, check the Last Contacted Date for the customer. If it is within the last 7 days, suppress the customer: write a `Suppressed` row to the Activity Log (Email Sent = `No`, Message Preview = blank) and stop processing that row. Customers outside the 7-day window continue to categorization.

### FR3 -- Categorization

Evaluate each customer against four categories in priority order. The first match wins, and a customer gets at most one email per run. The categories and their criteria:

| Priority | Category | Criterion |
|---|---|---|
| 1 | Ticket | Support Ticket Closed Date within the last 24 hours |
| 2 | Inactivity | Last Activity Date more than 14 days ago |
| 3 | Renewal | Renewal Date within the next 30 days |
| 4 | Milestone | Milestone Reached? = `Yes` |
| -- | No Action | None of the above |

A customer who matches no category gets a `No Action` row in the Activity Log (Email Sent = `No`, Message Preview = blank) and no email.

### FR4 -- Personalized email generation

For a matched category, an LLM generates the email body from the customer's fields. Each category uses its own prompt:

- **Ticket:** warm follow-up, glad the issue was resolved, invite further questions.
- **Inactivity:** state how many days since last activity, politely encourage a return.
- **Renewal:** state the exact number of days until the auto-renewal date, no action required from the customer.
- **Milestone:** congratulatory, acknowledge the achievement, keep it brief.

The subject line is fixed per category, not generated:

| Category | Subject |
|---|---|
| Ticket | `We're here if you need us, [Customer Name]` |
| Inactivity | `We miss you, [Customer Name]` |
| Renewal | `Your renewal is coming up, [Customer Name]` |
| Milestone | `Congratulations on your milestone, [Customer Name]!` |

### FR5 -- Email send

Send the generated email via Gmail from the operator's account. The recipient address comes from the customer row, pulled dynamically. It is never hardcoded.

### FR6 -- Logging

Append one row to the Activity Log sheet for every customer the pipeline touches, regardless of outcome. The row records the timestamp, customer name, company, trigger type, whether an email was sent, and a preview of the message (first 100 characters of the email body). Suppressed and No Action rows leave the preview blank.

### FR7 -- Last Contacted update

After a customer receives an email, write today's date to that customer's Last Contacted Date in the Customer sheet. This update only runs for customers who actually got an email; it is what feeds the 7-day suppression check on the next run.

---

## Non-Functional Requirements

### NFR1 -- Rate limiting

LLM calls run on the Groq free tier. If multiple rows process in rapid succession, add a 3-second Wait node between LLM calls to stay within Groq free-tier limits.

### NFR2 -- No manual steps after the trigger

Once the workflow runs, it processes every row to completion without operator intervention.

### NFR3 -- No hardcoded credentials or IDs

API keys, sheet IDs, email addresses, and credential IDs come from n8n's credential manager or from placeholders. The exported workflow JSON uses `YOUR_GOOGLE_SHEET_ID` for the sheet ID and never carries a live recipient address.

### NFR4 -- Platform

Runs on n8n. The output is a single importable n8n workflow JSON file.

---

## Acceptance Criteria

1. The workflow reads all customer rows in one pass and processes each row without manual intervention.
2. A customer with a Last Contacted Date within 7 days is suppressed: a `Suppressed` row lands in the Activity Log and no email is sent.
3. Each non-suppressed customer is evaluated against the four categories in priority order, and the first match wins.
4. A matched customer receives exactly one email, with the body generated by the per-category prompt and the fixed subject line for that category.
5. A customer matching no category gets a `No Action` row in the Activity Log and no email.
6. Every customer the pipeline touches produces exactly one Activity Log row with timestamp, customer name, company, trigger type, email-sent flag, and message preview.
7. Suppressed and No Action rows show Email Sent = `No` and a blank message preview.
8. A customer who receives an email has today's date written to Last Contacted Date in the Customer sheet.
9. The exported workflow JSON contains no live credentials, sheet IDs, or recipient email addresses.

---

## Reference

- Project overview and manual-build comparison: `../README.md`
- Architecture, node table, sheet schemas, and prompt detail: `./BUILD_PROCESS.md`
- Build constraints and phases: `./CLAUDE.md`
- Build issues and fixes found during the original build: `./LESSONS_LEARNED.md`
