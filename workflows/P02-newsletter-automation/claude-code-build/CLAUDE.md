# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

Read `n8n_SKILL.md` completely before writing or editing any node JSON. It encodes runtime lessons that prevent workflows that import but fail silently.

Read `REQUIREMENTS.md` for the goal, scope, functional and non-functional requirements, and acceptance criteria. Do not restate those here.

Read `BUILD_PROCESS.md` for the workflow architecture, node table, sheet schemas, technology choices, credentials, classifier prompt, and the architectural decisions with their rationales.

## What You Are Building

A single n8n workflow that produces a synthesized daily AI-industry newsletter: reads 10 companies from a Google Sheet, pulls recent news per company, filters and classifies it, logs every decision, and emails a briefing of at most 5 paragraphs. Runs every 24 hours. Output: one importable workflow JSON file (`P02-newsletter-automation-claude-code.json`).

## Constraints

- Use placeholder values for all IDs: `YOUR_GOOGLE_SHEET_ID` for the sheet, placeholders for credential IDs.
- The recipient email lives only in the Config node, never hardcoded downstream. Both Gmail nodes read `={{ $('Config').first().json.recipientEmail }}`.
- All company data flows from the trigger and sheet reads via cross-node references; do not hardcode it.
- Every LLM prompt ends with the verbatim global prompt rule in `BUILD_PROCESS.md`.
- The Log Logged column uses `={{ $now.toISO() }}` for timestamps.
- Gmail body must render newlines as HTML line breaks (Sanitize Text emits the `html` field).
- Validate JSON is syntactically correct before writing the file.
