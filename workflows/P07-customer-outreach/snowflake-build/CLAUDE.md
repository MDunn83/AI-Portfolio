# CLAUDE.md

Directions for the AI building this. The design lives in the docs below.

## Read first

- `../../../reference/n8n_SKILL.md`, the n8n pre-build checklist.
- `../../lessons_learned.md`, cross-build lessons (date handling, "pass calculated values not raw inputs," test-data discipline).
- `REQUIREMENTS.md`, goal, scope, the four triggers, suppression, acceptance criteria.
- `BUILD_PROCESS.md`, the dimension/fact model, the trigger view SQL, and exactly which n8n nodes change.

## What you are building

The P07 pipeline with its data layer on Snowflake: a `CORE.CUSTOMER` dimension, a `CORE.ACTIVITY_LOG` append-only audit fact, and a `CORE.V_CUSTOMER_TRIGGER` view that does the 7-day suppression and the priority cascade in SQL. n8n reads the view, keeps the per-category prompts, and writes back. `setup.sql` already stands up the tables and view; the remaining deliverable is the updated workflow JSON.

## Hard constraints

- No account locators, warehouse names, usernames, passwords, or key pairs in any committed file. Placeholders only. This folder syncs publicly on merge to `main`.
- Do not change pipeline behavior: same four triggers, same priority order, same 7-day cooldown, same per-category prompts and fixed subjects, one email per customer per run.
- The suppression window and priority cascade live in the view, not in n8n Code nodes. n8n branches on `TRIGGER_TYPE`; it does not re-derive the decision.
- Parameterize the INSERT and UPDATE; never string-build SQL with customer fields (apostrophes in names will break it).
- Recipient email comes from the customer row, never hardcoded.
- Keep the email generation in n8n for v1. Cortex generation is an optional later extension, not part of this build.
- Build in phases (setup SQL and seed, then view read + branching, then email + audit insert, then last-contacted write-back). Push after each phase and stop for confirmation.

## Pointers

- Setup and run for a human: `README.md`.
- Shared Snowflake account setup: `../../P02-newsletter-automation/snowflake-build/README.md`.
- The original pipeline this mirrors: `../claude-code-build/`.
