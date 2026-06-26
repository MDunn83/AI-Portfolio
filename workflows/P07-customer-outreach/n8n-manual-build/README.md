# Proj7 Outreach: Customer Message Automation

An n8n workflow that monitors a Google Sheet of customers and automatically sends personalized, AI-generated outreach emails when key events occur. Each email is written by an LLM (Groq / Llama 3.3 70B) using the customer's real data, then logged back to the sheet.

---

## How It Works

### Trigger
The workflow fires whenever a row is updated in the **Customers** tab of the linked Google Sheet. Every update is evaluated, but a built-in cooldown prevents a customer from being contacted more than once every 7 days.

### Cooldown Check
An **If** node computes how many days have passed since `Last Contacted Date`. If it's been 7 days or fewer, the workflow skips sending and instead writes a suppressed-email record to the Activity Log. If it's been more than 7 days (or the field is blank), the workflow continues to routing.

### Routing (Switch Node)
The updated row is evaluated against four conditions in order. The first match wins and routes to the corresponding email path:

| Path | Condition |
|---|---|
| **Ticket** | `Support Ticket Closed Date` is within the last 24 hours |
| **Inactivity** | `Last Activity Date` is 14 or more days ago |
| **Renewal** | `Renewal Date` is 30 or fewer days away |
| **Milestone** | `Milestone Reached?` equals `"Yes"` |

### AI Email Generation
Each path passes the customer's data to a **Groq Chat Model** (llama-3.3-70b-versatile) via an LLM Chain node. The prompt is tailored per path:

- **Ticket**: Warm follow-up acknowledging the resolved issue; subtly notes the relationship if renewal is near
- **Inactivity**: Re-engagement email noting how long the customer has been inactive and offering help
- **Renewal**: Courtesy auto-renewal notice with days-until-renewal and an offer to answer questions
- **Milestone**: Congratulatory note celebrating the customer's milestone

All prompts produce plain-text email bodies only (no subject line, no sign-off, 2–3 paragraphs).

### Email Delivery
Each path sends the generated body via **Gmail** (OAuth2). Subject lines are pre-set per path:

| Path | Subject |
|---|---|
| Ticket | `Ticket Resolution` |
| Inactivity | `{Customer Name}, We Want You Back!` |
| Renewal | `Auto-Renewal Reminder` |
| Milestone | `Congratulations Are In Order, {Customer Name}` |

### Logging & Record Update
After each email is sent, two write-back steps run in sequence:

1. **Append to Activity Log**: Adds a row to the `Activity Log` sheet with: Timestamp, Customer Name, Company, Trigger Type, Email Sent (`Yes`), and the first 100 characters of the email as a preview.
2. **Update Last Contacted Date**: Sets `Last Contacted Date` on the customer's row to today, which resets the 7-day cooldown clock.

Suppressed (cooldown-blocked) emails are also logged in step 1 with `Email Sent = No` and `Message Preview = "Contacted less than 7 days ago"`.

---

## Google Sheet Structure

**Customers tab**: one row per customer:

| Column | Description |
|---|---|
| Customer Name | Full name (used as the matching key) |
| Company | Company name |
| Plan Tier | Subscription tier |
| Email | Recipient address |
| Last Activity Date | ISO date of most recent product activity |
| Renewal Date | ISO date of subscription renewal |
| Last Contacted Date | ISO date of last outreach (updated by this workflow) |
| Milestone Reached? | `Yes` / blank |
| Support Ticket Closed Date | ISO date a support ticket was closed |

**Activity Log tab**: append-only audit trail written by the workflow:

| Column | Description |
|---|---|
| Timestamp | Full datetime of the automation run |
| Customer Name | Customer who triggered the workflow |
| Company | Customer's company |
| Trigger Type | `Ticket`, `Inactivity`, `Renewal`, `Milestone`, or `Surpressed` |
| Email Sent | `Yes` or `No` |
| Message Preview | First 100 characters of the generated email |

---

## Workflow Diagram

```
Google Sheets Trigger (row update)
        |
        v
   [If] Last Contacted > 7 days ago?
    |                    |
   Yes                   No
    |                    |
    v                    v
 [Switch]         Log "Suppressed"
  |  |  |  |       to Activity Log
  |  |  |  |
  T  I  R  M   (Ticket / Inactivity / Renewal / Milestone)
  |  |  |  |
  v  v  v  v
 [Groq LLM Chain — path-specific prompt]
  |  |  |  |
  v  v  v  v
 [Gmail — send email]
  |  |  |  |
  v  v  v  v
 [Append to Activity Log]
  |  |  |  |
  v  v  v  v
 [Update Last Contacted Date on Customers sheet]
```

---

## Setup Requirements

- **n8n** instance with the LangChain nodes package installed
- **Google Sheets OAuth2** credential connected to the spreadsheet
- **Google Sheets Trigger OAuth2** credential (separate OAuth app for the trigger)
- **Gmail OAuth2** credential for the sending address
- **Groq API** credential (API key from console.groq.com)

Import `Proj7 Outreach.json` into n8n, attach your credentials to each node, then activate the workflow.
