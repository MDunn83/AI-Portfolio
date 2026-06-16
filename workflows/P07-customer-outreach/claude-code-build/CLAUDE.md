# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read `n8n_SKILL.md` completely before writing any node JSON. It encodes runtime lessons; breaking its rules produces workflows that import but fail silently.

Read `LESSONS_LEARNED.md` before building. It captures the issues and fixes found during the original build of this workflow.

Read `REQUIREMENTS.md` for the goal, scope, category logic, and acceptance criteria. Do not restate those here.

Read `BUILD_PROCESS.md` for the node sequence, sheet schemas, credentials, subject lines, and per-category prompt guidance. Do not restate those here.

## What You Are Building

An n8n workflow JSON file that watches a customer database and sends a personalized, AI-written email when a customer hits one of four behavioral triggers. Output: a single importable n8n workflow JSON file.

## Constraints

- GitHub MCP tools only. All file pushes go through `mcp__github__push_files`. Do not run `git` locally or modify files on the local machine. Trust the MCP push response rather than reading files back to verify.
- Target branch: `claude/plan-n8n-outreach-PKA07` on `mdunn83/proj7_outreach_claude`.
- The workflow JSON must be valid and importable into n8n without modification.
- Use the placeholder `YOUR_GOOGLE_SHEET_ID` for the sheet ID. Pull the recipient email dynamically from the customer row; never hardcode an address.
- After each build phase, push to GitHub and stop. Wait for explicit confirmation before the next phase.
- If you are unsure how to implement a node or connection, stop and ask rather than guessing.

## Build Phases

Build in three or four phases to stay within token limits. Do not generate the full workflow JSON in one response. End each phase with a GitHub push, then wait for confirmation before continuing.
