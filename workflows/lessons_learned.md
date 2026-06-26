# n8n Build Lessons: Source of Truth

Mark Dunn | Automation & AI Orchestration Portfolio

This is the canonical, detailed record of every n8n build lesson: the pattern, the code, and the reason it exists. `reference/n8n_SKILL.md` is the lean pre-build checklist distilled from this file: when the skill states a rule in one line, the full pattern and code live here under the matching section heading. Both files are read together on every n8n task, so nothing is duplicated between them. The skill points here for depth.

Project-specific narrative and benchmarks live in each build's own `BUILD_PROCESS.md` / `LESSONS_LEARNED.md`.

---

## Triggers and Batch Processing

- Use a Manual Trigger + Google Sheets `getRows` node to read all rows at once when processing a list in a single run. The UI operation is **Get Row(s)** → `"operation": "getRows"` in JSON. There is no `getAll` operation, it does not exist and fails the node.
- **Never add a `resource` field to a Google Sheets read node.** Adding `"resource": "sheetWithinDocument"` (or any value) makes the node render only the Resource selector, all other parameters disappear and it becomes unconfigurable.
- **Get Rows returns no data?** Enable Execute Once in the node's Settings tab so it runs once and returns the full sheet.
- Google Sheets Trigger must use typeVersion 1, higher versions cause "Install this node" errors on import.
- Never design for one-row-at-a-time trigger processing unless the use case genuinely requires it. For dedup, read the log sheet separately and check in a Code node. Do not use the trigger to filter.

---

## Code Nodes

- Always specify mode explicitly: `runOnceForAllItems` or `runOnceForEachItem`.
  - `runOnceForEachItem`: use `$json`; return a single object `return { json: {...} }`.
  - `runOnceForAllItems`: use `$input.all()`; return an array `return [{ json: {...} }]`.
- **Never use `$input.first()`**, it only ever returns the first item regardless of how many are flowing.
- Every Code node must open by assigning all needed fields off `$json` before referencing them. A field referenced before assignment throws a `ReferenceError` with no clear root-cause signal:
  ```javascript
  let text_clean = $json.text_clean || "";
  let action_items = $json.action_items || [];
  ```
- **`fetch()` is NOT available** in the Code node sandbox, it throws `ReferenceError: fetch is not defined` at runtime with no import error. Use `this.helpers.httpRequest()`:
  ```javascript
  const data = await this.helpers.httpRequest({
    method: 'GET',
    url: url,
    headers: { 'accept': 'application/json' },
    json: true
  });
  ```
- **Fetching inside a Code node loop beats HTTP Request nodes when processing a list.** Raw responses stored in HTTP Request node output accumulate in execution data and cause OOM at scale. In a loop, responses are processed and discarded, only filtered results enter execution data:
  ```javascript
  for (const company of companies) {
    let data;
    try {
      data = await this.helpers.httpRequest({ method: 'GET', url: url, json: true });
    } catch (e) { continue; }
    for (const job of (data.jobs || [])) {
      if (passesFilters(job)) matched.push(normalize(job));
    }
  }
  return [{ json: { matched } }];
  ```

---

## Data Flow Between Nodes

- HTTP Request nodes and file processing nodes strip upstream item context, after them the item only holds the response data; all upstream fields are gone.
- **chainLlm nodes also strip all upstream context, including arrays passed in before the chain.** If a chainLlm node is anywhere in the path, treat `$json` as dead downstream, use `$('NodeName').item.json` cross-node references in every Code node after it.
- Always add a Code/Edit Fields node after the last enrichment node to carry needed fields (IDs, names, context) forward onto the item. Downstream nodes then use `$json.fieldName`, not cross-node refs.
- Status-sheet column mappings must pull from the Build Status Row node output (`$json`), not the original trigger. Pulling from the trigger bypasses enriched fields (check-in date, timestamp, status flags) so they never get written.

### Execution Order Enforcement

- Cross-node references (`$('NodeName').all()`) only work if that node has already executed in the current run. If not, the reference returns empty data silently with no error.
- To force order without corrupting data flow: place the must-run-first node earlier in the main connection chain, and have the dependent node retrieve its working parameters via cross-node reference to the original trigger, not from the flowing data. (Project 2: wire Signal Log Read → Exa Pull; Exa Pull ignores the Signal Log data and reads its search params from the trigger, so Signal Log rows are available to the later Dedup Code node.)
- **Fan-out dead-end pattern**: when a node must execute for its cross-node side effect but its output must NOT flow into the pipeline, wire it as a dead-end from the trigger:
  ```
  Trigger → [Prerequisite Node (dead-end, no outgoing connections), Main Chain Node]
  Main Chain Node → downstream...
  ```
  The prerequisite is listed first in the trigger's connections array, so it runs first; its data is available via cross-node ref. WARNING: if the prerequisite has an outgoing connection into the main chain, its N output rows each trigger the next node, causing N×M item multiplication.

### Always-Fire Downstream Pattern

When a processing node must always trigger downstream nodes regardless of result count (e.g. always send an email even on zero results), never return `[]`; it halts all downstream execution silently. Always return exactly one wrapper item and handle both states downstream:

```javascript
// Processing node — always returns 1 item
return [{ json: { matched: matched, hasNew: matched.length > 0 } }];

// Downstream notification node
if (result.hasNew) {
  // render results
} else {
  // render "no results" message
}
```

---

## Merge Nodes and Synchronization Gates

- Merge node (typeVersion 3) defaults to 2 inputs. Connections wired to index 2+ silently vanish on import, always set `"numberInputs"` explicitly to the actual incoming count.
- The correct combineByPosition key is `"combineBy": "combineByPosition"`, NOT `"combinationMode": "mergeByPosition"`. The wrong key silently falls back to Match Fields mode, which fails because no matching fields are defined.
- Always enable `"includeUnpaired": true` on Merge nodes used as sync gates, without it the Merge drops items when one branch produces fewer than expected.
- **Merge as synchronization gate (not data aggregator):** when multiple parallel branches must all complete before a final action, use one Merge input per branch. One input carries the payload; the others are completion signals only. All are necessary for the gate to fire exactly once. (Project 5: Gmail Welcome (signal), Gmail Manager (signal), Limit (signal), Check_In (data), four inputs, one data carrier. Configure `"mode": "combineByPosition"`, `"includeUnpaired": true`.)
- **Limit node as synchronization reducer:** any branch producing N items that feeds a sync Merge must have a Limit node (`maxItems: 1`) immediately before it. Otherwise the Merge fires N times, producing duplicate log rows. Use Limit (not Aggregate) when the downstream node only needs a completion signal. Confirm `maxItems` is set and visible before exporting, an empty `{}` parameters object defaults to an unspecified limit on import.
- **Field-name collisions after parallel branches:** when parallel LLM chains all output `text`, or parallel classifiers all output `classification`, only one survives the Merge. Add an Edit Fields (Set) node after each branch to rename to a branch-specific key (`summary`, `actions`; `query_classification`, `response_classification`) *before* the Merge. Zero field-name overlap is the rule.
- Post-build check: every node feeding a Merge gate must have an entry in the connections object. Limit, Check_In, and multi-input Merge feeds are the most commonly missing, and missing connections produce no error (the node runs and drops its output).

---

## LLM Prompt Syntax

- All LLM prompt expressions must be wrapped in `{{ }}`, even in expression mode. Never use JavaScript backtick template literals with `${ }`; n8n does not evaluate them. String concatenation with `+` is valid inside `{{ }}`:
  ```
  {{ 'Static text ' + $json.company + ' more text ' + $json.summary }}
  ```
- For multi-line prompts with `\n`, keep everything inside a single `{{ }}` expression using concatenation.
- Always add explicit field labels and line breaks when passing multiple fields. Labels are what make the data parseable by the model:
  ```
  First Name: {{ $json['First Name'] }}
  Role: {{ $json.Role }}
  ```
- **Pass calculated values, not raw inputs.** Compute the value the model needs and pass that, rather than making the model do arithmetic:
  ```
  Days Inactive: {{ $now.diff(DateTime.fromISO($json["Last Activity Date"]), 'days').days }}
  ```

---

## LLM Prompt Behavior

- Every structured/parseable LLM prompt must include this verbatim (add it to CLAUDE.md as a global instruction):
  ```
  Output ONLY the requested content. Begin directly with the first line of output.
  Do not include any introductory text, preamble, or closing remarks.
  ```
- For list extraction, never rely on newline separation. Models ignore it. Use `---` as the delimiter:
  ```
  Separate each item with this exact text on its own line: ---
  ```
  ```javascript
  const items = text.split("---").map(i => i.trim()).filter(i => i.length > 0);
  ```
- LLM output is always dirty. Always `.trim()` before parsing, and implement a regex fallback to isolate the JSON block from any preamble.
- Some models emit literal `\n` strings (two chars) instead of newlines. In a Code node: `text = text.replace(/\\n/g, ' ');`, and in a JSON workflow file this must be written as `\\\\n` to survive double-escaping.
- Models with a reasoning mode (e.g. `qwen/qwen3-32b`) emit `<think>...</think>` traces. Add `"reasoning_effort": "none"` to the request body AND a safety-net strip:
  ```javascript
  text = text.replace(/<think>[\s\S]*?<\/think>/gi, '');
  ```
- When rendering an array in a Gmail body expression, always include an `Array.isArray` guard. Without it, undefined/malformed arrays render as `[object Object]` with no error.
- **Funding amounts** arrive as suffix notation ("$30B", "$500M"); `>=` coerces them to `NaN` and fails silently. Strip and normalize to a common unit before comparing:
  ```javascript
  function parseFundingToMillions(str) {
    if (!str) return null;
    const match = str.replace(/,/g, '').match(/\$?([\d.]+)\s*([BMK]?)/i);
    if (!match) return null;
    const num = parseFloat(match[1]);
    const suffix = (match[2] || '').toUpperCase();
    if (suffix === 'B') return num * 1000;
    if (suffix === 'M') return num;
    if (suffix === 'K') return num / 1000;
    return num;
  }
  // parseFundingToMillions("$30B") === 30000, parseFundingToMillions("$500M") === 500
  ```

---

## Structured Output from LLMs

**Default: skip the n8n Structured Output Parser node.** It injects conflicting schema instructions that cause model output failures. Instead, instruct the LLM to return raw JSON only (no markdown fences) and parse it in a Code node with try/catch and a regex fallback:

```javascript
const raw = ($json.text || '').trim();
let score = 5;
let rationale = 'Could not parse LLM output.';
try {
  const cleaned = raw.replace(/```(?:json)?\s*/gi, '').replace(/```\s*/g, '').trim();
  const parsed = JSON.parse(cleaned);
  score = Math.min(10, Math.max(1, parseInt(parsed.score, 10)));
  rationale = parsed.rationale || rationale;
} catch (e) {
  const scoreMatch = raw.match(/"score"\s*:\s*(\d+)/);
  const rationaleMatch = raw.match(/"rationale"\s*:\s*"([^"]+)"/);
  if (scoreMatch) score = Math.min(10, Math.max(1, parseInt(scoreMatch[1], 10)));
  if (rationaleMatch) rationale = rationaleMatch[1];
}
return { json: { score, rationale } };
```

**Exception, when the parser earns its place:** use the n8n Structured Output Parser only when a downstream **Split Out** or loop genuinely requires a true typed array (not a string that looks like JSON). When output goes straight to Gmail, Sheets, or any node that only needs text fields, skip the parser and use the inline `JSON.parse` approach above. The tradeoff: the parser buys you a typed array but reintroduces the schema-instruction conflict, so only pay that cost when a downstream node actually needs the typed structure.

---

## LLM Output Sanitization for Email

Even with formatting rules in the prompt, models insert hard line breaks mid-sentence. Prompt instructions alone are not enough. Add a dedicated Sanitize Text Code node immediately after every LLM Chain that feeds an email:

```javascript
let text = $json.text || '';
text = text.replace(/\\n/g, ' ');        // literal backslash-n (two chars)
text = text.replace(/\n(?!\n)/g, ' ');   // single newlines mid-prose
text = text.replace(/ {2,}/g, ' ');      // collapse extra spaces
text = text.trim();
return { json: { text } };
```

(In a JSON workflow file the first replace must be `\\\\n` to survive double-escaping.)

- The sequence is always **LLM Chain → Sanitize Text → Gmail → Log → Update**.
- Never wire Gmail directly from an LLM Chain node.
- Log nodes pull the email body from the Sanitize Text node via cross-node ref, not from the LLM Chain.

---

## Content Sanitization

Always sanitize raw scraped content before any LLM call:

```javascript
let cleaned = ($input.item.json.data || '').toString();
cleaned = cleaned.replace(/\[.*?\]\(https?:\/\/[^\)]+\)/g, '');
cleaned = cleaned.replace(/https?:\/\/\S+/g, '');
cleaned = cleaned.replace(/[\*#]+/g, '');
cleaned = cleaned.replace(/cookie|opt.out|preferences|privacy|GDPR|consent/gi, '');
cleaned = cleaned.replace(/\n+/g, ' ');
cleaned = cleaned.trim();
if (!cleaned || cleaned.length < 50) {
  cleaned = 'No meaningful content available for this company.';
}
cleaned = cleaned.substring(0, 3000);
```

- Cap content at 3000 characters to control token usage; always include the empty-content fallback.
- **Jina content** needs extra cleaning *before* the character cap. Ticker-tape noise fills the budget before article content:
  ```javascript
  cleanText = cleanText.replace(/[A-Z]{1,5}\s+\d+\.\d+\s+\([+-]\d+\.\d+%\)\s*/g, '');
  ```

---

## Gmail and Logging Pattern

Gmail does not pass email content to downstream nodes but does allow them to execute.

**Preferred: sequential (confirms delivery before logging):**
```
LLM Chain → Sanitize Text → Gmail → Log → Update Last Contacted
```
Log is wired from Gmail's output and uses a cross-node ref for the body: `{{ $('Sanitize Text Ticket').item.json.text.substring(0, 100) }}`.

**Alternate: parallel branch (when delivery confirmation isn't required):**
```
LLM Chain → Gmail          (email branch, terminates)
          → Log → Update   (logging branch, parallel)
```
Both branches wire from the LLM Chain / Sanitize node; Log uses `$json.text` directly. Do not wire Log from Gmail in this pattern.

- **Never hardcode email addresses in Gmail `sendTo`**, always dynamic: `{{ $('Category Router').item.json.email }}`. A hardcoded address is always a production bug; add `sendTo` verification to the pre-export checklist.

---

## IF Node Conditions

- Boolean conditions must use expression mode on the left side: `{{ $json.fieldName }}`.
- Use the **is true** / **is false** operator, never "equal to true/false" (type-mismatch errors).
- IF conditions do not always import correctly. The left side showing as a static value like `"true"` instead of an expression is the most common import failure. **Verifying every IF node is a mandatory post-import check**, it is the single most import-fragile part of any workflow.

---

## Deduplication

- Read the log sheet with a `getRows` node fanned out from the same trigger, then check each item in a Code node (`runOnceForEachItem`), passing the log rows as a field (`summaryRows` array). Use `$now.toISO()` for timestamps written to the log.
- **Set-based URL dedup**: do NOT use Compare Datasets (it's a JOIN that pairs by index, not a lookup). Use a JavaScript Set for O(1) "does this URL exist anywhere in the log":
  ```javascript
  const logUrls = new Set(
    $('Get Signal Log').all().map(item => item.json['Signal URL'])
  );
  const items = [];
  for (const input of $input.all()) {
    if (!logUrls.has(input.json.url)) items.push({ json: input.json });
  }
  return items;
  ```
- **Log at dedup time, not end of pipeline.** Records dropped by downstream filters never reach end-of-pipeline append nodes, so they'd be re-fetched and re-pass dedup next run. Add a Sheets Append immediately after the Dedup Code node, logging every record that passes dedup with `"Not Relevant"` placeholders for undetermined fields.
- **Progressive enrichment (two-stage write):** Stage 1 (at dedup) appends with placeholders; Stage 2 (end of pipeline) uses an Update keyed on a unique field (e.g. Signal URL) to overwrite placeholders with real values. `"Not Relevant"` beats blank. Blank is ambiguous.
- **Value-based pairing after filter nodes:** when a filter (IF, dedup Code) sits between a source and a downstream node needing that source's fields, match on a unique field with `.find()` instead of index-based pairing (which breaks silently when item counts change after filtering):
  ```javascript
  const allItems = $('Dedup Code').all();
  const match = allItems.find(item => item.json.url === $json.url);
  const companyName = match ? match.json.companyName : '';
  ```
- **Descending sort before batch delete**: any workflow deleting multiple Sheets rows sequentially must sort by `row_number` descending before the Delete node. Top-down deletion shifts indices (row 5 becomes row 4 after row 4 is deleted), so every other row survives. Bottom-up eliminates shifting. Mandatory, not an optimization.

---

## External APIs and Rate Limiting

- **NewsAPI free tier blocks cloud-hosted requests.** Use GNews (gnews.io) or Google News RSS. RSS is completely free, needs no key, no rate limits.
- **Rate limiting on free tiers:** use the HTTP Request node's Batching option: Items per Batch 1, Batch Interval 2000ms.
- Free-tier limits are a hard operational constraint: reduce the question set, add Wait nodes, or use a more generous provider.
- **Exa.ai / semantic search:** results come as a nested `results` array inside the response body. Loop the outer array and explode each nested array into individual items:
  ```javascript
  const items = [];
  for (const response of $input.all()) {
    const results = response.json.results || [];
    const companyName = response.json.companyName || '';
    for (const article of results) items.push({ json: { ...article, companyName } });
  }
  return items;
  ```
  Exa HTTP nodes don't carry upstream fields through. Add an Edit Fields node after to re-attach context (set the field type to **Array** when carrying a results array; String serializes it and breaks parsing). Live semantic APIs are non-deterministic; ranking shifts between calls, and that is not a dedup bug. Disambiguate ambiguous company names with an anchor ("Glean AI enterprise", "Cursor AI coding", quoted phrases for multi-word names).
- **Jina:** use the native n8n Jina node, not an HTTP Request to `r.jina.ai` (HTTP triggers DDoS-protection blocks across multiple companies). The native node returns data at `$json.data.content` (not `$json.text`), published time at `$json.data.publishedTime`, URL at `$json.data.url`. Verify the actual output structure before writing parse code.

---

## Relevance Pre-Filtering

Pre-filter before any classifier call. Every classifier call costs tokens, and a record that fails relevance still fails classification, just more expensively.

- Title-only is too strict; full-text is too loose. **Title plus lede (first 500 chars)** is the balance. Primary subjects are named in the opening sentences:
  ```javascript
  const title = ($json.title || '').toLowerCase();
  const lede = ($json.text || '').substring(0, 500).toLowerCase();
  const isRelevant = companyAliases.some(alias =>
    title.includes(alias.toLowerCase()) || lede.includes(alias.toLowerCase())
  );
  return { json: { ...$json, isRelevant } };
  ```
- Alias tables are required for any ambiguous/multi-word name (cover product names, tickers, CEO names, legal entity names). Build the alias table in CLAUDE.md or a config node, not hardcoded in filter logic.

---

## Date and Time Handling

- **Google Sheets Trigger returns dates as serial numbers** (e.g. `46132`), not strings. Format all date columns as Plain Text before building.
- Reformatting to Plain Text does NOT convert existing values. Manually re-enter each cell that already had data (click, F2, Enter).
- Blank optional date fields break `DateTime.fromISO()`. Guard every date expression: `{{ $json["Field"] ? [expr] : fallback }}`.
- **Luxon elapsed time:** `{{ $now.diff(DateTime.fromISO($json["Past Date"]), 'days').days }}`. The `.days`/`.hours` suffix is required, else you get a Duration object, not a number. Direction matters: `$now.diff(pastDate)` = elapsed; `futureDate.diff($now)` = remaining.
- Writing today's date to a Sheets date column: `{{ $now.toISODate() }}` → clean `YYYY-MM-DD`.

---

## Google Tasks Due Dates

- Set due dates in full ISO 8601 datetime: `"2026-07-01T00:00:00.000Z"`. The API rejects bare date strings like `"2026-07-01"` with a 400. Never use `.split('T')[0]` on `toISOString()` for task due dates.

---

## Model Selection

- **Switch models before iterating on the prompt.** When structured output fails or formatting is wrong, switch models first. If the new model is correct, the prompt was fine and the model was the problem.
- Pairing by task type:
  - Classification (simple, fast): `llama-3.1-8b-instant`
  - Complex structured extraction: `llama-3.3-70b-versatile`
  - Summary, scoring, outreach generation: `openai/gpt-oss-20b` via Groq, or Gemini 2.5 Flash
  - Governance / sensitive-query workflows: Gemini 2.5 Flash (appropriate refusals, no hallucination on sensitive content)
  - Temperature: 0.3 summary, 0.1 scoring, 0.7 outreach email generation

---

## Classification Prompt Design

- **UNCERTAIN is a valid output, not a failure state.** Define it explicitly in the prompt with a clear trigger rule; UNCERTAIN always routes to human review.
- For governance, classify query and response independently, with two parallel classifier nodes, one on the query, one on the response. The routing IF fires if EITHER is SENSITIVE or UNCERTAIN.

---

## Governance Workflow Patterns

Platform-agnostic; these held up on both the n8n and Zapier governance builds.

- **Fail closed on invalid classifier output.** Validate the classifier's class against the allowed set in a Code step. If it comes back malformed or unrecognized, default to the most restrictive value (SENSITIVE), never the safe-looking one. A bad classification should get caught, not slip through. Put the override in code, not the prompt.
- **Log before you filter.** Write every item to the audit log before any routing or filtering runs, regardless of how it was classified. If the routing logic breaks, you still have a complete record. The audit log should never depend on the filter logic being correct.

---

## Test Data Discipline

Use test data matching the actual target profile, and always include at least one genuinely poor-fit record to confirm IF routing works.

---

## Audit Log Metadata Sourcing

Map every audit-log column to its source before building: LLM fields (response text, classification), n8n fields (timestamp via DateTime node, routing destination), calculated fields (estimated cost via token counts). If a field can't be sourced reliably, leave it blank in v1 and document it as a v2 addition.

---

## Build Sequencing for Token Limits

Break large builds into phases to stay within Claude Code token limits, stop after each, and retrieve the JSON from the branch before starting the next:
- Phase 1: Trigger, data reading, dedup
- Phase 2: Enrichment (scraping, APIs, sanitization), first LLM
- Phase 3: Scoring LLM, routing IF
- Phase 4: Output nodes (email, logging)

---

## Environment

Use Chrome or Edge. Firefox has websocket instability with the n8n editor. Save frequently (Ctrl+S) during build/debug.

---

## n8n Syntax Claude Code Gets Wrong

A recurring shortlist for any session generating node JSON (full detail in the sections above): backtick literals aren't evaluated (use `{{ }}`); `$input.first()` only returns the first item; return syntax differs by Code-node mode; typeVersion mismatches fail on import (specify the n8n Cloud version in CLAUDE.md; Google Sheets Trigger must be typeVersion 1).

---

## Make (Integromat) Platform Notes

From the P02 Make build (the third build of the newsletter monitor). Make maps to n8n closely (module = node, route = IF branch, aggregator = Aggregate), but the expression layer and editor have their own traps.

- **Never type `{{ }}` yourself.** The field picker inserts the braces when you select a value. Typing them by hand produces a literal text token instead of a bound reference, and it fails silently as plain text. This bit the RSS URL and the Gemini prompts repeatedly.
- **`+` is numeric only.** There is no string concatenation operator. Putting variables next to each other (adjacency) inside one expression concatenates; for anything else use a function (`encodeURL`, `substring`, etc.).
- **`=` does not compare reliably inside `if()`.** Use `contains()` for membership tests, or push the comparison into a native Filter operator. The native Filter operators (`date:greater`, `text:contain`, `number:greater`, `number:equal`, `text:notequal`) worked flawlessly for recency, relevance, dedup, and the include/route gating; the `if()` equality did not.
- **Gemini module: turn on Response Format → JSON Output** for structured returns. Its `result` field is typed inconsistently across runs (sometimes an object, sometimes a string), so don't depend on the shape; JSON Output plus a Parse JSON module is the stable path.
- **Switch models before fighting the output.** Gemini 2.5 Flash-Lite intermittently fenced its JSON even with JSON Output on; Gemini 3.1 Flash-Lite fixed it with no prompt change. Same lesson as Model Selection above, now confirmed cross-platform: change the model first, then the prompt.
- **Backtick literals can't be matched** in string functions. Don't try to compare against a backtick-quoted literal.
- **Heavy editing leaves stale pill references.** After a lot of rewiring, a module can keep pointing at an old mapping that no longer exists. Delete the module and re-add it to force the graph to recompute.
- **Empty array brackets return an array, not a scalar.** `[].x` gives you an array; index it (`[1]`) to get a value.
- **Sheets modules cache their columns.** After changing the sheet, the column picker is stale until you "Run this module only" to refresh it.
- **Gmail body is Raw HTML only.** There's no plain-to-HTML conversion; wrap preformatted text in `<pre>` to keep newlines without converting them yourself.
- **Don't filter the link into a Router.** Put the filter on each route instead. A filter on the inbound link to a Router will skip every route when the input is empty, which silently produces no output (this was the no-news bug: the no-news route never fired). One filter per route, gated on the aggregated array length.
- **Batch row deletes need descending order.** `Delete a Row` deletes by the live row index, so top-down deletion renumbers the rows still queued and clobbers the wrong ones. Order the source `Search Rows` by the timestamp column descending; on an append-only sheet that hands Delete the highest row numbers first (bottom-up), which never shifts an index you still need. No separate sort module required. The row index field is `__ROW_NUMBER__`, mapped as `{{1.`__ROW_NUMBER__`}}`. (Same lesson as the n8n "descending sort before batch delete".)
- **Running one module in isolation starves it of input.** "Run this module only" gives a downstream module no upstream bundles, so anything mapped from a previous module (e.g. `{{1.`__ROW_NUMBER__`}}`) resolves empty and fails validation ("Row number field was empty"). The module isn't broken; the test is. Use "Run once" on the whole flow so each module gets fed in sequence.
