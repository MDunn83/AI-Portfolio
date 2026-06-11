# Lessons From the Zapier Copilot Build

I built the meeting minutes pipeline a second time, this time in Zapier, with Zapier Copilot (their built-in AI builder) doing most of the wiring. Phase 1 took about 45 minutes of hands-on time. Phase 2 took another couple of sessions to close the gaps that actually matter.

This is the writeup of what worked, what tripped me up, and where I overrode Copilot's defaults.

---

## Phase 1: Copilot-Led Build

### What Worked

**Building inside the platform.** Zapier Copilot is good. I described what I wanted, it laid out the steps, and the heavy wiring was already done by the time I started checking the details. Cool that I could build this through AI inside Zapier itself, rather than a separate IDE.

**Credentials were a non-issue.** Both Google Sheets and Google Tasks connected in one click. No client IDs, no consent screens to debug. This was the biggest day-one friction point on my n8n build, and Zapier just handled it.

**GPT-native with options.** Zapier ships with about 17 models out of the box and lets you bring your own API key for anything else. For this build I used GPT-4o-mini and didn't need to leave the platform.

**Single-shot extraction held up.** I had Copilot produce one AI call that returns all five fields instead of the four parallel chains my n8n build runs. For a synthetic meeting transcript at this length, it works. Whether it holds up on a long, messy real transcript is the next test.

### Where I Leaned on n8n Knowledge

Two of the three biggest snags Zapier Copilot's own writeup celebrated as "lessons learned" were not new to me. I had already worked through them in n8n.

**Bullets, not JSON arrays.** The first AI prompt returned `["task 1 - Owner", "task 2 - Owner"]`. I recognized the shape immediately; the LLM is doing what it thinks "structured" means. The fix is the same one I used in n8n: rewrite the prompt to ask for plain-text bullets and to start the response with the data, not a preamble.

**Sheets won't stamp today's date for you.** Same gotcha I hit in n8n; the Sheets node will insert whatever you give it, but it won't fill in a "today" value on its own. The fix is a small Code step that generates `MM/DD/YYYY` and feeds it into the row.

The takeaway: a second build on a new platform is dramatically faster when you've already mapped the failure modes once.

### What Was New for Me

**Paths is the workaround for parallel fan-out.** Zapier doesn't have an n8n-style "merge" node. To fan out the AI output to three destinations at once, Copilot used a 3-way Path with an always-true filter (`field iexist`) on each branch. Clean trick.

**Path filters need real field keys.** Early versions of the path conditions failed silently because the field references were abstract. The fix was to use the actual trigger field key from the Zap output with a simple `iexist` match. If a path isn't firing in test, that's the first place to look.

**"Test run" is hidden in plain sight.** I spent a while looking for a way to manually fire the Zap. I was pasting test rows into the responses sheet to force the trigger, which works but feels silly. Eventually found a "Test run" button in the editor.

**Task budget matters.** Each step in a Zap is one task. A single Phase 1 run consumes around 7 tasks. n8n is flat-rate per run. For a low-volume use like this it's fine; for something firing hundreds of times a day, it's the first thing to look at.

---

## Phase 2: I Drive, Copilot Wires

Phase 1 was Copilot-led. Phase 2 is where I made the design decisions up front and used Copilot as the IDE.

The signal in Phase 2 is the pushback. Every place where I overrode a default is a place where the build shows judgment. Here are the three that mattered.

### Pushback 1: Text-split Looping beats structured output parsing

The original spec called for a second AI call to re-parse `action_items` into a structured JSON array, then iterate the array with Looping by Zapier. That mirrors what my n8n build does (LLM Chain + Structured Output Parser + Split Out).

When I went to build it, I realized Looping by Zapier has a text-delimiter mode. Set the delimiter to `\n- ` and it splits the plain-text bullet list directly. One step instead of two. No re-parse, no risk of the second AI call hallucinating a different schema, lower task cost.

I went with text-split. The tradeoff: the prompt and the upstream Validate step have to guarantee `action_items` always starts with `\n- ` so the delimiter matches even for single-item meetings. That's a small price for skipping a whole AI call.

This is the kind of thing the original spec couldn't anticipate because I hadn't used Zapier's Looping primitive before. The lesson: spec the outcome, not the implementation. Let the platform tell you the cleanest way to hit it.

### Pushback 2: Three-layer failure isolation, not just retries

The original P2-NFR2 said "if any AI step fails, the Zap still sends the email with `(unavailable)` in the missing section." Vague.

When I sat down to actually build it, I split that into three layers:

1. **Validate-and-substitute.** A Code step right after the AI checks all five fields. Empty or whitespace gets replaced with `"unavailable"` and a `has_degradation` flag is set. Downstream paths read the validated data, not the raw AI output.

2. **Loop guard.** A filter before the Google Tasks loop requires `action_items` to contain `\n- `. Malformed AI responses skip Path C silently instead of creating one giant garbage task.

3. **Degradation notification path.** A fourth Path branch fires only when `has_degradation == true`. Sends me a separate Gmail alert with the full transcript and all five validated fields. I see the problem in real time without scanning Zap history.

The recap email (Path A) only fires when degradation is false, so the recipient never sees a half-broken summary. The log sheet writes regardless and includes a column for the degradation flag, so I can filter the sheet for degraded runs later.

This is more defensive than the n8n build, which doesn't have any of these guards. The Zapier build is genuinely better here.

**Bug I hit while wiring it up: empty first iteration.** My first cut at action item normalization did a small prepend: if `action_items` started with `- `, prepend `\n` so the loop delimiter `\n- ` would match for single-item meetings. Looked right on paper. In practice, splitting `\n- A\n- B\n- C\n- D` on `\n- ` produces `['', 'A', 'B', 'C', 'D']` — five elements with an empty string at the front. Zapier Looping's `trim_whitespace: true` option doesn't drop empty iterations, so Google Tasks tried to create a task with no title and errored on "Required field Title is missing." Every multi-item run failed.

The fix is more aggressive normalization in the Validate step: split the field by newline, trim each line, drop any line that isn't a bullet, rejoin with `\n`. That guarantees no phantom empties hit the loop. The single-item edge case (e.g., `- A` with no `\n- ` anywhere) still slips through the loop guard filter and Path C gets skipped silently — known limitation, mitigated by the recap email still showing the item.

The lesson: when a Zapier text-split delimiter doesn't match what you think `trim_whitespace` will catch, fix the data before it hits the loop. Don't rely on the loop step to clean up.

### Pushback 3: Prompt aligned with the eval rules, not just the spec

While building the eval harness for the next project, I wrote out the extraction rules (R1-R6) that the eval would score against: action item ownership and verb shape (R1), decision phrasing (R2), open question explicitness (R3), participant exact spelling (R4), side conversation filtering (R5), due date verbatim preservation (R6).

Reading those back, I realized the AI prompt I'd been using only covered R1 implicitly. R4, R5, R6 weren't in the prompt at all. If I ran T05 (international names) or T06 (verbatim dates) or T07 (side conversation about a birthday cake) through the pipeline, GPT-4o-mini wouldn't know to follow those rules and the eval would tank by design.

So I rewrote the prompt to encode each rule explicitly. The Søren-Niamh-Lakshmi names get preserved. Side conversations get filtered. Due dates stay as written ("Friday after next", not normalized to ISO). And empty sections return the literal string `"None"` instead of being blank, so the degradation alert doesn't false-positive on a legitimate "no action items" meeting.

The lesson: the prompt is part of the pipeline under test. Writing the eval rules first surfaced gaps in the prompt I'd never have noticed otherwise. Build the rubric, then check the spec against the rubric.

---

## What I'd Do Differently

1. **Plan the AI output format up front.** Tell the assistant exactly what the downstream nodes need: plain-text bullets, no preamble, no JSON wrappers. Saves a full rebuild.
2. **Write the eval rules before finalizing the prompt.** The prompt is part of the pipeline; if the rubric isn't in the prompt, the pipeline will fail the rubric.
3. **Test path filters as soon as you create them.** Don't wait until the end. They fail silently, and the failure isn't obvious from the run log.
4. **Pick the simplest architecture that meets the goal.** Single AI call beat four parallel calls on cost and complexity. Text-split Looping beat structured-output-parser on the same axes. If section quality starts degrading, swap in the four-chain pattern.
5. **Build failure isolation before you need it.** The three-layer pattern (validate, guard, notify) took less than an hour to add and would have saved me real time if any of my synthetic test runs had hit a degraded response.

---

## What's Next

Same workflow now exists in n8n (manual and Claude Code) and Zapier (Copilot v4). Three builds of the same pipeline; three different tradeoff profiles. Next up is the Zapier-native eval harness in `../zapier-eval-build/` — the one that turned out to be the reason this prompt got rewritten in the first place.

The canvas looks simple in both tools. What's configured inside the nodes is still where the real work gets done.
