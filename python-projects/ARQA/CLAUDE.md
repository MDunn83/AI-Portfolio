# ARQA — Project CLAUDE.md

Applies to the `ARQA` project only. Read the root CLAUDE.md first — this file adds project-specific context.

---

## Project Overview

ARQA (Automated Requirements Quality Assistant) is an AI-powered document intelligence suite built with LangChain and RAG. It extracts SHALL statements from technical specifications and evaluates them against systems engineering standards with page-level citations.

## Project Files

| File | Notes |
|---|---|
| `ARQA.ipynb` | The v2 notebook (the shipped tool) — runs in Google Colab |

## Key Architecture

- Designed for Google Colab — no local installation required
- The committed notebook is v2: Google Gemini LLM + embeddings (free with a Google API key)
- v1 was an OpenAI + ChromaDB prototype that proved the RAG approach; it is not in this repo
- Vector store does not persist between Colab sessions — re-upload and re-embed on each new session
- FlashRank reranker (`ms-marco-MiniLM-L-12-v2`) for improved retrieval quality
- Document-agnostic: swap in any PDF standards or guidelines

## Credentials Required

| Key | Where to set |
|---|---|
| `GOOGLE_API_KEY` | Colab Secrets tab |

Known limitations (regex extraction, heuristic header filtering, no ground-truth oracle, no Colab persistence) are documented in `README.md` § Known Limitations.
