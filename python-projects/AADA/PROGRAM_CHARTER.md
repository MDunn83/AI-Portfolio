# Program Charter: Adversarial AI Decision Analyzer (AADA)

**Version:** 1.0
**Date:** 2026-06-01
**Program Manager:** Mark Dunn

---

## Problem Statement

AI models are known to display overconfidence and domain-specific knowledge gaps when operating without adversarial feedback. High-stakes decision workflows that rely on single-model outputs risk compounding errors without detection. Errors can include but are not limited to missed regulatory exposure, flawed calculations, and lack of disclosures. AADA addresses these shortfalls through a structured multi-model critique architecture that uncovers disagreements, forces revision, and generates an audit trail for each query.

---

## Objectives

1. Reduce undetected single-model errors in AI-assisted decision support by ≥30% relative to single-model baseline outputs
2. Deliver a per-query JSON audit trail to support compliance and review workflows
3. Maintain cost ≤ $0.05/query and total latency ≤ 120 seconds across all modes

---

## Scope

**In scope (v3.x):**
- Multi-model critique pipeline: Claude, Gemini, GPT-4o
- Dynamic routing: router evaluates critic disagreement and triggers second pass if warranted
- Four operational modes: Fast 2-model, Deep 2-model, Fast 3-model (parallel), Deep 3-model (parallel with routing)
- Streamlit UI and Python CLI
- JSON audit log generated per query
- Prompt configuration externalized to YAML

**Out of scope (v3.x):**
- Fine-tuning any model
- Storage of PII, PHI, or CUI
- More than 2 critique passes (hard cap)
- Integration with external data sources or internal systems
- User authentication or multi-tenant access control

---

## Deliverables

| Deliverable | Version | Status |
|-------------|---------|--------|
| Python CLI with 4 modes | v3.0 | Complete |
| Streamlit UI | v3.5 | Complete |
| YAML prompt configuration | v3.5 | Complete |
| Commercial-ready web interface | v4.0 | In design |
| API wrapper for integration | v5.0 | Planned |

---

## Success Criteria

Formal measurement of these criteria is a v4.0 milestone. Targets are defined here; validation plan names when and how each will be measured.

| Criterion | Target | Validation Plan |
|-----------|--------|----------------|
| Cost per query | ≤ $0.05 | Captured from per-run audit log; reported across a 20-run sample at v4 acceptance |
| Total latency | ≤ 120s | Captured from per-run audit log; reported across the same 20-run sample at v4 acceptance |
| Audit trail generation | 100% of queries | Verified during v4 acceptance test |
| Error catch rate vs. single-model | Net new errors identified per 10-query sample | Run a curated 10-query benchmark against single-model baseline at v4 acceptance; track unique catches |

---

## Constraints

- **2-pass maximum:** hard cap enforced in code; no exceptions
- **Prompts externalized:** all prompts live in `prompts.yaml`, not inline
- **Cost tiering:** Haiku-class models for routing decisions; Sonnet-class for synthesis
- **No fine-tuning:** model behavior shaped through prompt engineering only (v3.x)

---

## Assumptions

- API availability maintained for all three providers (Anthropic, Google, OpenAI) throughout program
- API pricing stable within ±25% for program duration
- Users provision their own API keys
- Python runtime available locally or via Streamlit Community Cloud

---

## Milestones

| ID | Milestone | Status |
|----|-----------|--------|
| M1 | v3.0 CLI operational with 4 modes | Complete |
| M2 | v3.5 Streamlit UI with full mode parity | Complete |
| M3 | v3.5 validated on real estate compliance case | Complete |
| M4 | v4.0 web UI scope definition gate | In progress |
| M5 | v4.0 web UI delivered | Planned |
| M6 | v5.0 commercial API wrapper | Planned |

---

## Program Manager Authority

The program manager has authority to:
- Approve or reject scope additions to any version
- Adjust milestone sequencing within program constraints
- Make model substitution decisions within cost and quality parameters
- Halt a version release pending audit trail or cost target validation
