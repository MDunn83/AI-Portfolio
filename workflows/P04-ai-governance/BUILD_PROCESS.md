# P04 AI Governance Tool -- BUILD_PROCESS.md

Architecture, design decisions, and node-level spec for the n8n build.

---

## Environment

- n8n Cloud or self-hosted
- Groq API (free tier)
- Google Sheets OAuth2
- Output: single importable n8n workflow JSON file (`P04-ai-governance.json`)
- `active: false` in exported JSON

---

## Credentials

Use these exact credential names so n8n wires them automatically on import:

| Node | Credential Type | Expected Name | n8n Internal Key |
|---|---|---|---|
| Read Questions | Google Sheets OAuth2 | `Google Sheets OAuth2 API` | `googleSheetsOAuth2Api` |
| Append Audit Log | Google Sheets OAuth2 | `Google Sheets OAuth2 API` | `googleSheetsOAuth2Api` |
| Append Review | Google Sheets OAuth2 | `Google Sheets OAuth2 API` | `googleSheetsOAuth2Api` |
| Generate Response (Groq) | HTTP Bearer Auth | your Groq key | (custom) |
| Classify Query (Groq) | HTTP Bearer Auth | your Groq key | (custom) |
| Classify Response (Groq) | HTTP Bearer Auth | your Groq key | (custom) |

---

## Google Sheets Structure

- Document name: user-specified (set `YOUR_GOOGLE_SHEET_ID` on import)
- **Questions sheet**: input: columns `User ID`, `Query`
- **Audit Log Claude sheet**: output: 12 columns (see Output Columns table below)
- **Review Claude sheet**: output: same 12 columns as Audit Log Claude

---

## Technology Choices

| Purpose | Tool | Notes |
|---|---|---|
| LLM (all three calls) | Groq (qwen/qwen3-32b) | Free tier: 60 RPM; `reasoning_effort: none` suppresses thinking blocks; `batchSize: 1` / `batchInterval: 4000ms` respects rate limit |
| Sheets integration | Google Sheets OAuth2 | Trigger on manual, read full Questions sheet in one batch, append to two output sheets |
| Parallel execution | Merge node by position | Both classifiers fan out; Merge combines without field collisions |

---

## Workflow Architecture

```
Manual Trigger
    └── Read Questions
            └── Set Start Time
                    └── Generate Response (Groq)
                            └── Strip Markdown
                                    ├── Classify Query (Groq) ──► Parse Query Result ──► Merge (input 0)
                                    └── Classify Response (Groq) ► Parse Response Result ► Merge (input 1)
                                                                                                └── Assemble Row
                                                                                                        └── Append Audit Log
                                                                                                                └── Route to Review (IF)
                                                                                                                        ├── [SENSITIVE/UNCERTAIN] Append Review
                                                                                                                        └── [STANDARD] No Operation
```

**Key design points:**
- Strip Markdown fans out to both classifiers simultaneously (true parallel execution).
- Merge node combines branches by position; each branch outputs uniquely named fields with no collisions.
- All three Groq HTTP Request nodes use `batchSize: 1` / `batchInterval: 4000ms` to respect the free-tier 60 RPM limit.
- `reasoning_effort: none` is set on all Groq calls to suppress qwen3 thinking blocks.

---

## Node Table

| # | Node Name | Type | Purpose |
|---|---|---|---|
| 1 | Manual Trigger | `n8n-nodes-base.manualTrigger` | Starts workflow; operator initiates run |
| 2 | Read Questions | `n8n-nodes-base.googleSheets`, op: `getAll` | Reads all rows from Questions sheet |
| 3 | Set Start Time | `n8n-nodes-base.code` | JS: records `$now` for latency calculation |
| 4 | Generate Response | `n8n-nodes-base.httpRequest` | POST to Groq; model: `qwen/qwen3-32b` |
| 5 | Strip Markdown | `n8n-nodes-base.code` | JS: removes markdown formatting (asterisks, headers, bullets) |
| 6 | Classify Query | `n8n-nodes-base.httpRequest` | POST to Groq; returns class + domain |
| 7 | Parse Query Result | `n8n-nodes-base.code` | JS: parses JSON response, extracts class and domain |
| 8 | Classify Response | `n8n-nodes-base.httpRequest` | POST to Groq; returns class + domain |
| 9 | Parse Response Result | `n8n-nodes-base.code` | JS: parses JSON response, extracts class and domain |
| 10 | Merge | `n8n-nodes-base.merge` | Combines both classifier branches by position |
| 11 | Assemble Row | `n8n-nodes-base.code` | JS: builds output row with all 12 columns (see table below) |
| 12 | Append Audit Log | `n8n-nodes-base.googleSheets` | Appends every row to Audit Log Claude sheet |
| 13 | Route to Review | `n8n-nodes-base.if` | TRUE: either class is SENSITIVE or UNCERTAIN; FALSE: both are STANDARD |
| 14 | Append Review | `n8n-nodes-base.googleSheets` | Appends row to Review Claude sheet (TRUE branch only) |
| 15 | No Operation | `n8n-nodes-base.noOp` | Placeholder for FALSE branch (STANDARD items skip review) |

---

## Output Columns

Both **Audit Log Claude** and **Review Claude** sheets receive the same 12 columns:

| Column | Description | Value Type |
|---|---|---|
| Timestamp | ISO 8601 timestamp of row write | ISO string |
| User ID | From the Questions sheet | string |
| query | Original user query text | string |
| response | LLM-generated plain-text response (markdown stripped) | string |
| response class | Classification of response | `SENSITIVE` / `STANDARD` / `UNCERTAIN` |
| response domain | Governance domain of response | `PII` / `FINANCIALS` / `STRATEGIC` / `CREDENTIALS` / `LEGAL` / `MEDICAL` / `HR` / `NAMED_INDIVIDUAL` / `NONE` |
| query class | Classification of query | `SENSITIVE` / `STANDARD` / `UNCERTAIN` |
| query domain | Governance domain of query | `PII` / `FINANCIALS` / `STRATEGIC` / `CREDENTIALS` / `LEGAL` / `MEDICAL` / `HR` / `NAMED_INDIVIDUAL` / `NONE` |
| input tokens | Total prompt tokens across all three Groq calls | integer |
| output tokens | Total completion tokens across all three Groq calls | integer |
| latency ms | Wall-clock time from Set Start Time to Assemble Row | integer |
| est cost | Always 0 (Groq free tier) | number |

---

## Known Issues

**IF node conditions on import** -- n8n sometimes imports IF node conditions with the left side as a static value instead of an expression. If the workflow runs but all items go to the STANDARD branch regardless of classification, open the Route to Review node and manually re-enter the four conditions as expressions:

- `{{ $json['response class'] }}` equals `SENSITIVE`
- `{{ $json['response class'] }}` equals `UNCERTAIN`
- `{{ $json['query class'] }}` equals `SENSITIVE`
- `{{ $json['query class'] }}` equals `UNCERTAIN`
- Combinator: **OR**

---

## Groq Prompt Design

### Response Generation

- **Goal:** plain-text answer to the user query; no markdown in the output
- **Constraints:** no asterisks, no headers, no bullet formatting; clean readable prose
- **Input:** the query text from the Questions sheet

### Classification (Query and Response)

- **Goal:** return structured JSON with exactly two fields: `class` and `domain`
- **Output format:** raw JSON object, no markdown fences, no explanation -- `{"class": "<value>", "domain": "<value>"}`
- **Class values and definitions:** see REQUIREMENTS.md FR3
- **Domain values:** `PII`, `FINANCIALS`, `STRATEGIC`, `CREDENTIALS`, `LEGAL`, `MEDICAL`, `HR`, `NAMED_INDIVIDUAL`, `NONE`
- **Note:** the same prompt design covers both classifiers; substitute the query text (FR3) or the generated response text (FR4) as the input

---

## Rate Limiting Configuration

All three Groq HTTP Request nodes must include:

```json
{
  "batchSize": 1,
  "batchInterval": 4000,
  "reasoning_effort": "none"
}
```

This respects the free-tier 60 RPM limit and suppresses thinking blocks in qwen3.

---

## n8n JSON Export Rules

- Each node requires: `id` (UUID string), `name`, `type`, `typeVersion`, `position` (`[x, y]`), `parameters`, and `credentials` (where applicable).
- Connections are defined in the top-level `"connections"` object keyed by source node name.
- IF node output[0] = TRUE branch, output[1] = FALSE branch.
- Placeholder values for all sensitive data: `YOUR_GOOGLE_SHEET_ID`, credential IDs as `CRED_ID_PLACEHOLDER`.
- Validate JSON is syntactically correct before writing the file.
- The `settings` object must include `"executionOrder": "v1"`.
- `"active": false` in exported JSON.
