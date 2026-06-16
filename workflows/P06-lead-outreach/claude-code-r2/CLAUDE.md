# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Before building, read `n8n_SKILL.md` for n8n-specific build rules.

Read `P6_Requirements.md` for the target persona, scoring thresholds, acceptance criteria, and out-of-scope boundaries. Do not restate those here.

Read `BUILD_PROCESS.md` for the workflow architecture, node table, technology choices, and credentials setup.

## What You Are Building

An n8n workflow JSON file that automates lead enrichment and outreach for AI workflow automation consulting. Output: a single importable n8n workflow JSON file named `P06-lead-outreach-claude-code-r2.json`.

## Constraints

- `active: false` in the exported JSON
- Use placeholder values (`SPREADSHEET_ID_PLACEHOLDER`, `CRED_ID_PLACEHOLDER`, etc.) for all IDs
- All company data must flow from the trigger node via cross-node references (`$('New Lead Added').first().json`) -- do not hardcode
- Gmail body must convert `\n` to `<br>` HTML tags
- Log sheet Recency column must use `$now` for timestamps
- Validate JSON is syntactically correct before writing the file

## Build Phases

Build and deliver in three phases. Stop after each phase and ask the user to confirm before continuing.

- **Phase 1:** Trigger through Summarizer LLM
- **Phase 2:** Scorer LLM
- **Phase 3:** Outreach, logging
