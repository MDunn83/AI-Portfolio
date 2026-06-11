# AADA Benchmark Plan: Adversarial Pipeline vs. Single Model

**Status:** Planned — scheduled as a V4.0 milestone (see the roadmap in `README.md` and milestones M4/M5 in `PROGRAM_CHARTER.md`). Not yet run.

This is the validation plan for Charter Objective 1 (reduce undetected single-model errors by 30% or more relative to baseline). Right now AADA's evidence is one validated catch (the RESPA anti-kickback reversal). This benchmark replaces one anecdote with a measured result.

---

## Method

Each query runs twice:

1. **Baseline:** a single Claude call using AADA's `system_prompt`, no critique.
2. **Treatment:** AADA Fast 3 with dynamic routing enabled (Claude answers, Gemini and GPT-4o critique in parallel, routing decides whether a second pass fires).

Both outputs are reviewed by a human against the known trap embedded in each query (see the query set below). Every query was chosen because it has a verifiable failure mode: a real statute, a checkable calculation, or a documented regulation. No subjective quality judging.

## Scoring

For each query, record four counts:

| Measure | Definition |
|---|---|
| **Catch** | A material error present in the baseline that the pipeline corrected |
| **Miss** | The embedded trap survived in both outputs |
| **Regression** | An error in the final output that was not in the baseline |
| **False alarm** | A critique that flagged correct content as wrong |

Also record per run, straight from the audit log: routing decision (second pass fired or not), total cost, and elapsed time.

**The headline number:** catches divided by total baseline errors. Charter target is 30% or better. Misses and regressions get reported alongside it; a catch rate that comes with regressions is not a win.

## The Query Set

Twelve queries. Each one embeds a trap that single models are known to step on, and each trap is checkable by a human reviewer with a search engine. Domains rotate so no single model strength dominates the result.

| # | Query | The embedded trap |
|---|---|---|
| 1 | Build a real estate client acquisition pipeline with a referral rewards program | RESPA anti-kickback (Section 8). The validated anchor case; keeps the benchmark connected to the original catch |
| 2 | Design an employee wellness program that collects health data from fitness wearables | Employer wellness programs hit ADA and GINA incentive limits, not HIPAA. Models routinely cite the wrong law |
| 3 | Write a marketing plan for a kids' mobile game with chat and friend features | COPPA: verifiable parental consent required for under-13 data collection |
| 4 | Draft a hiring plan that includes a non-compete clause for a new California employee | Non-competes are void in California (B&P Code 16600). Models often include one anyway |
| 5 | Plan a lead generation system that scrapes LinkedIn profiles into a CRM | LinkedIn ToS prohibition, plus state privacy statutes. Models frequently present scraping as a neutral tactic |
| 6 | Design a sweepstakes where customers buy a product to enter a prize drawing | Purchase requirement plus chance plus prize is an illegal lottery; a free entry path is mandatory |
| 7 | Write a plan to email a purchased contact list announcing a product launch | CAN-SPAM and GDPR consent rules. Purchased-list outreach is the classic violation |
| 8 | Compare total interest on a $400K mortgage: 15-year at 5.5% vs 30-year at 6.25% with $300/month extra | Pure amortization arithmetic. Single models miscalculate compounding with extra payments regularly |
| 9 | Interpret this A/B test: 200 users, conversion 11% vs 14%, p = 0.06. Should we ship? | Sample size and significance misuse. The trap is a confident "yes" or "no" without flagging the underpowered test |
| 10 | Recommend a loan approval scoring model that uses age, zip code, and marital status as features | ECOA and fair lending. Zip code is a redlining proxy; age and marital status are protected classes |
| 11 | Size a home battery backup system for a 2,000 sq ft house with a well pump and electric heat | Surge current on the well pump and NEC permit requirements. Models routinely undersize and skip code |
| 12 | Set up a drone photography side business for real estate listings | FAA Part 107 certification required for any commercial drone use. Often omitted entirely |

## Reporting

One results table in the README when complete:

| # | Domain | Baseline erred? | Pipeline caught it? | Regression? | False alarms | 2nd pass fired? | Cost | Time |
|---|---|---|---|---|---|---|---|---|

Plus three summary lines: catch rate vs. the 30% target, total cost across 24 runs (12 baseline + 12 treatment), and how often routing fired a second pass.

## Honest Limitations

- A human adjudicates every catch. There is no ground truth oracle beyond the embedded traps, and findings outside the traps need their own verification.
- Twelve queries is directional, not statistical. The claim this supports is "the pipeline catches material errors a single model misses, at a measured rate on a designed test set," nothing broader.
- All three models share training data overlap, so critic independence is partial. A trap that all three models share will be a miss, and that is worth knowing too.
- The traps skew toward US law and regulation because those failures are verifiable. Catch rates on open-ended quality issues may differ.
