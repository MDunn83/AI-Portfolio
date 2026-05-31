# ARQA — Project CLAUDE.md

Applies to the `ARQA` project only. Read the root CLAUDE.md first — this file adds project-specific context.

---

## Project Overview

ARQA (Automated Requirements Quality Assistant) is an AI-powered document intelligence suite built with LangChain and RAG. It extracts SHALL statements from technical specifications and evaluates them against systems engineering standards with page-level citations.

## Project Files

| File | Notes |
|---|---|
| `ARQA.ipynb` | Main notebook — runs in Google Colab |

## Key Architecture

- Designed for Google Colab — no local installation required
- v1: OpenAI LLM + embeddings, ChromaDB vector store
- v2: Google Gemini LLM + embeddings (free to run with Google API key)
- Vector store does not persist between Colab sessions — re-upload and re-embed on each new session
- FlashRank reranker (`ms-marco-MiniLM-L-12-v2`) for improved retrieval quality
- Document-agnostic: swap in any PDF standards or guidelines

## Credentials Required

| Key | Where to set |
|---|---|
| `OPENAI_API_KEY` | Colab Secrets tab (v1 only) |
| `GOOGLE_API_KEY` | Colab Secrets tab (v2) |

## Known Limitations

- SHALL extraction is regex-based — may miss statements with unusual formatting
- Header filtering is heuristic — not exhaustive
- No ground truth oracle — findings require human review before action
- Colab session storage only — PDFs and vector store do not persist between sessions
