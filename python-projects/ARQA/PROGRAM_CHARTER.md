# Program Charter: Automated Requirements Quality Assistant (ARQA)

**Version:** 1.0
**Date:** 2026-06-01
**Program Manager:** Mark Dunn

---

## Problem Statement

Reviewing requirements documents by hand is slow and easy to get wrong. Program managers and systems engineers read each SHALL statement, check it for quality and completeness, and compare it against the applicable standards. The work is tedious, results vary from one reviewer to the next, and there is usually no citation trail behind a finding. A 50-requirement document can take hours. ARQA automates the SHALL extraction, evaluates each statement against embedded engineering standards using RAG, and returns page-level citations with suggested rewrites. The result is a faster review with a traceable record behind every finding.

---

## Objectives

1. Reduce time to complete a requirements document review by ≥60% relative to manual baseline
2. Achieve page-level citation accuracy on ≥90% of flagged requirements
3. Produce a structured, exportable audit report for every document processed

---

## Scope

**In scope (v2.x):**
- PDF ingestion and text extraction
- SHALL statement isolation using pattern matching
- RAG-based evaluation against embedded engineering standards corpus (LangChain + ChromaDB)
- Reranking via FlashRank (`ms-marco-MiniLM-L-12-v2`)
- Structured output: per-SHALL finding, citation, compliance status, suggested rewrite
- Google Colab runtime (no local installation required)
- Document-agnostic: standards corpus swappable

**In scope (v3.0, planned):**
- Verification method generator for each SHALL statement

**Out of scope:**
- Classified, proprietary, or access-controlled document processing
- Real-time multi-user collaboration
- Non-English documents
- Scanned or image-only PDFs (OCR not supported in v2.x)
- Autonomous document sign-off without human review

---

## Deliverables

| Deliverable | Version | Status |
|-------------|---------|--------|
| Natural language Q&A against standards corpus | v1.0 | Complete |
| Automated SHALL extraction and RAG evaluation | v2.0 | Complete |
| Page-level citations and suggested rewrites | v2.0 | Complete |
| Validation on 10-requirement test document | v2.0 | Complete |
| Verification method generator | v3.0 | Planned |
| Scalability evaluation for large documents | v3.0 | Planned |

---

## Success Criteria

Formal measurement of these criteria is a v3.0 milestone. Targets are defined here; validation plan names when and how each will be measured.

| Criterion | Target | Validation Plan |
|-----------|--------|----------------|
| SHALL extraction recall | ≥ 90% | Built and labeled test set of 50 SHALL statements; measured at v3.0 acceptance |
| Citation accuracy (page-level) | ≥ 90% of flagged findings | SME review of citations against source standards on the v3.0 test set |
| Review time reduction vs. manual | ≥ 60% | Time-boxed comparison: manual review vs. ARQA on a held-out document at v3.0 acceptance |
| Rewrite acceptance rate (SME review) | ≥ 50% | SME pass on rewrites generated against the v3.0 test set; accepted vs. rejected counted |
| Processing time (standard document) | ≤ 30 minutes | Captured from Colab runtime on the v3.0 test set |

---

## Constraints

- **Runtime:** Google Colab only (v2.x); no local installation required or supported
- **API tier:** Gemini Flash free tier (v2.x); paid tier required for v3.0+ at scale
- **Corpus design:** Standards documents must be swappable without code changes
- **No storage:** Document content is not retained beyond the active Colab session
- **Human-in-the-loop:** Rewrite suggestions are advisory; SME review required before acceptance

---

## Assumptions

- Input PDFs are text-extractable (not scanned/image-only)
- Engineering standards documents are available as PDFs and can be embedded in the corpus
- Gemini Flash free tier rate limits are sufficient for documents ≤50 SHALL statements
- Users have a Google account for Colab access

---

## Milestones

| ID | Milestone | Status |
|----|-----------|--------|
| M1 | v1.0: natural language Q&A against standards corpus | Complete |
| M2 | v2.0: automated SHALL extraction and evaluation | Complete |
| M3 | v2.0: 10-requirement validation test (5/10 flagged, 3 substantive gaps, avg 3 citations/finding) | Complete |
| M4 | v3.0: scope definition gate | Planned |
| M5 | v3.0: verification method generator delivered | Planned |
| M6 | v3.0: scalability evaluation for large documents | Planned |

---

## Program Manager Authority

The program manager has authority to:
- Approve or reject scope additions to any version
- Define and enforce the human-review gate before rewrite suggestions are accepted in any downstream process
- Make corpus update and model substitution decisions within cost and quality parameters
- Halt a version release pending citation accuracy or extraction recall validation
