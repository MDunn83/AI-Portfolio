# Zapier Copilot Build: Meeting Intelligence Pipeline

This is my second build of the meeting minutes workflow, this time in Zapier, with Zapier Copilot (Zapier's built-in AI builder) doing the initial wiring. The goal is the same as the n8n version: a transcript goes in, and a summary email, a row in the log, and Google Tasks come out. Because Zapier works differently, I had to take different shortcuts and make different tradeoffs.

The n8n manual build is the reference, and this folder is for comparing the two side by side.

This is the v4 build. It covers Phase 1, the minimum working version, and Phase 2, which matches what the n8n build does and adds three layers of failure handling. `REQUIREMENTS.md` lists what each phase delivers, and `LESSONS.md` has my design notes.

---

## What It Does

When a new transcript row lands in a Google Sheet (via a connected Google Form), the Zap fires and runs:

1. One AI extraction step (GPT-4o-mini) that pulls summary, action items, decisions, open questions, and participants out of the transcript in a single call.
2. A Validate-and-Substitute Code step that checks each field for emptiness, substitutes `"unavailable"` when needed, and sets a `has_degradation` flag. Also normalizes the `action_items` format so the downstream Looping step works for single-item meetings.
3. A Code step that stamps today's date.
4. A 4-way Path branch:
   - **Path A** (📧): Recap email via Gmail. Only fires when no degradation.
   - **Path B** (📋): Append row to the meeting log Google Sheet, including the degradation flag.
   - **Path C** (✓): Loop through each action item and create one Google Task per item. Loop guard skips Path C if action items are malformed.
   - **Path D** (⚠️): Degradation alert email via Gmail. Only fires when at least one AI field came back empty.

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

As far as I could tell, Zapier doesn't have a node like n8n's that runs steps in parallel and then merges them. In v1, Copilot used a Path branch with `field iexist` filters instead, which sends the output of one step to several separate destinations.

In v4 I expanded that to four branches. Three of them do the actual work (email, log, and tasks), and the fourth sends an alert when something goes wrong. The Path filters now separate the branches that always run when there's a transcript (Paths B and C) from the ones that depend on whether any AI field came back empty (Paths A and D).

On cost, every path step and every action step counts as a Zapier task. A clean v4 run uses roughly 9 to 11 tasks, and a few more if Path C has several action items to loop through. The n8n version costs the same flat rate no matter what happens in the run.

---

## AI Model and Prompt

The model is GPT-4o-mini, through Zapier's built-in AI integration, so there's no separate API key to set up.

One AI step does all of the extraction, and the prompt follows the extraction rules in `../zapier-eval-build/extraction-rules.md`:

- **R1 action items** formatted as `- Owner: Task description (due date if stated)`.
- **R4 participants** preserved with exact spelling, including diacritics.
- **R5 side conversations** explicitly filtered (no birthday cake, no off-topic asides).
- **R6 due dates** preserved verbatim ("Friday after next" stays as written, not normalized to ISO).
- **"None"** returned as the literal string when a section is legitimately empty, so the downstream degradation detection doesn't false-positive.

I chose to simplify this from the n8n build, which runs four separate LLM chains in parallel. The reasons are in the "Platform-Native Tradeoffs" section of `REQUIREMENTS.md`.

---

## Failure Isolation (Three Layers)

In v4 I added three layers of protection around the AI step. The full story of why is under "Pushback 2" in `LESSONS.md`.

**Layer 1: Validate-and-Substitute.** A Code step after the AI checks all five fields. If a field is empty or only whitespace, it gets replaced with `"unavailable"`, and the `has_degradation` flag is set to true.

**Layer 2: Loop guard.** A filter before the Google Tasks loop only lets the run through if `action_items` contains `\n- `. If the AI's response is malformed, Path C gets skipped quietly instead of throwing an error.

**Layer 3: Degradation notification.** Path D runs when `has_degradation == true` and sends a Gmail alert with the full transcript and all five checked fields. On that same run, the recap email (Path A) doesn't go out, so the recipient never gets a half-broken summary.

---

## Email Output

Both emails (Path A recap and Path D alert) send via Gmail (`GoogleMailV2CLIAPI`).

**Path A, recap email format:**

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

**Path D, degradation alert format:**

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

Column G makes it easy to filter the sheet for runs where a field came back empty, without digging through Gmail.

---

## Data Source

This works the same way as the n8n build. A Google Form with one long-answer field labeled "Meeting Minutes" feeds a Google Sheet, and the trigger watches that sheet for new rows.

For testing, made-up transcripts work fine. Test transcripts T01 through T07 are in `../zapier-eval-build/`, and each one tests specific extraction rules.

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

Each place where the Zapier build differs was a choice I made on purpose, not something I couldn't match. The reasoning is in the "Platform-Native Tradeoffs" section of `REQUIREMENTS.md`.

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

- [Zapier](https://zapier.com): workflow automation with Copilot AI builder, Paths, Looping
- GPT-4o-mini (via Zapier's native AI integration): extraction
- Google Sheets: trigger and persistent log
- Google Tasks: action item capture
- Gmail: recap email and degradation alert delivery
