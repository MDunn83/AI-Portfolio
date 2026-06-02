# claude_code_SKILL.md -- Claude Code Patterns for All Projects

## When to read this

Skim once per session for any project work in this repo. These are Claude-Code-as-a-tool patterns: session management, branch handling, token limits, CLAUDE.md hygiene, and GitHub MCP gotchas. They apply equally to n8n, Python, and outreach work.

For n8n-specific syntax and runtime rules, read `n8n_SKILL.md`. For the full n8n build pattern library (node behavior, dedup, execution-order, with code), read `n8n-workflows/lessons_learned.md`.

---

## Setup and Access

**Claude Code web version requires a GitHub connection.**
For a fully cloud-based workflow with no local install, connect via GitHub integration.

**GitHub repo permissions are not automatic.**
Repos created after the initial GitHub authorization are not automatically visible to Claude Code. Go to GitHub Settings -> Applications, find the Claude Code app, and manually add the new repo.

**Global CLAUDE.md requires local CLI install.**
The global CLAUDE.md file (at `~/.claude/CLAUDE.md`) only works with the local CLI install. When using the web version via GitHub, all context must live inside the repo itself.

---

## Session Management

**Always specify the branch at session start.**
Claude Code defaults to `main` on every resumed session.

**Push after every phase -- not at the end.**
Force a push after every major phase and confirm the file exists on GitHub before telling it to continue.

**Break complex builds into small sub-phases.**
Even when a build is already split into phases, individual phases can be too large. Break each phase down until each sub-phase has one clear deliverable and one push.

**Watch for silent hangs.**
If there is no new output after 2 minutes, interrupt it. When in doubt, interrupt and ask for a status update.

**Resumed sessions carry forward bad state.**
When a session goes sideways, close it and start fresh rather than resuming. CLAUDE.md is the persistent context -- the session itself is disposable.

---

## Local Machine and Git

**Stop hooks are a hidden hazard.**
Add the following to every CLAUDE.md before starting any session:

```
Do not initialize local git repos. Do not create or modify stop hooks or any files
under ~/.claude/. GitHub MCP only. Do not run any local git commands.
```

**Claude Code runs in a Linux container, not your Windows machine.**
File paths like `/root/.claude/` are inside Claude Code's cloud container. Closing the session wipes the container state automatically.

**Stop hook sync after MCP push.**
`mcp__github__push_files` creates a new commit on the remote branch; the local repo has no knowledge of it. A stop hook that checks for uncommitted local changes will fire after every MCP push. After any MCP push, sync the local branch to the remote:

```bash
git fetch origin <branch-name>
git reset --hard origin/<branch-name>
```

---

## CLAUDE.md -- The Most Important Habit

**Put mandatory read instructions at the very top.**
Skill file instructions must be the first lines in CLAUDE.md or Claude Code may skip them entirely.

**CLAUDE.md is a forcing function.**
The quality of Claude Code output is directly proportional to the quality of CLAUDE.md. Minimum content for any project CLAUDE.md: credential names exactly as they appear in the target system, LLM provider and model, data source structure and column names, output targets, and lessons from prior builds.

**Claude Code will rewrite your CLAUDE.md if you let it.**
Always check that your mandatory read instructions and constraints are still present after any session where Claude Code touched CLAUDE.md.

**Include phase-gating instructions in CLAUDE.md.**

```
After completing each phase, push to GitHub and stop. Wait for explicit confirmation
before proceeding to the next phase.
```

**Wiring instructions need to be diagram-level specific.**
Describe wiring as: "Route By Score True branch connects to BOTH Email Writer Chain AND Log to Summary. Gmail is a dead end -- nothing wires from it."

**CLAUDE.md quality determines output quality.**
The gap between a Claude Code build that imports cleanly and one that requires hours of post-import fixes is almost entirely determined by CLAUDE.md quality.

---

## Token Limits and Output Management

**32,000 output token limit on Pro plan.**
Break large builds into explicit parts and instruct Claude Code to stop and wait after each one.

**Keep prompts lean.**
Instructions like "double and triple check your work" dramatically inflate output size without improving quality.

---

## Architecture and Design

**Do design work before opening Claude Code.**
Use Claude chat to finalize architecture and then bring a clean spec to Claude Code.

**Claude Code's tool choices are often better than manual build choices.**
Trust Claude Code's independent tool selections. The friction is target-system syntax, not design quality.
