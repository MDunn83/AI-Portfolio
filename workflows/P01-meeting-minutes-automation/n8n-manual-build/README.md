# n8n Meeting Intelligence Pipeline

This is the manual n8n build of my meeting pipeline, and it's the one I built by hand first. When a meeting transcript comes in, the workflow pulls out a summary, the action items, the decisions, and the open questions all at the same time. Then it creates a task for each action item, emails a formatted recap to the attendees, and logs the meeting to a Google Sheet, so nobody has to take notes by hand.

---

## What It Does

When someone submits a transcript through a Google Form, the workflow starts on its own and runs four AI passes on the transcript at the same time:

- **Summary**: 3 to 5 bullets covering the main points of the meeting, with the date and participants pulled out at the top
- **Action Items**: every task, with its owner and due date listed first so they're easy to scan
- **Decisions**: every final decision, policy change, or agreed outcome, leaving out general discussion
- **Open Questions / Blockers / Dependencies (QBD)**: anything still unresolved that needs follow-up

Once all four are done, the workflow combines them into one record and sends it three places at once: a formatted email, a log sheet that keeps every meeting, and Google Tasks.

---

## Architecture

```
Google Form submission (transcript pasted)
  → Google Sheets Trigger (new row added)
      → [4 parallel LLM chains run simultaneously]
          → LLM Chain 1: Summary + Date + Participants extraction
          → LLM Chain 2: Action items with owners and due dates
          → LLM Chain 3: Decisions and agreed outcomes
          → LLM Chain 4: Open questions, blockers, dependencies
      → Edit Fields (rename outputs: summary, actions, decisions, qdb)
      → Merge (4 inputs, wait for all parallel chains to complete)
      → Aggregate (collect all 4 outputs into single object)
      → Edit Fields4 (parse and structure: extract date, participants, summary, actions, decisions, qdb)
          → Send a message (Gmail: formatted HTML email with all sections)
          → Append row in sheet (Google Sheets log: persistent record of every meeting)
      → LLM Chain 5: Re-parse action items into structured JSON array
          → Structured Output Parser (enforce JSON schema)
          → Split Out (unpack action_items array)
          → Create a task (Google Tasks: one task per action item)
```

---

## Parallel Processing Design

All four LLM chains start from the same trigger and get the full transcript at the same time, and each one works on its own. Because they run in parallel, the four passes take about as long as one would. The Merge node waits for all four to finish before passing anything along, so that no section is missing when the email and the log entry get written.

Creating the tasks runs on its own branch. After the outputs are combined, I send the action items through a fifth LLM chain that turns the bulleted list into a JSON array, using a Structured Output Parser to hold it to a fixed format. That way the Split Out node can break the list apart and create one Google Task per action item, instead of one task holding the whole list.

---

## AI Model

All five LLM chains run on **Groq** with the `llama-3.1-8b-instant` model. Groq is fast, which helps a lot here, because the four calls running at once finish without any noticeable wait.

Each chain has its own system prompt that tells the model to act like an administrative assistant, return only plain-text bullet lists, and start right away without an introduction. The chain that builds the task list uses a stricter prompt that only allows JSON, and the Structured Output Parser node checks that the JSON matches the expected format.

---

## Email Output Format

The Gmail node sends a formatted HTML email with clearly labeled sections:

```
Hi Team,

Date: [extracted date]

Participants: [extracted participant list]

Executive Summary:
• [bullet]
• [bullet]
• [bullet]

Action Items:
• [Owner] | [Due Date] | [Task description]
• ...

Decisions:
• [Decision]
• ...

QBD (Questions, Blockers, Dependencies):
• [Open item]
• ...

Regards,
M
```

---

## Log Sheet Structure

Every meeting is appended to a persistent Google Sheet with the following columns:

| Column | Content |
|---|---|
| Date | Meeting date extracted from transcript |
| Participants | Attendee list extracted from transcript |
| Summary | 3-5 bullet executive summary |
| Action Items | Full action item list with owners and due dates |
| Decisions | All decisions and agreed outcomes |
| QBD | Open questions, blockers, and dependencies |

---

## Data Source

The trigger is a **Google Form** with one large text field labeled "Meeting Minutes." Each submission adds a row to a connected Google Sheet, and that new row starts the Google Sheets Trigger node. The transcript lands in the sheet's `Meeting Minutes` column.

For testing, I used made-up transcripts written by an AI model, and they worked well. The workflow doesn't need real meeting recordings or a connection to Zoom, Google Meet, or Teams. Any text that reads like a meeting transcript will work.

---

## Setup

### Prerequisites
- n8n Cloud account (or self-hosted n8n instance)
- Google account with Google Sheets, Gmail, and Google Tasks access
- Groq API key (free tier available at console.groq.com)

### Step 1: Create your Google Form
Create a Google Form with one long-answer text question labeled "Meeting Minutes." Connect it to a Google Sheet so form responses populate automatically.

### Step 2: Create your log sheet
Create a second Google Sheet for the persistent meeting log with these column headers: `Date | Participants | Summary | Action Items | Decisions | QBD`

### Step 3: Create a Google Tasks list
In Google Tasks, create a task list for the action items. Write down the task list ID, because you'll need it for the Create a task node.

### Step 4: Set up credentials in n8n
Create the following credentials in n8n's credential manager:
- **Groq API**: API key from console.groq.com
- **Google Sheets Trigger OAuth2 API**: OAuth2 for the trigger node
- **Google Sheets OAuth2 API**: OAuth2 for the append node
- **Gmail OAuth2 API**: OAuth2 for the send email node
- **Google Tasks OAuth2 API**: OAuth2 for the task creation node

### Step 5: Import and configure
1. Import `P01-meeting-minutes-automation-manual.json` into n8n via the workflow menu
2. Update the Google Sheets Trigger node to point to your form responses sheet (`YOUR_FORM_SHEET_ID`)
3. Update the Append row in sheet node to point to your log sheet (`YOUR_LOG_SHEET_ID`)
4. Update the Send a message node with your email address (`YOUR_EMAIL_HERE`)
5. Update the Create a task node with your Google Tasks list ID (`YOUR_TASK_LIST_ID`)
6. Connect all credentials to their respective nodes
7. Activate the workflow

### Step 6: Test
Submit a transcript through your Google Form. Within 30-60 seconds you should receive an email, see a new row in your log sheet, and find new tasks in Google Tasks.

---

## A Note on Meeting Minutes as a Snapshot

This pipeline records where things stood at the time of the meeting, and it isn't meant to be the final word. The decisions it captures are the positions people held in that meeting. If something changes afterward, that change shows up in the record for a later meeting, not this one.

That's also why the QBD section exists. I wanted the record to show what was still open after the meeting, so open questions and unresolved items are called out on their own instead of only listing what was decided.

---

## File Structure

```
n8n-meeting-intelligence/
├── P01-meeting-minutes-automation-manual.json    # n8n workflow (credentials scrubbed)
└── README.md
```

---

## Built With

- [n8n](https://n8n.io): workflow automation
- [Groq](https://console.groq.com): LLM inference (llama-3.1-8b-instant)
- Google Forms: transcript ingestion
- Google Sheets: trigger and persistent log
- Gmail: formatted email delivery
- Google Tasks: automatic task creation
