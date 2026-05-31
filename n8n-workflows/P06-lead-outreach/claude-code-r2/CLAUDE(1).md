# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Before building, read n8n_SKILL.md for n8n-specific build rules.

## What You Are Building

An n8n workflow JSON file that automates lead enrichment and outreach for AI workflow automation consulting. The output is a single importable n8n workflow JSON file named `P6_Leads_V2_claude.json`.

---

## Environment

- n8n Cloud version 2.17.5
- Output must be a valid importable n8n workflow JSON file
- `active: false` in the exported JSON

---

## Credentials

Use these exact credential names so n8n wires them automatically on import:

| Service | Credential Name | n8n Internal Key |
|---|---|---|
| Google Sheets Trigger | Google Sheets Trigger OAuth2 API | `googleSheetsTriggerOAuth2Api` |
| Google Sheets (read/append) | Google Sheets OAuth2 API | `googleSheetsOAuth2Api` |
| Gmail | Gmail OAuth2 API | `gmailOAuth2` |
| Google Gemini | Google Gemini API | `googleGeminiApi` |

Use placeholder values (`SPREADSHEET_ID_PLACEHOLDER`, `CRED_ID_PLACEHOLDER`, etc.) for all IDs.

---

## Google Sheet Structure

- Document name: P6: Leads
- Input sheet: **Companies** — columns: Company, Website, Contact Name, Role, Email
- Log sheet: **Summary** — columns: Company, Orig Text, Summary, Rating, Recency

---

## Technology Choices

| Purpose | Tool | Notes |
|---|---|---|
| Website scraping | Jina AI Reader | `https://r.jina.ai/{url}` — free, no API key, handles JS sites |
| Recent news | Google News RSS | `https://news.google.com/rss/search?q={company}&hl=en-US&gl=US&ceid=US:en` — free, no API key |
| LLM (all phases) | Google Gemini 1.5 Flash | Free tier: 15 RPM, 1M tokens/day; model name: `models/gemini-1.5-flash` |

---

## Workflow Architecture (3-Phase Build)

Build and deliver in three distinct phases. Stop after each phase and ask the user to confirm before continuing.

### Phase 1 — Trigger through Summarizer LLM

| # | Node Name | Type | Purpose |
|---|---|---|---|
| 1 | New Lead Added | `n8n-nodes-base.googleSheetsTrigger` typeVersion 4 | Fires on new row in Companies sheet |
| 2 | Get Summary Log | `n8n-nodes-base.googleSheets` typeVersion 4, op: `getAll` | Reads all rows from Summary sheet |
| 3 | Check 30-Day Dedup | `n8n-nodes-base.code` typeVersion 2 | JS: checks if company exists in Summary with Recency within 30 days; outputs `isRecent` bool plus all trigger fields |
| 4 | Skip If Recent | `n8n-nodes-base.if` typeVersion 2 | TRUE branch (`isRecent === false`) continues; FALSE branch stops |
| 5 | Scrape Website | `n8n-nodes-base.httpRequest` typeVersion 4.2 | GET `https://r.jina.ai/` + Website from trigger |
| 6 | Fetch News | `n8n-nodes-base.httpRequest` typeVersion 4.2 | GET Google News RSS with company name as query param |
| 7 | Summarizer Chain | `@n8n/n8n-nodes-langchain.chainLlm` typeVersion 1.4 | Produces 2–3 sentence company summary from scraped data |
| 8 | Gemini Flash | `@n8n/n8n-nodes-langchain.lmChatGoogleGemini` typeVersion 1 | Sub-node connected to Summarizer Chain via `ai_languageModel` |

### Phase 2 — Scorer LLM

| # | Node Name | Type | Purpose |
|---|---|---|---|
| 9 | Scorer Chain | `@n8n/n8n-nodes-langchain.chainLlm` typeVersion 1.4 | Scores company 1–10 for fit; outputs score (integer) + one-sentence rationale |
| 10 | Gemini Flash (Scorer) | `@n8n/n8n-nodes-langchain.lmChatGoogleGemini` typeVersion 1 | Sub-node for scorer |
| 11 | Route By Score | `n8n-nodes-base.if` typeVersion 2 | TRUE branch (score ≥ 7) continues to outreach; FALSE branch goes to logging |

### Phase 3 — Outreach, logging

| # | Node Name | Type | Purpose |
|---|---|---|---|
| 12 | Email Writer Chain | `@n8n/n8n-nodes-langchain.chainLlm` typeVersion 1.4 | Generates personalized cold outreach email |
| 13 | Gemini Flash (Email) | `@n8n/n8n-nodes-langchain.lmChatGoogleGemini` typeVersion 1 | Sub-node for email writer |
| 14 | Send Email | `n8n-nodes-base.gmail` | Sends via Gmail; converts `\n` to `<br>` in body |
| 15 | Log to Summary | `n8n-nodes-base.googleSheets` typeVersion 4, op: `appendOrUpdate` | Appends row to Summary for ALL companies (both branches merge here) |

---

## Key Constraints

- `P6_Requirements.md` is the source of truth for scoring criteria, target persona, and success criteria
- Deduplication window: **30 days** (check Recency column in Summary before processing)
- Log sheet Recency column must use `$now` for timestamps
- Gmail body must convert `\n` to `<br>` HTML tags
- All company data (name, website, contact, email) must flow from the trigger node via cross-node references (`$('New Lead Added').first().json`) — do not hardcode
- Target companies: small to mid-size SaaS and tech companies with operational complexity; exclude large enterprises
- Value proposition: deploy internal productivity tools using n8n, Claude, and Google Workspace
- Scoring must be relative to that value proposition (see scoring prompt guidance below)
- Email tone: friendly-professional, authentic business voice — no corporate jargon, no buzzword soup

---

## Scoring Prompt Guidance

Score 1–10 where 10 = perfect fit for AI workflow automation consulting. Key signals:

- **High score (7–10)**: SaaS/tech company, 10–500 employees, has visible operational complexity (multiple tools, manual processes, rapid growth), non-technical ops roles, uses Google Workspace
- **Mid score (4–6)**: Relevant industry but unclear automation need or wrong size
- **Low score (1–3)**: Large enterprise (builds own automation), non-tech industry, or no web presence

Output format the scorer must return: `{"score": <integer 1-10>, "rationale": "<one sentence>"}`

---

## n8n JSON Output Rules

- Each node requires: `id` (UUID string), `name`, `type`, `typeVersion`, `position` (`[x, y]`), `parameters`, and `credentials` (where applicable)
- Connections are defined in the top-level `"connections"` object keyed by source node name
- Sub-nodes (LLM models) connect via `"ai_languageModel"` connection type, not `"main"`
- IF node output[0] = TRUE branch, output[1] = FALSE branch
- Validate JSON is syntactically correct before writing the file
- The `settings` object must include `"executionOrder": "v1"`
