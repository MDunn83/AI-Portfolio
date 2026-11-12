# AI Portfolio

Solving professional problems with personal builds.

I built these tools to make my own work easier. There's a tool that has several AI models critique each other's answers to stress-test a decision, a tool that checks the requirements in technical specifications, and a set of automations that handle the repetitive parts of tasks like a job search or a meeting recap. Each one started with a problem I actually had.

This repo copies over automatically from my private wiki every time I update it. It only holds the finished work, and my drafts and work in progress stay in the private wiki.

---

## Projects

### Adversarial AI Decision Analyzer
[`python-projects/AADA/`](python-projects/AADA/)

This pipeline sends one question to Claude, Gemini, and GPT-4o, has the models critique each other's answers, and then works those critiques into a final answer. When I asked it to design a real estate pipeline, the critics caught a referral rewards program that could violate the federal RESPA anti-kickback rules, which the single-model answer had missed. Each run costs about 3 cents and takes about 95 seconds.

The current version is V3.5, and it only runs a second round of critiques when the first-round critics meaningfully disagree. It never runs more than two rounds.

### Automated Requirements Quality Assistant
[`python-projects/ARQA/`](python-projects/ARQA/)

This is a LangChain and RAG tool that reads a technical specification, pulls out every SHALL statement, and checks each one against a knowledge base of systems engineering standards. For each requirement it cites the page in the standard, and if the requirement doesn't meet the standard, it suggests a rewrite. I built it for systems engineers and TPMs, because I've spent too many afternoons searching through PDFs by hand.

Version 1 was a prototype that answered plain-language questions across a library of guidebooks. Version 2 is the finished tool that checks every SHALL statement in a spec automatically. Version 3, which will suggest how to verify each requirement, is planned.

### Workflows
[`workflows/`](workflows/)

These are automations I've built on n8n, Make, and Zapier. The main one is a job board monitor that checks Greenhouse and Ashby for a list of target companies, filters the postings by title and location, removes any it has already seen using a Google Sheets history, and emails me a summary every morning, even when nothing new came up.

The workflows I use day to day are in `standalone-builds/`. The numbered folders, P01 through P07, are the projects I built to learn, and several of them have the same pipeline built more than one way: by hand in n8n, with Claude Code, and on Zapier. The patterns that held up across all of them are collected in `lessons_learned.md`.

---

## Reference

The `reference/` folder has the rules I give Claude Code when I build with it.

- `n8n_SKILL.md` is the checklist and the key code snippets I use before writing n8n workflow JSON.
- `claude_code_SKILL.md` covers how I manage Claude Code sessions, branches, and pushes.

---

## How These Get Built

I design the architecture, and Claude Code writes most of the code. I review it, debug it, and compare it against the builds I did by hand, and each project's docs say how the work was split. The commits in this repo are made by the bot that copies over my private wiki, so the commit history shows the publishing step, not the build work. The build work is written up in each project's docs.

---

## About

I'm Mark Dunn, a technical program manager who runs large software and hardware programs and builds AI pipelines in my personal time. This repo holds the finished half of that work, and the drafts and works in progress stay in my private wiki until they're ready.

- **LinkedIn:** [linkedin.com/in/mdunn83](https://www.linkedin.com/in/mdunn83)
- **GitHub:** [github.com/MDunn83](https://github.com/MDunn83)

If you're hiring for technical program management in AI or automation, I'd start with the Adversarial AI Decision Analyzer's README, then the [P01 meeting pipeline](workflows/P01-meeting-minutes-automation/), where I built the same pipeline by hand in n8n, with Claude Code, and with Zapier Copilot and measured the results.
