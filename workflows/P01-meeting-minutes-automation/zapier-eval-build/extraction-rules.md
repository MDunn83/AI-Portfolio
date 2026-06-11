# Extraction Rules

The spec the ground truth in T01-T07 follows. These rules define what counts as each output type so the labels are consistent across the test set and reproducible by anyone who picks the project up later.

Without rules, ground truth is just one person's opinion of what should come out of a transcript. With rules, ground truth is "what the rules say when applied to this transcript," which is much harder to argue with. The eval judge should be prompted with these rules so it scores the model against them, not against label-matching.

---

## R1 — Action Items

An item counts as an action item if and only if all three are present:

1. **An owner.** A named person, or "we" when the context makes the responsible team obvious. If ownership is genuinely ambiguous, the item is not yet an action item.
2. **A future-tense actionable verb.** "Will", "going to", "plan to", "let me", or an imperative direction. Past-tense work doesn't qualify.
3. **A deliverable.** Something specific that gets produced, sent, completed, or decided. "Look into" without a deliverable doesn't qualify.

**Qualifies:**
- "Mike: I'll start on the profile page tomorrow." (owner + future verb + deliverable)
- "Sarah: I'll ping the research team today." (same)
- "David: Maya, send me your justification doc by next Tuesday." (assigned owner + imperative + deliverable)

**Does not qualify:**
- "Mike: I shipped the login bug fix yesterday." (past tense, status update)
- "We should probably look at the slow search results." (no clear owner, no deliverable)
- "It might be worth doing a competitive scan." (provisional, no owner)

---

## R2 — Decisions

An item counts as a decision if it's stated in final, committing language:

- "We're going to..."
- "Let's lock that in."
- "Decision is..."
- "Agreed."
- "OK, [X] is a yes."
- Explicit deferral or cancellation ("we're deferring X to next sprint", "we're cutting X").

**Does not qualify (provisional language):**
- "Maybe we should..."
- "I'm thinking about..."
- "We might want to..."
- "Could we...?"
- "What if we...?"

If the transcript shows a topic being discussed but never resolved with committing language, that's an open question (R3), not a decision.

---

## R3 — Open Questions, Blockers, and Dependencies

Anything where the transcript shows explicit unresolved uncertainty:

- Stated open questions ("Open question — should we...?", "I don't know yet.").
- Acknowledged unknowns ("TBD", "we need to figure out", "genuinely not sure").
- Stated blockers preventing progress ("we can't ship until X").
- Stated dependencies waiting on external input ("waiting on legal", "depends on what finance says").

**Don't infer questions the model thinks should have been asked but weren't.** R3 captures uncertainty the transcript itself surfaces, not uncertainty a reader might project onto the meeting.

---

## R4 — Participants

Every person named as a speaker in the transcript. Rules:

- **Exact spelling.** Preserve the spelling as written. The pipeline must not anglicize, normalize, or simplify names. "Søren" is not "Soren". "Niamh" is not "Niav".
- **Order doesn't matter.** Any consistent order is fine (alphabetical, order of speaking, whatever the pipeline produces).
- **Speakers only.** People mentioned but not present in the meeting (e.g., "I'll talk to Mei about it") are not participants.

---

## R5 — Side Conversation Filter

Any topic clearly outside the meeting's stated purpose is filtered out of every output field, even when the language matches an action item or decision pattern.

**The test:** would this item appear in a recap email to the team's manager? If the answer is obviously no, it's filtered.

**Examples that get filtered:**
- Birthday parties, weekend plans, personal chitchat.
- Food orders, coffee runs, cake pickups.
- Off-topic gossip even when it includes commitments ("I'll text you about the party").

**Examples that don't get filtered (still real work):**
- A short tangent about a related work topic that loops back to the agenda.
- A commitment about scheduling a follow-up work meeting.

The filter rule is the hardest of the six to apply because LLMs love structure and will happily turn "I'll bring the cake" into a clean action item. Score this rule strictly.

---

## R6 — Due Dates and Time References

When an action item includes a due date, capture the date language **exactly as stated in the transcript**. Don't normalize to ISO format — that's the pipeline's job downstream, not the extraction step's.

**Qualifies (preserve as written):**
- "by Friday"
- "end of sprint"
- "before the demo on the 15th"
- "tomorrow"
- "next Tuesday"
- "ASAP"
- A specific date like "August 5th"

**If no date is stated**, omit the field rather than invent one. The pipeline should not guess "by end of week" because that feels reasonable; it should leave the date empty.

---

## How to Use These Rules

When labeling ground truth for a new transcript, walk through each rule in order:

1. **R4 first.** List the participants.
2. **R1 next.** Find every candidate action item. Apply the three-part test (owner, future verb, deliverable). Reject the ones that don't pass.
3. **R2.** Find every decision candidate. Apply the final-language test. Reject provisional language.
4. **R3.** Find every open question, blocker, or dependency the transcript itself surfaces.
5. **R5 throughout.** As you label, ask the recap-email test on anything borderline. Reject side conversation.
6. **R6 during R1.** Capture date language verbatim on action items where it appears.

When prompting the judge, paste these rules into the system prompt verbatim and ask the judge to score whether the model's output applied each rule correctly. The judge isn't matching the model's output to the labels; it's checking whether the model and the labels both follow the same rules.

---

## Rule Versioning

These rules are v1. If you tighten or relax a rule based on what the eval surfaces, bump the version and note the change. The score history in the eval log should record which rules version was in effect, so a regression in scores after a rule change is recognizable as the rule change rather than a model regression.
