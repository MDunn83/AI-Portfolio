# Future Builds: Pushing the Portfolio Up the Difficulty Curve

The current portfolio covers automation workflows in n8n, Python projects (AADA, ARQA), and a Zapier port of P01. The next moves should aim higher than another workflow port. These three builds add capabilities that are currently missing and that AI/automation TPM roles are actually hiring against in 2026: evaluation, agent loops with budget controls, and runtime policy enforcement.

Ranked by signal-per-hour-of-build. Top pick has the highest portfolio multiplier because the pattern reuses across every other project here.

---

## 1. LLM-Judge Evaluation Harness on the Zapier Meeting Minutes Build

**Top pick.** **Audience: AI/automation TPM roles AND Zapier specifically.**

### What you build
A second Zap that exercises the Phase 1 (or Phase 2) Zapier meeting minutes pipeline against a fixed set of test transcripts and scores the outputs.

- 6 to 8 synthetic transcripts in a Google Sheet, each with a known ground truth (X action items, Y decisions, Z attendees, etc.). Pre-generated as `T01.md`–`T07.md` in `zapier-eval-build/`, chosen to cover the categories that actually expose regressions: short clean, long messy, no decisions, no action items, weird names, ambiguous due dates, side-conversation noise. More samples don't help when the judge has its own variance; tightening the rubric does.
- A runner Zap that loops the transcript list and either fires the existing pipeline directly or replays its key steps inline.
- A separate LLM judge step (one more Zapier AI step) that scores each output against a rubric: did it catch every decision, did action items have owners, did it hallucinate names or dates, is the summary faithful.
- Scores logged to a Google Sheet with prompt version, model version, and timestamp on every row.
- A delta view (separate sheet tab with a query/formula or a scheduled Zap) that flags regressions when scores drop run-over-run.

### Why this signals what you want signaled
- Shows the TPM lens. Measurement of AI output quality is what production AI teams actually do; "I built it" is junior, "I built it and I measure it" is senior.
- Forces you into Zapier's harder surface area. Looping by Zapier for the transcript loop, Sub-Zaps for invoking the pipeline under test, Storage by Zapier for state across runs, Code steps for the score math. That's a much bigger Zapier flex than another single-Zap port.
- Almost nobody has shipped a public LLM-eval pipeline on Zapier. Searching for it turns up nothing. Being the first public reference is the signal.
- Generalizes. Once the eval pattern works on Zapier, the same pattern plugs into every other Zapier workflow you build.
- Clean LinkedIn story. "You can't ship LLM workflows without an eval layer. Here's what mine caught, built entirely in Zapier."

### Where it lives
- `workflows/P01-meeting-minutes-automation/zapier-eval-build/` (sibling to `zapier-copilot-build/`).
- Optional follow-on: port the eval pattern to n8n once the Zapier version is shipped and write the comparison. That's a bonus post, not the main deliverable.

### Effort estimate
- Test transcripts: pre-generated as `T01.md`–`T07.md` in `zapier-eval-build/`. Paste into a Sheet.
- Eval Zap: 1 to 2 hours of implementation with Copilot doing the wiring, on top of architecture decisions made up front from this spec.
- Judge prompt tuning so scores are consistent run-to-run: 1 to 2 hours. This is the part Copilot can't shortcut; the model's first prompt rarely scores reliably and dialing it in is iterative.
- Total: 3 to 5 hours, plus 1 hour to load the transcripts into the Sheet and verify the ground truth.
- First useful insights: same day you ship.

### Tradeoffs
- The judge model is itself an LLM, so the eval has its own error rate. Worth saying out loud in the writeup; not a reason to skip.
- 6 to 8 transcripts is enough to catch big regressions, not enough for statistical significance. Document the limitation rather than overclaim. Smaller sample also makes the inner loop fast: you can iterate on the judge prompt four times in the budget that 25 transcripts would burn once.
- Zapier's task budget at this volume is roughly 6-8 transcripts × ~7 steps each = ~50 tasks per eval run. Order of magnitude cheaper than the original 20-30 sample plan and keeps iteration cost low.

---

## 2. Research Agent With Tool Use, Budget Cap, and a Quality Score

**Audience: AI/automation TPM roles, agent-focused roles. Does not signal Zapier competence.**

### What you build
A Python project (or n8n + Code-step hybrid) that takes a research question, decides which tools to call, iterates with reasoning, and produces a cited answer.

- Tools available to the agent: web search, page fetch, summarize, math/calculator. Each one defined as a tool spec.
- Reasoning loop: model picks a tool, sees the result, decides next move. Capped at N iterations and M total tokens.
- Budget governor as the centerpiece. If the agent burns through 80% of its token budget without a confident answer, it must return what it has with an explicit "low confidence" flag. No silent runaway.
- A self-scoring step at the end: the agent rates its own answer on confidence and citation quality.
- Optional: a human-judge eval pass that compares the agent's self-score to a ground-truth score.

### Why this signals what you want signaled
- Agents are where AI work is heading in 2026. Most public agent demos are toys with no budget control, no evaluation, and no graceful degradation. Building one with all three lands above the noise.
- The budget-and-governance angle reads exactly like the TPM-shaped work that production AI teams need.
- Differentiates from AADA, which was an early-stage build. This is the matured version of that pattern.

### Where it lives
- `python-projects/research-agent/` (new top-level Python project).
- Uses Anthropic's tool-use API or OpenAI function calling.

### Effort estimate
- 8 to 15 hours including the eval pass.
- More than option 1, less than a full AADA-scale build.

### Tradeoffs
- Bigger scope than option 1. More moving parts, more debugging.
- Doesn't reuse across other projects the way the eval harness does.
- Doesn't help the Zapier-recruiter angle, since agent work isn't Zapier-shaped.

---

## 3. Runtime Guardrails Layer on the AI Governance Pipeline

**Audience: AI safety, trust, and compliance roles. Currently scoped to n8n (extends P04); could be re-scoped to Zapier if Zapier signal becomes the priority.**

### What you build
Take the existing P04 AI governance pipeline and add a runtime policy enforcement layer that actually catches violations.

- Policy definitions in a versioned config: PII detection, prohibited topics, output schema enforcement, jailbreak pattern detection.
- A check step that runs on every prompt before it hits the model, and on every output before it gets returned.
- Violations logged with policy version, prompt, output, and which rule fired.
- A dashboard sheet showing violation counts by rule over time.
- Optional: a "policy update flow" where a human reviews a flagged output and decides whether to harden the rule or let similar outputs through.

### Why this signals what you want signaled
- Pushes the existing governance project from "I researched governance" to "I built enforcement." That distinction matters to any AI safety, trust, or compliance role.
- Most public portfolios that mention governance stop at the conceptual level. A working policy layer with violation logs is rare.
- Reuses for any future LLM workflow that needs guardrails, including the meeting minutes pipeline and the research agent.

### Where it lives
- Extends `workflows/P04-ai-governance/` rather than starting a new project.
- Optionally uses NeMo Guardrails, Guardrails AI, or a hand-rolled regex + LLM judge.

### Effort estimate
- 6 to 10 hours depending on how many policies you ship in v1.
- The first 3 policies are the slow ones; subsequent policies are formulaic.

### Tradeoffs
- Narrower audience than options 1 and 2. Targets AI safety and compliance recruiters specifically.
- The existing governance project does some of the framing work already, which means this build is more "extension" than "new direction."

---

## Recommended Sequence

If Zapier-as-employer is a priority lane, these stack in this order:

1. **Phase 2 of P01 Zapier.** Already specced. Closes parity gaps using Sub-Zaps, Looping, Gmail integration, structured output. Highest-priority Zapier signal for the least new design work.
2. **Eval harness on Zapier (Build 1 above).** Top pick of the three. Forces the harder Zapier surface area, gives a public reference nobody else has shipped, and sets up a pattern reusable across every Zapier build you do next.
3. **One or two more Zapier ports** that push different platform features (lead-gen for rate limits and batching, customer outreach for state across runs). Skip the ports that don't add new Zapier signal.
4. **Research agent (Build 2).** Bigger build, doesn't help Zapier but covers the agent gap in the portfolio. Sequence this after the Zapier work if Zapier is the active target.
5. **Guardrails layer (Build 3).** Targets a different audience (AI safety/compliance). Sequence last unless a role description forces it up the queue.

Each build alone is a portfolio upgrade. The sequence compounds because patterns from earlier builds (eval harness, budget control, policy enforcement) plug into later ones.

---

## Honest Caveats

- These are recommendations, not commitments. Roles you're actually interviewing for should override priority order.
- "AI/automation TPM" is a real lane, but the specific roles on the market in any given month vary in what they weight. If a target role description leans heavily on one capability (eval, agents, governance, guardrails), bump that build up the queue.
- Every estimate here assumes the existing projects in this repo as a starting point. A clean-room version of any of these would take longer.

---

## Reference

- Existing n8n projects: `P01` through `P07` in this folder
- Python projects: `python-projects/AADA/`, `python-projects/ARQA/`
- Zapier Copilot build of P01: `P01-meeting-minutes-automation/zapier-copilot-build/`
- Writing style for any public-facing writeup: `../reference/WRITING_STYLE.md`
