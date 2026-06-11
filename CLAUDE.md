# CLAUDE.md

This is the public AI-Portfolio repo. The source of truth lives in a separate private wiki.

---

## MANDATORY: Read Before Starting Any Session

1. **Read `reference/WRITING_STYLE.md`** before writing any user-facing copy — READMEs, post drafts, email bodies, or anything that will be shared publicly.
2. **If working with n8n workflow JSON:** read `reference/n8n_SKILL.md` and `workflows/lessons_learned.md` completely before writing any node JSON.
3. **Read the project's own CLAUDE.md** (inside each project folder) before making any changes to that project.

Do not build or modify anything until you have confirmed you have read the relevant files.

---

## How edits flow

All code in this repo is mirrored from the upstream private wiki by a GitHub Action that fires on every push to main on the source side. Direct edits made in this repo will be overwritten on the next sync.

If you want to change something here, change it upstream.

---

## What lives here

- `workflows/` — automation projects built in n8n, including the production builds under `standalone-builds/`
- `python-projects/AADA/` — Adversarial AI Decision Analyzer (CLI + Streamlit)
- `python-projects/ARQA/` — Requirements quality assistant (LangChain + RAG, Colab)
- `reference/` — runtime rules and writing guides used across the projects

Each project has its own README and CLAUDE.md with setup details and architecture notes.

---

## Conventions

- No credentials, API keys, or sheet IDs in any committed file. Project READMEs cover how to set up the relevant `.env` file or Colab secrets.
- LLM prompts live in dedicated files (`prompts.yaml`, etc.), not inline in Python.
- READMEs are written in plain English. Buzzwords are out. Specific numbers and named tools are in.
