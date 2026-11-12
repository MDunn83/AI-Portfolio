# Zapier Copilot Build: AI Governance Pipeline

AI governance gets a lot of airtime. I wanted to actually understand it, so I built a working pipeline to find out what it takes.

It's a 10-step Zap that answers a question, classifies the question and the answer separately for sensitivity, logs everything, and routes anything risky to a human review queue. I built it in Zapier, with Copilot doing the initial wiring.

See `LESSONS.md` for the design decisions and where I overrode the obvious choice, and `P04-ai-governance-zapier-copilot.json` for the scrubbed export.

---

## What It Does

A new row lands in the "Questions" sheet and the Zap fires:

1. **Trigger.** Google Sheets webhook on a new row in the Questions sheet.
2. **Answer the question.** GPT-4.1 nano generates a plain-text answer. The prompt tells it to skip markdown so the output is clean.
3. **Classify the question.** A separate AI call labels the query SENSITIVE, STANDARD, or UNCERTAIN and assigns a domain (PII, FINANCIALS, LEGAL, HR, MEDICAL, CREDENTIALS, STRATEGIC, NAMED_INDIVIDUAL, or NONE).
4. **Classify the answer.** Another AI call runs the same schema on the response, independently of the question.
5. **Validate and override.** A Code step parses both classifications and fails closed: any invalid class becomes SENSITIVE.
6. **Log everything.** Every query writes to the "Zapier Audit Log" sheet regardless of classification: timestamp, user ID, question, answer, and both classifications.
7. **Route the risky ones.** A Path checks whether the query class OR the response class is SENSITIVE or UNCERTAIN.
8. **Queue for review.** Flagged items get appended to the "Zapier Review" sheet as the human review queue.
9. **Notify the reviewer.** Gmail sends a formatted email to the reviewer inbox with the question, the answer, and both classifications.
10. **Done.** Everything is audited, nothing is skipped, and the reviewer sees flagged items in real time.

So every question gets answered, and the question and the answer are classified separately, because a harmless question can still produce a sensitive answer. If a classification comes back invalid, it's treated as sensitive. Everything is logged permanently, and anything risky goes to a review queue with an email sent right away.

---

## Architecture

```
Google Sheets trigger (new row in Questions)
  -> AI answer (GPT-4.1 nano, plain text)
      -> AI classify question (class + domain)
      -> AI classify answer (class + domain)
          -> Validate + override (fail closed: invalid -> SENSITIVE)
              -> Append to Audit Log (always, every query)
                  -> Path: query OR response is SENSITIVE / UNCERTAIN
                      -> Append to Review queue sheet
                      -> Gmail alert to reviewer
```

Cost note: each step is a Zapier task. The webhook trigger keeps runs with a single new question cheap, and that's the main reason I built it this way instead of on a schedule. See `LESSONS.md` for the task-budget math.
