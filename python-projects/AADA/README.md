# AADA: Adversarial AI Decision Analyzer

> *"Does your AI output seem "off"? Stress test it."*

Most AI tools give you one confident answer, and it's hard to tell when that answer is wrong. I built AADA to check an answer by having other AI models critique it.

AADA sends a question to Claude, then has competing models, Gemini and GPT-4o, critique Claude's answer. Those critiques go back to Claude, which revises its answer. The final answer has been challenged by more than one model, so it holds up better than what any single model gives you, and a run costs about three cents.

I built it as a governance prototype. Having several models critique each other, sending the question back for another round when they disagree, and keeping a record of every step are the same ideas that larger AI review systems use.

It doesn't get rid of hallucinations or wrong answers. It does cut down on them, as long as you know what data each of the AI tools has been trained on.

---

## Roadmap

| Version | Theme | Status |
|---------|-------|--------|
| **V1** | Command-line proof of concept, with a single Claude→Gemini→Claude pass | ✅ Complete |
| **V2** | Fast and Deep modes, retry logic, token tracking, and a prompt config file | ✅ Complete |
| **V2.5** | Four modes, GPT-4o added, a Streamlit UI, and a JSON audit trail | ✅ Complete |
| **V2.6** | Optional disagreement analysis, covering agreement, disagreement, reversals, and defended positions | ✅ Complete |
| **V3** | Gemini and GPT-4o critique at the same time instead of one after the other | ✅ Complete |
| **V3.5** | A second round of critiques runs automatically when the critics disagree | ✅ Current |
| **V4** | Web application with a browser UI and streaming output | 🔜 Next |
| **V5** | Commercial product with billing and a public API | 📋 Planned |

## How It Works

<!-- Screenshot pending: uncomment when images/streamlit-ui.png is uploaded.
![AADA Streamlit UI](images/streamlit-ui.png)
-->

V3.5 uses up to three models, Claude, Gemini, and GPT-4o, and has four modes. In Fast 3 and Deep 3, Gemini and GPT-4o critique Claude's answer at the same time, and neither one sees what the other wrote. After the first round, an optional check looks at how much the critics disagreed and runs a second round if it's needed. There's also an optional disagreement analysis that shows how the pipeline got to its final answer.

| Mode | Models | API Calls | Description |
|------|--------|-----------|-------------|
| **Fast 2** | Claude + Gemini | 3 | Claude answers → Gemini critiques → Claude revises |
| **Deep 2** | Claude + Gemini | 5 | Two full rounds, where Gemini critiques Claude's *revision* as well as the original |
| **Fast 3** | Claude + Gemini + GPT-4o | 4–8 | Both critics at once, with the optional second round and optional analysis |
| **Deep 3** | Claude + Gemini + GPT-4o | 7–11 | Two rounds with both critics at once, plus the optional second round and optional analysis |

---

## Disagreement Analysis

Fast 3 and Deep 3 can run an extra call that writes up a four-part report:

1. **Points of Agreement:** issues both critics flagged on their own
2. **Points of Disagreement:** where the critics disagreed, and why
3. **Decision Reversals:** positions Claude changed between its first answer and its final one
4. **Defended Positions:** critiques Claude received but pushed back on

---

## The Second Round (V3.5)

After Claude revises its answer the first time, a quick Claude call checks whether Gemini and GPT-4o meaningfully disagreed. If they did, a second round of critiques runs automatically. It never runs more than two rounds.

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

The biggest catch was legal. Claude's first answer recommended a referral rewards program, and the critics flagged that it could violate the federal RESPA anti-kickback rules, so Claude reversed it in the final answer.

I'm planning a 12-question test against a single model as part of V4.0. The method and the questions are in [`EVAL_PLAN.md`](EVAL_PLAN.md).

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

### 4. Run the command-line version

```
python aada_v35.py
```

### 5. Or run the Streamlit UI

```
streamlit run aada_streamlit_v35.py
```

---

## Prompts

All five prompts are in `prompts.yaml`, and the command-line version and the Streamlit UI both use them:

| Prompt | Purpose |
|--------|--------|
| `system_prompt` | Sets up how Claude writes its first answer |
| `critique_prompt` | Sent to Gemini and GPT-4o |
| `revision_prompt` | Sent to Claude along with the critiques |
| `analysis_prompt` | Writes the disagreement analysis (Fast 3 and Deep 3 only) |
| `routing_prompt` | Checks whether the critics disagreed (V3.5 only) |

---

## Requirements

- Python 3.8+
- Anthropic API key
- Google Gemini API key
- OpenAI API key *(Fast 3 and Deep 3 only)*

---

## License

MIT
