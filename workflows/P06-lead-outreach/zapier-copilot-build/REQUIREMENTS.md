# P06 Lead Generation & Outreach — Requirements & Spec

## Overview

A daily automation that reads a list of companies from Google Sheets, scores each one (1-10) for fit with AI workflow automation consulting, and sends personalized outreach emails to high-scoring prospects (7+).

The workflow is a loop + filter + conditional send pattern: read data, loop through each company, invoke AI to score, filter by threshold, send email if threshold met, log results.

---

## Phase 1: MVP (Complete)

### Phase 1 Deliverables

1. **Daily trigger.** Schedule fires every day at 5:00 AM.
2. **Fetch companies.** Read up to 500 rows from a Google Sheet (columns A-E: Company, Website, Contact Name, Role, Email).
3. **Parse data.** Convert raw rows into five separate arrays so each field can be looped independently.
4. **Loop through companies.** Iterate through the company list with all five fields available in each iteration.
5. **Score with AI.** GPT-4.1 evaluates each company and returns JSON: `{summary, score, rationale}`.
6. **Filter by score.** Only companies scoring > 7 proceed to email.
7. **Send personalized email.** Gmail sends a templated message with three personalization points: company name, contact name, role.
8. **Log to Google Sheets.** Upsert the company name, summary, and score to a Summary sheet (lookup by Company name to avoid duplicates).

### Phase 1 Constraints

- Loop size capped at 500 rows per run (Google Sheets `get_many_rows` default).
- AI scoring is sequential, one company per call (no parallelization).
- Email personalization uses loop variables only; no external data enrichment.
- Upsert uses Company name as the key; exact case/spacing match required.

---

## Phase 2: Extensions (Not Yet Implemented)

Phase 2 enhancements would add:

1. **Company normalization.** Lowercase + trim company names before upsert lookup to handle case/spacing variance.
2. **Email validation.** Filter out rows where email doesn't match `^[^\s@]+@[^\s@]+\.[^\s@]+$` pattern before looping.
3. **Retry logic.** If AI returns non-JSON, retry once with a fallback prompt before skipping the company.
4. **Batch scoring.** Sub-Zap or Zapier's native batch integration to score multiple companies in parallel.
5. **Deduplication.** Check if a company already exists in Summary sheet before sending email (avoid duplicate outreach).
6. **Response tracking.** Add a "Last Emailed" timestamp to Summary sheet; skip companies emailed in the last 30 days.

---

## Scoring Rubric

The AI evaluator uses this schema and decision tree:

### Input to Scorer

```
Company: {{company_name}}
Website: {{website_url}}
Role: {{prospect_role}}
```

### Output Schema (JSON)

```json
{
  "summary": "string (2-3 sentences describing the company, focusing on operational complexity and automation potential)",
  "score": "integer (1-10)",
  "rationale": "string (one sentence explaining the score choice)"
}
```

### Scoring Logic

| Score Range | Criteria | Example |
|---|---|---|
| **9-10** | SaaS/tech, 50-300 employees, visible ops complexity, non-technical role (Ops, People, Finance leadership), web presence strong | "HubSpot hiring team" → 10 |
| **7-8** | SaaS or adjacent, 20-500 employees, operational role, some indication of growth/scaling pain | "Zapier Finance Manager" → 8 |
| **5-6** | Relevant industry but marginal fit: size at edges (10 or 500+), role ambiguous, web presence weak, or limited ops complexity signals | "Fortune 500 non-tech company" → 3 |
| **3-4** | Non-tech or large enterprise (likely has dedicated teams), ops role but in mature org, no scaling pain visible | "University admin" → 4 |
| **1-2** | No web presence, consumer/entertainment, micro-cap, role not operations-adjacent, no work automation signals | "Personal blog" → 1 |

### Scoring Examples

- **Alice Smith, Head of Operations at Acme Corp (SaaS, 200 people):** Score 8. Company size + role + ops focus + tech = high fit.
- **Bob Johnson, VP People at TechStartup (50-person SaaS):** Score 9. VP-level + people/HR + small/scaling = perfect fit.
- **Carol Lee, Finance Manager at Legacy Corp (10,000-person enterprise):** Score 4. Large enterprise likely has internal teams; lower urgency.
- **Dave Chen, CTO at Acme Corp:** Score 6. CTO role is technical, not operational; less likely to sponsor workflow automation.

### Key Distinctions

- **Size matters:** 10-500 employees is the sweet spot. <10 = too early, >500 = too late (internal teams).
- **Role is critical:** Non-technical ops roles (Head of Ops, VP People, Finance, Customer Success Ops) are higher fit than technical roles (CTO, VP Engineering).
- **Industry signal:** SaaS > adjacent B2B > enterprise > consumer. 
- **Pain signal:** Mention of "scaling", "growth", "hiring", "process" in website or role title = +1 point.

---

## Data Schemas

### Input: Companies Sheet (Google Sheets)

**Sheet name:** Companies (or any name, configured in Zap trigger)

**Location:** Columns A-E, starting from row 2 (row 1 = headers)

| Col | Header | Type | Required | Example | Notes |
|---|---|---|---|---|---|
| A | Company | String | Yes | "Acme Corp" | Used in email greeting and upsert lookup |
| B | Website | String | Yes | "https://acme.com" | Passed to AI scorer for research |
| C | Contact Name | String | Yes | "Alice Smith" | Personalization in email |
| D | Role | String | Yes | "Head of Operations" | Personalization in email + scoring |
| E | Email | String | Yes | "alice@acme.com" | Email recipient |

**Row count:** 1-500 per run. Larger lists should be split or run on longer schedules to manage task costs.

**Assumptions:** Headers are in row 1 and won't change. No blank rows in the middle of the list.

---

### Output: Summary Sheet (Google Sheets)

**Sheet name:** Summary (or any name, configured in upsert step)

**Purpose:** Running log of all companies scored, whether emailed or not.

| Col | Header | Type | Populated By | Example | Notes |
|---|---|---|---|---|---|
| A | Company | String | Code step | "Acme Corp" | Lookup key for upsert |
| B | Notes | String | Manual | "CTO is technical, better target is COO" | Human review notes |
| C | Summary | String | AI step | "Acme Corp is a 200-person SaaS..." | AI-generated description |
| D | Score | Integer (1-10) | AI step | 8 | Determines if email sent |
| E | Response Status | String | Manual | "REPLIED", "BOUNCED", "NO_REPLY" | Tracking status |

**Upsert logic:** Lookup by Company name (A). If found, update C+D. If not found, add a new row.

---

## Loop Implementation

The loop iterates through five parallel arrays:

```javascript
// Input: raw_rows (array of arrays from Google Sheets)
const companies = [];
const websites = [];
const contactNames = [];
const roles = [];
const emails = [];

rawRows.forEach(row => {
  if (Array.isArray(row) && row.length >= 5) {
    companies.push(row[0] || '');
    websites.push(row[1] || '');
    contactNames.push(row[2] || '');
    roles.push(row[3] || '');
    emails.push(row[4] || '');
  }
});

return { companies, websites, contactNames, roles, emails };
```

The Looping by Zapier step then iterates across all five arrays in lockstep:

```
Loop iteration 1: Company[0], Website[0], ContactName[0], Role[0], Email[0]
Loop iteration 2: Company[1], Website[1], ContactName[1], Role[1], Email[1]
...
```

Each loop variable is available as `{{variable}}` in downstream steps.

---

## AI Scoring Prompt

Sent to GPT-4.1, no few-shot examples (model is capable enough):

```
You are an AI automation consultant evaluating companies for fit. 
Analyze the company data provided and return ONLY valid JSON with no markdown formatting or extra text.

Company: {{company}}
Website: {{website}}
Role: {{role}}

Based on this information, create a JSON object with:
- summary: 2-3 sentence description focusing on operational complexity and automation potential
- score: integer 1-10 where 10 = perfect fit for AI workflow automation consulting. 
  High score (7-10): SaaS/tech, 10-500 employees, visible operational complexity, non-technical ops roles. 
  Mid score (4-6): relevant industry but unclear need or wrong size. 
  Low score (1-3): large enterprise, non-tech, or no web presence.
- rationale: one sentence explaining the score

Return ONLY the JSON object, no other text.
```

**Model:** GPT-4.1 (specified in Zap)

**Parsing:** Expects valid JSON. If parse fails, the filter step should handle gracefully (skip the company rather than error).

---

## Email Template

**From:** YOUR_EMAIL_FROM (configured in setup step 3)

**To:** {{Email}} (loop variable, dynamic per iteration)

**Subject:** `I noticed {{Company}} - quick thought on workflow automation`

**Body (plain text):**

```
Hi {{ContactName}},

I came across {{Company}} and was impressed by what you're building. 
Based on your {{Role}} role, I thought you might find value in exploring 
workflow automation for your operations. My background is in helping 
{{Role}}-focused teams eliminate manual processes and scale without 
adding headcount.

Would you be open to a brief 20-minute conversation to explore if there's a fit?

Best,
Mark
```

**Personalization points:** Company name (1), Contact name (1), Role (2).

**Tone:** Professional but conversational. Opens with praise (lower spam filter risk). Frames automation as scaling enabler, not job threat.

---

## Filter: Score > 7

Applied after AI scoring step:

```
Condition: {{score}} > 7
Action: Continue (send email)
Else: Skip (don't email, but still log to Summary sheet)
```

**Rationale:** Score 1-10 scale; 7 = "moderate-to-high fit". Threshold ensures only companies with real automation need get contacted, reducing bounce and improving response rate.

**False positive risk:** If AI overscores, some unfit companies get emailed. Mitigate with Phase 2 deduplication (skip if emailed in last 30 days).

---

## Task Cost Estimation

Zapier prices by monthly task tiers, not per-task. Plans (as of 2026): Free 100 tasks, Starter ~$30/mo for 750, Professional ~$73/mo for 2,000.

**Per-run cost breakdown** (5 companies, current sheet size):

- Trigger: 1
- Fetch 5 rows: 1
- Parse arrays: 1
- Loop × 5:
  - AI score: 5
  - Filter: 5
  - Email (only score > 7, typically 2-3): 2-3
  - Upsert: 5
- **Total: ~18-20 tasks per run, ~540-600 tasks/month**

Fits inside Starter plan with headroom. Adds $0 marginal cost if already on Professional for other Zaps.

**Scaling thresholds:**

| Companies/day | Tasks/day | Tasks/month | Plan needed |
|---|---|---|---|
| 5 (current) | ~20 | ~600 | Starter |
| 25 | ~95 | ~2,850 | Professional |
| 100 | ~370 | ~11,100 | Team |
| 500 (max config) | ~1,830 | ~55,000 | Company |

The Zap's `row_count: 500` and `iteration_limit: 500` are upper bounds, not expected usage. Scale the Companies sheet deliberately — task consumption grows linearly with row count.

---

## Edge Cases & Recovery

| Scenario | Behavior | Recovery |
|---|---|---|
| Email bounces | Zap doesn't catch it; Gmail sends and logs as sent | Manual cleanup: check Gmail sent folder and update Response Status in Summary sheet |
| Duplicate company name | Upsert updates same row (company name is key) | Accept as feature; Summary sheet shows latest score, not history |
| AI returns non-JSON | Filter fails, email doesn't send | Log as ERROR in Summary sheet; Phase 2 adds retry logic |
| Empty row in Companies sheet | Parse Code step filters out (length < 5) | No email, no log entry |
| Company name mismatch on re-run | Treated as new company, creates duplicate row | Phase 2 adds normalization (lowercase, trim) |

---

## Testing Checklist

Before publishing to production:

- [ ] Fetch step returns 5-10 test companies correctly
- [ ] Parse step creates 5 arrays of equal length
- [ ] Loop fires 5+ times without error
- [ ] AI score returns valid JSON for all 5 companies
- [ ] Filter correctly passes/fails based on score (some should be <7)
- [ ] Email sends only to high-scoring companies
- [ ] Summary sheet upserts create new rows for new companies
- [ ] Summary sheet updates existing row if company name matches
- [ ] Email includes correct personalization (check a few Zap history entries)

---

## Future Enhancements

- **Lead enrichment:** Fetch LinkedIn/Crunchbase data before scoring
- **Batch scoring:** Sub-Zap architecture to score multiple companies in parallel
- **Multi-model:** Use different models for different industries (legal firms → contract AI, etc.)
- **Reputation scoring:** Pull NPS/Glassdoor sentiment and factor into fit
- **Email sequencing:** Sub-Zap to send follow-up emails after N days if no reply
- **Conversion tracking:** Webhook to track which prospect replies (requires email integration)

---

## Reference

- Build: `P06-lead-generation-zapier-copilot.json`
- Zap ID: 368769852
- Created: 2026-06-16
- Last updated: 2026-06-16
