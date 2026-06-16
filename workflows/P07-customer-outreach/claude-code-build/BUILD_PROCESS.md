# BUILD_PROCESS.md

Architecture, design decisions, and node-level spec for the P07 Claude Code build.

For the issues and fixes found while building this workflow, see `LESSONS_LEARNED.md`. This file does not repeat them.

---

## Environment

- Automation platform: n8n
- Output: a single importable n8n workflow JSON file
- LLM provider: Groq, free tier
- Model: `llama-3.3-70b-versatile`

---

## Credentials

Use these exact credential names so n8n wires them automatically on import:

| Service | Credential Name in n8n |
|---|---|
| Gmail | `Gmail OAuth2 API` |
| Google Sheets | `Google Sheets OAuth2 API` |
| Groq | `Groq account` |

---

## Google Sheet Structure

Both sheets live in the same Google Spreadsheet, on separate tabs.

### Customer sheet (trigger and update source)

| Column | Notes |
|---|---|
| Customer Name | |
| Company | |
| Plan Tier | |
| Last Activity Date | Used for the inactivity check (14-day threshold) |
| Renewal Date | Used for the renewal check (30-day window) |
| Last Contacted Date | Used for the suppression check (7-day window); updated at the end of a run |
| Milestone Reached? | Values: `Yes`, or blank/other |
| Support Ticket Closed Date | Used for the ticket check (24-hour threshold) |
| Email | Recipient address for the Gmail node; always pull dynamically, never hardcode |

### Activity Log sheet

| Column | Notes |
|---|---|
| Timestamp | Use `$now.toISO()` |
| Customer Name | |
| Company | |
| Trigger Type | `Suppressed` / `Ticket` / `Inactivity` / `Renewal` / `Milestone` / `No Action` |
| Email Sent | `Yes` or `No` |
| Message Preview | First 100 characters of the email body; blank for Suppressed and No Action |

---

## Workflow Architecture

### Trigger

- **Testing:** Manual Trigger feeds a Google Sheets `getRows` node, which reads all rows at once. n8n iterates each row on its own through the `runOnceForEachItem` Code nodes.
- **Production:** swap the Manual Trigger for a daily Schedule Trigger. No other node changes.

### Node sequence

1. **Manual Trigger** to **Get Customer Rows** (Google Sheets `getRows` on the customer sheet).
2. **Suppression Check** (Code node, `runOnceForEachItem`): checks whether Last Contacted Date is within the last 7 days.
   - **Yes:** append a `Suppressed` row to the Activity Log (Email Sent = `No`, Message Preview = blank). Stop processing this row.
   - **No:** continue to the category checks.
3. **Category Router** (Code node): evaluates all four category flags in priority order, computes `daysInactive` and `daysUntilRenewal`.
4. **Is Ticket?** to **Is Inactive?** to **Is Renewal?** to **Is Milestone?** (chained IF nodes; the false output of each feeds the next).
5. **No Action branch:** nothing matched, so append a `No Action` row to the Activity Log (Email Sent = `No`, Message Preview = blank).
6. **Groq LLM Chain** (one per active category branch): generates the email body from the customer fields.
7. **Sanitize Text** (Code node, one per branch): collapses mid-sentence line breaks into spaces and preserves paragraph breaks.
8. **Gmail node:** sends the email using the sanitized text.
9. **Append to Activity Log:** Timestamp, Customer Name, Company, Trigger Type, Email Sent = `Yes`, and the first 100 characters of the sanitized body (cross-node reference to the Sanitize Text node).
10. **Update Customer Sheet:** write today's date to the Last Contacted Date column for this row.

Each of the four trigger categories has its own branch with the same shape: LLM Chain, Groq Model sub-node, Sanitize Text, Gmail, Log, and Update Last Contacted.

### Category hierarchy

One email per customer per run. Checks run in this order; the first match wins.

| Priority | Category | Criterion |
|---|---|---|
| 1 | Ticket | Support Ticket Closed Date within the last 24 hours |
| 2 | Inactivity | Last Activity Date more than 14 days ago |
| 3 | Renewal | Renewal Date within the next 30 days |
| 4 | Milestone | Milestone Reached? = `Yes` |
| -- | No Action | None of the above |

### Email subject lines (fixed per category)

| Trigger Type | Subject |
|---|---|
| Ticket | `We're here if you need us, [Customer Name]` |
| Inactivity | `We miss you, [Customer Name]` |
| Renewal | `Your renewal is coming up, [Customer Name]` |
| Milestone | `Congratulations on your milestone, [Customer Name]!` |

### LLM prompt guidance per category

- **Ticket:** warm follow-up; glad the issue was resolved; invite further questions.
- **Inactivity:** state how many days since last activity; politely encourage a return.
- **Renewal:** state the exact number of days until the auto-renewal date; no action required from the customer.
- **Milestone:** congratulatory; acknowledge the achievement; keep it brief.

### Global LLM prompt rule

Every LLM prompt must include this instruction verbatim:

```
Output ONLY the requested content. Begin directly with the first line of output.
Do not include any introductory text, preamble, or closing remarks.
```

---

## Key Architectural Decisions

- **Sanitize Text node.** Always put a Code node between the LLM Chain and Gmail. Prompt-level formatting rules alone do not reliably stop mid-sentence line breaks. The sanitize node collapses single newlines into spaces while keeping paragraph breaks. Sequence: LLM Chain, then Sanitize Text, then Gmail, then Log, then Update.
- **Gmail sequencing.** Gmail fires first, to confirm delivery, then Log, then Update Last Contacted. Log uses cross-node references to pull the email body from the Sanitize Text node, not from Gmail's output, which carries no useful data.
- **LLM context preservation.** After any `chainLlm` node, `$json` is dead. Use `$('NodeName').item.json` cross-node references in every downstream Code node.
- **No Loop Over Items.** n8n iterates rows on its own through `runOnceForEachItem`. A Loop Over Items node adds confusion and is not needed.
- **Suppressed and No Action rows.** Email Sent = `No`, Message Preview = blank string, not null.
- **Last Contacted Date update.** Runs after logging, and only for rows where an email was actually sent (the Ticket, Inactivity, Renewal, and Milestone branches).
- **Date comparisons.** Do all date arithmetic in Code nodes using `Date.now()` and `new Date(value).getTime()`. Do not rely on n8n expression date helpers for threshold logic.
- **Sheet IDs.** Use the placeholder `YOUR_GOOGLE_SHEET_ID` in the exported JSON. Fill it in by hand after import.

---

## Reference

- Requirements, scope, and acceptance criteria: `REQUIREMENTS.md`
- Build constraints and phases: `CLAUDE.md`
- Build issues and fixes: `LESSONS_LEARNED.md`
