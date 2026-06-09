# Zapier Copilot Build — Meeting Intelligence Pipeline

A second build of the meeting minutes workflow, this time on Zapier, with Zapier Copilot (Zapier's built-in AI builder) doing the wiring. Same goal as the n8n version: paste a transcript in, get a summary email, a logged row, and Google Tasks out. Different platform, different shortcuts, different tradeoffs.

The n8n manual build is the reference. This folder is a side-by-side comparison.

This is the v4 build, which covers both Phase 1 (MVP) and Phase 2 (functional equivalence with three-layer failure isolation). See `REQUIREMENTS.md` for what each phase delivers and `LESSONS.md` for the design notes.

---

## What It Does

When a new transcript row lands in a Google Sheet (via a connected Google Form), the Zap fires and runs:

1. One AI extraction step (GPT-4o-mini) that pulls summary, action items, decisions, open questions, and participants out of the transcript in a single call.
2. A Validate-and-Substitute Code step that checks each field for emptiness, substitutes `"unavailable"` when needed, and sets a `has_degradation` flag. Also normalizes the `action_items` format so the downstream Looping step works for single-item meetings.
3. A Code step that stamps today's date.
4. A 4-way Path branch:
   - **Path A** (📧) — Recap email via Gmail. Only fires when no degradation.
   - **Path B** (📋) — Append row to the meeting log Google Sheet, including the degradation flag.
   - **Path C** (✓) — Loop through each action item and create one Google Task per item. Loop guard skips Path C if action items are malformed.
   - **Path D** (⚠️) — Degradation alert email via Gmail. Only fires when at least one AI field came back empty.

---

## Architecture

```
Google Sheets trigger (new row from form)
  → AI extraction (GPT-4o-mini, single call → 5 fields)
      → Validate-and-Substitute (substitute empties, set degradation flag,
                                  normalize action_items delimiter)
          → Code step (generate today's date as MM/DD/YYYY)
              → Paths (4-way fan-out)
                  → Path A: Recap email via Gmail (only if has_degradation = false)
                  → Path B: Append row to meeting log (always when transcript exists)
                  → Path C: Loop → loop guard → Create one Google Task per action item
                  → Path D: Degradation alert via Gmail (only if has_degradation = true)
```

---

## How Parallel Branches Work in Zapier

Zapier doesn't have an n8n-style parallel-then-merge node. The pattern Copilot used in v1 was a Path branch with `field iexist` filters, which gives the effect of a fan-out from one upstream step to multiple independent destinations.

The v4 build extends that pattern to four branches: three productive (email, log, tasks) and one defensive (degradation alert). Path filters now distinguish between "always fire when transcript exists" (Paths B and C) and "fire conditionally on degradation state" (Paths A and D).

Cost note: each path step and each action step counts as a Zapier task. A v4 run consumes roughly 9-11 tasks on a clean run, slightly more if Path C iterates multiple action items. The n8n version is flat-rate per run.

---

## AI Model and Prompt

GPT-4o-mini via Zapier's native AI integration. No external API key required.

A single AI step does all the extraction work. The prompt encodes the extraction rules defined in `../zapier-eval-build/extraction-rules.md`:

- **R1 action items** formatted as `- Owner: Task description (due date if stated)`.
- **R4 participants** preserved with exact spelling, including diacritics.
- **R5 side conversations** explicitly filtered (no birthday cake, no off-topic asides).
- **R6 due dates** preserved verbatim ("Friday after next" stays as written, not normalized to ISO).
- **"None"** returned as the literal string when a section is legitimately empty, so the downstream degradation detection doesn't false-positive.

This is a deliberate simplification from the n8n build, which runs four separate LLM chains in parallel. See `REQUIREMENTS.md` "Platform-Native Tradeoffs" for why.

---

## Failure Isolation (Three Layers)

The v4 build adds defensive layers around the AI step. See `LESSONS.md` "Pushback 2" for the full story.

**Layer 1: Validate-and-Substitute.** A Code step after the AI checks all five fields. Empty or whitespace-only fields are replaced with `"unavailable"` and a `has_degradation` flag is set true.

**Layer 2: Loop guard.** A filter before the Google Tasks loop requires `action_items` to contain `\n- `. Malformed responses skip Path C silently without erroring.

**Layer 3: Degradation notification.** Path D fires when `has_degradation == true`. Sends a Gmail alert with the full transcript and all five validated fields. The recap email (Path A) is suppressed on the same run so the recipient never sees a half-broken summary.

---

## Email Output

Both emails (Path A recap and Path D alert) send via Gmail (`GoogleMailV2CLIAPI`).

**Path A — Recap email format:**

```
Subject: Meeting Minutes - [MM/DD/YYYY]

Meeting Summary
[summary paragraph]

Key Decisions
[bulleted list]

Action Items
[bulleted list with owners and due dates if stated]

Open Questions / Blockers
[bulleted list]
```

**Path D — Degradation alert format:**

```
Subject: ⚠️ AI Step Degraded - Missing Data in Run [timestamp]

[Alert intro]
[Possible causes]

Transcript / Input:
[full original transcript]

Validated Output (with degradation):
- Summary: ...
- Action Items: ...
- Decisions: ...
- Open Questions: ...
- Participants: ...
```

---

## Log Sheet Structure

One row per meeting, appended to a separate Google Sheet:

| Column | Content |
|---|---|
| A | Date (generated at runtime by the Code step) |
| B | Participants |
| C | Summary |
| D | Action Items |
| E | Decisions |
| F | Open Questions |
| G | `has_degradation` flag (true / false) |

Column G lets you filter the sheet for degraded runs without scanning Gmail.

---

## Data Source

Same as the n8n build: a Google Form with a single long-answer field labeled "Meeting Minutes" feeds a Google Sheet. The trigger watches that sheet for new rows.

For testing, synthetic transcripts work fine. Test transcripts T01-T07 live in `../zapier-eval-build/` and exercise specific extraction rules.

---

## Differences from the n8n Build

| Concern | n8n manual build | Zapier v4 build |
|---|---|---|
| AI calls | 4 parallel LLM chains | 1 call returning all 5 fields |
| AI model | Groq `llama-3.1-8b-instant` | GPT-4o-mini (Zapier-native) |
| Action items → Tasks | One Google Task per item via Structured Output Parser + Split Out | One Google Task per item via Looping by Zapier with `\n- ` text delimiter |
| Meeting date | Extracted from transcript | Submission date (Zap triggers same day as notes) |
| Email sender | Gmail | Gmail |
| Failure isolation | None | Three layers: validate, loop guard, degradation alert |
| Parallel execution | True parallel via 4 chains + Merge | Sequential AI, then 4-way Paths fan-out |
| Cost model | Flat per-run | ~9-11 Zapier tasks per run |

See `REQUIREMENTS.md` "Platform-Native Tradeoffs" for why each Zapier-side divergence is a deliberate choice rather than a parity gap.

---

## Setup

### Prerequisites
- Zapier account (any paid plan that supports multi-step Zaps, Paths, and Looping)
- Google account with Sheets, Gmail, and Tasks access
- A Google Form connected to a Google Sheet for transcript intake
- A separate Google Sheet for the persistent log (pre-populate column headers including `has_degradation` in column G)
- A Google Tasks list to receive action items

### Step 1: Import the Zap
Use Zapier's import feature on `P01-meeting-minutes-automation-zapier-copilot.json`.

### Step 2: Connect credentials
The exported JSON has placeholders for sensitive values. After import, Zapier will prompt you to connect:
- Google Sheets (used by the trigger and the log append step)
- Google Tasks
- Gmail (used by both Path A and Path D)
- Zapier's AI step uses Zapier's built-in OpenAI integration with no setup

### Step 3: Replace placeholders
Open each step and replace:
- `YOUR_FORM_SHEET_ID` → your form responses spreadsheet
- `YOUR_LOG_SHEET_ID` → your meeting log spreadsheet
- `YOUR_TASK_LIST_ID` → your Google Tasks list
- `YOUR_EMAIL_FROM` → your Gmail address (used as the From field)
- `YOUR_EMAIL_TO` → the recipient address for both recap and alert emails

### Step 4: Publish and test
Submit a transcript through the Google Form. Use the Zap history to watch the run.

For a clean run, you should see Paths A, B, and C fire. For a transcript that causes the AI to truncate or return empty fields, you should see Paths B and D fire (and Path C may or may not fire depending on whether the action_items field was the one that degraded).

---

## File Structure

```
zapier-copilot-build/
├── P01-meeting-minutes-automation-zapier-copilot.json  # Zap export, credentials scrubbed
├── REQUIREMENTS.md                                      # Phase 1 + Phase 2 spec
├── LESSONS.md                                           # Build notes and design pushbacks
└── README.md                                            # This file
```

---

## Built With

- [Zapier](https://zapier.com) — workflow automation with Copilot AI builder, Paths, Looping
- GPT-4o-mini (via Zapier's native AI integration) — extraction
- Google Sheets — trigger and persistent log
- Google Tasks — action item capture
- Gmail — recap email and degradation alert delivery
