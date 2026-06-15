# Lessons From the AI Governance Build

I built an AI governance pipeline in Zapier to understand what governance actually takes. Answer a question, classify the question and the answer separately, log all of it, and route anything sensitive to a human. Here's what I learned building it, including a few places where the obvious choice turned out to be the wrong one.

---

## 1. Webhook triggers miss rapid batch pastes

The Google Sheets new-row webhook doesn't reliably catch a fast batch paste. When I pasted 30 rows at once, the trigger missed events or batched them unpredictably. For single entries it's fine, and spacing pastes a couple of seconds apart works too. But if you need every row in a batch guaranteed, a polling trigger (Check Spreadsheet for Rows) catches them, at the cost of running a check every interval whether there's data or not.

## 2. Classify the input and the output separately

I classified the question and the answer independently, and that's the whole point. A STANDARD question can produce a SENSITIVE answer, and the reverse happens too. If I'd only classified the input, an AI response that leaked sensitive data on a harmless question would have sailed right through. For governance, never assume the input predicts the output. Classify both.

## 3. Fail closed

The Code step validates both classifications and overrides anything invalid to SENSITIVE, not STANDARD. If the model returns a malformed classification, defaulting to SENSITIVE means the bad case gets caught instead of slipping through. In a governance workflow, assuming risky by default beats assuming safe.

## 4. Log before you filter

The Audit Log captures all 30 queries no matter how they're classified. Logging happens before the routing and filtering, so if the governance logic ever breaks, I still have a complete record. The audit log should be comprehensive and never depend on the filter logic being correct.

## 5. Real-time alerts beat batched, at this volume

I went with one email per flagged query instead of a batched digest, after looking at what batching would cost in scheduler complexity. The tradeoff is that 30 flagged queries means 30 emails, but the reviewer sees each issue immediately. I'd only switch to batching if email fatigue became a real problem, somewhere north of 100 items a day.

## 6. Count tasks for everything, not just the actions

A scheduler-plus-table approach would have cost 96+ tasks a day just to check for new rows, even on a day with zero queries. The action steps aren't the only thing that burns tasks; monitoring and scheduling have their own hidden cost. I stuck with the webhook and per-query emails to avoid paying for checks that mostly find nothing.

## 7. Check which AI models your plan actually includes

I wanted to test Claude models, but they didn't have free credits on my plan. GPT-4.1 nano was included, so that's what I used. Don't assume every model is free; verify what your plan covers before you wire it in.

## 8. Control output format in the prompt first

Instead of adding a Formatter step to strip markdown out of the answer, I just told the AI not to use markdown. It listened. That's simpler than a transformation step. Try prompting for the format you want before you add a step to fix it after the fact.

## 9. OR logic in Zapier Paths needs different group IDs

The review Path uses four filter rules: query class is SENSITIVE, query class is UNCERTAIN, response class is SENSITIVE, response class is UNCERTAIN. To make those an OR instead of an AND, each rule goes in its own group. Same group ID is AND; different group IDs is OR. That one tripped me up until I sorted out the grouping.

## 10. Plain-text email timestamps need the inline formula syntax

`{{now()}}` didn't render in the Gmail plain-text body. Switching to `{{=utils.now()}}` fixed it. Plain-text bodies want the inline formula syntax, so check the field type before you pick how to reference a value.

---

## Where It Stands

What's solid right now:

- Fail-closed classification; invalid classes default to SENSITIVE.
- Complete audit log; nothing gets skipped.
- Question and answer classified independently.
- Real-time reviewer notification by email and sheet.
- Webhook trigger, so single entries cost almost nothing.
- Known batch limitation; rapid pastes need a couple of seconds of spacing.
- Handles medium volume, roughly 30 to 100 queries a day.

When to revisit: if flagged items pass 100 a day, it's worth reconsidering a time-based digest or a polling trigger with batching.
