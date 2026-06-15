# Zapier Copilot Build: AI Governance Pipeline

AI governance gets a lot of airtime. I wanted to actually understand it, so I built a working pipeline to find out what it takes.

It's a 10-step Zap that answers a question, classifies the question and the answer separately for sensitivity, logs everything, and routes anything risky to a human review queue. Built in Zapier with Copilot doing the wiring.

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

The result: every question gets answered, the question and answer are classified independently (a clean question can still produce a sensitive answer), the classification fails closed, the whole thing is logged for good, and anything risky lands in a review queue with an instant email.

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

Cost note: each step is a Zapier task. The webhook trigger keeps single-entry runs cheap, which is the main reason it's built this way instead of on a scheduler. See `LESSONS.md` for the task-budget math.
