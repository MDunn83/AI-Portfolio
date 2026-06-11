# n8n Job Board Aggregation & Delta Detection Pipeline

A two-workflow automated data pipeline built in n8n that aggregates job listings from multiple job board APIs (Greenhouse and Ashby), filters for relevant roles, normalizes disparate data schemas into a unified format, detects net-new listings against a historical baseline, and delivers automated email notifications, all on a configurable schedule.  This workflow is meant to save time so you're not constantly manually searching career pages

Built as a first n8n project. No Python. No code. Just nodes.

---

## What It Does

**Workflow 1 — Build Database (PermDB)**
Pulls job listings from Greenhouse and Ashby APIs for a configurable list of target companies, filters for roles matching specified criteria (e.g. title contains "Manager", location is "Remote"), normalizes field names across both platforms into a single unified schema, and writes results to a Google Sheets database.

**Workflow 2 — Compare and Notify (Compare DB and Email)**
Runs on a schedule. Rebuilds a fresh dataset from the same APIs, compares it against the historical database to identify net-new listings, appends new listings to the historical database, sends a single aggregated email notification with all new URLs, and clears the temporary dataset for the next run.

---

## Architecture

### Workflow 1 — Build Database

```
Schedule Trigger
  → Get row(s) in sheet       # Read list of target companies (name, API type, token)
  → Loop Over Items           # Process one company at a time
      → Switch (mode: Rules)  # Route by API type: Greenhouse | Ashby | Lever
          → HTTP Request (Greenhouse: boards-api.greenhouse.io)
              → Split Out     # Unpack jobs array
              → If            # Filter: title contains "Manager" AND location contains "Remote"
                  → Append row in sheet (OrigDB)
          → HTTP Request (Ashby: api.ashbyhq.com/posting-api)
              → Split Out     # Unpack jobs array
              → If            # Filter: workplaceType equals "Remote" AND title contains "Manager"
                  → Append row in sheet (OrigDB)
          → Merge             # Reconcile all branches before next loop iteration
```

### Workflow 2 — Compare and Notify

```
Schedule Trigger
  → Get row(s) in sheet1      # Read company list (same source as Workflow 1)
  → OrigDB (Get row(s))       # Read historical database — Compare Datasets Input A
  → Loop Over Items           # Rebuild fresh dataset
      → Switch → HTTP Requests → Split Out → If → Temp DB Populate
      → Merge
  → Loop done → Limit (1)
      → TempDB_AfterLoop (Get row(s))   # Read completed Temp DB — Input B
  → Compare Datasets          # Key field: absolute_url
      → In B only             # Net-new listings not in historical database
          → Aggregate         # Collect all new records into single list
          → Split Out         # Unpack for row-by-row append
          → Append row in sheet1 (OrigDB)   # Update historical database
          → Send a message (Gmail)           # One email with all new listings
          → Clear sheet       # Wipe Temp DB for next run (keep header row)
```

---

## API Details

### Greenhouse
**Endpoint:** `https://boards-api.greenhouse.io/v1/boards/{token}/jobs`
**Auth:** None required for public job boards
**Key fields:**
- `jobs.title` — job title
- `jobs.location.name` — location string (e.g. "Remote", "New York, NY")
- `jobs.absolute_url` — direct link to job posting
- `jobs.updated_at` — last updated timestamp
- `jobs.first_published` — first published timestamp

### Ashby
**Endpoint:** `https://api.ashbyhq.com/posting-api/job-board/{token}`
**Auth:** `accept: application/json` header required
**Key fields:**
- `jobs.title` — job title
- `jobs.workplaceType` — "Remote", "OnSite", "Hybrid"
- `jobs.jobUrl` — direct link to job posting (maps to `absolute_url` in unified schema)
- `jobs.updatedAt` — last updated timestamp
- `jobs.publishedAt` — first published timestamp

### Schema Normalization
Greenhouse and Ashby use different field names for the same data. The Append node maps both to a unified schema:

| Unified Field | Greenhouse Source | Ashby Source |
|---|---|---|
| `absolute_url` | `jobs.absolute_url` | `jobs.jobUrl` |
| `title` | `jobs.title` | `jobs.title` |
| `updated_at` | `jobs.updated_at` | `jobs.updatedAt` |
| `first_published` | `jobs.first_published` | `jobs.publishedAt` |

---

## Source Sheet Structure

The pipeline reads from a Google Sheet that lists target companies. Each row is one company:

| Column | Description | Example |
|---|---|---|
| `Token` | API board token/slug for the company | `stripe` |
| `Type` | API type: `greenhouse` or `ashby` | `greenhouse` |

The Switch node reads the `Type` field to route each row to the correct HTTP Request node.

---

## Key Technical Decisions

**Race condition via Merge node**
When True/False If branches run at different speeds, they compete to feed the next node. A Merge node with 3 inputs (true branch, false branch, and Append output) forces all branches to reconcile before the next loop iteration begins. Without this, data loss and duplicate loop heartbeats occur.

**Loop completion via Limit node**
The Loop Over Items node's "done" output passes all accumulated loop data downstream.  In testing this produced 4,000+ items being passed to a simple Get Row(s) node, causing it to execute thousands of times. A Limit node set to 1 item truncates this to a single trigger pulse, ensuring TempDB_AfterLoop fires exactly once after the loop completes.

**Delta detection via Compare Datasets**
The Compare Datasets node keys on `absolute_url` in both inputs. The "In B only" output contains records present in the fresh Temp DB but absent from OrigDB, which are the new listings. OrigDB grows with each run, so previously seen listings are never surfaced again.

**Aggregate before notify**
Without aggregation, the Gmail node fires once per new listing, producing one email per record. An Aggregate node set to "All Item Data Into a Single List" collects all new records before the email node, producing one consolidated notification per run regardless of how many new listings were found.

**"Always output data" on specific nodes**
Several nodes inside the loop require "Always output data" enabled to prevent empty outputs from killing the workflow when no jobs match the filter criteria. This is a known n8n behavior for conditional branches — without it, a company with zero matching jobs causes the loop to stall.

---

## Setup

### Prerequisites
- n8n Cloud account (or self-hosted n8n instance)
- Google account with Google Sheets and Gmail access
- List of target companies with their Greenhouse or Ashby board tokens

### Finding API Tokens
- **Greenhouse:** Visit `https://boards.greenhouse.io/{company-slug}` — the slug in the URL is the token
- **Ashby:** Visit the company's job board hosted on Ashby — the slug in the URL is the token

### Configuration Steps

1. **Import workflows** — import each JSON file into n8n via the workflow menu (three-dot → Import)

2. **Create your source sheet** — Google Sheet with columns `Token` and `Type`, one row per target company

3. **Create OrigDB** — Google Sheet with header row: `absolute_url | title | updated_at | first_published`.  You can add more fields as you'd like, such as job title.

4. **Create Temp DB** — Google Sheet with the same header row as OrigDB

5. **Connect Google Sheets credential** — OAuth2 in n8n's credential manager, apply to all Google Sheets nodes

6. **Connect Gmail credential** — OAuth2 in n8n's credential manager, apply to Send a message node

7. **Update document IDs** — in each Google Sheets node, update the Document field to point to your sheets (replace `YOUR_SOURCE_SHEET_ID`, `YOUR_ORIGDB_SHEET_ID`, `YOUR_TEMPDB_SHEET_ID`)

8. **Update filter criteria** — in the If nodes, update `YOUR_FILTER_KEYWORD` and `YOUR_LOCATION_FILTER` to match your search criteria.  You can add as many filters as you'd like

9. **Update Gmail recipient** — in Send a message node, replace `YOUR_EMAIL` with the email address you want to send new job openings to

10. **Run Workflow 1 once** to populate OrigDB with the initial dataset

11. **Activate Workflow 2** for ongoing scheduled delta detection.  

### Schedule
Both workflows are configured to trigger at 7:00 AM by default. Update the Schedule Trigger node to your preferred cadence. Workflow 2 should run after Workflow 1 has had time to complete — if running both on a schedule, stagger them by at least 10-15 minutes.  Since my original DB is already built, I only have Workflow 2 scheduled.

---

## File Structure

```
n8n-job-pipeline/
├── PermDB_clean.json                   # Workflow 1 — Build Database
├── Compare_DB_and_Email_clean.json     # Workflow 2 — Compare and Notify
└── README.md
```

---

## Notes

- The Temp DB is cleared (except for the first column) at the end of every Workflow 2 run. If a run fails before reaching the Clear node, clear it manually in Google Sheets before the next run to avoid false positives in the comparison.
- Google Sheets API rate limits apply. After heavy testing, you may experience throttling on the Get Row(s) nodes. Wait 15-20 minutes and retry.
- Credential IDs in the JSON files are placeholders. You must reconnect credentials in your own n8n instance after import.

---

## Built With

- [n8n](https://n8n.io) — workflow automation
- [Greenhouse Jobs API](https://developers.greenhouse.io/job-board.html) — job board data
- [Ashby Posting API](https://developers.ashbyhq.com/reference/introduction) — job board data
- Google Sheets — data storage
- Gmail — notification delivery
