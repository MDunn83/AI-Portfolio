# P02 AI Competitive Intelligence Monitor
## Requirements Document

Version 1.0 | June 2026

---

## Goal

Watch a fixed list of AI companies and get back, automatically, one email a day:

1. A synthesized briefing of at most 5 paragraphs covering the news that actually mattered.
2. A persistent log of every signal the workflow saw and what it decided to do with it.
3. One email every run, even on days when nothing survives the filters, so a quiet inbox always means "ran, found nothing" and never "broke."

No manual reading. No copy-paste. The workflow reads the company list from a Google Sheet, pulls the news, filters and classifies it, and sends the briefing on its own.

---

## Scope

### In scope

- Run on a 24-hour schedule (08:00 daily) for production, plus a manual trigger for testing.
- Read 10 companies and their search terms from a Google Sheet.
- Pull recent news per company from Google News RSS, no API key.
- Filter to recent, relevant articles before any LLM sees them.
- Classify each surviving article into one of 8 signal types and pull out any funding amount.
- Apply a $100M threshold so small funding stories drop out but other signal types pass on merit.
- Synthesize the included signals into a short daily briefing with a free-tier LLM.
- Email the briefing, or a short "no news" note, to a configured recipient.
- Log every signal to a Google Sheet, including the ones excluded from the briefing.
- Deduplicate across runs so the same article never gets reported twice.
- Prune log rows older than 7 days on every run.

### Out of scope

- Discovering companies on its own. The 10-company list is curated by hand in the sheet.
- Article full-text extraction. The workflow works off RSS titles and descriptions only.
- Removing duplicate articles within a single run. The same article can be a real signal for two companies, and the synthesizer consolidates it anyway.
- Real-time or polling-based monitoring. The workflow is schedule-based.
- Multi-user support. Single Google account, single recipient.
- Paid news APIs. The earlier manual build used Exa.ai and Jina; this build is constrained to free sources.

---

## Functional Requirements

### FR1 - Triggers

The workflow fires from either a Schedule Trigger (every 24 hours, 08:00 daily, for production) or a Manual Trigger (for testing). Both feed the same Config node, so the path downstream is identical.

### FR2 - Configuration

A Config node holds the recipient email address. Nothing downstream hardcodes a recipient; both email nodes read the address from Config.

### FR3 - Read the company list

Read all rows from the Targets sheet. Each company carries a search Anchor (a disambiguated Google News term) and a Sector. The Anchor builds the RSS query and also serves as a relevance alias; the Sector is passed to the classifier.

### FR4 - Fetch news

Build a Google News RSS query per company from the Anchor plus a `when:2d` recency window, then fetch the feed over HTTP. The fetch is throttled to one request at a time to avoid Google's rate-limit 403s. No API key.

### FR5 - Parse and pre-filter articles

Parse the RSS responses into articles, capped at 6 per company and limited to a 48-hour window. Re-attach each article to its company by response order. Then run a relevance pre-filter against the company name and Anchor before anything reaches the LLM, to shrink volume.

### FR6 - Cross-run deduplication

Before classifying, drop any article whose Signal URL already appears in the Log sheet. Dedup is cross-run only, keyed on Signal URL. Duplicates within the same run are kept on purpose.

### FR7 - Classification

Classify each surviving article into exactly one of 8 signal types: Product Launch, Partnership, Funding, Leadership Change, Research Publication, Hiring Signal, Regulatory/Legal, Other. The classifier also extracts any monetary amount central to the story (or N/A) and writes a 1-2 sentence summary. It returns raw JSON with `category`, `funding`, and `summary` fields.

### FR8 - Inclusion rules

Decide which classified signals belong in the briefing:

- `Other` is always excluded.
- `Funding` signals are included only when the extracted amount is at least $100M.
- All other categories (Partnership, Product Launch, and the rest) are included regardless of any dollar amount.

### FR9 - Synthesis

Collect the included signals and synthesize them into a single briefing of at most 5 paragraphs using a free-tier LLM. When no signals are included, skip synthesis and fall through to the "no news" path.

### FR10 - Email send

Send one email per run to the configured recipient. When there are included signals, send the synthesized briefing. When there are none, send a short "no news" note. Briefing text is sanitized into paragraphs and rendered with HTML line breaks for the email body.

### FR11 - Logging

Append a row to the Log sheet for every signal the workflow classified, whether or not it made the briefing. The row records company, title, URL, signal type, summary, publication date, log timestamp, a Yes/No for whether it was included, and any funding amount.

### FR12 - Log retention

On every run, prune Log rows older than 7 days. Since the news fetch window is only 2 days, a pruned row can never come back and reappear as a duplicate.

---

## Non-Functional Requirements

### NFR1 - Free or low-cost services

News comes from Google News RSS, which needs no API key. The LLM work runs on Groq's free tier: `llama-3.1-8b-instant` for classification and `llama-3.3-70b-versatile` for synthesis. Token volume is capped (descriptions trimmed to 800 characters before classification, combined text to 6000 characters before synthesis) to stay inside the free limits.

### NFR2 - One email per run

A run always ends in exactly one email, even when no news survives the funnel. The only exception is an empty Targets sheet, in which case nothing runs at all.

### NFR3 - No manual steps after trigger

Once a trigger fires, the workflow runs to completion without anyone touching it.

### NFR4 - No hardcoded credentials or IDs

Sheet IDs, the recipient email, and credential IDs are not baked into the exported JSON. The recipient lives only in the Config node as a placeholder; the sheet ID is a placeholder; credentials are wired through n8n's credential manager.

### NFR5 - Platform

Runs on n8n. The deliverable is a single importable n8n workflow JSON file.

---

## Acceptance Criteria

1. Either trigger fires the workflow and produces the same downstream behavior.
2. The workflow reads 10 companies from the Targets sheet and builds one RSS query per company from the Anchor.
3. News fetch runs one request at a time and does not trip Google's 403 rate limit on a normal run.
4. Articles older than 48 hours, or beyond 6 per company, do not reach the classifier.
5. An article whose Signal URL is already in the Log is not classified or re-sent.
6. Every classified article gets exactly one of the 8 signal types and a 1-2 sentence summary.
7. A Funding signal below $100M is excluded; a Funding signal at or above $100M is included.
8. An `Other` signal is always excluded; a non-Funding, non-Other signal is included regardless of dollar amount.
9. A run with at least one included signal sends a synthesized briefing of 5 paragraphs or fewer.
10. A run with no included signals still sends exactly one email (the "no news" note).
11. Every classified article produces a Log row, including excluded ones, with the Briefing Included flag set correctly.
12. Log rows older than 7 days are removed on each run.
13. The exported workflow JSON contains no live credentials, sheet IDs, or email addresses.

---

## Reference

- Two-build comparison: `../README.md`
- Claude Code build JSON: `./P02-newsletter-automation-claude-code.json`
- Architecture, schema, and design decisions: `./BUILD_PROCESS.md`
- Build directives for Claude Code: `./CLAUDE.md`
