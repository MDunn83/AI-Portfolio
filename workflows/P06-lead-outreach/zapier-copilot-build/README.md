# Zapier Copilot Build: Lead Generation & Outreach Automation

A daily lead research, scoring, and outreach workflow that autonomously identifies high-fit companies, researches them with AI, scores them 1-10, and sends personalized cold emails to prospects who score 7+. Built entirely in Zapier with Copilot doing the wiring.

This workflow demonstrates scoring gates, conditional routing, and looping patterns at scale — all with minimal code steps.

---

## What It Does

Every morning at 5 AM, the Zap fires and runs:

1. **Trigger.** Daily schedule (every day at 5:00 AM).
2. **Fetch leads.** Read company rows from a Google Sheet (up to 500 rows, columns A-E: Company, Website, Contact Name, Role, Email).
3. **Parse into arrays.** A Code step converts raw rows into separate arrays for looping.
4. **Loop through companies.** For each company, extract the individual fields (Company, Website, ContactName, Role, Email).
5. **AI scoring.** GPT-4.1 evaluates each company based on:
   - Company size (10-500 employees optimal)
   - Industry (SaaS/tech preferred)
   - Operational complexity (visible process automation needs)
   - Prospect role (non-technical ops roles higher fit)
   - Return: JSON with summary (2-3 sentences), score (1-10), rationale (1 sentence).
6. **Filter by score.** Only companies scoring 7 or higher proceed.
7. **Send personalized email.** Gmail sends a templated cold email with company-specific details.
8. **Log results.** Google Sheets upsert appends the score, summary, and company name to a Summary sheet for tracking.

---

## Architecture

```
Daily Schedule (5 AM)
  → Fetch rows (A:E, 500 rows max, first row = 2)
      → Parse arrays (Company, Website, ContactName, Role, Email)
          → Loop through each company
              → AI score (GPT-4.1 JSON output: summary, score, rationale)
                  → Filter score > 7
                      → Send personalized email via Gmail
                      → Upsert to Summary sheet (lookup by Company name)
```

**Cost model:** Zapier prices by monthly task tiers. For 5 companies (current sheet size): ~18-20 tasks per daily run, ~600 tasks/month — fits inside the Starter plan. Task count scales linearly with row count; see `REQUIREMENTS.md` for the scaling table.

---

## Data Flow

### Input: Companies Sheet

| Column | Header | Example |
|---|---|---|
| A | Company | "Acme Corp" |
| B | Website | "https://acme.com" |
| C | Contact Name | "Alice Smith" |
| D | Role | "Head of Operations" |
| E | Email | "alice@acme.com" |

Up to 500 rows, starting from row 2 (row 1 = headers).

### AI Scoring JSON

The AI step returns:

```json
{
  "summary": "Acme Corp is a 200-person SaaS startup with visible workflow complexity in their HR and ops teams. Strong automation potential.",
  "score": 8,
  "rationale": "Tech + ops focus + 200-person size + non-technical roles = high fit"
}
```

The score is the gate: only score > 7 sends email.

### Output: Summary Sheet

| Column | Header | Content |
|---|---|---|
| A | Company | From loop |
| B | (empty) | Reserved for notes |
| C | Summary | AI summary text |
| D | Score | Integer 1-10 |
| E | (empty) | Reserved for email response status |

The lookup is by Company name, so repeat companies update the same row rather than duplicating.

---

## Scoring Rubric (Embedded in AI Prompt)

The AI evaluator uses this logic:

**High score (7-10):** SaaS/tech company, 10-500 employees, visible operational complexity, non-technical ops roles (Head of Operations, VP of People, etc.).

**Mid score (4-6):** Relevant industry or size but unclear automation need, or marginal fit on one or more dimensions.

**Low score (1-3):** Large enterprise (likely has dedicated automation teams), non-tech industry without clear workflow pain, or no web presence.

The prompt is tuned to avoid false positives (scoring companies that don't actually need automation) and to prioritize operational roles over technical ones.

---

## Personalization Strategy

The email template uses loop variables to customize for each prospect:

```
Hi {{ContactName}},

I came across {{Company}} and was impressed by what you're building. 
Based on your {{Role}} role, I thought you might find value in exploring 
workflow automation for your operations. My background is in helping 
{{Role}}-focused teams eliminate manual processes and scale without 
adding headcount. Would you be open to a brief 20-minute conversation 
to explore if there's a fit?

Best,
Mark
```

Three data points personalize each email: company name, contact name, and role. The role is referenced twice to signal domain expertise.

---

## Setup

### Prerequisites

- Zapier account (any paid plan supporting multi-step, looping, and AI steps)
- Google account with Sheets and Gmail
- Two Google Sheets:
  - **Companies sheet** with A:E headers (Company, Website, Contact Name, Role, Email)
  - **Summary sheet** with A:E headers (Company, Notes, Summary, Score, Response Status)
- Company lead data (20-100 rows is a good starting point)

### Step 1: Import the Zap

Use Zapier's import feature on `P06-lead-generation-zapier-copilot.json`.

### Step 2: Connect credentials

After import, Zapier will prompt you to connect:
- Google Sheets (used for fetch and upsert)
- Gmail (used for sending emails)
- OpenAI (Zapier's native integration)

### Step 3: Replace placeholders

Open each step and replace:
- `YOUR_LEADS_SHEET_ID` → your Companies sheet ID
- `YOUR_SUMMARY_SHEET_ID` → your Summary sheet ID

Also update:
- **Email From:** your Gmail address
- **Email To:** leave as `{{368770524__Email}}` (loop variable) to send to prospects

### Step 4: Configure the schedule

The trigger is set to 5 AM daily. Adjust the time and days if needed (weekends enabled by default).

### Step 5: Test and publish

Run a test with 5-10 rows in your Companies sheet. Watch the Zap history to verify:
- Rows fetch correctly
- AI scores are returned as JSON
- Filter passes/fails correctly (some companies score <7)
- Emails send to high-scoring prospects
- Summary sheet updates

Once verified, publish the Zap.

---

## Failure Modes & Mitigations

| Failure Mode | Cause | Mitigation |
|---|---|---|
| AI returns non-JSON | Malformed company data or prompt overflow | Add JSON validation in the Code step before filter |
| Email bounces | Invalid email address in source data | Validate email format in the parse Code step |
| Upsert creates duplicates | Company names don't match exactly (case, spacing) | Normalize Company names in the parse Code step (lowercase, trim) |
| Schedule doesn't fire | Time zone mismatch | Check Zapier account time zone in settings |
| Too many tasks / cost overrun | Loop size > 100 companies per day | Split the Zap into two runs or reduce company list size |

---

## Differences from n8n Version (If Any)

This Zapier version is the primary implementation. There is no n8n port yet.

Key Zapier-specific tradeoffs:
- **Single AI model per loop:** GPT-4.1 does all scoring. An n8n version could parallelize multiple prompts.
- **Sequential AI calls:** Each company is scored one at a time. Zapier's task cost makes parallel less economical.
- **Upsert by lookup:** Zapier's lookup + write pattern avoids duplicates naturally; no merge logic needed.

---

## File Structure

```
zapier-copilot-build/
├── P06-lead-generation-zapier-copilot.json  # Zap export, credentials scrubbed
├── README.md                                 # This file
└── REQUIREMENTS.md                           # Detailed spec (if present)
```

---

## Built With

- [Zapier](https://zapier.com) — workflow automation, looping, AI steps
- GPT-4.1 (via Zapier's OpenAI integration) — company scoring
- Google Sheets — companies and summary data
- Gmail — outreach email delivery
