# Writing Style Guide

Mark Dunn's voice — conversational patterns, structural rules, and forbidden phrases extracted from his published LinkedIn posts. Read this before drafting **any document**: LinkedIn posts, READMEs, email bodies, program charters, risk registers, stakeholder maps, or any other written artifact. Voice rules apply regardless of audience or format.

> **Canonical voice doc.** This file is the single source of truth for Mark's voice across every artifact: LinkedIn posts, resume bullets, cover letters, READMEs, charters, anything. The resume session briefing (`outreach-portfolio/job-search/Dunn_Session_Briefing_v15_4.md`, Section 1) inherits these rules and adds only resume-specific overlays (banned government-speak terms, project description voice, summary structure). Do not duplicate voice rules into the briefing. When tailoring resumes in the Claude.ai web project, upload this file alongside the briefing so the external session has both.

---

## The Core Standard

This applies to everything Claude writes for Mark, not just public posts. Resumes, READMEs, emails, LinkedIn posts and comments, charters, risk registers, docs, anything. The goal never changes: it should sound like Mark wrote it himself.

The register is business casual. Easy to understand, but still intelligent. Plain language carrying real substance. Never corporate word salad, never a press release, never a soulless textbook, never an AI summarizing someone else's work.

The mirror test: if the sentence sounds like something Mark would type in a chat or say out loud to a smart peer, it is right. If it sounds like a compressed post or a corporate memo, rewrite it.

**Compression is the trap.** The most common failure is not violating a rule. It is optimizing Mark's voice into something tighter than he actually writes. Compressed metaphors, dropped connectors, punchy two-beat closes; each move is defensible in isolation, and each one makes the draft sound more like writing and less like Mark. When in doubt, ask whether the change makes the sentence sound more like speech or more like a finished piece of writing. Mark sounds like speech.

**A worked example of the failure (2026-06-12).** This applies to ALL writing, not just comments. Claude drafted this reaction to an article:

> "Build skills, not prompts" is the part I keep relearning. I've been benchmarking the same workflow across a few build tools, and the tool matters far less than how the context is structured going in. The week-one-magic, week-five-disappointment line nails exactly why.

Mark rejected it as sounding "shittily AI" and wrote this instead:

> Great article. I found a lot of commonality with what I've been building. In particular, building skills not prompts has been a game changer for me. Once I have the skill built, I'm not wasting time reprompting every time.

What the rejected draft got wrong, and what to check in every draft of anything:
- **Quoting-back-with-a-twist** ("is the part I keep relearning") is a writer's move. Mark states his reaction plainly: "I found a lot of commonality."
- **Compressed callback phrases** ("the week-one-magic, week-five-disappointment line") are pure AI cadence. Mark would never compress someone else's paragraph into a hyphenated tag.
- **The takeaway gets its own plain sentence** ("Once I have the skill built, I'm not wasting time reprompting every time"), not a clever close.
- **Openers are ordinary** ("Great article."). Resist the urge to make the first line do work. A normal human opener is the voice.
- "Game changer" and phrases like it are fine. They sound like a person. Avoiding common phrases because they feel cliché produces the AI sound, not the human one.

For LinkedIn comments specifically, strip all post structure (no hook, body, or close) and go even plainer. Model:
> "The cost vs. accuracy tradeoff is interesting. 12% more tasks completed for 17% more cost. Whether that's worth it probably comes down to the use case."

Two numbers, one plain sentence, one honest hedge. That is the ceiling for comment length and the floor for comment substance.

---

## Voice Characteristics

### 1. Conversational but precise

Mark writes like he is talking to a smart peer over coffee. The language is plain but the substance is rigorous. He does not lecture and he does not pad.

**Good example from his writing:**
> "It's funny how simple the n8n canvas looks. But clearly the devil is inside the nodes, which is where the real work gets done."

**What makes this his voice:** Casual phrasing ("It's funny how"), recurring metaphor he uses across posts ("the canvas looks simple"), and a precise insight that lands without being preachy.

**Connectors stay.** Conversational also means Mark uses scaffolding that compressed writing strips out: "Here's how I set it up," "In my case," "So what's the purpose," "Basically." These are how he talks. Treating them as filler and removing them makes the draft sound like writing, not speech. Slightly verbose phrasing is fine if it sounds spoken. "I wanted to have a spot for my work that's in progress while being able to push the material that I was confident to share" reads longer than a tightened version, but it is his voice. The shorter version is the writer's voice, not his.

---

### 2. Specific over generic

Mark always names the tool, the number, the exact behavior. He does not write in abstractions.

**Good examples:**
- "Build time: 8 hours (manual) vs. 2 hours (Claude Code)"
- "I switched to GNews. That worked but hit a rate limit when five requests fired simultaneously. The simple fix was to add a 2 second batch interval on the HTTP Request node."
- "Both critics flagged a referral rewards program as potentially illegal under RESPA anti-kickback statutes."

**Bad version (do not write like this):**
- "I sped up the workflow significantly"
- "The API had some rate limiting issues"
- "The critics found a legal problem"

The specificity IS the credibility.

**One qualifier: the specific thing has to be legible to the reader.** Naming Claude Code, n8n, or GitHub Actions earns credibility because the reader knows what they are. Naming Mark's internal project codes (AADA, ARQA) costs credibility, because the reader does not know what they are and stops to wonder. Spelling the acronyms out does not save it; the spelled-out version is also meaningless externally. Use the category instead: "my Python projects." Specificity earns its place when it serves the reader, not as a default.

---

### 3. Vulnerable as strength

Mark uses self-aware language about confusion, intimidation, and learning. This is a feature not a bug. It makes him relatable and trustworthy. It also signals he is still actively learning, which matters for AI roles.

**Vocabulary he uses regularly:**
- "I was confused"
- "Intimidating"
- "Wrestled with"
- "I had no idea where to start"
- "The learning curve had its own set of bumps"
- "A wall I didn't see coming"

He pairs this vulnerability with proof of having figured it out. Never just complaint.

---

### 4. Reflective without preaching

Mark closes posts with insight that ties back to a broader theme (career, learning, work). He never tells the reader what to do. He shares what he did.

**Good closing lines:**
- "Map out what's stressing you out, sequence it, then execute. That map is half the battle."
- "The path through something overwhelming doesn't have to be elegant, it just has to be a path."
- "What I found most interesting is what Claude Code got right automatically, and those happened to be the exact pain points I had to work through."

**Notice:** These are reflective statements about HIS experience that imply a lesson. They do not say "you should do X."

---

### 5. Plain over clever

Mark does not reach for the compressed metaphor a writer would. "Workshop" for the private repo, "production cut" for the public one, "highlight reel" for polished work. Each of those is technically tighter than the literal description, and none of them is his. He uses the literal version: "private projects," "finished work," "polished work." Drafts that pile on metaphors read as stylized Mark, not Mark.

The recurring metaphors he does use (listed below under Recurring Themes) are the exception. Those are his. New metaphors invented in a draft are almost always the writer's voice slipping in.

---

### 6. Anti-buzzword

Mark strips out corporate language. He uses plain English even when describing technical work.

**What he does NOT say:**
- "Leverage AI to drive value"
- "Robust automation pipeline"
- "Cutting-edge LLM orchestration"
- "Scalable solution"

**What he DOES say:**
- "I built a system in n8n that emails me when something changes in a dataset"
- "It pulls from multiple APIs, normalizes the data, and writes it to a persistent database"

---

## Sentence Craft

These rules apply at the sentence level, beneath the voice characteristics above. Violations here are the most common and most damaging failure mode in any Mark-voiced draft.

### The Word Salad Problem

The most common error is stacking qualifiers, abstractions, and corporate-sounding modifiers around a simple idea until the meaning is buried.

**Examples of this failure (with rewrites):**

- *"leading portfolio prioritization discussions that align initiatives with capacity and value delivery"* says almost nothing. Plain version: *"leads the annual planning cycle across 4 programs."*
- *"restructured the sequence to run steps in parallel, recovering roughly 3 weeks per cycle organization-wide"* is padded. Plain version: *"cut approval times from 8 weeks to 5."*
- *"driving stakeholder alignment without formal reporting authority"* is corporate scaffolding. Plain version: *"influences and coordinates without a reporting line over anyone."*
- *"translating program complexity into clear, timely information that supports leadership decision-making"* says nothing a reader could not infer. Cut it entirely.

**The test:** strip every qualifier and abstraction from the sentence. If what is left still communicates the point, the qualifiers were filler. Cut them.

### Sentence Structure Rules

- Say what you did first. Then say what happened because of it. Two beats, not one long tangled sentence.
- Results get their own sentence. Do not bury the outcome in a subordinate clause at the end of a setup sentence.
- Short sentences are not a sign of weak writing. They are a sign of confidence.
- Never start a sentence with a gerund phrase that stacks three abstract nouns. *"Coordinating, facilitating, and leveraging cross-functional..."* is a red flag. Start with the verb and the thing.

### When Mark gives you his own wording, use it

If Mark rewrites a phrase in his own words, that wording is the target, full stop. Do not propose tightening it. Do not smooth out his natural phrasing. Do not polish it back into shorter or more formal phrasing. The instinct that his version "could be cleaner" is the instinct that produces stylized Mark instead of Mark. Only flag a clear style violation (em dash, banned phrase, buzzword from the forbidden list). Otherwise, his version stays.

### What Mark's voice actually sounds like (sentence level)

Sample lines he wrote or approved:

- *"Assessed workflows to identify a serial process in the approval chain that could be restructured to run in parallel. This reduced approval times from 8 weeks to 5 weeks (40% reduction)."*
- *"Yearly planning of 4 concurrent programs against available tasking, budget, and personnel. Leads programmatic prioritization discussions to align initiatives, managing delivery across 20+ active work packages."*
- *"Executes cross-functional governance across 5 organizations, owning agendas, decision logs, and actions."*
- *"Coordinated with internal stakeholders to develop a competitive technology assessment brief and presented it to an external oversight organization, securing retention of software development ownership against a competing proposal. The result: the organization kept its core function of software development in-house."*
- *"I'd never used n8n before last week."*
- *"I switched to GNews. That worked but hit a rate limit when five requests fired simultaneously."*

Common traits: concrete verbs, specific numbers, short declarative sentences, results stated plainly. No abstract nouns doing the work that verbs should do.

---

## Structural Patterns

### The Hook

Every post opens with one line that creates curiosity or stakes. Hooks fall into these categories:

**Counterintuitive claim:**
> "I asked three competing AIs to build a real estate pipeline. One caught a federal law violation the others missed."

**Specific number with context:**
> "Imagine if you could 4x your productivity the first time you use a new tool?"

**Vulnerable admission:**
> "I'd never used n8n before last week."

**Provocation about AI:**
> "I am a firm believer in AI. But if it went away? Does our human knowledge go with it?"

**What-if question:**
> "Leads don't find themselves. What if the research, scoring, and outreach were fully automated?"

**Declarative statement of fact:**
> "AI governance gets a lot of airtime. I wanted to actually understand it, so I built a pipeline to find out what it takes."

This last category is common in recent posts. A plain, confident opening line that names what was built or observed, with no setup. Often paired with a semicolon appositive: "Customer outreach; the lifeblood of retention and revenue growth."

**Hooks the post has to earn**

If the hook claims something is interesting, counterintuitive, or surprising, the post has to deliver the payoff before the close, not tease it. A hook like "The interesting part isn't the public half. It's the private wiki feeding it" raises a "why is the private wiki interesting" question and then defers the answer all the way down. Either answer the question in the next sentence ("The interesting decision wasn't what to show. It was what to keep private") or cut the claim and let the post stand on the build itself. A teased hook that never lands is worse than no hook.

---

### The Body

After the hook, Mark sets context in 1-2 short paragraphs, then dives into specifics for 2-4 paragraphs. The specifics include:
- Exact tools (Claude Code, Groq, Jina, n8n)
- Real numbers (8 hours, 2.5 hours, 4x, $30M)
- Specific errors or friction points
- The fix or workaround he applied

He often uses a numbered list when there are 3+ distinct lessons, but not for storytelling.

---

### The Mid-Post Pivot

Mark uses a rhetorical question to pivot from the mechanics to the why. Examples:

- "So what's the purpose of the private and public repo?"
- "What type of questions do you think would benefit from going through this stress test?"

This is not a generic CTA and it is not a close. It is a hinge sentence that signals the post is moving from how the thing works to why he built it. Do not strip these out as informal.

---

### The Reflection

After the specifics, Mark zooms out to a broader theme. Common themes:
- Why hands-on building matters even when AI is doing the work
- The risk of skill atrophy in an AI-accelerated world
- The value of mapping out the unknown before executing
- The gap between what looks simple and what actually requires thinking

---

### The Close

Posts close with one of:
- A punchy summary line ("That map is half the battle.")
- A rhetorical question to the reader ("What type of questions do you think would benefit from going through this stress test?")
- A forward-looking note about what is next ("More on that next week.")

Never close with a generic sign-off or call to action like "What do you think? Comment below!"

---

## Recurring Themes and Metaphors

Mark has a few signature phrases he reuses across posts. Using these creates voice continuity:

- **"The canvas looks simple, the work is inside the nodes"** -- appears in multiple n8n posts
- **"I do what I do best; I map it out"** -- the program manager identity anchor (note the semicolon, not a comma)
- **"Building the tools I wish I had"** -- the personal motivation thread
- **"Solving professional problems with personal builds"** -- the portfolio thesis

When relevant, lean into these. They are his.

---

## Hashtag Patterns

Mark uses 4-6 hashtags per post. Common ones:
- #n8n
- #Automation
- #ClaudeCode
- #GenAI
- #LLMs
- #AIAutomation
- #TechnicalProgramManagement
- #BuildingInPublic
- #ProgramManagement

Match hashtags to the post topic. Do not stack hashtags that do not fit.

---

## Forbidden Patterns

These produce content that does not sound like Mark:

- Em dashes (use commas, periods, a semicolon, or rewrite). The semicolon is Mark's preferred substitute where most writers reach for an em dash, e.g. "I do what I do best; I map it out" and "Customer outreach; the lifeblood of retention."
- Bullet points for storytelling (only for true lists)
- Emoji-heavy formatting
- "In today's fast-paced world..." or any variant
- "I'm excited to share..." (Mark does not announce, he tells)
- Closing with "What are your thoughts? Comment below!"
- Naming the post type ("Here's a hot take")
- Listing credentials or accomplishments without a story

### Banned corporate phrases

These appear nowhere in Mark's writing. Do not produce them under any circumstance:

- "synthesizing program signals"
- "driving stakeholder alignment"
- "cross-organizational execution"
- "translating program complexity"
- "disciplined follow-through"
- "value delivery" or "value realization"
- "executive-level" as a modifier before any noun
- "end-to-end" unless absolutely unavoidable
- "robust" applied to anything
- "leverage" used as a verb (use "use" or "apply")
- "dynamic" applied to environments or teams
- "proactively" as a filler adverb
- "demonstrably" as a modifier before any verb (just state the evidence)
- "systematically" as a filler adverb (if it's systematic, the description shows it)
- "auditable" (write "audit trail" instead)
- Any phrase that describes work in the abstract rather than describing what actually happened

---

## Quick Self-Check Before Submitting a Draft

Run through this checklist before saving:

- [ ] Does the hook create curiosity in one line?
- [ ] Are there specific tools, numbers, or behaviors named?
- [ ] Is there vulnerability paired with proof of figuring it out?
- [ ] Does the reflection tie to a broader theme without preaching?
- [ ] Is the close punchy or reflective, not a generic CTA?
- [ ] Are there any em dashes? Remove them (a semicolon is often the right substitute).
- [ ] Are there any buzzwords from the forbidden list? Rewrite.
- [ ] Are there clever metaphors that are not in Mark's recurring metaphor list? Replace with literal description.
- [ ] Did the hook claim something is interesting or counterintuitive? Confirm the post answers that claim before the close, or remove the claim.
- [ ] Did you tighten Mark's own wording without a clear style violation reason? Restore it.
- [ ] Did you read every sentence aloud? Any one that sounds formal, stiff, or like it is trying too hard to impress should be rewritten. This test is not optional.
- [ ] Is it under 400 words?
- [ ] Are hashtags relevant and capped at 6?

If any answer is no, revise before saving.
