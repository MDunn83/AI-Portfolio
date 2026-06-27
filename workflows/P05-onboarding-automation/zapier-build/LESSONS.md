# Lessons From the Employee Onboarding Build (Zapier)

I built an onboarding automation in Zapier: a new hire is added to a Google Sheet, and the Zap generates their onboarding content, emails the new hire and their manager, logs the run, and creates a Google Task for each manager action item. The build is short (9 steps) but a couple of the steps carry the real lessons.

---

## 1. One AI call, four outputs, two audiences

A single GPT-4.1 call with a defined output schema returns four fields at once: the welcome email, the 30/60/90 day plan, the manager action items, and the 30-day manager agenda. I don't make four calls. From that one generation, the new hire gets a warm welcome email and the manager gets a separate email with the action items and agenda. One generation, shaped differently for who is reading it. Cheaper, simpler, and the two messages stay consistent because they came from the same source.

## 2. Split the action list on its numbered markers, not on commas

The model returns the manager action items as a numbered list, and the items themselves contain commas ("Schedule a kickoff 1:1, review the plan, and set first-week goals"). My first instinct, splitting on commas, fragmented one action item into three. The Code step splits on the numbered markers ("1.", "2.") with a regex and ignores the commas inside each item. Parse on the structure the model actually produced, not on punctuation you assume separates items.

## 3. Gmail is HTML only, so preserve line breaks deliberately

The manager email renders the action items inside `<pre>` tags, replacing each newline with a `</pre><pre>` boundary (`Text.replace(..., String.fromCharCode(10), "</pre><pre>")`). Without it, the list collapses onto a single line. Gmail in Zapier sends HTML, not plain text, so any multi-line content needs its line breaks handled on purpose.

## 4. Let code do the date math, not the model

The 30/60/90 checkpoints and the task due dates are computed in the Code step from the start date with `datetime` and `timedelta`. I don't ask the model to add days to a date. Code doesn't get creative with a calendar; the model sometimes does.

## 5. Log the run and stamp the source row

The Zap writes a row to a log sheet (with a timestamp and status columns) and also updates the original new-hire row to mark it processed. The two-write pattern means the source sheet shows what's been handled and the log holds the history, so a re-run or a glance at the sheet both tell the truth.

## 6. Loop the parsed items into Google Tasks

The parsed action items become line items, and Zapier Looping turns each one into its own Google Task with a title, note, and due date. The parsing in lesson 2 is what makes this clean; if the split is wrong, the loop creates garbage tasks.

---

## Where It Stands

The build runs end to end on a synthetic new hire: content generated, both emails sent, run logged, tasks created. The fragile parts are all in the text handling (the action-item split and the HTML line breaks), which is the pattern across these AI-to-output builds: the AI call is easy, and the work is in shaping its output for the next step.
