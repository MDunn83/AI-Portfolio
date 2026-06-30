# P02 Snowflake Build, Architecture and Build Process

Version 0.1 (spec) | June 2026

This documents how the Snowflake build of the P02 monitor is structured: the schema layers, the table DDL, the SQL that does the work, the Cortex classification step, and the specific n8n nodes that change. It assumes you already know the original P02 pipeline (see `../claude-code-build/BUILD_PROCESS.md`).

---

## The shape of it

The original P02 logs every signal to a flat Google Sheet. This build replaces that one sheet with a three-layer warehouse pattern, the same shape a commercial data team uses:

```
RSS fetch (n8n)
   -> RAW.SIGNAL_LANDING      raw article JSON, append-only      (the lake / landing zone)
   -> transform (SQL MERGE)   flatten, type, dedup on URL        (the T in ELT)
   -> CORE.SIGNAL             modeled, typed, deduplicated fact   (the warehouse)
   -> Cortex classify         8-type label + funding + summary   (AI in the warehouse)
   -> briefing query          included signals for the run        (read model)
   -> retention Task          delete rows older than 7 days       (housekeeping)
```

n8n stays the orchestrator. Snowflake becomes the data layer. Every Snowflake interaction is a SQL statement run through the n8n Snowflake node (Execute Query).

---

## Schema layers

| Layer | Object | Job |
|---|---|---|
| RAW | `CI_DB.RAW.SIGNAL_LANDING` | Landing zone. Raw article object as VARIANT plus load metadata. Append-only, schema-on-read. |
| transform | `CI_DB.CORE.SP_LOAD_SIGNALS` (or an inline MERGE) | Flatten the VARIANT, apply the 48h window, MERGE into CORE.SIGNAL on SIGNAL_URL. |
| CORE | `CI_DB.CORE.SIGNAL` | Modeled fact table. One row per unique signal. This is the log and the read model. |

`RAW` holds everything the workflow saw, including duplicates and rows that later get excluded. `CORE` holds the clean, deduplicated, classified truth. Keeping the two separate is the whole point: the lake is the audit record, the warehouse is the model you query.

---

## Table DDL

All of this lives in `setup.sql` in this folder. Names are placeholders; change `CI_DB`, `CI_WH`, `CI_USER` to taste.

```sql
-- Warehouse: extra-small, suspend fast to protect trial credits.
CREATE WAREHOUSE IF NOT EXISTS CI_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS CI_DB;
CREATE SCHEMA IF NOT EXISTS CI_DB.RAW;
CREATE SCHEMA IF NOT EXISTS CI_DB.CORE;

-- Landing zone (the lake). One row per fetched article, raw.
CREATE TABLE IF NOT EXISTS CI_DB.RAW.SIGNAL_LANDING (
  LANDING_ID   STRING DEFAULT UUID_STRING(),
  RAW          VARIANT,                 -- the article object exactly as fetched
  SOURCE       STRING,                  -- 'google_news_rss'
  LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Modeled fact (the warehouse). One row per unique signal URL.
CREATE TABLE IF NOT EXISTS CI_DB.CORE.SIGNAL (
  SIGNAL_URL        STRING PRIMARY KEY,  -- dedup key
  COMPANY_NAME      STRING,
  SIGNAL_TITLE      STRING,
  SIGNAL_TYPE       STRING,              -- one of the 8 categories, set by Cortex
  SUMMARY           STRING,              -- Cortex 1-2 sentence summary
  PUB_DATE          TIMESTAMP_NTZ,
  FUNDING_MUSD      NUMBER(12,2),        -- parsed funding in millions, NULL if N/A
  BRIEFING_INCLUDED BOOLEAN,
  LOGGED_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

`SIGNAL_URL` as the primary key is what makes dedup a one-line MERGE instead of a JavaScript Set rebuilt every run.

---

## The transform (flatten, type, dedup)

This is the step that earns the "ELT" claim. n8n has already dropped the raw articles into the landing zone; this MERGE pulls them forward into the model. It flattens the VARIANT, applies the recency window, and inserts only URLs not already present.

```sql
MERGE INTO CI_DB.CORE.SIGNAL AS tgt
USING (
  SELECT
    RAW:url::STRING            AS SIGNAL_URL,
    RAW:company::STRING        AS COMPANY_NAME,
    RAW:title::STRING          AS SIGNAL_TITLE,
    TRY_TO_TIMESTAMP_NTZ(RAW:pubDate::STRING) AS PUB_DATE
  FROM CI_DB.RAW.SIGNAL_LANDING
  WHERE LOAD_TS >= DATEADD('hour', -48, CURRENT_TIMESTAMP())
    AND RAW:url IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY RAW:url::STRING ORDER BY LOAD_TS DESC) = 1
) AS src
ON tgt.SIGNAL_URL = src.SIGNAL_URL
WHEN NOT MATCHED THEN INSERT
  (SIGNAL_URL, COMPANY_NAME, SIGNAL_TITLE, PUB_DATE)
  VALUES (src.SIGNAL_URL, src.COMPANY_NAME, src.SIGNAL_TITLE, src.PUB_DATE);
```

The `QUALIFY ROW_NUMBER()` collapses intra-batch duplicate URLs to one row before the MERGE even runs. The `WHEN NOT MATCHED` clause is the cross-run dedup: a URL already in CORE.SIGNAL from a prior run is skipped.

---

## In-warehouse classification (Cortex)

New CORE.SIGNAL rows arrive with `SIGNAL_TYPE`, `SUMMARY`, and `FUNDING_MUSD` still NULL. One SQL pass fills them using Snowflake Cortex, so the LLM runs against the data in place. This is the line that turns "I moved data into Snowflake" into "I ran AI inside the warehouse."

Classification with `CLASSIFY_TEXT` (clean, returns one of a fixed label set):

```sql
UPDATE CI_DB.CORE.SIGNAL
SET SIGNAL_TYPE = SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
      SIGNAL_TITLE,
      ['Product Launch','Partnership','Funding','Leadership Change',
       'Research Publication','Hiring Signal','Regulatory/Legal','Other']
    ):label::STRING
WHERE SIGNAL_TYPE IS NULL;
```

Summary and funding extraction with `COMPLETE` (free-form, asked to return JSON, parsed with `PARSE_JSON`):

```sql
UPDATE CI_DB.CORE.SIGNAL
SET SUMMARY = resp:summary::STRING,
    FUNDING_MUSD = TRY_TO_NUMBER(resp:funding_musd::STRING)
FROM (
  SELECT SIGNAL_URL,
         PARSE_JSON(
           SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
             'Return ONLY JSON {"summary":"1-2 sentences","funding_musd":<number or null>} for: '
             || SIGNAL_TITLE)
         ) AS resp
  FROM CI_DB.CORE.SIGNAL
  WHERE SUMMARY IS NULL
) s
WHERE CI_DB.CORE.SIGNAL.SIGNAL_URL = s.SIGNAL_URL;
```

Model availability (`llama3.1-8b`, `mistral-large`, others) and Cortex availability vary by Snowflake region; the setup README covers checking your region. The lessons-learned rules about dirty LLM output still apply: `PARSE_JSON` can fail on a fenced or chatty response, so keep the prompt strict ("Return ONLY JSON") and wrap the parse in `TRY_PARSE_JSON` if a run shows malformed rows.

If Cortex is not available in your trial region, the documented fallback is to keep the existing Groq classifier in n8n and write its output back to CORE.SIGNAL with an UPDATE. The warehouse pattern is identical; only the classifier call moves.

---

## Inclusion rule and briefing query

The $100M Funding rule and the briefing read are pure SQL now:

```sql
-- Set the inclusion flag (existing rules, expressed in SQL).
UPDATE CI_DB.CORE.SIGNAL
SET BRIEFING_INCLUDED = CASE
      WHEN SIGNAL_TYPE = 'Other' THEN FALSE
      WHEN SIGNAL_TYPE = 'Funding' AND COALESCE(FUNDING_MUSD,0) >= 100 THEN TRUE
      WHEN SIGNAL_TYPE = 'Funding' THEN FALSE
      ELSE TRUE
    END
WHERE BRIEFING_INCLUDED IS NULL;

-- The briefing read: included signals from this run window.
SELECT COMPANY_NAME, SIGNAL_TYPE, SIGNAL_TITLE, SUMMARY, FUNDING_MUSD
FROM CI_DB.CORE.SIGNAL
WHERE BRIEFING_INCLUDED = TRUE
  AND LOGGED_TS >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY (SIGNAL_TYPE = 'Funding') DESC, FUNDING_MUSD DESC NULLS LAST;
```

n8n takes that result set and either runs synthesis (Cortex `COMPLETE` or Groq, your choice) or, if the set is empty, falls through to the existing "no news" email path. The one-email-per-run guarantee is unchanged: an empty result still sends the no-news note.

---

## Retention

```sql
-- Run as a per-run step, or schedule it as a Task.
DELETE FROM CI_DB.CORE.SIGNAL
WHERE LOGGED_TS < DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Optional: same delete as a serverless Task (no warehouse needed to keep it on).
CREATE TASK IF NOT EXISTS CI_DB.CORE.PRUNE_SIGNALS
  SCHEDULE = 'USING CRON 0 7 * * * UTC'
  AS DELETE FROM CI_DB.CORE.SIGNAL
     WHERE LOGGED_TS < DATEADD('day', -7, CURRENT_TIMESTAMP());
-- ALTER TASK CI_DB.CORE.PRUNE_SIGNALS RESUME;  -- Tasks are created suspended.
```

A landing-zone retention delete (`RAW.SIGNAL_LANDING` older than a few days) belongs here too, so the lake does not grow without bound on the trial.

---

## What changes in the n8n workflow

Most of the original P02 graph is untouched: triggers, Config, the RSS fetch, the relevance pre-filter, the no-news sentinel, the email send. The data nodes are what swap out.

| Original node | Becomes |
|---|---|
| Get Log (Sheets read) | Removed. Dedup now lives in the transform MERGE, not a Set built in n8n. |
| Filter & Dedup (JS Set) | Slimmed to just the relevance pass and the no-news sentinel. The URL dedup moves to SQL. |
| (new) Land Raw | Snowflake Execute Query: `INSERT INTO RAW.SIGNAL_LANDING (RAW, SOURCE) SELECT PARSE_JSON(?), 'google_news_rss'`, one call carrying the batch of articles as JSON. |
| (new) Transform | Snowflake Execute Query: the MERGE above. |
| Classify (Groq chainLlm) | Snowflake Execute Query: the Cortex UPDATEs. (Or kept as-is in the fallback path.) |
| Append to Log (Sheets) | Removed. CORE.SIGNAL is the log; the MERGE already wrote it. |
| Get briefing rows | Snowflake Execute Query: the briefing SELECT. |
| Delete Old Log Rows (Sheets) | Snowflake Execute Query: the retention DELETE, or the scheduled Task. |

The Snowflake node uses one credential (account, warehouse, database, schema, user, auth) wired through n8n's credential manager. Sequence the SQL nodes so land, transform, classify, flag, read run in that order; n8n runs them in connection order, same as the original.

### n8n Snowflake node gotchas to verify on build

- The n8n Snowflake node's operation is Execute Query. Multi-statement scripts may not run in one call depending on the node version; if so, split each statement into its own node rather than separating with semicolons.
- Passing a batch of articles as a single VARIANT insert avoids one Snowflake round-trip per article. Build the JSON array in a Code node, then `INSERT ... SELECT PARSE_JSON(?)` once.
- Cortex calls bill tokens against trial credits. Trim `SIGNAL_TITLE` plus description to a fixed length before the COMPLETE call, same token discipline as the Groq build.
- Verify Cortex region availability before wiring the classify nodes (see README). If unavailable, take the Groq fallback path and write results back with an UPDATE.

---

## Why this design

- **Landing zone separate from the model.** The lake keeps everything raw and append-only so there is always a source of truth to re-transform. The warehouse is the clean model. This separation is the single most recognizable data-engineering pattern, and it is honest here because the workflow genuinely captures raw then shapes it.
- **Dedup as a MERGE, not a Set.** The original rebuilds a JavaScript Set from the whole log every run. In a warehouse the primary key plus a MERGE does it in one statement and scales past what a Sheet can hold.
- **Cortex over an external call.** Running classification in-warehouse is the differentiator. Almost nobody pivoting in has touched in-database LLM calls, and it ties the AI story to the data story instead of keeping them separate.
- **Tasks for housekeeping.** Moving retention to a serverless Task shows the scheduling primitive a warehouse gives you that a Sheet never could.

---

## Reference

- Goal, scope, acceptance criteria: `./REQUIREMENTS.md`
- Setup and run: `./README.md`
- Original pipeline this mirrors: `../claude-code-build/BUILD_PROCESS.md`
