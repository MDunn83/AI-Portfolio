# AADA — Adversarial AI Decision Analyzer

> *"Does your AI output seem "off"?  Stress test it."*

Most AI tools give you a confident answer. AADA gives you a **battle-tested** one.
 
AADA is a multi-model AI pipeline that stress-tests responses by automatically routing them through adversarial critique from competing AI models, then feeding those critiques back to the original model for a final, improved answer. The result is a more defensible, higher-confidence output than any single AI can produce alone, for about three cents per run.
 
Built as a practical governance prototype, the pattern used here (multi-model critique, disagreement routing, audit trail) is directly analogous to how enterprise AI review systems work at scale.
 
While this doesn't eliminate hallucinations or inaccurate results, it's a practical mitigator, as long as you understand what data each AI tool you're using has been trained on.

---

## Roadmap

| Version | Theme | Status |
|---------|-------|--------|
| **V1** | CLI proof of concept — single Claude→Gemini→Claude pass | ✅ Complete |
| **V2** | Fast/Deep modes, retry logic, token tracking, prompt config | ✅ Complete |
| **V2.5** | Four modes, GPT-4o, Streamlit UI, JSON audit trail | ✅ Complete |
| **V2.6** | Opt-in disagreement analysis — agreement, disagreement, reversals, defended positions | ✅ Complete |
| **V3** | Parallel critique — Gemini and GPT-4o critique simultaneously, async architecture | ✅ Complete |
| **V3.5** | Dynamic routing — automatic second pass triggered by critic disagreement | ✅ Current |
| **V4** | Web application — browser UI, streaming output | 🔜 Next |
| **V5** | Commercial product — billing, public API | 📋 Planned |

## How It Works

<!-- Screenshot pending: uncomment when images/streamlit-ui.png is uploaded.
![AADA Streamlit UI](images/streamlit-ui.png)
-->

V3.5 runs up to three competing models (Claude, Gemini, GPT-4o) across four modes. In Fast 3 and Deep 3, Gemini and GPT-4o critique simultaneously and neither sees the other's output. An optional routing call evaluates critic disagreement after pass 1 and automatically triggers a second pass, if warranted. An optional disagreement analysis provides insight into exactly how the pipeline arrived at its final answer.

| Mode | Models | API Calls | Description |
|------|--------|-----------|-------------|
| **Fast 2** | Claude + Gemini | 3 | Claude answers → Gemini critiques → Claude revises |
| **Deep 2** | Claude + Gemini | 5 | Two full adversarial passes where Gemini critiques the *revision*, not just the original |
| **Fast 3** | Claude + Gemini + GPT-4o | 4–8 | Parallel critique, optional dynamic routing, optional analysis |
| **Deep 3** | Claude + Gemini + GPT-4o | 7–11 | Two parallel passes, optional dynamic routing, optional analysis |

---

## Disagreement Analysis

Fast 3 and Deep 3 include an optional disagreement analysis call that produces a four-section structured report:

1. **Points of Agreement** — issues both critics flagged independently
2. **Points of Disagreement** — where critics diverged and why
3. **Decision Reversals** — positions Claude changed between initial and final answer
4. **Defended Positions** — critiques Claude received but pushed back on

---

## Dynamic Routing (V3.5)

After Claude's pass 1 revision, a lightweight Claude call evaluates whether Gemini and GPT-4o materially disagreed. If disagreement is detected, a second parallel critique pass runs automatically. A hard cap of 2 passes is enforced regardless.

---

## Real-World Example

**Query:** *"Build me a real estate client acquisition and conversion pipeline."*

| Metric | Result |
|--------|--------|
| Issues caught | 4 |
| Legal compliance reversals | 1 (RESPA anti-kickback) |
| Factual corrections | 2 (conversion rate table, referral statistic) |
| Structural omissions caught | 1 (NAR settlement) |
| Cost per run | $0.02945 |
| Elapsed time | 97 seconds |

A 12-query benchmark against a single-model baseline is planned as a V4.0 milestone; the method and query set are in [`EVAL_PLAN.md`](EVAL_PLAN.md).

---

## Quickstart

### 1. Clone the repo

```
git clone https://github.com/MDunn83/AADA.git
cd AADA
```

### 2. Install dependencies

```
pip install -r requirements.txt
```

### 3. Set your API keys

Copy `.env.example` to `.env` and fill in your keys:

```
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
OPENAI_API_KEY=sk-...        # only required for Fast 3 and Deep 3
```

### 4. Run the CLI

```
python aada_v35.py
```

### 5. Or run the Streamlit UI

```
streamlit run aada_streamlit_v35.py
```

---

## Prompt Architecture

All five prompts live in `prompts.yaml` and are shared between the CLI and Streamlit UI:

| Prompt | Purpose |
|--------|--------|
| `system_prompt` | Claude's persona for initial answers |
| `critique_prompt` | Sent to Gemini and GPT-4o |
| `revision_prompt` | Sent to Claude with critique attached |
| `analysis_prompt` | Disagreement analysis (Fast 3 / Deep 3 only) |
| `routing_prompt` | Evaluates critic disagreement (V3.5 only) |

---

## Requirements

- Python 3.8+
- Anthropic API key
- Google Gemini API key
- OpenAI API key *(Fast 3 and Deep 3 only)*

---

## License

MIT
