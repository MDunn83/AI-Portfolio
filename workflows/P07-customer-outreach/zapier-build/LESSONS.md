# Lessons From the Customer Outreach Build (Zapier)

I built a daily customer-outreach automation in Zapier: it reads a list of customers, decides for each one whether to reach out and what to say, sends at most one message, and logs every customer. The whole thing is a priority router with a strong bias toward staying quiet. Most of the lessons are about restraint.

---

## 1. Suppression before selection

Before deciding what to say, the Code step decides whether to say anything. If a customer was contacted in the last 7 days, the category is `Suppressed` and the Zap sends nothing, just logs why. The single most important rule in the build is the one that produces no message. An outreach automation without a suppression guard will bombard people the moment two triggers line up.

## 2. A priority cascade, so one customer gets one message

A customer can trip several reasons to reach out at once: an open ticket, a near renewal, and a milestone in the same day. Rather than send three emails, one Code step assigns a single category in a fixed priority order: Ticket (raised in the last day), then Inactivity (more than 14 days), then Renewal (inside 30 days), then Milestone, else No Action. They get one message, about the most urgent thing, today. The lower-priority reasons surface on later days if they still apply.

## 3. Keep the judgment in one Code step and the routing dumb

All the logic lives in that one Code step, which outputs a single `category` string. The six Paths after it (A through F) just match that string with `iexact` and send the matching message. Spreading the conditions across six path filters would have meant six places to change a rule and six places for the logic to drift. With one decision node, I change the rules in one place and can read the whole policy top to bottom.

## 4. Log every customer every run, including the silent ones

Both the `Suppressed` path and the `No Action` path still write a log row. So does every message path. That means I can always answer "why didn't this customer get a message today," not just "who did." Auditing the silence matters as much as auditing the sends; without it, a suppression bug looks identical to everything working.

## 5. Close the loop: stamp last-contacted after sending

Each message path updates the customer's source row after the send, which is what makes the 7-day suppression in lesson 1 work on the next run. The suppression guard is only as good as the write that records the contact, so the update is part of the send, not an afterthought.

## 6. Do the date math in code

The Code step parses dates as `YYYY-MM-DD` and computes day-deltas (days since activity, days until renewal, days since last contact) in JavaScript. The routing depends entirely on those numbers being right, so they're calculated deterministically rather than left to a formula field or the model.

---

## Where It Stands

The build loops a customer list daily, routes each customer through suppression and the priority cascade, sends at most one tailored message, and logs all of it. The design is deliberately conservative: when in doubt, it stays quiet and records why. The priority order is a policy choice (a support ticket outranks a renewal), and it's the first thing I'd tune if the mix of messages going out didn't match what actually needs attention.
