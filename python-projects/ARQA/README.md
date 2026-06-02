# Automated Requirements Quality Assistant (ARQA)

> *Technical standards don't read themselves. This tool does.*

An AI-powered document intelligence suite built with LangChain and RAG (Retrieval-Augmented Generation), designed for systems engineers and technical program managers working with complex specifications and standards.

Instead of manually searching through hundreds of pages of guidebooks, ask questions in plain English and get answers pulled directly from the source documents, with page-level citations.

---

## Tools

### v1.0 — Standards & Guidebook Q&A (prototype)

The original proof of concept: natural language querying across a collection of systems engineering standards and technical guidebooks. It validated the RAG + reranking approach that v2 builds on. Not included in this repo — v2 is the shipped tool.

**Example queries:**
- *"What are the consequences of poor requirements?"*
- *"Summarize the systems engineering process"*
- *"What does the DevSecOps guide say about continuous integration?"*

**Key Features:**
- Semantic search + FlashRank reranking
- Self-query retrieval — filter results by specific document
- Page-level citations with every answer
- Conversational memory across a session

---

### v2.0 — Automated Requirements Quality Assistant (current)

The shipped tool, and the notebook included in this repo (`ARQA.ipynb`). Automatically extracts SHALL statements from a performance specification and evaluates each one against a knowledge base of systems engineering standards.

**Validation Results (10-requirement synthetic audit):**

| Metric | Result |
|--------|--------|
| Requirements audited | 10 |
| NON-COMPLIANT findings | 5 |
| Substantive gaps flagged | 3 |
| Citations per finding | 3 (avg), page-level |
| Suggested rewrites provided | Yes — all non-compliant findings |

**Key Features:**
- Automatic SHALL statement extraction from any PDF
- Header/structural SHALL filtering
- LLM selects the most relevant standard(s) for each requirement
- FlashRank reranking
- Citation tracking with source document and page number

---

## Tech Stack

| Component | Tool |
|-----------|------|
| RAG orchestration | LangChain |
| LLM (v1) | OpenAI |
| LLM (v2) | Google Gemini (`gemini-flash-latest`) |
| Embeddings (v1) | OpenAI |
| Embeddings (v2) | Google Gemini (`gemini-embedding-001`) |
| Vector store | ChromaDB |
| Reranker | FlashRank (`ms-marco-MiniLM-L-12-v2`) |
| PDF loading | PyPDF |
| Runtime | Google Colab |

---

## Setup

### 1. Open in Google Colab

The notebook is designed to run in Google Colab — no local installation required.

### 2. Add your API keys

In Colab, go to the Secrets tab and add `GOOGLE_API_KEY` (v2 uses Google Gemini — free tier).

### 3. Upload your PDF documents

Upload your technical standards or requirements PDFs directly to the Colab session storage.

### 4. Run all cells in order

---

## Document Sources

The pipeline is document-agnostic. Swap in your own standards and the tool adapts.

**Current knowledge base:**
- `MIL-STD-882E.pdf` — System Safety
- `DOD SysEng Guidebook.pdf` — Systems Engineering best practices
- `Scrum-Guide-US-2020.pdf` — Agile/Scrum methodology
- `DOD_DevSecOps Fundamentals.pdf` — DevSecOps practices

---

## Project Roadmap

| Version | Tool | Status |
|---------|------|--------|
| v1.0 | Standards & Guidebook Q&A | ✅ Complete (prototype) |
| v2.0 | Automated Requirements Quality Assistant | ✅ Complete (current) |
| v3.0 | Verification Method Generator | 📋 Planned |

---

## Known Limitations

- No ground truth oracle — findings require human review
- SHALL extraction is regex-based — may miss unusually formatted statements
- Header filtering is heuristic — not exhaustive
- Colab session storage only — re-upload PDFs on each new session

---

*Built to solve real problems encountered managing large-scale technical programs.*
