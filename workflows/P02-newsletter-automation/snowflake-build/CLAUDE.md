# CLAUDE.md

Directions for the AI building this. Nothing else lives here; the design lives in the three docs below.

## Read first

- `../../../reference/n8n_SKILL.md`, the n8n pre-build checklist (runtime lessons that prevent silent failures).
- `../../lessons_learned.md`, the cross-build lessons, including the "switch models before iterating on the prompt" rule, which applies to Cortex model choice too.
- `REQUIREMENTS.md`, goal, scope, functional and non-functional requirements, acceptance criteria.
- `BUILD_PROCESS.md`, schema layers, table DDL, the transform MERGE, the Cortex SQL, and exactly which n8n nodes change.

## What you are building

The P02 monitor with its data layer on Snowflake instead of Google Sheets: a RAW landing zone, a SQL transform that dedups and types into a CORE fact table, and classification run in-warehouse with Snowflake Cortex. n8n stays the orchestrator. `setup.sql` already stands up the Snowflake objects; the remaining deliverable is the updated workflow JSON wired to the Snowflake node.

## Hard constraints

- No account locators, warehouse names, usernames, passwords, or key pairs in any committed file. Placeholders only (`YOUR_SNOWFLAKE_ACCOUNT`, `CI_DB`, `CI_WH`, `CI_USER`). This folder syncs publicly on merge to `main`.
- Do not change the monitor's behavior: same 10 companies, 8 categories, $100M Funding rule, one-email-per-run guarantee.
- `setup.sql` must be idempotent (`CREATE ... IF NOT EXISTS`) and run clean on a fresh trial account.
- Every Cortex prompt that must return parseable output ends with the verbatim global rule in `../../lessons_learned.md`, and the parse is wrapped (`TRY_PARSE_JSON`) because LLM output is dirty even in-warehouse.
- If Cortex is unavailable in the trial region, take the documented Groq fallback; do not block the build on it.
- Build in phases (setup SQL, then land+transform nodes, then classify+flag, then read+retention). Push after each phase and stop for confirmation.

## Pointers

- Setup and run steps for a human: `README.md`.
- The original pipeline this mirrors: `../claude-code-build/`.
