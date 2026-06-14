# P04 AI Governance Tool — Zapier Build Requirements

Rebuilding the n8n AI governance workflow as a Zapier Zap. The n8n reference build lives in `../`. This document is the complete, self-contained spec for the Zapier version. Requirements carried forward from the n8n build are marked **[BASELINE]**. Requirements that are new or improved in this build are marked **[NEW]**.

---

## Goal

Govern AI query/response pairs in real time: classify each query and its LLM response, log everything to an audit trail, and route sensitive or uncertain items to a human review queue — notifying a reviewer immediately when something needs attention.

---

## Functional Requirements

### FR1 — Trigger

**[BASELINE]** The Zap reads user queries from a Google Sheet with two columns: `User ID` and `Query`.

**[NEW — NR1]** The Zap fires on each new row added to the Questions sheet. Governance happens as queries arrive, not in a scheduled batch. Each Zap run governs exactly one query. The n8n version uses a manual trigger that reads the full sheet in one batch run; this build makes governance always-on.

---

### FR2 — Response Generation

**[BASELINE]** For each query, generate a plain-text LLM response. The response must have all markdown stripped — no asterisks, headers, or bullet formatting. Output is a clean readable answer.

Prompt guidance:
```
You are a helpful assistant. Answer the following query in plain text only.
Do not use markdown formatting, bullet points, or headers.
Query: [query]
```

---

### FR3 — Query Classification

**[BASELINE]** Classify the original query independently of the response. Return two values:

- **class:** `SENSITIVE` | `STANDARD` | `UNCERTAIN`
- **domain:** `PII` | `FINANCIALS` | `STRATEGIC` | `CREDENTIALS` | `LEGAL` | `MEDICAL` | `HR` | `NAMED_INDIVIDUAL` | `NONE`

Classification definitions:
- `SENSITIVE` — the query involves personal data, financial details, credentials, legal matters, medical information, HR decisions, or named individuals in a sensitive context
- `STANDARD` — the query is routine and involves no sensitive content
- `UNCERTAIN` — the query is ambiguous; it may or may not involve sensitive content

Prompt guidance:
```
Classify the following query for data governance purposes.

Return a JSON object with exactly two fields:
- "class": one of SENSITIVE, STANDARD, or UNCERTAIN
- "domain": one of PII, FINANCIALS, STRATEGIC, CREDENTIALS, LEGAL, MEDICAL, HR, NAMED_INDIVIDUAL, or NONE

Definitions:
- SENSITIVE: involves personal data, financial details, credentials, legal matters, medical info, HR decisions, or named individuals in a sensitive context
- STANDARD: routine query, no sensitive content
- UNCERTAIN: ambiguous — may or may not involve sensitive content

Query: [query]

Return only the JSON object. No explanation.
```

---

### FR4 — Response Classification

**[BASELINE]** Classify the generated response independently of the query. Use the same classification schema as FR3 (same class values, same domain values). The query classification and response classification are independent — a STANDARD query can produce a SENSITIVE response and vice versa.

Prompt guidance: same as FR3, substituting `Response: [response]` for the query line.

---

### FR5 — Fail-Safe Classification Default

**[NEW — NR2]** Before routing, validate both `query_class` and `response_class`. If either value is not exactly `SENSITIVE`, `STANDARD`, or `UNCERTAIN`, override it to `SENSITIVE`. Governance must fail closed, not open.

The n8n build passes unexpected AI output through as-is. Silently routing an unrecognized value to the STANDARD branch means potentially sensitive content skips review entirely.

Implementation: add a Code step after both classification steps that checks both values and applies the override before the audit log append.

---

### FR6 — Audit Log

**[BASELINE]** Append every query/response pair to the Audit Log sheet regardless of classification result. No item is ever skipped.

Output columns:

| Column | Value |
|---|---|
| Timestamp | ISO 8601 timestamp of the Zap run |
| User ID | From the Questions sheet |
| query | The original query text |
| response | The plain-text generated response |
| response_class | SENSITIVE / STANDARD / UNCERTAIN |
| response_domain | Governance domain of the response |
| query_class | SENSITIVE / STANDARD / UNCERTAIN |
| query_domain | Governance domain of the query |

---

### FR7 — Review Queue Routing

**[BASELINE]** Route an item to the Review Queue when **either** the query class or the response class is `SENSITIVE` or `UNCERTAIN`. Items where both are `STANDARD` do not go to the Review Queue.

Routing condition (OR logic):
- `query_class` = `SENSITIVE`
- `query_class` = `UNCERTAIN`
- `response_class` = `SENSITIVE`
- `response_class` = `UNCERTAIN`

---

### FR8 — Review Queue Status Field

**[NEW — NR4]** When appending to the Review Queue, include a `review_status` column set to `PENDING`. This gives the reviewer a field to update (PENDING → REVIEWED / ESCALATED / DISMISSED) and makes the queue auditable rather than just a log.

The n8n build has no status field. You cannot report on how many items were reviewed, how quickly, or what the outcome was.

Review Queue columns: all Audit Log columns (FR6), plus `review_status` defaulting to `PENDING`.

---

### FR9 — Active Reviewer Notification

**[NEW — NR3]** When an item routes to the Review Queue, send a Gmail alert to a configured reviewer address. The n8n build appends items silently — no one is notified. A review queue with no notification is a queue no one checks.

The alert email must include:
- The original query
- The generated response
- Both classification results (class + domain for query and response)
- The timestamp

The reviewer must be able to assess the item from the email without opening the sheet.

---

## Platform Constraints

These are Zapier limitations relative to the n8n build. Document in LESSONS.md after the build.

| Constraint | n8n behavior | Zapier behavior |
|---|---|---|
| Classification parallelism | Query and response classified simultaneously (fan-out + Merge node) | Sequential: classify query, then response. Slightly slower per item. |
| LLM cost | Groq free tier | Zapier AI (GPT-4o-mini, task cost) or connected Anthropic/OpenAI key |
| Task cost per run | Flat per run regardless of step count | ~8–10 tasks: trigger + 3 AI steps + Code + 2 Sheets appends + Paths + optional Gmail |
| Processing model | Batch (all rows in one run) | Per-row (one Zap run per new query) |

---

## Out of Scope

- Domain-based reviewer routing (e.g., PII → privacy team, LEGAL → legal team). Candidate Phase 2 extension.
- Escalation workflows or SLA tracking on the Review Queue.
- Any output channel outside Gmail and Google Sheets.
- Modifying or closing review items from within Zapier.

---

## Google Sheets Setup

| Sheet | Columns |
|---|---|
| Questions | `User ID`, `Query` |
| Audit Log | `Timestamp`, `User ID`, `query`, `response`, `response_class`, `response_domain`, `query_class`, `query_domain` |
| Review Queue | Same as Audit Log, plus `review_status` (set to `PENDING` on append) |
