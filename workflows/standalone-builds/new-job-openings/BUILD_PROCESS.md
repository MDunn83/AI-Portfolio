# New Job Openings v2 — Build Process & Technical Reference

## Why v2 Exists

The original implementation used two separate workflows:

- **PermDB_clean.json** — seeded an initial jobs database by looping over companies and writing all matching jobs to a Google Sheet
- **new-job-openings.json** — ran daily, rebuilt the full dataset, compared against the database via Compare Datasets node, and emailed net-new listings

**Problems with v1:**

1. Two workflows to maintain and keep in sync on every filter change
2. Loop Over Items + Merge pattern caused race conditions and is brittle in n8n
3. Compare Datasets is a JOIN node — it compares items by index, not by "does this URL exist anywhere in the log." This produces incorrect dedup results as the DB grows.
4. Temp DB pattern (write fresh, compare, clear) requires manual recovery if a run fails mid-way
5. HTTP Request nodes for each company stored full API responses in n8n execution data → OOM crashes at 26 companies

**v2 design goal:** Single workflow. No Loop Over Items. No Compare Datasets. No Temp DB. No separate seeder. Runs clean every time.

---

## Architecture

```
Schedule Trigger
├── Read Jobs DB          (dead-end: populates cross-node reference cache only)
└── Read Company List
    └── Fetch Filter Dedup   (single Code node: all HTTP calls, filtering, dedup)
        └── Build Email Code
            └── Send Email
                └── Prepare Rows Code
                    └── Append New Jobs
```

### Execution Order via Fan-Out

Schedule Trigger fans out to **two nodes simultaneously**:

- **Read Jobs DB** is the first listed connection → executes first → its rows are available via `$('Read Jobs DB').all()` when Fetch Filter Dedup runs
- **Read Company List** is the second listed connection → its output feeds Fetch Filter Dedup

Read Jobs DB has **no outgoing connection** — it is a dead-end node. Its only purpose is to execute before Fetch Filter Dedup so the known URLs Set can be built for dedup.

If Read Jobs DB had an outgoing connection into the main chain, it would multiply items: N DB rows × 26 companies = N×26 items fed into Fetch Filter Dedup, causing a timeout. This was the row multiplication bug encountered during the v2 build (see Bugs section).

---

## Code Nodes — Detailed

### Fetch Filter Dedup

**Mode:** `runOnceForAllItems`

**Responsibility:** Read all companies from the Company List, fetch job listings from the Greenhouse or Ashby API for each company, apply the filter hierarchy, dedup against known URLs, and return a single wrapper item.

**Filter Configuration Constants:**
```javascript
const TITLE_EXCLUDE = ['Product', 'Social Media', 'Account', 'Sales', 'Marketing'];
const TITLE_KEYWORDS = ['Manager', 'AI'];
const TITLE_MODE = 'any';          // 'any' = OR match, 'all' = AND match
const LOCATION_KEYWORDS = ['Remote'];
const LOCATION_MODE = 'any';
```

**Filter Hierarchy (order matters):**
1. Exclude list checked first — title containing ANY exclude term is immediately dropped
2. Include keywords checked second — title must match the configured mode
3. Location filter checked third
4. URL dedup checked last — URLs already in Jobs DB are skipped

This order means "Product Manager Remote" is dropped at step 1 before include or dedup checks.

**Why all HTTP calls happen inside one Code node:**

n8n stores each node's full output in execution data. If 26 companies each return 200+ job listings through HTTP Request nodes, that's 5,000+ raw items accumulating in memory before any filtering — an OOM crash. By fetching inside a single Code node loop, raw API responses are processed and discarded immediately. Only the small filtered result set (typically 0–30 items) ever enters n8n execution data.

**HTTP method inside Code nodes:**
```javascript
const data = await this.helpers.httpRequest({
  method: 'GET',
  url: url,
  headers: { 'accept': 'application/json' },
  json: true
});
```
`fetch()` is **not** available in n8n's Code node sandbox. `this.helpers.httpRequest()` is the required method.

**Output shape:** Always exactly one item:
```javascript
return [{ json: { matched: matched, hasNew: matched.length > 0 } }];
```
The wrapper item is returned even when `matched` is empty. This ensures Build Email Code always fires (see "Always-Fire Pattern" below).

---

### Build Email Code

**Mode:** `runOnceForAllItems`

**Responsibility:** Render the email body HTML and set the recipient. Handles both states.

```javascript
if (result.hasNew) {
  // HTML <ul> list of matching jobs with title, company, and URL
} else {
  emailBody = '<p>No new job openings today matching your criteria.</p>';
}
```

**Placeholder:** `recipientEmail: 'YOUR_EMAIL'` — replace after import.

---

### Prepare Rows Code

**Mode:** `runOnceForAllItems`

**Responsibility:** Unpack the matched jobs array into individual items for the Append node.

```javascript
const jobs = $('Fetch Filter Dedup').all()[0].json.matched || [];
return jobs.map(function(job) { return { json: job }; });
```

Uses a cross-node reference rather than `$input` because Send Email outputs Gmail API metadata, not matched jobs. When `matched` is empty, this node returns no items — Append New Jobs does not execute, which is correct.

---

## Always-Fire Email Pattern

v1 only sent an email when new jobs were found. v2 always sends an email.

The key is the return shape of Fetch Filter Dedup. If it returned `[]` (empty array) when no jobs matched, n8n would halt execution and Build Email Code would never fire. By always returning `[{ json: { matched: [], hasNew: false } }]`, the downstream chain always executes and Build Email Code decides which message to render based on `hasNew`.

---

## API Details

### Greenhouse
**Endpoint:** `https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=false`
**Auth:** None required for public boards
**Relevant fields:** `jobs[].title`, `jobs[].absolute_url`, `jobs[].location.name`, `jobs[].updated_at`, `jobs[].first_published`

### Ashby
**Endpoint:** `https://api.ashbyhq.com/posting-api/job-board/{token}`
**Auth:** `accept: application/json` header required
**Relevant fields:** `jobs[].title`, `jobs[].jobUrl` (maps to `url`), `jobs[].workplaceType`, `jobs[].updatedAt`, `jobs[].publishedAt`

The Code node normalizes both APIs to a unified schema: `title`, `url`, `location`, `company`, `updated_at`, `first_published`.

---

## Bugs Encountered During Build

### Bug 1: `fetch is not defined`
**Symptom:** Code node throws `ReferenceError: fetch is not defined`
**Cause:** n8n Code node sandbox does not expose `fetch()` as a global
**Fix:** Replace `fetch(url)` with `this.helpers.httpRequest({method, url, headers, json})`

### Bug 2: OOM crash (HTTP Request node approach)
**Symptom:** Workflow crashed with out-of-memory error when processing 26 companies
**Cause:** Original design used individual HTTP Request nodes per company type. n8n stores each node's full output in execution data. 26 companies × 200+ raw job listings each → thousands of items in memory before any filtering
**Fix:** Collapsed all HTTP calls into a single Code node loop. Raw responses are processed and discarded immediately; only the filtered result set enters execution data.

### Bug 3: Row multiplication (6968 items, 60-second timeout)
**Symptom:** After first run seeded 268 jobs into Jobs DB, second run produced 6968 items and timed out
**Cause:** Connection chain was `Trigger → Read Jobs DB (268 rows) → Read Company List`. n8n fired Read Company List once per DB row → 268 × 26 = 6968 items into Fetch Filter Dedup
**Fix:** Fan-out from Schedule Trigger to both nodes simultaneously. Read Jobs DB is now a dead-end with no outgoing connection. Read Company List always receives exactly 1 trigger item and always produces 26 items regardless of DB size.

### Bug 4: Filter placeholders never replaced
**Symptom:** Workflow returned "No output data" — Fetch Filter Dedup matched zero jobs
**Cause:** Filter configuration constants still had `YOUR_FILTER_KEYWORD` placeholder values. No job title ever contains that string.
**Fix:** Bake actual keyword values into the file before export. The constants are now the real values.

---

## Placeholder Reference

After importing into n8n, replace these before activating:

| Placeholder | Location | Replace With |
|---|---|---|
| `YOUR_EMAIL` | Build Email Code node | Your email address |
| `YOUR_JOBS_DB_SHEET_ID` | Read Jobs DB, Append New Jobs | Google Sheet ID of Jobs DB |
| `YOUR_JOBS_DB_TAB_NAME` | Read Jobs DB, Append New Jobs | Tab name within that sheet |
| `YOUR_COMPANY_LIST_SHEET_ID` | Read Company List | Google Sheet ID of Company List |
| `YOUR_COMPANY_LIST_TAB_NAME` | Read Company List | Tab name within that sheet |
| `REPLACE_CREDENTIAL_ID` | All Google Sheets nodes | Select your OAuth2 credential |
| `REPLACE_CREDENTIAL_ID` | Send Email node | Select your Gmail OAuth2 credential |

---

## Files in This Folder

| File | Status | Notes |
|---|---|---|
| `new-job-openings-v2.json` | **Active** | Import this one |
| `archive/new-job-openings.json` | Superseded | Original v1 Workflow 2 — kept for reference |
| `archive/PermDB_clean.json` | Superseded | Original v1 Workflow 1 (seeder) — kept for reference |
| `archive/README_v1.md` | Superseded | Original v1 user-facing README |
| `README.md` | Active | User setup guide |
| `BUILD_PROCESS.md` | Active | This file |
| `CLAUDE.md` | Active | Claude Code context for this project |
