# P01 Meeting Minutes Automation — Zapier Build

Requirements for rebuilding the existing n8n meeting intelligence pipeline as a Zapier Zap, in two phases.

- **Phase 1 — MVP.** Functional end-to-end pipeline using Zapier's idiomatic patterns (built-in AI, Paths for fan-out, Zapier outbound mail). Trades some n8n parity for build speed and platform simplicity. The Zapier Copilot v1 build delivers Phase 1.
- **Phase 2 — Functional equivalence.** Closes the meaningful gaps between the Zapier build and the n8n manual build on the outcomes that matter (per-action-item tasks, real Gmail sending, graceful degradation on AI failures). Phase 2 deliberately diverges from n8n implementation patterns where Zapier's native primitives produce a better result. The v4 build delivers Phase 2.

The n8n reference build lives in `../n8n-manual-build/`. This document defines what each Zapier phase must do, not how each Zap step gets configured.

---

## Goal

Paste a meeting transcript into a Google Form. Get back, within a couple of minutes:

1. A formatted email summarizing the meeting.
2. A row appended to a persistent Google Sheet log.
3. One Google Task per action item.

No manual note-taking. No copy-paste. The Zap runs end-to-end from a single form submission.

---

## Scope

### In scope (both phases)

- Trigger from a Google Form / Google Sheets row-add.
- AI-driven extraction of summary, action items, decisions, open questions / blockers / dependencies (QBD), and participants from the transcript.
- HTML email with all sections, sent to a configured recipient.
- Append to a persistent Google Sheet log.
- Google Tasks creation for action items.
- No hardcoded credentials, sheet IDs, task list IDs, or email addresses in committed JSON.

### Out of scope (both phases)

- Real-time meeting recording or transcription. Transcript text is the input.
- Calendar integrations (no auto-creating events, no parsing meeting invites).
- Slack, Teams, or any non-Google output channel.
- Editing or correcting transcripts after submission.
- Multi-tenant support. Single Google account, single user.

---

# Phase 1 — MVP Scope

The goal of Phase 1 is to prove the pipeline works end-to-end on Zapier with the minimum number of moving parts. Idiomatic Zapier patterns win over n8n parity where they conflict.

## Functional Requirements (Phase 1)

### P1-FR1 — Trigger

Zap fires when a new row is appended to the form-responses Google Sheet. The transcript text lives in a column named `Meeting Minutes`. Empty submissions must not fan out to all three destinations.

### P1-FR2 — Single AI extraction

One AI step pulls all five fields out of the transcript in a single call:

| Field | Output format |
|---|---|
| `summary` | 2 to 3 sentence overview of the meeting |
| `action_items` | Plain-text bulleted list, each line formatted `- Owner: Task description (due date if stated)` |
| `decisions` | Plain-text bulleted list, one decision per line |
| `open_questions` | Plain-text bulleted list of unresolved questions, blockers, or dependencies |
| `participants` | Comma-separated list of attendee names |

The prompt must explicitly require plain-text bullets, not JSON arrays, and instruct the model to start with the data (no preamble).

### P1-FR3 — Parallel fan-out via Paths

After the AI step, a Path branch fans out to email, log, and tasks simultaneously. Each path has a filter so empty transcripts short-circuit cleanly.

### P1-FR4 — Email via Zapier outbound mail

HTML email sent via Zapier's built-in mail service. Format:

```
Subject: Meeting Minutes - [submission date]

Meeting Summary
[summary paragraph]

Key Decisions
[bulleted list]

Action Items
[bulleted list with owners]

Open Questions / Blockers
[bulleted list]
```

### P1-FR5 — Append to log sheet

Append one row to the persistent meeting-log Google Sheet with columns: `Date | Participants | Summary | Action Items | Decisions | Open Questions`. The date is the submission date generated at runtime by a Code step.

### P1-FR6 — Single Google Task per run

Create one Google Task in a configured task list. The task title carries the full action-items bullet list; the task notes carry the submission timestamp.

## Non-functional Requirements (Phase 1)

### P1-NFR1 — Latency

End-to-end runtime, form submission to all three outputs delivered, within 2 minutes for a transcript of 2,000 words or fewer.

### P1-NFR2 — Zapier task cost

Target: under 10 tasks per run. Phase 1 build is approximately 7 tasks.

### P1-NFR3 — No hardcoded credentials

API keys, sheet IDs, email addresses, and task-list IDs supplied via Zapier's credential manager. Exported Zap JSON committed to this repo uses placeholders.

## Acceptance Criteria (Phase 1)

1. Submitting the form triggers the Zap within Zapier's standard polling window.
2. Within 2 minutes of trigger, an HTML email arrives with all four sections populated.
3. A new row appears in the log sheet with all six columns populated.
4. The configured Google Tasks list receives one new task containing the action items.
5. A transcript with no decisions completes successfully, with the Decisions section empty rather than producing a Zap error.
6. The exported Zap JSON contains no live credentials, sheet IDs, email addresses, or task list IDs.

## Phase 1 Status

**Delivered (v1).** The Zapier Copilot v1 build met all six criteria. See `LESSONS.md` for build notes.

---

# Phase 2 — Functional Equivalence Scope

The goal of Phase 2 is to close the gaps that affect outcomes, not to mirror n8n implementation details. Where a Zapier-native primitive produces a better result than the n8n pattern, the Zapier build uses the native pattern and documents why.

## Build Approach (Phase 2)

Phase 1 was Copilot-led: described the goal, accepted Copilot's architecture, verified the output.

Phase 2 flips that. Architecture decisions are made up front by reading these requirements; Copilot is used as the IDE that wires up each step against a spec that already exists. When Copilot suggests a different pattern than the one specced, push back rather than accepting. Document deviations in `LESSONS.md`; the deviations are the signal.

## Functional Requirements (Phase 2)

### P2-FR1 — One Google Task per action item

Replace the single-task-per-run pattern with one task per action item. Implementation:

- A Looping by Zapier step that splits the `action_items` field on the `\n- ` delimiter and iterates each item.
- Each task title carries the item text; notes carry the meeting timestamp.
- A loop guard filter (action_items contains `\n- `) prevents a malformed AI response from creating one giant garbage task.
- The upstream Validate step (see P2-NFR2) normalizes single-item responses so the delimiter always matches.

**Delivered (v4).** Note: this deliberately diverges from the n8n pattern (LLM Chain + Structured Output Parser + Split Out) in favor of a single Looping step that splits plain text. See "Platform-Native Tradeoffs" below.

### P2-FR2 — Gmail send

Replace Zapier outbound mail with Gmail integration so emails originate from the user's actual Gmail address.

**Delivered (v2).** Switched from `ZapierMailCLIAPI` to `GoogleMailV2CLIAPI`. Recap email and degradation alert both use Gmail.

### P2-FR3 — AI prompt aligned with eval extraction rules

The AI prompt must match the rules defined in `../zapier-eval-build/extraction-rules.md` so the eval harness measures the right thing. Specifically:

- R4 (participant exact spelling): preserve names verbatim including diacritics; do not anglicize.
- R5 (side conversation filter): exclude personal logistics, social asides, and off-topic comments from every field.
- R6 (due dates verbatim): preserve due dates as stated; do not normalize to ISO; omit dates that were not explicitly stated.
- "None" instead of empty when an entire section (action items, decisions, open questions) is legitimately empty. Distinguishes valid empty from AI degradation downstream.

**Delivered (v4).** Prompt rewritten to encode R4, R5, R6, and the "None" rule explicitly.

## Non-functional Requirements (Phase 2)

### P2-NFR1 — Latency

End-to-end runtime under 90 seconds for a 2,000-word transcript.

### P2-NFR2 — Failure isolation (three-layer)

When the AI step degrades (truncation, partial output, malformed bullets), the Zap continues running and surfaces the degradation rather than failing silently or producing garbage. Three layers:

**Layer 1: Validate-and-substitute.** A Code step after the AI step checks each of the five output fields. Empty or whitespace-only fields are replaced with `"unavailable"`. A `has_degradation` boolean flag is set true if any substitution occurred. The same step normalizes `action_items` for the downstream Looping by Zapier delimiter: split by newline, trim each line, drop any line that isn't a bullet (`- ...`), rejoin with `\n`. This keeps the loop from receiving phantom empty iterations that error Google Tasks creation with "Required field Title is missing."

**Layer 2: Loop guard filter.** Before the Google Tasks loop, a filter requires `action_items` to contain at least one `\n- ` delimiter. Malformed responses fail this check and skip Path C without erroring the Zap.

**Layer 3: Degradation notification path.** A fourth Path branch (Path D) fires when `has_degradation == true`. Sends a separate Gmail alert containing the run timestamp, the original transcript, and all five validated fields. Lets the operator catch degradations in real time without scanning Zap history.

The normal recap email (Path A) only fires when `has_degradation == false`, so the recipient never sees a partially-broken summary. The log sheet (Path B) writes regardless and includes the `has_degradation` flag in column G so degraded runs are searchable later.

**Delivered (v4).**

### P2-NFR3 — Eval harness coverage

The pipeline must be runnable through the eval harness defined in `../zapier-eval-build/` against test transcripts T01-T07 without code changes. The judge applies `extraction-rules.md` against pipeline output.

Deferred until Build 1 in `../../FUTURE_BUILDS.md` is built.

## Acceptance Criteria (Phase 2)

Phase 2 is done when Phase 1 acceptance criteria still pass AND:

1. A transcript with three action items produces three separate Google Tasks.
2. A transcript with one action item produces one Google Task (validates the loop normalization).
3. The summary email arrives from the configured Gmail address, not Zapier outbound.
4. A transcript that causes the AI to return an empty field triggers the degradation alert email AND skips the recap email, with the log row showing `has_degradation = true`.
5. A transcript with zero action items legitimately (T04-shaped retro) shows "Action Items: None" in the recap email and does NOT trigger Path D.
6. The exported Zap JSON contains no live credentials.

---

## Platform-Native Tradeoffs (Phase 2 design notes)

The Zapier build deliberately diverges from the n8n manual build in three places. Each divergence is a choice, not a shortcut.

### Tradeoff 1: Single AI call instead of four parallel chains

n8n runs four parallel LLM chains (summary, actions, decisions, QBD) then merges. Zapier doesn't have a parallel-then-merge primitive — true parallelism would require Sub-Zaps or Looping with extra orchestration. Cost: more steps, more tasks per run, more debugging surface.

The Zapier build uses one GPT-4o-mini call that returns all five fields. For transcripts under 2,000 words the single-shot call holds up. If quality regresses on long transcripts, reopen this decision; the four-chain pattern can be reintroduced as Sub-Zaps.

Why this is a real tradeoff, not a shortcut: a reviewer looking at four Sub-Zaps fanning out and merging on Zapier would conclude the engineer didn't know when to abandon a pattern that doesn't fit the platform.

### Tradeoff 2: Text-split Looping instead of structured output parsing

The original spec called for a second AI call (or Code step) to re-parse `action_items` into a structured JSON array, then iterate the array. n8n uses this pattern with its Structured Output Parser + Split Out.

The Zapier build uses Looping by Zapier with a `\n- ` text delimiter. One step instead of two. No re-parse hallucinations. Lower task cost. The tradeoff: requires the upstream prompt and the Validate step to guarantee `action_items` always starts with `\n- ` for any non-empty list.

Why this is better on Zapier: the structured-output approach burns an extra AI call and reintroduces the JSON-array failure mode the prompt explicitly avoids. Text-split is the idiomatic Zapier solution.

### Tradeoff 3: Submission date instead of transcript date

n8n extracts the meeting date from the transcript itself. The Zapier build stamps the submission date in a Code step.

Why: real meeting notes rarely include explicit dates in the transcript. Extracting "meeting date" would add an AI extraction step that fires 100% of runs to capture a value 10% of runs actually contain. The Zap triggers on form submission, which happens the same day the notes are written for any realistic use, so submission date is functionally equivalent for the use case. Time-of-day precision is not needed for the recap or the log.

### Tradeoff 4: GPT-4o-mini (Zapier native) instead of Groq

n8n uses Groq `llama-3.1-8b-instant` via BYO API key. The Zapier build uses Zapier's native GPT-4o-mini.

Why: zero credential setup, no BYO API key configuration, and GPT-4o-mini quality is acceptable for transcripts at this length. If a documented cost or latency gap emerges, swap in Groq via BYO key — the prompt and output schema don't change.

---

## Reference

- n8n manual build: `../n8n-manual-build/`
- n8n Claude Code build: `../claude-code-build/`
- n8n README (source of truth for the original pipeline): `../n8n-manual-build/README.md`
- Eval harness build spec: `../zapier-eval-build/`
- Future builds: `../../FUTURE_BUILDS.md`
- Zapier Copilot build artifacts: `README.md`, `LESSONS.md`, `P01-meeting-minutes-automation-zapier-copilot.json` in this folder
