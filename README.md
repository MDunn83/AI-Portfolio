# AI Portfolio

Solving professional problems with personal builds.

These are the tools I built to make my own work better. Adversarial AI for stress-testing decisions, RAG for cutting through technical specifications, n8n automations for the boring parts of a job hunt. Each one started as a real friction point and turned into something I could ship.

The code in this repo is auto-synced from my private wiki on every push to main. What you see here is the production cut. Drafts, lessons learned, and writing experiments live upstream.

---

## Projects

### AADA — Adversarial AI Decision Analyzer
[`python-projects/AADA/`](python-projects/AADA/)

A multi-model pipeline that routes a single question through Claude, Gemini, and GPT-4o, has them critique each other, then folds the critiques back into a final answer. On one real-estate pipeline prompt it caught a federal RESPA anti-kickback violation that the single-model answer missed. About 3 cents per run, roughly 95 seconds end to end.

Current version is V3.5 with dynamic routing. The second critique pass only fires when the first-pass critics materially disagree, with a hard cap of two passes regardless.

### ARQA — Automated Requirements Quality Assistant
[`python-projects/ARQA/`](python-projects/ARQA/)

A LangChain and RAG suite that reads technical specifications, pulls out every SHALL statement, and evaluates each one against a knowledge base of systems engineering standards. Returns page-level citations and a suggested rewrite when a requirement is non-compliant. Built for systems engineers and TPMs who have spent too many afternoons searching PDFs by hand.

v1 was a prototype for natural-language Q&A across a guidebook library; v2 is the shipped tool that automates the full SHALL audit. v3 (verification method generator) is on the roadmap.

### Workflows
[`workflows/`](workflows/)

Automation builds across two platforms. The headline build is a daily job board monitor that watches Greenhouse and Ashby for a target company list, filters by title and location, deduplicates against a Google Sheets history, and emails a digest every morning whether or not anything new showed up.

Production workflows live in `standalone-builds/`. The numbered project folders (P01 through P07) trace the learning builds, several with the same pipeline built multiple ways: by hand in n8n, with Claude Code, and on Zapier. `lessons_learned.md` collects the patterns that survived contact with real data.

---

## Reference

The `reference/` folder collects the runtime rules I lean on when building with Claude Code.

- `n8n_SKILL.md`. The pre-build checklist and critical snippets for writing n8n workflow JSON.

---

## How These Get Built

I direct the architecture; Claude Code generates most of the code, which I review, debug, and benchmark against manual builds. That division of labor is deliberate and documented per project. Commits here are made by a sync bot mirroring my private wiki, so the commit history shows the publishing pipeline, not the build work. The build work lives in the project docs.

---

## About

I'm Mark Dunn, a technical program manager building the tools I wish I had. I run large software and hardware programs by day and build AI pipelines on my own time. This repo is the production half of that work. A private wiki holds the drafts and works-in-progress that are not ready to ship yet.

- **LinkedIn:** [linkedin.com/in/mdunn83](https://www.linkedin.com/in/mdunn83)
- **GitHub:** [github.com/MDunn83](https://github.com/MDunn83)

If you're hiring for technical program management in AI or automation, the fastest tour is AADA's README, then the [P01 comparison](workflows/P01-meeting-minutes-automation/): the same pipeline built by hand in n8n, with Claude Code, and with Zapier Copilot, with measured results.
