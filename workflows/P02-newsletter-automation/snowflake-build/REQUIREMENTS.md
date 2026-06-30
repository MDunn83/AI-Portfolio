# P02 Competitive Intelligence Monitor, Snowflake Build
## Requirements Document

Version 0.1 (spec, not yet built) | June 2026

---

## Goal

Take the working P02 monitor and move its data layer off Google Sheets and into a Snowflake warehouse, structured as a real ELT pipeline. The workflow logic stays the same: watch 10 AI companies, filter and classify the news, send one briefing a day. What changes is where the data lands and how it gets shaped:

1. Every article the workflow sees lands first in a raw, semi-structured landing zone (the lake), exactly as fetched, before anything is decided about it.
2. A SQL transform flattens, dedups, and types the raw rows into a modeled signal table (the warehouse). This is the T in ELT, run inside Snowflake.
3. Classification runs in-warehouse with Snowflake Cortex, so the LLM call happens against the data where it lives instead of round-tripping through an external API.
4. The daily briefing is a query against the modeled table. Retention is a scheduled delete.

The point is not to make the monitor better. It already works. The point is to rebuild the same pipeline on a warehouse stack so the data engineering pattern (landing zone, ELT transform, dimensional model, in-warehouse AI) is real and demonstrable.

---

## Scope

### In scope

- A three-layer schema in Snowflake: a RAW landing zone, a transform step, and a modeled CORE table.
- n8n writes raw fetched articles into the landing zone as semi-structured JSON (VARIANT).
- Cross-run deduplication done in SQL (MERGE on signal URL) instead of a JavaScript Set.
- Classification into the 8 existing signal types using Snowflake Cortex, with the Groq classifier kept as a documented fallback.
- The daily briefing query reads the modeled CORE table.
- 7-day retention enforced by a scheduled delete (a Snowflake Task, or a delete step in the run).
- All Snowflake objects created from a single setup script committed to this folder.

### Out of scope

- Changing the monitor's behavior: same 10 companies, same 8 categories, same $100M funding rule, same one-email-per-run guarantee.
- Replacing n8n. n8n stays the orchestrator; Snowflake is the data layer.
- Snowflake Streams and Tasks for change-data-capture beyond the single retention Task. Noted as a future extension, not required for v1.
- Multi-warehouse or multi-cluster sizing. An XS warehouse on the trial is the target.
- Any paid Snowflake tier. The build must fit inside the 30-day free trial credits.

---

## Functional Requirements

### FR1, Landing zone (the lake)

Articles that survive the relevance pre-filter are written to `RAW.SIGNAL_LANDING` as semi-structured rows: a VARIANT column holding the raw article object (company, title, URL, description, pub date) plus load metadata (load timestamp, source). The landing zone is append-only and schema-on-read. Nothing is dropped here; this is the complete record of what the workflow saw.

### FR2, Transform to the modeled table

A SQL transform reads the landing zone, flattens the VARIANT into typed columns, applies the 48-hour recency window, and MERGEs into `CORE.SIGNAL` keyed on `SIGNAL_URL`. Existing URLs are left untouched (this is the dedup); new URLs are inserted. The transform runs each pipeline run, before classification.

### FR3, In-warehouse classification

Each newly inserted CORE.SIGNAL row is classified into exactly one of the 8 signal types (Product Launch, Partnership, Funding, Leadership Change, Research Publication, Hiring Signal, Regulatory/Legal, Other) using `SNOWFLAKE.CORTEX.CLASSIFY_TEXT` or `SNOWFLAKE.CORTEX.COMPLETE`. The same call extracts any central funding amount and writes a 1 to 2 sentence summary. Results update the row in place.

### FR4, Inclusion rules (unchanged)

The existing rules carry over, expressed in SQL: `Other` is always excluded; `Funding` is included only when the parsed amount is at least 100 (millions); every other category is included regardless of amount. The `BRIEFING_INCLUDED` flag on CORE.SIGNAL is set by this rule.

### FR5, Briefing query and synthesis

The briefing reads the included signals for the current run window from CORE.SIGNAL and synthesizes them into a briefing of at most 5 paragraphs. Synthesis can run on Cortex (`COMPLETE`) or stay on Groq; both paths are documented. When no signals are included, the workflow falls through to the existing "no news" email path.

### FR6, Logging is the warehouse

CORE.SIGNAL is the log. Every classified article is a row, included or not, with the same fields the Google Sheets Log carried: company, title, URL, signal type, summary, pub date, logged timestamp, briefing-included flag, funding amount. There is no separate log sheet.

### FR7, Retention

Rows in CORE.SIGNAL older than 7 days are deleted on a schedule. The target is a Snowflake Task running a parameterized `DELETE`. A per-run delete step in n8n is an acceptable fallback if Tasks are not enabled on the trial. Safe for dedup because the fetch window is only 2 days.

---

## Non-Functional Requirements

### NFR1, Free trial only

Everything runs inside the Snowflake 30-day free trial ($400 in credits). An XS warehouse with auto-suspend at 60 seconds keeps credit burn near zero. Cortex token usage is capped by trimming article descriptions before classification, same discipline as the Groq build.

### NFR2, No hardcoded credentials or identifiers

No account locator, warehouse name, database name, username, password, or key pair appears in any committed file. Setup uses placeholders (`YOUR_SNOWFLAKE_ACCOUNT`, `YOUR_WAREHOUSE`, `CI_DB`, `CI_USER`). The n8n Snowflake credential is wired through n8n's credential manager.

### NFR3, Reproducible setup

All Snowflake objects (database, schema, warehouse, tables, the transform, the optional Task) are created by one idempotent SQL script committed to this folder. Running it on a fresh trial account stands the whole thing up.

### NFR4, Platform

n8n orchestrates; Snowflake is the data layer. The n8n Snowflake node executes all SQL. The deliverable is one importable workflow JSON plus the setup SQL.

---

## Acceptance Criteria

1. Running the setup SQL on a fresh trial account creates the warehouse, database, schema, both tables, the transform, and the retention Task with no manual edits beyond filling placeholders.
2. A pipeline run writes every relevance-passing article to RAW.SIGNAL_LANDING as a VARIANT row with load metadata.
3. The transform MERGE inserts only URLs not already in CORE.SIGNAL; a URL already present is not duplicated.
4. Every new CORE.SIGNAL row gets exactly one of the 8 signal types, a funding amount or N/A, and a 1 to 2 sentence summary, all produced by a Cortex call.
5. The briefing-included flag follows the existing rules: Other excluded, Funding included only at 100M or above, all other categories included.
6. A run with at least one included signal produces a 5-paragraph-or-fewer briefing from the warehouse query; a run with none still sends one "no news" email.
7. CORE.SIGNAL rows older than 7 days are gone after the retention step runs.
8. No committed file contains a live account identifier, credential, or warehouse name.

---

## Resume keywords this build earns (once actually built)

These become honest, claimable terms only after the build runs end to end, framed the same as every other portfolio project (personal build, Mark directed the architecture):

Snowflake, data warehouse, data lake / landing zone, ELT, semi-structured data (VARIANT), SQL MERGE, dimensional modeling, in-warehouse LLM (Snowflake Cortex), data pipeline, Snowflake Tasks.

---

## Reference

- Original P02 build and two-build comparison: `../README.md`, `../claude-code-build/REQUIREMENTS.md`
- Architecture, table DDL, and the n8n rewiring: `./BUILD_PROCESS.md`
- Setup and run instructions: `./README.md`
- Build directives: `./CLAUDE.md`
