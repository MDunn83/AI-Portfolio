# Automated Requirements Quality Assistant (ARQA)

> *Technical standards don't read themselves. This tool does.*

I built this tool with LangChain and RAG (retrieval-augmented generation) for systems engineers and technical program managers who work with long specifications and standards. I've spent a lot of time searching through hundreds of pages of guidebooks by hand, and this lets you ask a question in plain English and get an answer pulled straight from the source documents, with the page number cited.

---

## Tools

### v1.0: Standards and Guidebook Q&A (prototype)

The first version was a proof of concept that let you ask plain-language questions across a set of systems engineering standards and technical guidebooks. It showed that the RAG and reranking approach worked, and v2 builds on it. It isn't in this repo, because v2 is the finished tool.

**Example questions:**
- *"What are the consequences of poor requirements?"*
- *"Summarize the systems engineering process"*
- *"What does the DevSecOps guide say about continuous integration?"*

**What it did:**
- Searched by meaning and then reranked the results with FlashRank
- Let you limit the search to one specific document
- Cited the page for every answer
- Remembered the conversation within a session

---

### v2.0: Automated Requirements Quality Assistant (current)

This is the finished tool and the notebook in this repo (`ARQA.ipynb`). It pulls every SHALL statement out of a performance specification and checks each one against a knowledge base of systems engineering standards.

I tested it on a made-up specification with 10 requirements:

| Metric | Result |
|--------|--------|
| Requirements audited | 10 |
| NON-COMPLIANT findings | 5 |
| Substantive gaps flagged | 3 |
| Citations per finding | 3 on average, each with a page number |
| Suggested rewrites provided | Yes, for every non-compliant finding |

**What it does:**
- Pulls the SHALL statements out of any PDF
- Filters out SHALLs that are just headers or document structure
- Has the LLM pick the standard or standards that matter most for each requirement
- Reranks the results with FlashRank
- Tracks the source document and page number for every citation

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

The notebook is built to run in Google Colab, so there's nothing to install locally.

### 2. Add your API key

In Colab, open the Secrets tab and add `GOOGLE_API_KEY`. Version 2 uses Google Gemini, which has a free tier.

### 3. Upload your PDF documents

Upload your technical standards or requirements PDFs to the Colab session storage.

### 4. Run all cells in order

---

## Document Sources

The pipeline works with any documents, so you can swap in your own standards.

**Current knowledge base:**
- `MIL-STD-882E.pdf`: System Safety
- `DOD SysEng Guidebook.pdf`: Systems Engineering best practices
- `Scrum-Guide-US-2020.pdf`: Agile and Scrum methodology
- `DOD_DevSecOps Fundamentals.pdf`: DevSecOps practices

---

## Project Roadmap

| Version | Tool | Status |
|---------|------|--------|
| v1.0 | Standards and Guidebook Q&A | ✅ Complete (prototype) |
| v2.0 | Automated Requirements Quality Assistant | ✅ Complete (current) |
| v3.0 | Verification Method Generator | 📋 Planned |

---

## Known Limitations

- There's no answer key to check the findings against, so a person still needs to review them.
- The SHALL extraction uses pattern matching, so it can miss statements that are formatted in an unusual way.
- The header filtering is based on rules of thumb and won't catch everything.
- Files only live in the Colab session, so you have to upload the PDFs again each new session.

---

*I built this to solve problems I ran into while managing large technical programs.*
