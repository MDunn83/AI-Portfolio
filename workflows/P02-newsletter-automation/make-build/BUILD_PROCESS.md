# BUILD_PROCESS.md

Architecture, design decisions, and module-level spec for the P02 Make build: the third build of the newsletter monitor, done in Make (formerly Integromat) so the same project exists in n8n, Make, and Zapier for an apples-to-apples comparison.

---

## Environment

- Platform: Make (Integromat)
- Output: two importable Make blueprints. `P02-newsletter-automation-make.json` is the newsletter scenario; `P02-newsletter-prune-make.json` is a small companion scenario that prunes old Log rows (see Log pruning below).
- Same job as the two n8n builds: read companies from a Google Sheet, pull recent news per company, filter and classify it, log every decision, and email a synthesized daily briefing.
- This build uses Google's Gemini for both LLM steps, where the n8n manual build used Exa plus an LLM and the Claude Code build used Groq. The AI choice is deliberate per platform, not incidental (see the comparison below).

---

## Credentials (Make connections)

The blueprint ships with connection IDs nulled (`"__IMTCONN__": null`). On import Make will prompt you to pick a connection for each module. You need three:

| Service | Modules that use it |
|---|---|
| Google Sheets | Get Companies, Check_Log, Log row |
| Google Gemini AI | Classify, Synthesize |
| Google Email (Gmail) | Briefing email, No-news email |

---

## Google Sheet Structure

Same two-tab workbook as the n8n builds. Make references columns by zero-based index, not header name, so the column order matters.

### Targets (input)

| Index | Column | Used as |
|---|---|---|
| 0 | Company Name | classifier context and the relevance keyword |
| 1 | Website URL | informational |
| 2 | Anchor | disambiguated Google News search term; builds the RSS query |
| 3 | Sector | passed to the classifier |

### Log (output plus dedup source)

| Index | Column |
|---|---|
| 0 | Company Name |
| 1 | Signal Title |
| 2 | Signal URL (dedup key) |
| 3 | Signal Type |
| 4 | Summary |
| 5 | PubDate |
| 6 | Logged |
| 7 | Briefing Included |
| 8 | Funding |

---

## Technology Choices

| Purpose | Tool | Notes |
|---|---|---|
| News source | Google News RSS | free, no key; query is `encodeURL(Anchor) + " when:2d"` against `news.google.com/rss/search`, read by the native RSS module |
| LLM (classify) | Gemini 3.1 Flash-Lite | Response Format set to JSON Output, `temperature 0`, `thinkingBudget 0`, `maxOutputTokens 300`; one call per surviving article |
| LLM (synthesize) | Gemini 3.1 Flash-Lite | `temperature 0.4`, free-text output; one call per run |

Both LLM steps run on Gemini 3.1 Flash-Lite. An earlier pass on Gemini 2.5 Flash-Lite intermittently wrapped its JSON in markdown fences even with JSON Output on; swapping to 3.1 fixed it without a prompt change. That is the same "switch models before iterating on the prompt" lesson from the n8n builds, now confirmed on Make (see `workflows/lessons_learned.md`).

---

## Scenario Architecture

Make iterates over bundles automatically, so there are no explicit loops. Get Companies emits one bundle per row; the RSS module runs once per company; the relevance filter, classifier, and log step run once per article; the second aggregator collapses everything back to a single bundle before the router.

```
Get Companies (Targets) -> Set recipientEmail
  -> Check_Log -> Aggregate seen URLs
  -> RSS (Anchor + "when:2d", per company)
  -> [Relevance filter: recent AND mentions company AND URL not seen]
  -> Classify (Gemini, JSON) -> Parse JSON -> Set briefingInclude
  -> Log row (append to Log)
  -> Aggregate included signals  [filter: category != "Other"]
  -> Router
       route 1  [length(included) > 0]  -> Synthesize (Gemini) -> Gmail briefing
       route 2  [length(included) = 0]  -> Gmail no-news note
```

### Module list

| Module | Type | Purpose |
|---|---|---|
| Get Companies | google-sheets:filterRows | Reads the Targets tab |
| Set recipientEmail | util:SetVariable2 | Holds the recipient as a roundtrip variable; both Gmail modules read it via `{{3.recipientEmail}}`, so the recipient lives in one place |
| Check_Log | google-sheets:filterRows | Reads the Log tab |
| Aggregate seen URLs | builtin:BasicAggregator | Collapses Log rows into one array used for the dedup check |
| RSS | rss:ActionReadArticles | Google News RSS per company; query built from the Anchor plus `when:2d` |
| Relevance filter | filter on the link into Classify | Three conditions, all must pass (see below) |
| Classify | gemini-ai:createACompletionGeminiPro | Gemini 3.1 Flash-Lite, JSON Output; returns category, summary, funding |
| Parse JSON | json:ParseJSON | Parses the classifier result |
| Set briefingInclude | util:SetVariable2 | `Yes` if category is one of the seven real types, else `No` |
| Log row | google-sheets:addRow | Appends the signal and its decision to the Log tab |
| Aggregate included signals | builtin:BasicAggregator | Filter `category != "Other"`; aggregates the included signals into one array |
| Router | builtin:BasicRouter | Two routes, each gated by its own filter |
| Synthesize | gemini-ai:createACompletionGeminiPro | Route 1; builds the briefing of at most 5 short paragraphs |
| Gmail briefing | google-email:sendAnEmail | Route 1; sends the synthesized briefing |
| Gmail no-news note | google-email:sendAnEmail | Route 2; sends the short no-news note |

### The relevance filter

The single filter on the link into Classify carries all three pre-LLM checks (every condition must pass):

1. `dateCreated` is newer than `addDays(now; -2)` (recency).
2. `lower(title) + lower(description)` contains `lower(Company Name)` (relevance).
3. `contains(seenUrls; url)` equals `false` (cross-run dedup, the URL is not already in the Log).

Filtering before the classifier matters for the same reason as the n8n build: every Gemini call costs an operation, and an article that fails relevance would fail classification anyway, just more expensively.

---

## Classifier prompt (intent)

The classify step gets the company, sector, headline, and description and must return JSON only with three fields: `category` (exactly one of eight labels: Product Launch, Partnership, Funding, Leadership Change, Research Publication, Hiring Signal, Regulatory/Legal, Other), `funding` (a monetary amount in suffix notation or `N/A`), and `summary` (one to two factual sentences). JSON Output mode is on, so no markdown-fence stripping is needed once the model is right. The synthesize step gets the aggregated included signals as JSON and writes the briefing of at most five short paragraphs. Verbatim prompt text lives in the blueprint, not here.

---

## n8n vs. Make vs. Zapier

What the three-way build surfaced:

- **Structure.** Make maps to n8n almost one for one. A Make module is an n8n node, a Make route is an n8n IF branch, and a Make aggregator is an n8n Aggregate node. The relevance filter, the classifier, the per-route gating, and the dedup-by-array all have direct n8n equivalents. Zapier is the outlier of the three; its linear Zap model fights this kind of fan-out and per-route branching.
- **Cost model.** n8n self-hosted is effectively free per execution (you pay for the box). Make meters by operation, so every module run on every bundle counts; the pre-LLM relevance filter is doing double duty here as a cost control. Zapier meters by task in a similar spirit.
- **AI tooling.** Each platform got the AI that is idiomatic to it: Groq on the Claude Code n8n build, Exa plus an LLM on the manual n8n build, and Gemini here on Make. None of these is forced; each is a reasonable native choice on its platform, which is the point of building the same project three ways.

---

## Log pruning (companion scenario)

`P02-newsletter-prune-make.json` is a separate Make scenario that keeps the Log from growing unbounded, matching the n8n build's 7-day retention. Make allows only one trigger per scenario, so this can't be a disconnected branch on the newsletter canvas; it's its own scenario pointed at the same sheet, on its own daily schedule.

Two modules:

| Module | Type | Purpose |
|---|---|---|
| Search Rows | google-sheets:filterRows | Reads the Log tab, **ordered by `Logged` descending** |
| Delete a Row | google-sheets:deleteRow | Filter `Logged` *Earlier than* `addDays(now; -7)`; deletes by `{{__ROW_NUMBER__}}` |

The descending sort is the load-bearing detail. `Delete a Row` deletes by the live row index, so deleting top-down would renumber the rows still queued for deletion and clobber the wrong ones. Because the Log is append-only and chronological, the newest `Logged` value is also the highest row number, so ordering by `Logged` descending feeds Delete the highest row numbers first. That's bottom-up deletion with no separate sort module. `limit` is 1000, so a single run won't see Log rows beyond the first 1000; daily runs keep the Log well under that.

## Known issues and scope notes

- **Targets tested on three companies.** The scenario was validated against OpenAI, Hugging Face, and Anthropic. Re-populate the Targets tab with the full set before treating it as production.

---

## Post-import checklist

1. Map all three connections (Google Sheets, Gemini, Gmail) when Make prompts on import.
2. Set the real Sheet ID in Get Companies, Check_Log, and Log row (placeholder is `YOUR_GOOGLE_SHEET_ID`).
3. Confirm both Gemini modules have Response Format set to JSON Output where applicable (Classify yes; Synthesize is free text).
4. Set the recipient in the `Set recipientEmail` variable; both Gmail modules already read it via `{{3.recipientEmail}}`. Set each Gmail `from` to your own sender address.
5. Confirm the relevance filter on the link into Classify kept all three conditions after import.
6. Confirm both router filters survived: route 1 `length(included) > 0`, route 2 `length(included) = 0`.
7. Run once and confirm Google News RSS returns data (needs open outbound network; not testable in a GitHub-only sandbox).
