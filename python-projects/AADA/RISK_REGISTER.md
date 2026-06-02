# Risk Register: Adversarial AI Decision Analyzer (AADA)

**Version:** 1.0
**Date:** 2026-06-01
**Program Manager:** Mark Dunn

---

## Scoring Guide

**Probability:** L = Low (<20%) | M = Medium (20-60%) | H = High (>60%)
**Impact:** L = Low (minor rework or cost) | M = Medium (milestone slip or cost overrun) | H = High (program objective at risk)
**Score:** Probability × Impact. HH = Critical | HM / MH = High | MM / HL / LH = Medium | ML / LM / LL = Low

---

## Risk Register

| ID | Risk Description | Category | Probability | Impact | Score | Mitigation | Owner | Status |
|----|-----------------|----------|-------------|--------|-------|------------|-------|--------|
| R01 | API pricing increases >25% across one or more providers, making ≤$0.05 cost target unachievable | Cost | M | M | Medium | Monitor pricing quarterly; evaluate model substitution (e.g., Haiku for critique, Flash for routing) if threshold approached | PM | Open |
| R02 | One provider API deprecated, rate-limited, or degraded (GPT-4o, Gemini, Claude) | Technical | L | H | Medium | Abstract model calls behind provider interface to enable substitution; maintain provider status page subscriptions | PM | Open |
| R03 | Dynamic router triggers a second pass too often, defeating the hard cost cap | Technical | L | H | Medium | 2-pass hard cap enforced in code; router prompt calibrated to require strong critic disagreement; validated in testing | PM | Mitigated |
| R04 | Critic models share training data blind spots, producing false confidence in multi-model agreement | AI Quality | M | H | High | Use structurally diverse providers (different companies, training pipelines); monitor error overlap across cases | PM | Open |
| R05 | End users submit sensitive data (PII, PHI, CUI) without data handling guidance | Compliance | L | H | Medium | Surface data handling policy at session start in Streamlit UI; no server-side storage of query content | PM | Open |
| R06 | Streamlit Community Cloud service interruption breaks hosted demo | Technical | M | L | Low | Loom demo video maintained as fallback; local CLI always operational | PM | Open |
| R07 | Parallel API calls in 3-model modes create race conditions or inconsistent state | Technical | L | M | Low | asyncio.gather handles parallel execution; critic outputs are independent inputs to synthesis; no shared mutable state | PM | Mitigated |
| R08 | Latency increases as model providers throttle or add processing overhead, breaching 120s target | Performance | M | M | Medium | Track latency per run in audit log; alert threshold at 100s; evaluate async mode expansion if trend emerges | PM | Open |
