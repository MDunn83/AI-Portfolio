# AADA — Project CLAUDE.md

Applies to the `AADA` project only. Read the root CLAUDE.md and `../../reference/WRITING_STYLE.md` first — this file adds project-specific context.

---

## Project Overview

AADA (Adversarial AI Decision Analyzer) is a multi-model AI pipeline that stress-tests LLM responses by routing them through adversarial critique from Claude, Gemini, and GPT-4o. Current version: V3.5 with dynamic routing.

## Project Files

| File | Notes |
|---|---|
| `aada_v35.py` | CLI version — current |
| `aada_streamlit_v35.py` | Streamlit UI version — current |
| `prompts.yaml` | All five prompts — edit here, not in Python |

## Key Architecture

- All prompts live in `prompts.yaml`, shared between CLI and Streamlit UI
- Dynamic routing: a Claude call evaluates critic disagreement after pass 1 and triggers a second pass if warranted
- Hard 2-pass cap regardless of routing decision
- Retry logic: all three API clients retry up to 3 times with exponential backoff (2s, 4s, 8s)
- Four modes: Fast 2, Deep 2, Fast 3, Deep 3 (3-model variants run Gemini and GPT-4o in parallel)

## Credentials Required

| Key | Where to set |
|---|---|
| `ANTHROPIC_API_KEY` | `.env` file |
| `GEMINI_API_KEY` | `.env` file |
| `OPENAI_API_KEY` | `.env` file (Fast 3 / Deep 3 only) |

Never commit `.env` — it is listed in `.gitignore`.

## Post-Edit Checklist

- [ ] Prompts edited in `prompts.yaml`, not hardcoded in Python
- [ ] No API keys in any committed file
- [ ] Both CLI (`aada_v35.py`) and Streamlit (`aada_streamlit_v35.py`) updated if core logic changed
- [ ] `.env` is listed in `.gitignore` and not staged for commit
