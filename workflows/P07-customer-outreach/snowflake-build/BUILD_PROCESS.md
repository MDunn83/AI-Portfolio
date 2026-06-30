# P07 Snowflake Build, Architecture and Build Process

Version 0.1 (spec) | June 2026

How the Snowflake build of P07 is structured: the dimension table, the audit fact table, the view that does the suppression and trigger logic in SQL, and the n8n nodes that change. Assumes you know the original P07 pipeline (see `../claude-code-build/BUILD_PROCESS.md`).

---

## The shape of it

The original P07 keeps a Customer sheet and an Activity Log sheet, and does the suppression window and the priority cascade inside n8n Code nodes. This build moves all of that into Snowflake:

```
CORE.CUSTOMER              customer master                    (dimension)
   -> CORE.V_CUSTOMER_TRIGGER   suppression + trigger in SQL  (analytical view)
   -> n8n reads the view, generates the email per category    (orchestration + LLM)
   -> CORE.ACTIVITY_LOG       every touch, append-only         (audit fact)
   -> UPDATE CORE.CUSTOMER    last-contacted write-back        (feeds next run's suppression)
```

The interesting move is the view. Trigger detection over customer events is exactly what analytical SQL is for: date math, a priority CASE, a windowed suppression check. Pushing it into the view is what makes this look like customer-data engineering rather than an automation that happens to touch a database.

---

## Tables

| Object | Type | Job |
|---|---|---|
| `CX_DB.CORE.CUSTOMER` | dimension | One row per customer. The master record. n8n updates `LAST_CONTACTED_DATE`. |
| `CX_DB.CORE.ACTIVITY_LOG` | fact (append-only) | One row per touch, including suppressions and no-actions. The audit trail. |
| `CX_DB.CORE.V_CUSTOMER_TRIGGER` | view | Computes suppression and the matched trigger per customer. n8n reads this. |

---

## Table DDL

Full script is `setup.sql`. Names are placeholders.

```sql
CREATE TABLE IF NOT EXISTS CX_DB.CORE.CUSTOMER (
  CUSTOMER_ID            STRING PRIMARY KEY,
  CUSTOMER_NAME          STRING,
  COMPANY                STRING,
  EMAIL                  STRING,
  LAST_CONTACTED_DATE    DATE,
  SUPPORT_TICKET_CLOSED  TIMESTAMP_NTZ,
  LAST_ACTIVITY_DATE     DATE,
  RENEWAL_DATE           DATE,
  MILESTONE_REACHED      BOOLEAN
);

CREATE TABLE IF NOT EXISTS CX_DB.CORE.ACTIVITY_LOG (
  LOG_ID           STRING DEFAULT UUID_STRING(),
  LOG_TS           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  CUSTOMER_ID      STRING,
  CUSTOMER_NAME    STRING,
  COMPANY          STRING,
  TRIGGER_TYPE     STRING,    -- Ticket | Inactivity | Renewal | Milestone | Suppressed | No Action
  EMAIL_SENT       BOOLEAN,
  MESSAGE_PREVIEW  STRING
);
```

---

## The view (suppression and priority cascade in SQL)

This is the heart of the build. It expresses the original's Code-node logic as one declarative query: suppression first, then the four triggers in priority order, else No Action.

```sql
CREATE OR REPLACE VIEW CX_DB.CORE.V_CUSTOMER_TRIGGER AS
SELECT
  CUSTOMER_ID,
  CUSTOMER_NAME,
  COMPANY,
  EMAIL,
  -- 7-day cooldown: suppressed when contacted within the last 7 days.
  (LAST_CONTACTED_DATE IS NOT NULL
     AND DATEDIFF('day', LAST_CONTACTED_DATE, CURRENT_DATE) < 7) AS SUPPRESSED,
  -- Days-since values the email prompts need, computed once here.
  DATEDIFF('day', LAST_ACTIVITY_DATE, CURRENT_DATE)  AS DAYS_INACTIVE,
  DATEDIFF('day', CURRENT_DATE, RENEWAL_DATE)        AS DAYS_TO_RENEWAL,
  -- Priority cascade. First match wins, top to bottom.
  CASE
    WHEN (LAST_CONTACTED_DATE IS NOT NULL
          AND DATEDIFF('day', LAST_CONTACTED_DATE, CURRENT_DATE) < 7)
      THEN 'Suppressed'
    WHEN SUPPORT_TICKET_CLOSED IS NOT NULL
          AND DATEDIFF('hour', SUPPORT_TICKET_CLOSED, CURRENT_TIMESTAMP()) <= 24
      THEN 'Ticket'
    WHEN LAST_ACTIVITY_DATE IS NOT NULL
          AND DATEDIFF('day', LAST_ACTIVITY_DATE, CURRENT_DATE) > 14
      THEN 'Inactivity'
    WHEN RENEWAL_DATE IS NOT NULL
          AND DATEDIFF('day', CURRENT_DATE, RENEWAL_DATE) BETWEEN 0 AND 30
      THEN 'Renewal'
    WHEN MILESTONE_REACHED = TRUE
      THEN 'Milestone'
    ELSE 'No Action'
  END AS TRIGGER_TYPE
FROM CX_DB.CORE.CUSTOMER;
```

The `DAYS_INACTIVE` and `DAYS_TO_RENEWAL` columns are pre-computed in the view so the email prompts get the number directly, instead of n8n doing Luxon date math. This mirrors the lessons-learned rule "pass calculated values, not raw inputs," now done in SQL.

n8n reads this with a single query and branches on `TRIGGER_TYPE`:

```sql
SELECT * FROM CX_DB.CORE.V_CUSTOMER_TRIGGER;
```

Customers with `TRIGGER_TYPE IN ('Suppressed','No Action')` skip email generation and go straight to a log write. The rest go to the matching per-category prompt.

---

## Audit write and last-contacted write-back

Logging every touch is one insert per customer, run by n8n after it decides the outcome:

```sql
INSERT INTO CX_DB.CORE.ACTIVITY_LOG
  (CUSTOMER_ID, CUSTOMER_NAME, COMPANY, TRIGGER_TYPE, EMAIL_SENT, MESSAGE_PREVIEW)
VALUES (?, ?, ?, ?, ?, ?);
```

After a real send, write the contact date back so next run's suppression sees it:

```sql
UPDATE CX_DB.CORE.CUSTOMER
SET LAST_CONTACTED_DATE = CURRENT_DATE
WHERE CUSTOMER_ID = ?;
```

The fact table is append-only on purpose. It is the complete record of who was contacted and, just as importantly, who was deliberately not (the Suppressed and No Action rows). That "we logged the customers we chose not to email" detail is the audit-trail story worth keeping.

---

## What changes in the n8n workflow

| Original node | Becomes |
|---|---|
| Get Customers (Sheets read) | Snowflake Execute Query: `SELECT * FROM CORE.V_CUSTOMER_TRIGGER`. |
| Suppression Code node | Removed. Suppression is the `SUPPRESSED` flag / `TRIGGER_TYPE = 'Suppressed'` in the view. |
| Categorization Code node (priority cascade) | Removed. The view's CASE does it. n8n just branches on `TRIGGER_TYPE`. |
| Days-inactive / days-to-renewal date math | Removed. Pre-computed columns in the view. |
| Per-category LLM prompts + subjects | Unchanged. Still in n8n. |
| Append to Activity Log (Sheets) | Snowflake Execute Query: the INSERT above. |
| Update Last Contacted (Sheets) | Snowflake Execute Query: the UPDATE above. |

Everything LLM and email stays in n8n. Everything data and decision moves to Snowflake.

### n8n Snowflake node gotchas to verify on build

- The Snowflake node operation is Execute Query. Parameterize the INSERT and UPDATE rather than string-building SQL with customer fields, both for safety and to avoid quoting bugs on names with apostrophes.
- Read the view once at the top of the run, then drive the per-customer branches off that result set, the same shape as the original's single Customer read.
- `DATEDIFF` argument order matters: `DATEDIFF('day', start, end)` is end minus start. `LAST_CONTACTED_DATE -> CURRENT_DATE` gives days since contact; `CURRENT_DATE -> RENEWAL_DATE` gives days until renewal. The view above is written in that direction; verify against a test row.
- Dates loaded from a sheet can arrive as strings. When seeding `CORE.CUSTOMER`, cast with `TRY_TO_DATE` / `TRY_TO_TIMESTAMP_NTZ` so a bad cell lands as NULL instead of failing the load.

---

## Optional extension: Cortex for the email body

The per-category prompts could move into the warehouse with `SNOWFLAKE.CORTEX.COMPLETE`, generating the email body in SQL alongside the trigger decision. Left out of v1 on purpose: the prompts already work in n8n, and keeping generation there keeps the build honest about what moved (the data and the decision logic) versus what did not. Worth doing later as a "now the whole thing runs in-warehouse" follow-up, and it pairs naturally with the P02 Cortex work.

---

## Why this design

- **A dimension and a fact, not two flat sheets.** Naming the customer master a dimension and the activity log an append-only fact is the standard warehouse modeling vocabulary, and it fits the data exactly.
- **Decision logic in a view.** Suppression and the priority cascade are analytical questions about customer state over time. SQL with `DATEDIFF` and a CASE is the native way to ask them, and it moves the logic out of imperative Code nodes into a declarative model anyone can read.
- **The audit fact keeps the non-contacts.** Logging suppressions and no-actions as first-class rows is the part that reads as governance, not just "we sent some emails."

---

## Reference

- Goal, scope, acceptance criteria: `./REQUIREMENTS.md`
- Setup and run: `./README.md`
- Original pipeline this mirrors: `../claude-code-build/BUILD_PROCESS.md`
