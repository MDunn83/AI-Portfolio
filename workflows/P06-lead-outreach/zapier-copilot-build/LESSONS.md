# P06 Build Lessons — Design Decisions & Tradeoffs

## Pushback 1: Sequential AI vs Parallel Scoring

**The question:** Should we score companies one at a time (sequential) or batch them and score in parallel?

**The tradeoff:**

- **Sequential (chosen):** One AI call per company. Easier to implement, easier to debug, task cost is predictable. For 50 companies = 50 AI calls. Slower wall-clock time (~50 seconds) but cheaper in Zapier tasks.
  
- **Parallel:** Batch companies into groups (e.g., 5 at a time) and score via Sub-Zap or a native batch integration. Faster wall-clock time (~15 seconds for 50) but more Zapier tasks, more complex routing.

**Why sequential:** Lead generation isn't time-critical. The Zap runs once daily; 50 seconds vs 15 seconds doesn't matter. Task cost does matter (we're paying per-task). Sequential = simpler to debug if something breaks mid-loop.

**If I'd change it:** For >200 companies per run, parallel would become worth the complexity. For now, sequential is the right call.

---

## Pushback 2: Score Threshold (7 vs 6 vs 8)

**The question:** What's the cutoff for "send email"? 

**Analysis of options:**

- **Threshold = 8:** Very selective. Only highest-fit companies get emailed. Higher reply rate, but leaves a lot of 7-scoring companies on the table (e.g., decent SaaS, right ops role, unclear size). Probably miss 30-40% of good leads.

- **Threshold = 7 (chosen):** Sweet spot. Catches the "moderate-to-high fit" band (SaaS, ops roles, 50-300 person range). Includes some false positives (mitigate with Phase 2 dedup), but maximizes outreach volume.

- **Threshold = 6:** Too loose. Starts including marginal fits (e.g., large enterprises with Ops roles, where they probably have internal teams already).

**Why 7:** On a 1-10 scale, 7 = "clearly fit, worth reaching out to." 6 = "maybe fit, skeptical." The difference matters in cold outreach (lower threshold = lower reply rate but more volume).

**Iteration path:** If reply rate tanks, bump to 8. If we're being too selective, drop to 6.5 (requires phase 2 float support).

---

## Pushback 3: Personalization Depth

**The question:** How many personalization points should we include in the email?

**Options:**

- **Minimal (1 point):** "Hi {{ContactName}}, I noticed you might benefit from workflow automation." Generic, low personalization signal, probably higher spam filter risk.

- **Light (2 points, chosen):** "Hi {{ContactName}}, I noticed {{Company}} and I think {{Role}} roles can benefit from automation." Shows we looked them up, but not deeply.

- **Deep (4+ points):** "Hi {{ContactName}}, {{Company}} is a {{size}}-person {{industry}} company. I noticed you're hiring {{department}} roles. At {{average_company}}, teams in {{function}} spend {{X}}% time on {{process}}. That's where automation wins." Requires data enrichment (Crunchbase, company filings, etc.). Much higher lift.

**Why light (2 points):** We're looping through 50-100 companies per day. Company name, contact name, and role are in our source data. Pulling 4 more data points per company (industry, size, department hiring, process time) = 3-5× more API calls and complexity. ROI doesn't justify it for Phase 1.

**Phase 2 upgrade:** Once we nail reply rate, invest in Crunchbase enrichment. The "I noticed you're hiring for X" angle is *much* stronger than generic ops role mention.

---

## Pushback 4: Upsert vs Append

**The question:** Should we upsert (update existing rows) or append (always create new rows)?

**Tradeoff:**

- **Append:** Simpler implementation. Every scoring run creates a new row in Summary sheet. Easy to see history (Company X was scored 3 times, scores were 7, 7, 8). But Summary sheet gets messy — duplicate company names, hard to find "latest" score.

- **Upsert (chosen):** Lookup by Company name. If it exists, update (Summary + Score columns). If not, create new row. Summary sheet stays clean, always shows latest score per company. Supports "skip if already contacted" logic in Phase 2.

**Why upsert:** Cleaner data model. Makes Phase 2 deduplication possible. The lookup happens by exact Company name match (case-sensitive), which is a minor risk (we accept in Phase 1, fix in Phase 2 with normalization).

---

## Pushback 5: JSON Parsing Fragility

**The question:** What if GPT-4.1 returns non-JSON?

**Risk:** AI sometimes returns JSON with extra markdown (```json ... ```), or incomplete output if truncated, or plain text fallback.

**Mitigation in Phase 1:** We don't validate. If JSON parse fails in the filter step, the filter silently stops the run (no email sent). The company doesn't get logged to Summary sheet, so we lose track of it. Phase 2 fixes with:
- JSON validation Code step (try-catch)
- If invalid, log as ERROR to Summary sheet instead of skipping
- Optionally retry with a fallback prompt

**Why we accept it:** GPT-4.1 is reliable enough that this failure is rare (<1%). If it happens, the Zap history shows it clearly (filter stops), and we manually review. For Phase 1, acceptable.

---

## Pushback 6: Loop Size Limits

**The question:** Can the Zap handle 500 companies in one run?

**Yes, but:** 

- Zap will complete, but task cost = ~1800+ tasks (huge). At $0.01/task, that's $18 per run.
- Execution time = ~10 minutes (acceptable for daily schedule, but no room for Zap delays).
- If one AI call times out mid-loop, the entire run fails.

**Recommendation for Phase 1:** Keep Companies sheet to <100 rows. Once looping is rock-solid, grow to 200+.

**Phase 2:** Split into two Zaps (A: companies 1-250, B: companies 251-500) both running at 5 AM, or add a filter in the fetch step to exclude recently-contacted companies (drops the list size).

---

## Pushback 7: Email Sender Identity

**The question:** Should the email come from a personal Gmail address or a generic no-reply address?

**Analysis:**

- **Personal email (chosen):** Higher trust, more conversational, supports follow-up replies (they reply to Mark, not a noreply bot). Better for cold outreach.

- **Generic address:** More scalable if you expand to multiple outreachers, but lowers trust and "no reply" signals bot activity (bad for spam filter).

**Why personal:** This is lead gen for a personal consulting practice, not a company product. Personal touch matters.

**If scaling:** Phase 2 could add a {{sender_email}} loop variable to support multiple outreachers.

---

## Pushback 8: Email Response Tracking

**The question:** How do we know if a prospect replied?

**Current:** We don't. Email sends, Zap logs to Summary sheet, but no webhook or integration watches for replies.

**Phase 2 path:** Zapier's Gmail integration can watch for replies in a specific label. When a reply lands:
- Filter by sender address (match to prospect email)
- Update Summary sheet Response Status = "REPLIED"
- Trigger a Sub-Zap to notify Mark (Slack or email)

**For now:** Mark manually monitors Gmail for replies and updates Response Status column himself. Acceptable because volume is low (<10 replies/day expected).

---

## Pushback 9: Cold Email Compliance

**The question:** Are we spamming?

**Safeguards in place:**

1. **CAN-SPAM:** Email includes signature (from line is sufficient), and there's an implicit unsubscribe mechanism (prospect can reply "unsubscribe" or just ignore).
2. **Consent:** These are researched B2B leads, not scraped email lists. We're reaching out about a genuine service (automation consulting).
3. **Personalization:** Three data points per email signal human research, not blast spam.

**Still risky:** If reply rate is very low (<1%) or bounce rate high (>15%), it signals poor targeting → Gmail may flag as spam.

**Mitigation:** Monitor Gmail spam folder and bounce metrics. If we see a pattern, revise the scoring rubric or email template.

**Not doing:** No double-opt-in, no newsletter signup. Cold outreach is inherently asymmetric; we can't pre-qualify consent.

---

## Pushback 10: Model Choice (GPT-4.1 vs GPT-4o vs Groq)

**The question:** Why GPT-4.1 for scoring vs other models?

**Analysis:**

- **GPT-4.1:** High accuracy on scoring logic, consistent JSON output, available via Zapier native integration. No external API key needed.
- **GPT-4o:** Faster, cheaper, but marginally less reliable on structured output (JSON) in our testing.
- **Groq Llama-3.1:** Fast + cheap, but less reliable on JSON parsing; errors increase complexity.

**Why GPT-4.1:** Reliability > cost for scoring. A wrong score (say, 6 instead of 7) can suppress a good lead. Better to pay $0.003 more per call and get accurate scores.

**If budget tightens:** Could A/B test GPT-4o for a week, compare reply rates, and switch if no regression.

---

## What Worked Well

1. **Loop architecture:** Looping by Zapier with parallel arrays is clean and requires minimal Code steps.
2. **Upsert pattern:** Lookup + write naturally avoids duplicate rows, keeping Summary sheet tidy.
3. **Simple filter:** Score > 7 is intuitive and easy to adjust.
4. **JSON output schema:** Specifying exact output fields in the prompt made parsing predictable.

---

## What Was Tricky

1. **Parsing raw rows into arrays:** Required understanding Zapier's JSON output format from get_many_rows. Not obvious without documentation.
2. **Loop variable scope:** Each loop iteration creates a new scope; referencing arrays from outside the loop requires careful step chaining.
3. **Email personalization in a loop:** Template variables must use loop iteration variable names (e.g., `{{Company}}`, not `{{companies[i]}}`). Took iteration to get syntax right.

---

## Debugging Notes

- **Zap history is your friend:** Run a test, watch each step's input/output in the history. You'll spot where JSON parsing fails, where filter stops, etc.
- **Test with 5 rows first:** Don't test with 100 companies. Run a few, verify the loop works, then scale.
- **Check Gmail sent folder:** If an email doesn't appear in Gmail sent folder, it didn't actually send (filter or step failed upstream).
- **Monitor task count:** Watch the "tasks used" metric in Zap history. If it spikes unexpectedly, something is looping wrong.

---

## Next Steps (Phase 2+)

1. **Run a 2-week test:** Daily loop, same Companies sheet, track reply rate and bounce rate.
2. **Analyze scoring accuracy:** Did 7+ companies actually have automation needs? Did 6- companies give "not interested" replies?
3. **Refine the email template:** A/B test subject lines or opening lines.
4. **Add deduplication:** Skip companies emailed in the last 30 days.
5. **Enrich data:** Pull company size and industry from Crunchbase before scoring.
6. **Expand scope:** Replicate to other Zapier accounts or operationalize for other TMOs.

---

## Reference

- Build: `P06-lead-generation-zapier-copilot.json`
- Zap ID: 368769852
- Created: 2026-06-16
- Last updated: 2026-06-16
