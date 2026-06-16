# CLAUDE.md

## MANDATORY: Read n8n_SKILL.md before doing anything else. Do not build until you confirm you have read it.
## GitHub MCP only. Do not run any local git commands. Do not touch the local machine.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read `REQUIREMENTS.md` for the goal, scope, functional and non-functional requirements, and acceptance criteria. Do not restate those here.

Read `BUILD_PROCESS.md` for the workflow architecture, node sequence, sheet schemas, prompt templates, email formats, Google Tasks spec, error handling, and credentials. Do not restate those here.

## What You Are Building

An n8n workflow JSON file that runs the full new-hire onboarding sequence from a single trigger. Output: one importable n8n workflow JSON file named `P05-onboarding-automation-claude-code.json`. There is no build system, no tests, and no dependencies; the output artifact is the JSON file itself.

## Credentials

Reference these exact credential names so n8n wires them on import. Full table in `BUILD_PROCESS.md`.

- Gmail: `Gmail OAuth2 API`
- Google Sheets: `Google Sheets OAuth2 API`
- Google Tasks: `Google Tasks OAuth2 API`
- Groq: `Groq account`

## Constraints

- GitHub MCP tools only. All file pushes go through `mcp__github__push_files`. Do not run `git` locally or modify files on the local machine.
- Target branch: `claude/new-hire-onboarding-workflow-cfqeZ` on `mdunn83/proj5_onboard_claude`.
- Use placeholder values for all sheet IDs and credential IDs. No live credentials, sheet IDs, or email addresses in the JSON.
- The workflow JSON must be valid and import into n8n without modification.
- Credentials are referenced by name, not ID. Use the exact names above.
- Validate the JSON is syntactically correct before writing the file.
