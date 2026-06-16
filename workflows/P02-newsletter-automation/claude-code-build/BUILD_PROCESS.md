# BUILD_PROCESS.md

Architecture, design decisions, and node-level spec for the P02 Claude Code build (the RSS plus Groq rebuild of the newsletter monitor).

---

## Environment

- Platform: n8n
- Output: a single importable n8n workflow JSON file (`P02-newsletter-automation-claude-code.json`)
- The earlier manual build of this same monitor used Exa.ai semantic search and Jina article extraction; this build was constrained to free sources and rebuilt the same result on RSS plus heavier filtering.

---

## Credentials

Use these exact credential names so n8n wires them on import:

| Service | Credential name in n8n |
|---|---|
| Gmail | `Gmail OAuth2 API` |
| Google Sheets | `Google Sheets OAuth2 API` |
| Groq | `Groq account` |

---

## Google Sheet Structure

Workbook `Proj2_Claude.xlsx` becomes the live Google Sheet. Two tabs.

### Targets (input, 10 rows)

| Column | Notes |
|---|---|
| Company Name | e.g. OpenAI, Anthropic, Cursor |
| Website URL | informational |
| Anchor | disambiguated Google News search term (e.g. "Cursor AI coding", "Elasticsearch AI"); used to build the RSS query and also as a relevance alias |
| Sector | topic of interest, passed to the classifier |

### Log (output plus cross-run dedup source)

| Column | Notes |
|---|---|
| Company Name | |
| Signal Title | |
| Signal URL | dedup key; checked against incoming articles to prevent re-sending |
| Signal Type | one of the 8 categories |
| Summary | LLM 1-2 sentence summary |
| PubDate | from RSS |
| Logged | `={{ $now.toISO() }}`; also the field the 7-day cleanup keys on |
| Briefing Included | `Yes` (passed filters) / `No` (excluded) |
| Funding | LLM-extracted amount or `N/A` |

---

## Technology Choices

| Purpose | Tool | Notes |
|---|---|---|
| News source | Google News RSS | free, no API key; query built from the Anchor plus `when:2d`, fetched over an HTTP Request node |
| LLM (classify) | Groq `llama-3.1-8b-instant` | free tier; much higher per-minute limits than the larger model, so the high-volume per-article step uses it |
| LLM (synthesize) | Groq `llama-3.3-70b-versatile` | free tier; only the once-per-run synthesis step uses it |

There is no article-extraction step. The workflow works off RSS titles and descriptions directly.

---

## Workflow Architecture

Triggers: a Manual Trigger (testing) and a Schedule Trigger 24h (production, 08:00 daily). Both feed `Config`.

```
Triggers -> Config (recipientEmail) -> Get Log -> Get Targets
  -> Build RSS URL (Anchor + "when:2d") -> Fetch News (throttled HTTP)
  -> Parse Articles (<=6/company, 48h window; Always Output Data)
  -> Relevance Pre-filter -> Filter & Dedup -> Wait 3s
  -> Classify (Groq 8b) -> Parse Classification
  -> +- IF Real -true-> IF Include -true-> Log Included / -false-> Log Excluded
     +- Aggregate Included -> IF Has Signals
           +- true  -> Synthesize (Groq 70b) -> Sanitize Text -> Gmail Digest
           +- false -> Gmail No News
```

Two Groq model sub-nodes: `Groq Classify Model` (`llama-3.1-8b-instant`) feeds `Classify`; `Groq Synth Model` (`llama-3.3-70b-versatile`) feeds `Synthesize`.

A cleanup branch runs in parallel off `Get Log`: `Find Old Log Rows -> IF Has Old Rows -> Delete Old Log Rows` prunes Log rows older than 7 days each run.

### Node list

| Node Name | Purpose |
|---|---|
| Manual Trigger | Fires the workflow for testing |
| Schedule Trigger 24h | Fires the workflow at 08:00 daily in production |
| Config | Holds `recipientEmail`; single source for the recipient |
| Get Log | Reads all Log rows; `alwaysOutputData: true` so an empty Log still fires the pipeline; also feeds the cleanup branch |
| Get Targets | Reads the 10 company rows from Targets |
| Build RSS URL | Builds the Google News RSS query from Anchor plus `when:2d` |
| Fetch News | HTTP Request to Google News RSS; throttled (see decisions) |
| Parse Articles | Parses RSS to articles, caps 6/company, 48h window, re-attaches company by index; `alwaysOutputData: true` |
| Relevance Pre-filter | Drops articles not matching company name / Anchor before the LLM |
| Filter & Dedup | Removes articles whose Signal URL is already in Log; emits a sentinel item when nothing survives |
| Wait 3s | Incidental pause; fires once per batch, not per call |
| Classify | Groq chainLlm; classifies into 8 categories, extracts funding, writes summary |
| Groq Classify Model | `llama-3.1-8b-instant` sub-node feeding Classify |
| Groq Synth Model | `llama-3.3-70b-versatile` sub-node feeding Synthesize |
| Parse Classification | Parses the classifier JSON; reads article fields via `$('Filter & Dedup').item.json` |
| IF Real | Routes the sentinel away from logging; true continues to inclusion logic |
| IF Include | True branch logs as included, false branch logs as excluded |
| Log Included | Appends a Log row with Briefing Included = Yes |
| Log Excluded | Appends a Log row with Briefing Included = No |
| Aggregate Included | Collects the included signals for synthesis |
| IF Has Signals | True branch synthesizes and sends a digest, false branch sends the no-news note |
| Synthesize | Groq chainLlm; builds the <=5-paragraph briefing |
| Sanitize Text | Normalizes newlines into paragraphs and emits an `html` field |
| Gmail Digest | Sends the synthesized briefing to the Config recipient |
| Gmail No News | Sends the short no-news note to the Config recipient |
| Find Old Log Rows | Counts the leading Log rows older than 7 days |
| IF Has Old Rows | True branch deletes the old block |
| Delete Old Log Rows | Deletes the contiguous top block of old Log rows |

---

## Classifier Prompt and Output

The classifier receives company, sector, title, and description. It must pick exactly one of these 8 labels, using the label text verbatim:

```
Product Launch, Partnership, Funding, Leadership Change,
Research Publication, Hiring Signal, Regulatory/Legal, Other
```

It extracts any monetary amount central to the story using suffix notation (e.g. `$30B`, `$500M`, `$2.5M`), or `N/A` when there is none, and writes a factual 1-2 sentence summary. It returns raw JSON with no markdown fences in this shape:

```json
{"category": "<one of the categories above>", "funding": "<amount or N/A>", "summary": "<1-2 sentence summary>"}
```

### Global LLM prompt rule

Every LLM prompt ends with this verbatim:

```
Output ONLY the requested content. Begin directly with the first line of output.
Do not include any introductory text, preamble, or closing remarks.
```

---

## Key Architectural Decisions

- **Always one email per run.** n8n skips a node when its input has 0 items, so an empty funnel (no articles, all duplicates, or all irrelevant) would otherwise send nothing. `Parse Articles` has `alwaysOutputData: true`, and `Filter & Dedup` emits a sentinel item when nothing survives, which keeps the Classify to Aggregate to email path alive. The sentinel is routed away from logging by `IF Real`. The only exception is 0 rows in `Targets`, in which case nothing runs.

- **$100M rule gates Funding only (Option A).** The threshold applies only to `Funding`-category articles (`fundingMillions >= 100`). Partnerships and all other non-`Other` categories pass regardless of dollar amount. `Other` is always excluded.

- **Dedup is cross-run only,** keyed on `Signal URL` via a JS `Set` built from `Get Log`. Intra-run duplicates are intentionally not removed; the same article can be a legitimate signal for two companies, and the synthesizer consolidates it anyway.

- **RSS rate-limit mitigation.** `Fetch News` uses `batchInterval: 1500` (one request at a time), a real `User-Agent`, `retryOnFail` (3 times), and `onError: continueRegularOutput`. Bursting 10 bare requests is what triggers Google's 403s.

- **Recency via the query.** `when:2d` in the RSS query, plus a 48h safety filter in `Parse Articles`, makes it a true daily letter and shrinks volume before the LLM.

- **Company re-attachment after HTTP is index-based** in `Parse Articles` (10 responses in order). `continueOnFail` on `Fetch News` preserves the alignment.

- **`chainLlm` kills `$json` downstream.** `Parse Classification` reads article fields via `$('Filter & Dedup').item.json`, not `$json`.

- **Groq rate-limit handling.** `Classify` uses the lighter `llama-3.1-8b-instant` for its much higher free-tier limits; only `Synthesize` uses `llama-3.3-70b-versatile`. Both LLM nodes `retryOnFail` 5 times with 45s backoff, long enough to outlast Groq's per-minute window. Token volume is capped: description into Classify at 800 chars, combined text into Synthesize at 6000 chars. `Wait 3s` is incidental; the n8n Wait node fires once per batch, not per call, so the smaller model plus backoff are the real fixes.

- **Log retention: 7 days.** A cleanup branch off `Get Log` counts the leading rows whose `Logged` is older than 7 days and deletes that contiguous top block in one delete call. Rows are appended chronologically, so old rows are always the top block; no scattered or bottom-up delete is needed. This is safe for dedup because the fetch window is only `when:2d` (far less than 7 days), so a pruned row can never reappear. Note: n8n's delete-rows operation name and index fields vary by version, so verify the `Delete Old Log Rows` node on import (operation = Delete Rows or Columns, dimension = Rows, start index, number to delete).

- **Sanitize preserves paragraphs.** Single newlines become spaces, double newlines become paragraph breaks; it also emits an `html` field (`<br><br>`) for the Gmail body. It uses `String.fromCharCode` instead of escaped regex to avoid JSON double-escaping.

- **Recipient is never hardcoded.** Both Gmail nodes read `={{ $('Config').first().json.recipientEmail }}`; the placeholder lives only in the `Config` node.

- **`Get Log` has `alwaysOutputData: true`.** On the first run the Log tab has only headers (0 data rows); a Sheets read returns 0 items, and n8n skips downstream nodes that get 0 items, so without this `Get Targets` and the whole pipeline never fires on an empty Log. The empty placeholder item is harmless to dedup, since with no `Signal URL` it is filtered out of the Set.

- **Google Sheets nodes do not set a `resource` field.** It defaults to "Sheet Within Document" on its own; explicitly adding `resource` to the JSON broke the live node. Use `operation: "read"` for reads (the "Get Row(s)" op), not `getRows`, which is invalid in this n8n version and shows a red warning. Use `operation: "append"` for logs. `documentId` uses `"mode": "id"`, `sheetName` uses `"mode": "list"`.

---

## Post-Import Checklist

1. Set the Sheet ID (`YOUR_GOOGLE_SHEET_ID`) and confirm the tab gids resolve (Targets `0`, Log `802787579`).
2. Set `recipientEmail` in the Config node.
3. Map credentials: `Google Sheets OAuth2 API`, `Groq account`, `Gmail OAuth2 API`.
4. Verify every IF node (`IF Real`, `IF Include`, `IF Has Signals`, `IF Has Old Rows`); the left side is an expression and the operator reads "is true" (the most import-fragile part).
5. Confirm `Groq Classify Model` to `Classify` and `Groq Synth Model` to `Synthesize` links rendered, and verify the `Delete Old Log Rows` node (operation = Delete Rows or Columns, dimension = Rows).
6. First run via Manual Trigger; confirm Google News RSS returns data (open network required; not testable in the GitHub-only cloud sandbox).
