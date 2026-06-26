# n8n_SKILL.md: Pre-Build Essentials

## MANDATORY BEFORE BUILDING
Read this file completely before writing any node JSON. Do not build until you confirm you have read it.

This is the lean pre-build checklist. The **full patterns, code, and rationale are the source of truth in `workflows/lessons_learned.md`**, each rule below points to the section there. Both files are read on every n8n task; this one is the fast path, that one is the depth.

---

## n8n Credentials

Exact credential-manager names. Every Google Sheets, Gmail, or Groq node must reference these strings verbatim, a mismatch is a silent post-import failure.

| Service | Credential Name in n8n |
|---|---|
| Gmail | `Gmail OAuth2 API` |
| Google Sheets | `Google Sheets OAuth2 API` |
| Groq | `Groq account` |

---

## Node typeVersions

| Node | typeVersion |
|---|---|
| Google Sheets Trigger | **1** (higher → "Install this node" error on import) |
| Google Sheets (read/write) | 4 |
| Gmail | 2 |
| HTTP Request | 4.2 |
| Code | 2 |
| IF | 2 |
| LangChain chainLlm | 1.4 |

Always specify the n8n Cloud version in CLAUDE.md so typeVersions can be matched.

---

## Critical Snippets

The handful of patterns worth having inline so a build rarely has to leave this file. Everything else is an index entry below.

**Merge as a synchronization gate** (`lessons_learned.md` § Merge Nodes and Synchronization Gates):
```json
"combineBy": "combineByPosition",   // NOT "combinationMode": "mergeByPosition"
"numberInputs": 4,                  // must equal the actual incoming connection count
"includeUnpaired": true
```
Any branch producing N items that feeds the gate needs a Limit node (`maxItems: 1`) before it, or the gate fires N times.

**chainLlm kills `$json` downstream** (§ Data Flow Between Nodes): if a chainLlm node is anywhere in the path, `$json` is dead after it. Use cross-node refs in every later Code node:
```javascript
const company = $('New Lead Added').item.json.company;   // not $json.company
```

**Sanitize before email**: sequence is always **LLM Chain → Sanitize Text → Gmail → Log → Update** (§ LLM Output Sanitization for Email):
```javascript
let text = $json.text || '';
text = text.replace(/\\n/g, ' ');        // in a JSON workflow file: \\\\n
text = text.replace(/\n(?!\n)/g, ' ');
text = text.replace(/ {2,}/g, ' ');
return { json: { text: text.trim() } };
```

**Structured output: default to inline parse, no parser node** (§ Structured Output from LLMs): instruct the LLM to return raw JSON, then:
```javascript
const raw = ($json.text || '').trim();
try {
  const parsed = JSON.parse(raw.replace(/```(?:json)?\s*/gi, '').replace(/```\s*/g, '').trim());
  return { json: { score: parsed.score, rationale: parsed.rationale } };
} catch (e) {
  const m = raw.match(/"score"\s*:\s*(\d+)/);
  return { json: { score: m ? +m[1] : 5, rationale: 'Could not parse LLM output.' } };
}
```
Use the n8n Structured Output Parser node *only* when a downstream Split Out/loop needs a true typed array, see the section for that exception.

---

## Hard Rules: Silent-Failure Index

Violating these produces workflows that import but fail at runtime with no error. One line each; full pattern + code under the named `lessons_learned.md` section.

**Triggers & Sheets reads** (§ Triggers and Batch Processing)
- Operation is `getRows` ("Get Row(s)"); there is no `getAll`.
- Never add a `resource` field to a Sheets read node, it hides all other params.
- Get Rows returns nothing → enable Execute Once.

**Code nodes** (§ Code Nodes)
- Always set `mode`; return an array in `runOnceForAllItems`, a single object in `runOnceForEachItem`.
- Never `$input.first()`. Open every Code node by assigning fields off `$json` first.
- `fetch()` is unavailable, use `this.helpers.httpRequest()`; loop fetches in one Code node to avoid execution-data OOM.

**Data flow & order** (§ Data Flow Between Nodes)
- HTTP, file, and chainLlm nodes strip upstream context, carry fields forward with an Edit Fields/Code node.
- Cross-node refs only resolve if that node already executed; force order via the connection chain or a fan-out dead-end (never wire the prerequisite into the main chain, it multiplies items).
- Never return `[]` when downstream must always fire; return one wrapper item and branch on it.

**LLM prompts** (§ LLM Prompt Syntax, § LLM Prompt Behavior)
- Wrap every expression in `{{ }}`; never backtick `${ }`. Label every field on its own line.
- Append the "Output ONLY the requested content…" preamble-suppression block to every prompt.
- Use `---` (not newlines) as a list delimiter; `.trim()` + regex-fallback all output.
- Set `reasoning_effort: none` and strip `<think>…</think>` for reasoning models; strip literal `\n` (write as `\\\\n` in JSON).
- Guard arrays in Gmail bodies with `Array.isArray`; parse funding suffixes (B/M/K) before numeric compare.

**Merge / IF / Gmail**
- Merge gate: `combineBy`, `numberInputs`, `includeUnpaired`, see Critical Snippets (§ Merge Nodes and Synchronization Gates).
- IF conditions: expression-mode left side, `is true`/`is false` operator; **verify every IF on import**, the most import-fragile node (§ IF Node Conditions).
- Never hardcode Gmail `sendTo`; never wire Gmail straight from an LLM Chain (§ Gmail and Logging Pattern).

**Dedup, dates, APIs**
- Dedup with a JS `Set`, not Compare Datasets; log at dedup time; sort descending before batch delete (§ Deduplication).
- Sheets Trigger returns date serials, format columns as Plain Text; guard blank dates; Luxon needs the `.days` suffix (§ Date and Time Handling).
- Google Tasks due dates need full ISO 8601, not bare dates (§ Google Tasks Due Dates).
- Use the native Jina node, not HTTP to `r.jina.ai`; NewsAPI blocks cloud requests, use Google News RSS; batch free-tier calls at 2000ms (§ External APIs and Rate Limiting).
- Pre-filter on title + lede (500 chars) before any classifier call (§ Relevance Pre-Filtering).

**`__rl` reference format** for Google Sheets document/sheet selectors:
```json
"documentId": { "__rl": true, "value": "<id>", "mode": "id" },
"sheetName":  { "__rl": true, "value": "<name>", "mode": "name" }
```

---

## Post-Import Checklist

After importing a generated workflow into n8n, verify in this order:

1. Every IF node condition, left side in expression mode, operator correct.
2. All LLM prompt fields wrapped in `{{ }}` and evaluating.
3. Every LLM Chain is followed by a Sanitize Text node before any Gmail node.
4. Log nodes after Gmail use cross-node refs (`$('Sanitize Text Ticket').item.json.text`), not `$json.text`.
5. Trigger node typeVersion matches the n8n Cloud instance.
6. All placeholder Sheet IDs, Task List IDs, and email addresses are filled in.
7. Credential names match n8n's credential manager exactly (see n8n Credentials above).
8. Merge node set to `combineByPosition` (not Matching Fields) with `includeUnpaired` enabled.
9. Every node has an outgoing connection; Limit, Check_In, and Merge-gate inputs are the most commonly missing.
10. Google Tasks due dates use full ISO 8601 (`2026-07-01T00:00:00.000Z`).
11. Status-sheet column mappings pull from the Build Status Row node, not the original trigger.
12. `sendTo` fields in all Gmail nodes are dynamic expressions, never hardcoded.
13. Any cleanup/delete branch sorts rows by row_number descending before the Delete node.
14. Jina calls use the native node, not HTTP Request to `r.jina.ai`.
15. Any funding/suffixed numeric comparison uses parsed values, not raw strings.

---

## Pre-Export PII Checklist

Run before exporting any workflow JSON to GitHub or for sharing. Replace all literal values with labeled placeholders (e.g. `YOUR_GOOGLE_SHEET_ID`).

- `sendTo` fields in Gmail nodes: dynamic expressions, never hardcoded addresses
- Google Sheet IDs/URLs in `documentId` and `sheetName`
- Task List IDs in Google Tasks nodes
- OAuth2 credential IDs in all credentials blocks
- Webhook IDs in trigger nodes
- n8n instance ID in the meta block
- Workflow ID and versionId at the root level
