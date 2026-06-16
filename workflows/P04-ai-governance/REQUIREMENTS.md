# P04 AI Governance Tool -- Requirements

Version 1.0 | June 2026

---

## Goal

Govern AI query/response pairs in real time; classify each query and its LLM response, log everything to an audit trail, and route sensitive or uncertain items to a human review queue.

---

## Scope

### In scope

- Trigger from Google Sheets (Questions sheet with `User ID` and `Query` columns).
- Response generation via Groq (`qwen/qwen3-32b`) with markdown stripped.
- Independent query classification with class (`SENSITIVE` / `STANDARD` / `UNCERTAIN`) and domain (`PII` / `FINANCIALS` / `STRATEGIC` / `CREDENTIALS` / `LEGAL` / `MEDICAL` / `HR` / `NAMED_INDIVIDUAL` / `NONE`).
- Independent response classification with the same schema.
- Parallel execution of both classifiers (fan-out plus Merge node).
- Audit log append to capture every query/response pair and their classifications.
- Review queue routing for items where either query class or response class is `SENSITIVE` or `UNCERTAIN`.
- Token usage and latency tracking.

### Out of scope

- Domain-based reviewer routing (e.g., routing PII items to a privacy team).
- SLA tracking or escalation workflows on the review queue.
- Active reviewer notification via email (the Zapier build has this; the n8n build does not).
- Review queue status field (the Zapier build includes `review_status`; the n8n build appends to Review sheet only).
- Any output channel outside Gmail and Google Sheets.
- Modifying or closing review items from within n8n.
- Fail-safe classification default (the Zapier build validates and overrides unexpected classifier output to SENSITIVE; the n8n build passes through as-is).

---

## Functional Requirements

### FR1 -- Trigger

The workflow reads all rows from the Questions sheet (columns: `User ID`, `Query`). A manual trigger initiates a single batch run that processes all rows.

### FR2 -- Response Generation

For each query, generate a plain-text LLM response using Groq. Response must have all markdown stripped; no asterisks, headers, or bullet formatting. Output is clean and readable.

### FR3 -- Query Classification

Classify the original query independently of the response. Return two values:

- **class:** `SENSITIVE` | `STANDARD` | `UNCERTAIN`
- **domain:** `PII` | `FINANCIALS` | `STRATEGIC` | `CREDENTIALS` | `LEGAL` | `MEDICAL` | `HR` | `NAMED_INDIVIDUAL` | `NONE`

Classification definitions:
- `SENSITIVE`: the query involves personal data, financial details, credentials, legal matters, medical information, HR decisions, or named individuals in a sensitive context.
- `STANDARD`: the query is routine and involves no sensitive content.
- `UNCERTAIN`: the query is ambiguous; it may or may not involve sensitive content.

### FR4 -- Response Classification

Classify the generated response independently of the query. Use the same class and domain values as FR3. A `STANDARD` query can produce a `SENSITIVE` response and vice versa.

### FR5 -- Audit Log

Append every query/response pair to the Audit Log Claude sheet regardless of classification result. No item is ever skipped. Output columns: Timestamp, User ID, query, response, response class, response domain, query class, query domain, input tokens, output tokens, latency ms, est cost.

### FR6 -- Review Queue Routing

Route an item to the Review Claude sheet when **either** the query class or the response class is `SENSITIVE` or `UNCERTAIN`. Items where both are `STANDARD` do not go to the Review Queue.

Routing condition (OR logic):
- query class = `SENSITIVE`
- query class = `UNCERTAIN`
- response class = `SENSITIVE`
- response class = `UNCERTAIN`

---

## Non-Functional Requirements

### NFR1 -- Groq free tier

Must use Groq free tier (60 RPM limit). Batch execution must respect this rate limit via `batchSize: 1` / `batchInterval: 4000ms` on all three Groq HTTP Request nodes.

### NFR2 -- No hardcoded credentials

API keys, Google Sheet IDs, and credential references are supplied via n8n's credential manager. The exported workflow JSON uses placeholder values for all sensitive data.

### NFR3 -- No manual steps

Once triggered, the workflow runs to completion without operator intervention. All LLM calls suppress thinking blocks with `reasoning_effort: none`.

### NFR4 -- Platform

Must run on n8n Cloud or self-hosted n8n. Output is a single importable n8n workflow JSON file.

---

## Acceptance Criteria

1. Workflow triggers and reads all rows from the Questions sheet without manual intervention per-row.
2. Every query receives a plain-text LLM response with markdown stripped.
3. Every query is classified with a class value (`SENSITIVE` / `STANDARD` / `UNCERTAIN`) and a domain value from the allowed list.
4. Every response is classified with a class value and domain value using the same schema.
5. Query and response classifiers run in parallel (fan-out + Merge node).
6. Every query/response pair is appended to the Audit Log Claude sheet with all 12 output columns.
7. Items where query class or response class is `SENSITIVE` or `UNCERTAIN` are appended to the Review Claude sheet.
8. Items where both query class and response class are `STANDARD` are not appended to the Review Claude sheet.
9. All Groq HTTP Request nodes use `batchSize: 1` / `batchInterval: 4000ms` and `reasoning_effort: none`.
10. The exported workflow JSON contains no hardcoded API keys, sheet IDs, or live credential references.

---

## Reference

- Manual build canvas: `images/Proj4_Governance.png`
- Claude Code build canvas: `images/Proj4_Governance_ClaudeCode.png`
- Architecture and design decisions: `BUILD_PROCESS.md`
- Build notes and gotchas: `LESSONS_LEARNED.md`
- n8n workflow export: `P04-ai-governance.json`
