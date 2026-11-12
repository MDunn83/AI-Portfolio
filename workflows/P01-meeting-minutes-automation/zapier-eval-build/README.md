# Zapier Eval Build: Meeting Minutes Pipeline

This folder is where I'm building a way to test the Zapier meeting minutes build, and it's listed as Build 1 in `../../FUTURE_BUILDS.md`. Right now it holds the test data and the extraction rules, and the Zap that runs the tests comes next.

The plan is to take a fixed set of meeting transcripts where I already know the right answers and run them through the pipeline. Then an LLM judge scores each field of the output against the extraction rules. I'll log the scores over time, so that if a change makes the pipeline worse, the scores will drop and show me.

---

## Folder Structure

```
zapier-eval-build/
├── README.md              # This file
├── extraction-rules.md    # R1-R6: the spec the ground truth follows
├── T01.md                 # Short clean standup (baseline)
├── T02.md                 # Long messy quarterly planning
├── T03.md                 # Discovery meeting (no decisions)
├── T04.md                 # Retro (no action items)
├── T05.md                 # International sync (weird names)
├── T06.md                 # Sprint planning (ambiguous due dates)
└── T07.md                 # Filter test (side conversation)
```

Each T0X file has the transcript, the correct answers for all five output fields (summary, action items, decisions, open questions, and participants), and a note on which extraction rules it mainly tests.

`extraction-rules.md` defines what counts as an action item, a decision, an open question, a participant, a side conversation, and a due date. Every T0X file follows the same rules, and when I change the rules, I bump the version number and recheck the correct answers.

---

## How to Load Test Data Into Google Sheets

Create a sheet with these columns:

| Col | Header | Content |
|---|---|---|
| A | `transcript_id` | T01, T02, ... |
| B | `category` | What edge case the transcript tests (from each T0X header) |
| C | `rules_tested` | Comma-separated rule IDs from each T0X |
| D | `transcript_text` | The full transcript (paste the code block contents) |
| E | `gt_summary_points` | Ground truth summary points (newline-separated) |
| F | `gt_action_items` | Ground truth action items (newline-separated) |
| G | `gt_decisions` | Ground truth decisions (newline-separated) |
| H | `gt_open_questions` | Ground truth open questions (newline-separated) |
| I | `gt_participants` | Ground truth participants (comma-separated) |
| J | `gt_filter_check` | Negative ground truth for T07; empty for other rows |

Paste each T0X file into its own row. For cells with several lines, paste the whole block, and Sheets will keep the line breaks.

The eval Zap will add its own runtime columns later (model output per field, judge score per field, run timestamp, rules version in effect).

---

## How the Judge Should Score

The judge doesn't compare the model's output to the correct answers word for word. It checks whether the output follows the same rules the correct answers were written with. I paste `extraction-rules.md` into the judge's system prompt and ask it to score each output field on these:

**Strict criteria (score affects pass/fail):**
- Recall: is every ground-truth item represented in the model's output?
- Precision / no hallucination: does the model's output contain items not in the ground truth?
- Owner assignment: are action item owners correct?
- Date capture: are due dates preserved as written when present?
- Filter compliance (T07 specifically): are any filter-check items present?

**Loose criteria (don't penalize):**
- Exact wording. "Tanya will email Mei" and "Tanya: reach out to Mei in customer success about onboarding changes" are semantically equivalent.
- Order of items within a list.
- Style of bullet formatting (dashes vs asterisks vs numbers).

---

## Adding More Test Cases

If a real pipeline run surfaces a failure mode none of T01-T07 covers, add a T08 file modeled on the existing ones. Each new file should:

1. Name the category (what failure mode it exposes).
2. List the rule IDs it tests.
3. Include a transcript that genuinely exercises those rules.
4. Provide ground truth derived from applying the rules to the transcript, not from intuition.

If adding the transcript would require a new rule, update `extraction-rules.md` first, bump the version, and note the change in the rules file before labeling.

---

## Reference

- The pipeline under test (Phase 1): `../zapier-copilot-build/`
- Build spec: `../../FUTURE_BUILDS.md`
- Extraction rules: `extraction-rules.md`
- Test transcripts: `T01.md`–`T07.md` (these started as one `synthetic-transcripts.md` file that I later split, and `git log` has that history)
