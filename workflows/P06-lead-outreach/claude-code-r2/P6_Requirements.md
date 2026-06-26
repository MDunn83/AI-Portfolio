# P06 Lead Generation and Enrichment Pipeline
## Requirements Document

Version 1.1 | May 2026

---

## Goal

Add a target company to a Google Sheet. Get back, automatically:

1. A fit score with a one-sentence explanation of why.
2. A personalized cold outreach email sent to the contact -- if the fit score clears the threshold.
3. A log entry in the summary sheet regardless of outcome.

No manual research. No copy-paste. The pipeline runs from a single row added to the sheet.

---

## Scope

### In scope

- Trigger on new row added to the Companies sheet in Google Sheets.
- Website scraping via public HTTP to gather company information.
- Recent news fetch via public RSS to surface recent company activity.
- LLM-based company summarization from scraped content.
- LLM-based fit scoring against the consulting persona defined below.
- Personalized outreach email generation and Gmail send for companies that clear the score threshold.
- Logging all processed companies to a Summary sheet.
- 30-day deduplication to avoid reprocessing recently contacted companies.

### Out of scope

- Manual curation or editing of the Companies list before trigger.
- CRM integration.
- Phone, SMS, or direct mail outreach.
- Calendar booking or meeting scheduling from the pipeline.
- Real-time company monitoring (pipeline is trigger-based, not polling).
- Multi-user support. Single Google account, single operator.

---

## Consulting Value Proposition

AI workflow automation consulting that helps companies deploy internal productivity tools using n8n, Claude, and Google Workspace. The target client is a small to mid-size SaaS or tech company with operational complexity -- a company that would plausibly hire an outside consultant to automate manual internal processes. Large enterprises that build their own automation are not the target.

---

## Functional Requirements

### FR1 -- Trigger

Pipeline fires when a new row is appended to the Companies sheet. The trigger carries all contact fields: Company, Website, Contact Name, Role, and Email.

### FR2 -- Deduplication check

Before processing, check the Summary sheet for a prior log entry for this company. If a log entry exists with a timestamp within the last 30 days, skip the company without processing. Companies last contacted more than 30 days ago are eligible for re-engagement and proceed normally.

### FR3 -- Website research

Fetch the company's website to collect information about what the company does, who it serves, and how it operates. The fetch must work for JavaScript-heavy sites.

### FR4 -- News fetch

Pull recent news about the company from a public source using the company name as the query. No API key required.

### FR5 -- Company summarization

Use an LLM to produce a 2-3 sentence summary of the company from the scraped website and news content. The summary captures what the company does, its size or growth signals if visible, and anything relevant to the fit assessment.

### FR6 -- Fit scoring

Score the company 1-10 for fit against the consulting value proposition. The LLM must return an integer score and a one-sentence rationale as structured output. Scoring guidance:

| Score | Signal |
|---|---|
| 7-10 | SaaS or tech company, 10-500 employees, visible operational complexity (multiple tools, manual processes, rapid growth), non-technical ops roles, uses Google Workspace |
| 4-6 | Relevant industry but automation need is unclear or company size is outside the target range |
| 1-3 | Large enterprise (builds its own automation), non-tech industry, or no web presence |

### FR7 -- Score routing

Companies scoring 7 or above proceed to outreach email generation and sending. Companies scoring below 7 skip outreach and go directly to logging.

### FR8 -- Outreach email

For companies scoring 7 or above, generate a personalized cold outreach email addressed to the contact in the Companies sheet. Email must reference the specific company based on the research. Tone: friendly-professional, plain business voice. No corporate jargon.

Send via Gmail from the operator's account.

### FR9 -- Logging

Append one row to the Summary sheet for every processed company, regardless of score or outreach outcome. Log columns: Company, original scraped text, LLM summary, fit score, timestamp.

---

## Non-Functional Requirements

### NFR1 -- Free or low-cost APIs

Website scraping and news fetch must use free, no-API-key services where available. LLM usage must stay within free tier limits for normal single-company runs.

### NFR2 -- No manual steps after trigger

Once a row is added to the Companies sheet, the pipeline runs to completion without operator intervention.

### NFR3 -- No hardcoded credentials

API keys, sheet IDs, email addresses, and credential IDs are supplied via n8n's credential manager. The exported workflow JSON uses placeholders for all IDs.

### NFR4 -- Platform

Must run on n8n Cloud version 2.17.5 or later. Output is a single importable n8n workflow JSON file.

---

## Acceptance Criteria

1. Adding a new row to the Companies sheet triggers the pipeline without manual intervention.
2. A company with a Summary log entry timestamped within 30 days is skipped. No outreach, no new log row.
3. A company with no prior log entry, or a log entry older than 30 days, processes fully through all phases.
4. Every processed company receives an integer fit score between 1 and 10, plus a one-sentence rationale.
5. A company scoring 7 or above receives a personalized outreach email at the contact address in the Companies sheet.
6. A company scoring below 7 does not receive an outreach email.
7. Every processed company produces a new row in the Summary sheet with company name, summary, score, and timestamp.
8. The exported workflow JSON contains no live credentials, sheet IDs, or email addresses.

---

## Reference

- Three-way comparison summary: `../README.md`
- Claude Code R2 build: `./P06-lead-outreach-claude-code-r2.json`
- Build spec and architecture: `./BUILD_PROCESS.md`
- n8n build rules: `./n8n_SKILL.md`
