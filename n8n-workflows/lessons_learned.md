# n8n and Claude Code Lessons Learned

Mark Dunn | Automation & AI Orchestration Portfolio | May 2026

This is a living pattern library. Every entry is a transferable lesson -- something that burned time once and should never burn time again. Organized by topic so you can look up a problem type, not hunt through project history. The Build Summary doc is where project-specific narrative and benchmarks live.

**v6 update:** Added Project 2 lessons -- Exa.ai semantic search patterns, Set-based URL dedup, progressive data enrichment, title-plus-lede relevance filtering, value-based pairing lookup, Jina native node vs HTTP Request, funding amount suffix handling, descending sort before batch delete, and execution order enforcement without data flow corruption.

**v7 update:** Added New Job Openings v2 lessons -- `fetch()` unavailable in Code node sandbox, execution data OOM from raw API responses, fan-out dead-end pattern for execution order, always-fire downstream pattern via single wrapper item return, and stop hook sync after MCP push.

**Update (June 2026):** Generally applicable Claude Code session-management patterns moved to `reference/claude_code_SKILL.md`. The LLM prompt suffix and post-import checklist are now canonical in `reference/n8n_SKILL.md`; this file references them instead of duplicating.

---

# Section 1: n8n Patterns

---

## 1.1 Parallel Branches and Fan-In

**Problem: Parallel branches trigger downstream nodes multiple times**

When multiple LLM branches run simultaneously, each branch "pushes" its own execution downstream. A workflow with 4 parallel branches will execute every downstream node 4 times.

Resolution: Introduce a Merge node in Append mode with one input per parallel branch. This forces the workflow to wait until all branches check in before passing any data. Follow the Merge node with an Aggregate node set to Execute Once to collapse all items into a single JSON object with a `data` array.

**Problem: All parallel branch outputs have the same field name**

When parallel LLM chains all output a field called `text`, it is impossible to tell which output is which after merging.

Resolution: Add an Edit Fields (Set) node immediately after each LLM chain to rename the generic `text` output to a labeled key -- `summary`, `actions`, `decisions`, `qdb`, etc. The aggregated object then becomes a clearly labeled map that downstream nodes can reference predictably.

This same pattern applies to any parallel classifier branches. When two classifier branches each output a field called `classification`, only one survives the merge. Add an Edit Fields node after each branch's Code node to rename fields with a branch-specific prefix before the Merge. Example: `query_classification` and `response_classification` instead of `classification` on both. Zero field name overlap is the rule.

**Choosing the right Merge mode**

- Append mode: stacks all items from all inputs into a single list. Use when collecting outputs from parallel branches that each produce one item and you want to fan-in before aggregating. Note: 5 Jina items plus 5 news items in Append mode equals 10 items -- use Combine By Position instead when parallel branches process the same set of records.
- Combine By Position: zips items from multiple inputs by index order. Use when two parallel branches process the same companies or documents in the same order and you need one merged item per record. Enable "Include Any Unpaired Items" to prevent the Merge from dropping items when one branch produces fewer items than expected.
- Combine By Key: joins items using a shared unique identifier. Use when branches process multiple items at different speeds or produce different item counts. Always the safer choice for multi-document or multi-record pipelines. Requires a unique identifier (file_id, company_id, etc.) threaded through every node.

**Problem: Merge node parameter name mismatch on import**

The Merge node configured with `"combinationMode": "mergeByPosition"` in the JSON silently defaults to "Match Fields" mode on import, which fails because no matching fields are defined.

Resolution: The correct parameter is `"combineBy": "combineByPosition"` -- a different key name and a different value format. Always export a working workflow from the n8n UI and diff it against generated JSON. The UI export is the ground truth for parameter names.

**Problem: Merge node requires explicit input count**

The n8n Merge node (typeVersion 3) defaults to 2 inputs. Any connections wired to index 2 or 3 silently vanish on import with no error.

Resolution: Always add `"numberInputs": 4` (or the correct count) to the Merge node parameters explicitly. Do not assume n8n will infer it from the connections object.

**Pattern: Merge node as a synchronization gate, not a data aggregator**

A Merge node does not need to combine meaningful data from all its inputs. When the goal is to ensure all branches complete before a downstream node fires, the Merge node serves as a synchronization gate. The actual payload flows through a single input; the other inputs exist only to signal completion. This pattern ensures the log row is never written unless all branches succeed.

In Project 5, the sync gate Merge has 4 inputs: both Gmail nodes, the Limit node (task creation confirmation), and Check_In (the only input carrying meaningful data). Three inputs are completion signals. One carries data. All four are necessary.

When multiple parallel branches (Gmail Welcome, Gmail Manager, Google Tasks via Limit, Check_In) must all complete before a final action (Append Status), configure the Merge node with `"mode": "combineByPosition"` and `"includeUnpaired": true`. This ensures the final append only fires once after all branches complete.

**Pattern: Limit node as a synchronization reducer**

When a multi-item branch needs to feed a synchronization Merge node, the Limit node set to maxItems: 1 is the cleanest reduction tool. It passes the first item and discards the rest, converting N items into 1 without aggregating or transforming data.

In Project 5, Create a task produced 5 items (one per action item). Wiring it directly into the sync gate caused 5 log rows per hire. A Limit node reduced the output to 1 item.

A Google Tasks loop that creates one task per action item outputs N items (one per task). Without a Limit node, a downstream Merge gate receives N signals and fires N times, causing duplicate log rows. The Limit node collapses N outputs to 1 signal. This is the standard n8n pattern for any loop feeding into a sync gate.

Use Limit over Aggregate when the downstream node only needs a completion signal, not the actual data. Use Aggregate when the collapsed data is needed downstream.

Any branch that produces multiple items and feeds a synchronization Merge node needs a Limit node. Add this to the mandatory post-build checklist.

---

## 1.2 Google Sheets Date Handling

**Problem: Google Sheets Trigger returns date fields as serial numbers, not strings**

The Google Sheets Trigger node returns date fields as their underlying numeric serial value (e.g., `46132`) rather than the formatted display string. Format all date columns as Plain Text in Google Sheets before building.

**Problem: Reformatting a column to Plain Text does not convert already-stored values**

After changing a column format to Plain Text, manually re-enter the date value in every cell that already had data. Click the cell, press F2, press Enter.

**Problem: Blank optional date fields break DateTime.fromISO() expressions**

Wrap every date expression in a ternary guard:

```
{{ $json["Field Name"] ? [date expression] : fallback }}
```

---

## 1.3 Luxon Date Expressions

**Pattern: Calculating days or hours elapsed between two dates**

```
{{ $now.diff(DateTime.fromISO($json["Past Date Field"]), 'days').days }}
```

The `.days` or `.hours` suffix is required. Without it the expression returns a Luxon Duration object, not a number.

**Direction matters:** `$now.diff(pastDate)` gives positive elapsed time. `futureDate.diff($now)` gives positive time remaining.

**Pattern: Writing today's date back to a Google Sheets date column**

Use `{{ $now.toISODate() }}` -- produces a clean `YYYY-MM-DD` string.

---

## 1.4 Data Threading and Identifier Management

**Problem: File processing nodes strip all upstream metadata**

Add an Edit Fields (Set) node immediately after any file processing node. Use `$('Node Name').item.json.fieldName` to reach back upstream and reattach critical identifiers.

**Problem: Cross-node references lose context after HTTP Request nodes**

Add an Edit Fields or Code node after the last enrichment node to explicitly carry all needed fields forward. Downstream nodes reference `$json.fieldName`, not cross-node expressions.

**Problem: chainLlm nodes kill upstream item context**

Never rely on `$json` pass-through after a chainLlm node. Use cross-node references (`$('NodeName').item.json`) in every downstream Code node.

---

## 1.5 Structured Output and JSON Parsing

**Pattern: Prompt Tug-of-War**

Never mix JSON formatting instructions in the system prompt with a Structured Output Parser. The parser owns formatting. The prompt owns instructions.

**Problem: LLM output is a string even when it looks like JSON**

Use JSON.parse($json.text) in a downstream Code node. Always use `.trim()` before parsing and implement a regex fallback to isolate the JSON block.

**When to use Structured Output Parser vs inline JSON.parse**

- Use the parser when a downstream Split Out or loop requires a true typed array.
- Skip the parser and use JSON.parse in a Code node when output goes straight to Gmail, Sheets, or a node that only needs text fields.

**Problem: `response_format: json_object` breaks with reasoning models and low max_tokens**

Remove `response_format` entirely. Increase max_tokens to at least 200 for classifier nodes. Add a Code node with try/catch and regex fallback.

**Pattern: Use explicit delimiters instead of newlines for LLM list extraction**

Instruct the model to separate items with `---` on its own line. Split in the downstream Code node:

```javascript
const items = text
  .split("---")
  .map(item => item.trim())
  .filter(item => item.length > 0);
```

---

## 1.6 LLM Prompt Behavior

**Problem: LLM preamble breaks downstream parsing**

Use the canonical prompt suffix from `reference/n8n_SKILL.md` § LLM Prompt Behavior Rules.

**Pattern: Pass calculated values to LLM prompts, not raw date strings**

Calculate the derived value the LLM actually needs and pass that in the user message:

```
Days Inactive: {{ $now.diff(DateTime.fromISO($json["Last Activity Date"]), 'days').days }}
```

**Problem: Reasoning model outputs reasoning trace in response**

Add `"reasoning_effort": "none"` to every API request body for any model with a reasoning mode. Also add a regex strip as a safety net:
```javascript
text = text.replace(/<think>[\s\S]*?<\/think>/gi, '');
```

**Problem: User message fields concatenated with no separators**

Always add explicit field labels and line breaks. Every field gets its own labeled line.

---

## 1.7 Model Selection

**Rule: Switch models before iterating on the prompt**

When structured output is failing or formatting is wrong, switch models first. If the new model produces correct output, the prompt was fine -- the model was the problem.

**Model pairing by task type**

- Classification (simple, fast): llama-3.1-8b-instant
- Complex structured extraction: llama-3.3-70b-versatile
- Summary, scoring, outreach generation: openai/gpt-oss-20b via Groq or Gemini 2.5 Flash
- Governance and sensitive query workflows: Gemini 2.5 Flash (appropriate refusals, no hallucination on sensitive content)
- Temperature tuning: 0.3 for summary, 0.1 for scoring, 0.7 for outreach email generation

---

## 1.8 Node-Specific Behaviors

**Problem: Get Rows node returns no data**

Enable Execute Once in the node Settings tab so it runs a single time and returns the full sheet contents.

**Problem: Gmail node terminates the branch**

Wire logging nodes directly from the routing IF node, not from the Gmail node. Treat Gmail as a dead end.

**Problem: IF node conditions do not survive import**

Treat IF node condition verification as a mandatory post-import check on every build. For Boolean conditions, set the operator to "is false" and confirm expression mode is active on the left side.

**Problem: Google Sheets node requires `__rl` format for references**

```json
"documentId": { "__rl": true, "value": "<id>", "mode": "id" },
"sheetName": { "__rl": true, "value": "<name>", "mode": "name" }
```

**Problem: Hardcoded email addresses in Gmail sendTo field**

Always use dynamic expressions. A static email address in a sendTo field is always a bug in production context.

**Problem: Limit node exported with empty parameters**

Confirm maxItems is explicitly set and visible in the Parameters panel before exporting.

---

## 1.9 External APIs and Rate Limiting

**Problem: NewsAPI free tier blocks cloud-hosted requests**

Switch to GNews (gnews.io) or Google News RSS. Google News RSS is completely free, requires no API key, has no rate limits.

**Problem: Rate limiting on free API tiers**

Use the Batching option in the HTTP Request node. Set Items per Batch to 1 and Batch Interval to 2000ms.

**Free tier rate limits are a hard operational constraint**

For portfolio prototype work, either reduce the question set, add Wait nodes between items, or use providers with more generous free tiers.

---

## 1.10 Jina Web Scraping

**Use the native n8n Jina node, not HTTP Request**

Calling Jina via HTTP Request to r.jina.ai triggered DDoS protection blocks when called across 10 companies in sequence. The native node handles authentication and rate management cleanly.

**Jina native node field names**

Returns data at `$json.data.content` (not `$json.text`). Published time at `$json.data.publishedTime`. Article URL at `$json.data.url`.

---

## 1.11 Deduplication and Re-engagement

**Compare Datasets is wrong for URL lookup dedup**

Compare Datasets performs a JOIN-style operation -- it pairs items positionally. Use a Code node with a JavaScript Set for URL dedup:

```javascript
const logUrls = new Set(
  $('Get row(s) in sheet1').all().map(item => item.json['Signal URL'])
);
const items = [];
for (const input of $input.all()) {
  if (!logUrls.has(input.json.url)) {
    items.push({ json: input.json });
  }
}
return items;
```

**Log all URLs at dedup time, not at end of pipeline**

Articles dropped by relevance filters never reach end-of-pipeline append nodes. Add a Google Sheets Append node immediately after the Dedup Code node.

**Progressive data enrichment pattern**

Stage 1 at dedup: log with placeholder values. Stage 2 at end: Update operation overwrites placeholders with actual classifier output.

---

## 1.12 Test Data Discipline

Use test data that matches the actual target profile. Always include at least one genuinely poor-fit record to confirm IF routing works end to end.

---

## 1.13 Classification Prompt Design

**UNCERTAIN is a valid output, not a failure state**

Define UNCERTAIN explicitly in the classifier prompt as a valid and expected output with a clear trigger rule. UNCERTAIN always routes to human review.

**Classify both query and response independently for governance workflows**

Use two separate classifier nodes running in parallel. One receives the query text. One receives the response text. The IF routing rule fires if EITHER is SENSITIVE or UNCERTAIN.

---

## 1.14 Environment and Editor

Use Chrome or Edge. n8n's frontend is Chromium-based. Save frequently (Ctrl+S).

---

## 1.15 Audit Log and Metadata Sourcing

**Pattern: Every audit log field must have an identified source before building**

Map every column in the schema to its source before building:
- LLM fields: response text, classification label
- n8n fields: timestamp (DateTime node), routing destination
- Calculated fields: estimated cost (Code node using token counts)
- If a field cannot be sourced reliably, leave it blank in v1 and document it as a v2 addition.

---

## 1.16 Relevance Pre-Filtering

Title plus lede (500 characters) is the correct balance. Check title first, then first 500 characters of article text. Alias tables are required for any company with an ambiguous name.

---

## 1.17 Execution Order Enforcement

**Cross-node references require prior execution**

A cross-node reference only works if that node has already executed in the current run. If not, returns empty data silently.

**Side branch append nodes must be true dead ends**

A side branch node must have no outgoing connections. If wired into a downstream node in the main flow, it doubles the item count or corrupts data flow.

---

## 1.18 Value-Based Pairing Lookup

When a filter node sits between an upstream data source and a downstream node that needs fields from that source, use value-based lookup instead of index-based pairing. Match on a unique field (URL, ID) using `.find()`:

```javascript
const currentUrl = $json.data.url?.trim();
const dedupItems = $('Dedup Code').all();
const matched = dedupItems.find(item => item.json.url?.trim() === currentUrl);
const companyName = matched ? matched.json.companyName : null;
```

---

## 1.19 Google Sheets Batch Delete

Sort by row_number descending before the Delete node. Deletions proceed bottom-up. Row numbers of not-yet-deleted rows never shift.

---

## 1.20 Funding Amount String Parsing

LLMs return funding amounts as human-readable strings like "$30B" or "$500M". Detect and handle B and M suffixes before comparing:

```javascript
const raw = ($json.funding_amount ?? '0');
const num = parseFloat(raw.replace(/[^0-9.]/g, ''));
const isB = raw.toUpperCase().includes('B');
const isM = raw.toUpperCase().includes('M');
const amountInMillions = isB ? num * 1000 : isM ? num : num;
return amountInMillions >= 100;
```

---

# Section 2: n8n-Specific Claude Code Patterns

General Claude Code session-management patterns (setup, session management, local git, CLAUDE.md hygiene, token limits, architecture/design, stop hook sync) live in `reference/claude_code_SKILL.md`. The items below are n8n-specific Claude Code patterns that don't apply to non-n8n projects.

---

## 2.6 n8n-Specific Syntax Claude Code Gets Wrong

**Backtick template literals are not evaluated by n8n**

All LLM prompt expressions must use n8n {{ }} syntax. Never use backtick template literals with ${ }.

**The {{ }} wrapper is required even in expression mode**

The entire prompt string must be wrapped in {{ }}: `{{ 'static text ' + $json.company + ' more text' }}`

**$input.first() only returns the first item**

In runOnceForEachItem mode, use $json directly. In runOnceForAllItems mode, use $input.all().

**Return syntax differs by Code node mode**

- runOnceForAllItems: `return [{ json: {...} }]` -- returns an array
- runOnceForEachItem: `return { json: {...} }` -- returns a single object

**typeVersion mismatches on import**

Specify the n8n Cloud version in CLAUDE.md. For Google Sheets Trigger specifically: use typeVersion 1.

---

## 2.7 Post-Import Checklist

See `reference/n8n_SKILL.md` § Post-Import Checklist (canonical).

---

# Section 3: Cross-Tool Patterns

---

**Prompt Tug-of-War**

Never mix JSON formatting instructions in the system prompt with a Structured Output Parser.

**Data Threading**

Pass all necessary fields explicitly through every node. Never assume upstream data survives HTTP Request nodes, file processing nodes, chainLlm nodes, or mode changes.

**Model First**

When structured output is failing or formatting is wrong, switch models before iterating on the prompt.

**Test Data Discipline**

Test data must reflect the actual use case. Always include at least one edge case or poor-fit record.

**PII Export Discipline**

Every workflow export for public sharing must pass a PII checklist before GitHub commit.

**Suppression Before LLM**

All eligibility checks, suppression windows, and opt-out rules belong upstream of every LLM call.

**Set-Based URL Lookup for Dedup**

Compare Datasets is a JOIN node, not a lookup node. Use a Code node with a JavaScript Set.

**Log at the Earliest Possible Point**

Log every record that passes the first eligibility gate immediately -- with placeholder values for fields not yet determined.

---

## 1.21 HTTP Calls Inside Code Nodes (New Job Openings v2)

**Problem: `fetch is not defined` in Code node**

n8n's Code node sandbox does not expose `fetch()` as a global. Use `this.helpers.httpRequest()` for all HTTP calls inside Code nodes:

```javascript
const data = await this.helpers.httpRequest({
  method: 'GET',
  url: url,
  headers: { 'accept': 'application/json' },
  json: true
});
```

---

## 1.22 Execution Data OOM from Raw API Responses (New Job Openings v2)

**Problem: OOM crash when multiple HTTP Request nodes run in sequence**

n8n stores the full output of every node in execution data. Collapse all HTTP calls into a single Code node loop. Fetch each company, process the response immediately, append filtered results to a local array, then discard the raw response.

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

## 1.23 Fan-Out Dead-End Pattern for Execution Order (New Job Openings v2)

**Problem: Wiring a prerequisite node into the main chain causes item multiplication**

Fan-out from the trigger to both nodes simultaneously:

```
Trigger → [Node A (dead-end), Node B]
Node B → Node C
```

Node A has no outgoing connections. It executes first because it is listed first in the trigger's connection array. Its data is available via `$('Node A').all()` when Node C runs.

---

## 1.24 Always-Fire Downstream Nodes via Single Wrapper Item (New Job Openings v2)

**Problem: Processing node returns empty array, halting all downstream execution**

Always return exactly one wrapper item. Move the "no results" case into the downstream notification node:

```javascript
// Processing node -- always returns 1 item
return [{ json: { matched: matched, hasNew: matched.length > 0 } }];

// Email node -- handles both states
if (result.hasNew) {
  // render job list
} else {
  emailBody = '<p>No new openings today matching your criteria.</p>';
}
```
