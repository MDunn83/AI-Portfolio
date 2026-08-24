# claude_code_SKILL.md -- Claude Code Patterns for All Projects

## When to read this

Skim once per session for any project work in this repo. These are Claude-Code-as-a-tool patterns: session management, branch handling, token limits, CLAUDE.md hygiene, and GitHub MCP gotchas. They apply equally to n8n, Python, and outreach work.

For n8n-specific syntax and runtime rules, read `n8n_SKILL.md`. For the full n8n build pattern library (node behavior, dedup, execution-order, with code), read `workflows/lessons_learned.md`.

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

**A wrap signal that coincides with compaction can be lost.**
If "end session" (or any session-wrap phrase) arrives just as the context window compacts, the continuation prompt's "resume without acknowledging" instruction can swallow the End of Session Protocol. After any compaction, re-check whether a wrap was requested before treating the session as ongoing.

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

**A session branch may exist locally without existing on GitHub.**
A web/remote session can start with the session branch checked out locally and even show a `remotes/origin/<branch>` tracking ref, while the branch does not exist on GitHub yet. That tracking ref is a local artifact of the clone, not proof of a remote branch. Run `git ls-remote origin <branch>` (a live query) to confirm; `git branch -r` only shows what was already fetched. Since the branch isn't really on the remote until the first push, a session branch whose name no longer fits the work (they're auto-named from the opening task) can be renamed with `git branch -m` before that first push, with nothing to clean up remotely.

---

## GitHub Actions

**Scheduled workflows are dropped or delayed at the top of the hour.**
GitHub runs `schedule:` crons on a best-effort queue that is congested at :00 -- and the other round minutes (:05, :10, :15, :30). A daily `0 13 * * *` can simply never fire. Use an off-peak odd minute (e.g. `56 13 * * *`) and expect a few minutes of drift regardless. A newly changed cron may also skip its first cycle, so don't count on the very next slot.

**An invalid workflow YAML makes every push spawn a failed run.**
A malformed `.github/workflows/*.yml` (e.g. a duplicated `schedule:` key from a bad re-sync) isn't inert -- GitHub creates a failed run on each push and emails "No jobs were run." Validate workflow YAML (duplicate keys included) before pushing; a burst of those emails right after an edit points straight at the workflow file.

**The GitHub MCP token can't trigger workflow_dispatch.**
`run_workflow` returns 403 "Resource not accessible by integration" -- the app token lacks `actions:write`. Only the user (Actions UI / `gh`) or the cron can start a run. Don't promise to trigger a workflow yourself; wait for the schedule or hand the user the `gh workflow run` command.

---

## CLAUDE.md -- The Most Important Habit

**Put mandatory read instructions at the very top.**
Skill file instructions must be the first lines in CLAUDE.md or Claude Code may skip them entirely.

**CLAUDE.md is a forcing function, not the filing cabinet.**
Output quality tracks the quality of the spec Claude Code reads -- but the spec is the whole project folder, not CLAUDE.md alone. CLAUDE.md holds directives and pointers (the closed list in the root convention); the substance it points to -- credential names exactly as they appear in the target system, LLM provider and model, data source structure and column names, output targets, lessons from prior builds -- lives in BUILD_PROCESS.md and REQUIREMENTS.md. Putting that substance directly in CLAUDE.md is how the junk drawer forms: the file the agent auto-reads is the path of least resistance, so everything you don't want forgotten gets dumped there until it instructs nothing well. Route by type; CLAUDE.md points.

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

**Wrap deterministic logic in a script, keep judgment in the skill.**
When a task recurs and has a deterministic core (scrub, transform, validate), build that core as a tested script with its own verification, and keep the skill thin: routing, file placement, sync-check, the calls that need judgment. The skill leans on the script's built-in guard instead of re-deriving the logic in prose each run, so the part that can't be allowed to drift doesn't.

**PostToolUse hooks require settings.json registration — skills cannot fire automatically.**
A skill is a prompt invoked by the agent or user; it runs only when called. A PostToolUse hook fires on a system event (Edit/Write) without any invocation. To wire a check that runs automatically whenever a file is edited, register it in `.claude/settings.json` under `hooks.PostToolUse`. Use hooks when the check must be automatic; use skills when on-demand is acceptable.
