# P04 -- AI Governance Tool

An n8n workflow that reads user queries from Google Sheets, generates LLM responses via Groq, independently classifies both the query and the response for data governance, logs every result to an audit sheet, and routes sensitive or uncertain items to a human review queue.

---

## What It Does

1. Reads all rows from the **Questions** sheet (columns: `User ID`, `Query`)
2. Generates a plain-text LLM response for each query using Groq (`qwen/qwen3-32b`)
3. Classifies the **query** and the **response** independently and in parallel:
   - **Classification:** `SENSITIVE` | `STANDARD` | `UNCERTAIN`
   - **Domain:** `PII` | `FINANCIALS` | `STRATEGIC` | `CREDENTIALS` | `LEGAL` | `MEDICAL` | `HR` | `NAMED_INDIVIDUAL` | `NONE`
4. Appends every result to the **Audit Log Claude** sheet
5. Routes items where **either** the query class or the response class is `SENSITIVE` or `UNCERTAIN` to the **Review Claude** sheet

---

## Prerequisites

- n8n instance (cloud or self-hosted)
- Google Sheets OAuth2 credential configured in n8n
- Groq API key configured as a Bearer Auth credential in n8n

---

## Google Sheets Setup

The workflow targets your spreadsheet (set `YOUR_GOOGLE_SHEET_ID` on import). Create or verify the following sheets:

| Sheet name | Required columns |
|---|---|
| Questions | `User ID`, `Query` |
| Audit Log Claude | See REQUIREMENTS.md for output column details |
| Review Claude | See REQUIREMENTS.md for output column details |

---

## Import Steps

1. In n8n, go to **Workflows → Import** and upload `P04-ai-governance.json`
2. Open each HTTP Request node and re-select your Groq Bearer Auth credential
3. Verify the Google Sheets nodes are using your **Google Sheets OAuth2 API** credential
4. Open the **Route to Review** IF node and confirm all four conditions show as expressions (not static values); see BUILD_PROCESS.md Known Issues section for details
5. Save and run via the Manual Trigger

---

## Credentials

| Node | Credential type | Expected name |
|---|---|---|
| Read Questions | Google Sheets OAuth2 | `Google Sheets OAuth2 API` |
| Append Audit Log | Google Sheets OAuth2 | `Google Sheets OAuth2 API` |
| Append Review | Google Sheets OAuth2 | `Google Sheets OAuth2 API` |
| Generate Response | HTTP Bearer Auth | your Groq Bearer Auth credential |
| Classify Query | HTTP Bearer Auth | your Groq Bearer Auth credential |
| Classify Response | HTTP Bearer Auth | your Groq Bearer Auth credential |

---

## Files

| File | Description |
|---|---|
| `P04-ai-governance.json` | n8n workflow export: import this into n8n |
| `REQUIREMENTS.md` | Complete functional and non-functional requirements; goals, scope, acceptance criteria |
| `BUILD_PROCESS.md` | Architecture, design decisions, node table, technology choices, known issues |
| `LESSONS_LEARNED.md` | Build notes and gotchas for future n8n/Groq workflows |
| `validate_workflow.py` | Validation script used during development |
| `images/Proj4_Governance.png` | Manual build canvas |
| `images/Proj4_Governance_ClaudeCode.png` | Claude Code build canvas |
