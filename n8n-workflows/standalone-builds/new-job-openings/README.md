# New Job Openings — Automated Job Board Monitor

Checks Greenhouse and Ashby job boards for a configurable list of companies every morning. Filters for roles matching your criteria, deduplicates against a history sheet, and emails you a summary — whether or not new listings were found.

Built in n8n. No LLM required. No code to run locally.

---

## What It Does

1. Reads your company list from Google Sheets
2. Hits the public Greenhouse or Ashby API for each company
3. Filters jobs by title keywords, exclude terms, and location
4. Skips any URL already logged in your Jobs DB (dedup)
5. Emails you the results — new listings with links, or "no new openings today" if none
6. Appends any new listings to your Jobs DB for future dedup

---

## Setup

### Prerequisites
- n8n Cloud account (paid, for reliable execution at 26+ companies)
- Google account with Google Sheets and Gmail access
- A list of target companies with their Greenhouse or Ashby board tokens

### Step 1: Create Your Google Sheets

**Company List sheet** — one row per company:
| Column | Example |
|---|---|
| Company | Stripe |
| Type | greenhouse |
| Token | stripe |

**Jobs DB sheet** — starts empty, grows over time:
| Column | Notes |
|---|---|
| title | |
| url | Dedup key |
| company | |
| updated_at | |
| first_published | |

### Step 2: Find Board Tokens

**Greenhouse:** Visit `https://boards.greenhouse.io/{company-slug}` — the slug in the URL is the token.
Example: `https://boards.greenhouse.io/stripe` → token is `stripe`

**Ashby:** Visit the company's Ashby-hosted job board. The slug in the URL is the token.
Example: `https://jobs.ashbyhq.com/vercel` → token is `vercel`

Supported Type values: `greenhouse`, `ashby` (case-insensitive)

### Step 3: Import the Workflow

Import `new-job-openings-v2.json` into n8n via the workflow menu.

### Step 4: Connect Credentials

Connect the following credentials in n8n after import:
- **Google Sheets OAuth2 API** — to all three Google Sheets nodes
- **Gmail OAuth2 API** — to the Send Email node

### Step 5: Fill In Placeholders

| Node | Field | Set To |
|---|---|---|
| Read Jobs DB | Document + Sheet | Your Jobs DB sheet |
| Append New Jobs | Document + Sheet | Your Jobs DB sheet (same) |
| Read Company List | Document + Sheet | Your Company List sheet |
| Build Email Code | `recipientEmail` in the code | Your email address |

### Step 6: Activate

Enable the workflow. It runs daily at 6:00 AM by default (adjust the Schedule Trigger to your preference).

The first run seeds your Jobs DB with all currently matching jobs. Subsequent runs only notify you of listings that weren't in the DB from a prior run.

---

## Customizing Filters

Open the **Fetch Filter Dedup** Code node and edit the constants at the top:

```javascript
const TITLE_EXCLUDE = ['Product', 'Social Media', 'Account', 'Sales', 'Marketing'];
const TITLE_KEYWORDS = ['Manager', 'AI'];
const TITLE_MODE = 'any';        // 'any' = match if any keyword present
const LOCATION_KEYWORDS = ['Remote'];
const LOCATION_MODE = 'any';
```

**Filter hierarchy:** Exclude terms are checked first. A title containing any exclude term is dropped, regardless of whether it also matches an include keyword. This prevents "Product Manager" from matching when `Manager` is in your include list.

**TITLE_MODE / LOCATION_MODE options:**
- `'any'` — job passes if it matches at least one keyword
- `'all'` — job must match every keyword

Empty arrays (`[]`) skip that filter entirely and allow all values through.

---

## Adding or Removing Companies

Edit your Company List sheet. Add or remove rows. The workflow reads the sheet fresh every run — no workflow changes needed.

---

## Notes

- If a run fails before reaching Append New Jobs, the Jobs DB is unchanged. The next run will re-detect the same jobs as new. Re-import or re-run to clear this.
- Google Sheets API rate limits apply. If you see throttling errors after heavy testing, wait 15–20 minutes before retrying.
- The workflow supports Greenhouse and Ashby APIs only. Other job board platforms (Lever, Workday, etc.) are not supported in the current version.
