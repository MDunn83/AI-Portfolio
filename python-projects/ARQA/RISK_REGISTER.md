# Risk Register: Automated Requirements Quality Assistant (ARQA)

**Version:** 1.0
**Date:** 2026-06-01
**Program Manager:** Mark Dunn

---

## Scoring Guide

**Probability:** L = Low (<20%) | M = Medium (20-60%) | H = High (>60%)
**Impact:** L = Low (minor rework or cost) | M = Medium (milestone slip or degraded output quality) | H = High (program objective at risk)
**Score:** Probability × Impact. HH = Critical | HM / MH = High | MM / HL / LH = Medium | ML / LM / LL = Low

---

## Risk Register

| ID | Risk Description | Category | Probability | Impact | Score | Mitigation | Owner | Status |
|----|-----------------|----------|-------------|--------|-------|------------|-------|--------|
| R01 | Gemini Flash free tier rate limits exceeded during large document processing, causing API failures mid-run | Technical | M | M | Medium | Implement batch processing with inter-batch delay; document maximum SHALL count guidance in README; paid tier required for v3.0+ scale | PM | Open |
| R02 | RAG retrieval returns low-relevance standard passages, producing citations that don't substantiate findings | AI Quality | M | H | High | FlashRank reranker (`ms-marco-MiniLM-L-12-v2`) applied to retrieval results; validate citation accuracy on each new standards corpus; test set maintained | PM | Mitigated |
| R03 | Scanned or image-only PDF inputs cause text extraction failure with no clear error surfaced to user | Technical | M | M | Medium | Validate input format at intake with explicit error message; document supported file types in README; OCR capability scoped to v3.0 if demand justifies | PM | Open |
| R04 | Standards corpus becomes outdated relative to current published versions, causing compliance findings based on superseded requirements | Data Quality | M | M | Medium | Version-stamp corpus at creation; include standard publication date in output report; schedule quarterly corpus review | PM | Open |
| R05 | Google Colab session timeout during long document processing causes loss of progress | Technical | H | L | Medium | Implement checkpoint-and-resume pattern; document maximum document size for single-session processing; break large documents into batches | PM | Open |
| R06 | LLM-generated rewrite suggestions introduce new non-compliance while appearing to fix original finding | AI Quality | L | H | Medium | Surface explicit advisory disclaimer on all rewrite suggestions; SME acceptance gate enforced; rewrite acceptance rate tracked as success metric | PM | Open |
| R07 | Proprietary or sensitive document content submitted through Colab, creating data handling exposure | Compliance | L | H | Medium | No server-side storage beyond active session; document data handling scope in README; advise users not to submit CUI or proprietary content | PM | Open |
| R08 | ChromaDB vector store performance degrades on large corpora, increasing retrieval latency beyond acceptable threshold | Performance | L | M | Low | Monitor retrieval time per query; evaluate index partitioning or HNSW parameter tuning if threshold exceeded at scale | PM | Open |
| R09 | Gemini Flash model deprecated or replaced with breaking API changes | Technical | L | M | Low | Abstract LLM calls behind interface; monitor Google API changelog for deprecation notices; model substitution tested at each version gate | PM | Open |
